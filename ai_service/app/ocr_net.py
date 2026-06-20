"""
CRNN v2 — ResNet CNN + SE Attention + BiLSTM + CTC.

ReceiptLineCRNN (v2):
  - Mỗi stage: Conv→BN→ReLU → ResBlock → SEBlock → MaxPool
  - AdaptiveAvgPool2d((1, None)) cố định height → 1 (không phụ thuộc img_h)
  - BiLSTM 3 lớp hidden=256
  - Backward compat: meta["architecture_version"] = 1 → dùng v1 (4 ConvBlock đơn giản)
"""

from __future__ import annotations

import torch
import torch.nn as nn

from .ocr_charset import (
    AMOUNT_NUM_CLASSES,
    CHAR2IDX,
    CTC_CHARSET,
    IDX2CHAR,
    NUM_CTC_CLASSES,
)

__all__ = [
    "ReceiptLineCRNN",
    "ReceiptLineCRNN_v1",
    "ReceiptAmountCRNN",
    "CTC_CHARSET",
    "CHAR2IDX",
    "IDX2CHAR",
    "NUM_CTC_CLASSES",
]


# ─────────────────────────── v2 building blocks ────────────────────────────

class _SEBlock(nn.Module):
    """Squeeze-and-Excitation channel attention."""

    def __init__(self, ch: int, r: int = 8) -> None:
        super().__init__()
        mid = max(ch // r, 4)
        self.pool = nn.AdaptiveAvgPool2d(1)
        self.fc = nn.Sequential(
            nn.Linear(ch, mid, bias=False),
            nn.ReLU(inplace=True),
            nn.Linear(mid, ch, bias=False),
            nn.Sigmoid(),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        b, c, _, _ = x.shape
        s = self.pool(x).view(b, c)
        return x * self.fc(s).view(b, c, 1, 1)


class _ResBlock(nn.Module):
    """2-conv residual block with optional dropout."""

    def __init__(self, ch: int, dropout: float = 0.1) -> None:
        super().__init__()
        self.net = nn.Sequential(
            nn.Conv2d(ch, ch, 3, padding=1, bias=False),
            nn.BatchNorm2d(ch),
            nn.ReLU(inplace=True),
            nn.Dropout2d(dropout),
            nn.Conv2d(ch, ch, 3, padding=1, bias=False),
            nn.BatchNorm2d(ch),
        )
        self.act = nn.ReLU(inplace=True)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.act(self.net(x) + x)


class _Stage(nn.Module):
    """Conv proj → ResBlock → SE → MaxPool."""

    def __init__(self, in_ch: int, out_ch: int, pool: tuple[int, int], dropout: float) -> None:
        super().__init__()
        self.proj = nn.Sequential(
            nn.Conv2d(in_ch, out_ch, 3, padding=1, bias=False),
            nn.BatchNorm2d(out_ch),
            nn.ReLU(inplace=True),
        )
        self.res = _ResBlock(out_ch, dropout)
        self.se = _SEBlock(out_ch)
        self.pool = nn.MaxPool2d(pool)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.pool(self.se(self.res(self.proj(x))))


# ─────────────────────────── Architecture v2 ───────────────────────────────

class ReceiptLineCRNN(nn.Module):
    """CRNN v2: SE+Res CNN → AdaptivePool → BiLSTM → CTC.

    cnn_channels: tuple mặc định (64, 128, 256, 256)
    pool_schedule: (2,2) (2,2) (1,2) (1,2) — giữ height hợp lý
    Sau CNN: AdaptiveAvgPool2d((1, None)) → height cố định = 1, rnn_in = ch[-1]
    """

    ARCHITECTURE_VERSION = 2

    def __init__(
        self,
        *,
        img_h: int = 48,
        img_w: int = 160,
        cnn_channels: tuple[int, ...] = (64, 128, 256, 256),
        lstm_hidden: int = 256,
        lstm_layers: int = 3,
        num_classes: int = AMOUNT_NUM_CLASSES,
        dropout: float = 0.2,
        width_divisor: int = 16,
    ) -> None:
        super().__init__()
        self.img_h = img_h
        self.img_w = img_w
        self.num_classes = num_classes
        self.width_divisor = width_divisor

        # Số lần giảm chiều rộng = log2(width_divisor). divisor=16 → 4 lần (như cũ);
        # divisor=8 → 3 lần → T (số timestep CTC) GẤP ĐÔI → đủ "khe" cho dòng dài,
        # giảm hiện tượng nuốt ký tự / mất dấu tiếng Việt.
        width_halvings = max(0, width_divisor.bit_length() - 1)
        stages: list[nn.Module] = []
        in_ch = 1
        for i, out_ch in enumerate(cnn_channels):
            ph = 2 if i < 2 else 1                       # chiều cao luôn /4
            pw = 2 if i < width_halvings else 1          # chiều rộng /width_divisor
            stages.append(_Stage(in_ch, out_ch, (ph, pw), dropout * 0.4))
            in_ch = out_ch
        self.cnn = nn.Sequential(*stages)
        self.pool_h = nn.AdaptiveAvgPool2d((1, None))  # collapse height → 1

        rnn_in = cnn_channels[-1]
        self.rnn = nn.LSTM(
            input_size=rnn_in,
            hidden_size=lstm_hidden,
            num_layers=lstm_layers,
            batch_first=True,
            bidirectional=True,
            dropout=dropout if lstm_layers > 1 else 0.0,
        )
        self.drop = nn.Dropout(dropout)
        self.fc = nn.Linear(lstm_hidden * 2, num_classes)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        feat = self.cnn(x)               # (B, C, H', W')
        feat = self.pool_h(feat)         # (B, C, 1, W')
        b, c, _, w = feat.shape
        feat = feat.squeeze(2).permute(0, 2, 1)  # (B, W', C)
        out, _ = self.rnn(feat)
        return self.fc(self.drop(out))   # (B, T, num_classes)


# ─────────────────────────── Architecture v1 (backward compat) ─────────────

class _ConvBlock(nn.Module):
    def __init__(self, in_ch: int, out_ch: int, pool: tuple[int, int] = (2, 2)) -> None:
        super().__init__()
        self.net = nn.Sequential(
            nn.Conv2d(in_ch, out_ch, kernel_size=3, padding=1, bias=False),
            nn.BatchNorm2d(out_ch),
            nn.ReLU(inplace=True),
            nn.MaxPool2d(pool),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.net(x)


class ReceiptLineCRNN_v1(nn.Module):
    """CRNN v1 (cũ) — load checkpoint cũ (architecture_version=1)."""

    ARCHITECTURE_VERSION = 1

    def __init__(
        self,
        *,
        img_h: int = 32,
        img_w: int = 160,
        cnn_channels: tuple[int, ...] = (32, 64, 128, 256),
        lstm_hidden: int = 128,
        lstm_layers: int = 2,
        num_classes: int = AMOUNT_NUM_CLASSES,
        dropout: float = 0.15,
    ) -> None:
        super().__init__()
        self.img_h = img_h
        self.img_w = img_w
        self.num_classes = num_classes

        blocks: list[nn.Module] = []
        in_ch = 1
        for i, out_ch in enumerate(cnn_channels):
            pool = (2, 2) if i < 2 else (1, 2)
            blocks.append(_ConvBlock(in_ch, out_ch, pool=pool))
            in_ch = out_ch
        self.cnn = nn.Sequential(*blocks)

        self._cnn_out_ch = cnn_channels[-1]
        self._feat_h = max(1, img_h // 4)
        rnn_in = self._cnn_out_ch * self._feat_h

        self.rnn = nn.LSTM(
            input_size=rnn_in,
            hidden_size=lstm_hidden,
            num_layers=lstm_layers,
            batch_first=True,
            bidirectional=True,
            dropout=dropout if lstm_layers > 1 else 0.0,
        )
        self.drop = nn.Dropout(dropout)
        self.fc = nn.Linear(lstm_hidden * 2, num_classes)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        feat = self.cnn(x)
        b, c, h, w = feat.shape
        feat = feat.permute(0, 3, 1, 2).contiguous().view(b, w, c * h)
        out, _ = self.rnn(feat)
        return self.fc(self.drop(out))


ReceiptAmountCRNN = ReceiptLineCRNN
