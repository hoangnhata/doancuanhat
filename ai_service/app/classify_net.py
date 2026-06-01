"""
Kiến trúc from-scratch: CharCNN + BiLSTM + Attention (không pretrained).
"""
from __future__ import annotations

import torch
import torch.nn as nn
import torch.nn.functional as F


class AttentionPool(nn.Module):
    """Attention theo thời gian (LSTM outputs)."""

    def __init__(self, hidden_dim: int):
        super().__init__()
        self.proj = nn.Linear(hidden_dim, 1)

    def forward(self, h: torch.Tensor, mask: torch.Tensor) -> torch.Tensor:
        # h: (B, L, H), mask: (B, L) 1=valid 0=pad
        # fp32: AMP fp16 không chứa được -1e9 trong masked_fill
        h = h.float()
        scores = self.proj(h).squeeze(-1)
        if mask.size(1) != scores.size(1):
            if mask.size(1) > scores.size(1):
                mask = mask[:, : scores.size(1)]
            else:
                mask = F.pad(mask, (0, scores.size(1) - mask.size(1)), value=0)
        scores = scores.masked_fill(mask == 0, -1e4)
        weights = F.softmax(scores, dim=-1)
        return torch.bmm(weights.unsqueeze(1), h).squeeze(1)


class CharCNNBiLSTMAttn(nn.Module):
    """
    Embedding ký tự → CNN n-gram → BiLSTM ngữ cảnh → Attention → FC phân loại.
    """

    def __init__(
        self,
        vocab_size: int,
        num_classes: int,
        embed_dim: int = 96,
        num_filters: int = 64,
        kernel_sizes: list[int] | None = None,
        lstm_hidden: int = 128,
        lstm_layers: int = 1,
        dropout: float = 0.35,
        pad_idx: int = 0,
    ):
        super().__init__()
        if kernel_sizes is None:
            kernel_sizes = [2, 3, 4, 5, 6]

        self.pad_idx = pad_idx
        self.embedding = nn.Embedding(vocab_size, embed_dim, padding_idx=pad_idx)

        self.convs = nn.ModuleList()
        for k in kernel_sizes:
            self.convs.append(
                nn.Conv1d(embed_dim, num_filters, kernel_size=k, padding=k // 2)
            )
        cnn_out = num_filters * len(kernel_sizes)

        self.lstm = nn.LSTM(
            cnn_out,
            lstm_hidden,
            num_layers=lstm_layers,
            batch_first=True,
            bidirectional=True,
            dropout=dropout if lstm_layers > 1 else 0.0,
        )
        self.attn = AttentionPool(lstm_hidden * 2)
        self.drop = nn.Dropout(dropout)
        self.fc1 = nn.Linear(lstm_hidden * 2, 256)
        self.act = nn.GELU()
        self.fc2 = nn.Linear(256, num_classes)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        # x: (B, L)
        mask = (x != self.pad_idx).long()
        e = self.embedding(x)  # (B, L, E)
        e = e.permute(0, 2, 1)  # (B, E, L)

        feats = [torch.relu(conv(e)) for conv in self.convs]
        min_l = min(f.size(-1) for f in feats)
        feats = [f[..., :min_l] for f in feats]
        h = torch.cat(feats, dim=1).permute(0, 2, 1)  # (B, L', C)

        # Mask phải khớp chiều L' sau CNN (tránh RuntimeError masked_fill)
        seq_len = h.size(1)
        if mask.size(1) > seq_len:
            mask = mask[:, :seq_len]
        elif mask.size(1) < seq_len:
            mask = F.pad(mask, (0, seq_len - mask.size(1)), value=0)

        # BiLSTM: fp32 (AMP fp16 hay lỗi trên Colab T4 / cudnn)
        h, _ = self.lstm(h.float())
        ctx = self.attn(h, mask)
        ctx = self.drop(ctx)
        ctx = self.drop(self.act(self.fc1(ctx.float())))
        return self.fc2(ctx)


# Alias backward-compatible loader
CharTextCNN = CharCNNBiLSTMAttn
