"""
Dự báo chi tiêu — kiến trúc tự xây dựng, không dùng pretrained model.

SpendingForecastTransformer: Transformer phi-hồi quy (NON-AUTOREGRESSIVE)
  - Dự báo tất cả horizon bước SONG SONG, không tích luỹ lỗi qua các bước.
  - Toàn bộ các submodule (MultiHeadSelfAttn, MultiHeadCrossAttn, FFN,
    EncoderBlock, DecoderBlock) được xây dựng từ đầu bằng nn.Linear + math.

Luồng chuẩn hóa:
  VND → log1p → z-score toàn cục (training stats)
  → instance norm theo cửa sổ (trong model)
  → encoder / decoder → undo instance norm
  → output z-score toàn cục → inference denorm → VND
"""

from __future__ import annotations

import math

import torch
import torch.nn as nn
import torch.nn.functional as F

__all__ = ["SpendingForecastTransformer"]


# ══════════════════════════════════════════════════════════════════════════════
#  Transformer building blocks (xây từ đầu, chỉ dùng nn.Linear + math)
# ══════════════════════════════════════════════════════════════════════════════

class _MultiHeadSelfAttn(nn.Module):
    """Multi-head self-attention.

    Cho chuỗi x: (B, T, d_model) → output: (B, T, d_model).
    Tất cả T token attend lẫn nhau (không có causal mask).
    """

    def __init__(self, d_model: int, n_heads: int, dropout: float) -> None:
        super().__init__()
        if d_model % n_heads != 0:
            raise ValueError(f"d_model ({d_model}) phải chia hết cho n_heads ({n_heads})")
        self.h     = n_heads
        self.d_k   = d_model // n_heads
        self.scale = self.d_k ** -0.5
        self.W_qkv = nn.Linear(d_model, 3 * d_model, bias=False)
        self.W_out = nn.Linear(d_model, d_model)
        self.drop  = nn.Dropout(dropout)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        B, T, _ = x.shape
        qkv = self.W_qkv(x).view(B, T, 3, self.h, self.d_k).permute(2, 0, 3, 1, 4)
        Q, K, V = qkv[0], qkv[1], qkv[2]
        scores = (Q @ K.transpose(-2, -1)) * self.scale
        w      = self.drop(F.softmax(scores, dim=-1))
        out    = (w @ V).transpose(1, 2).reshape(B, T, -1)
        return self.W_out(out)


class _MultiHeadCrossAttn(nn.Module):
    """Multi-head cross-attention.

    Query từ x: (B, Tq, d), Key/Value từ context: (B, Tk, d).
    Dùng cho decoder để attend vào toàn bộ encoder output.
    """

    def __init__(self, d_model: int, n_heads: int, dropout: float) -> None:
        super().__init__()
        if d_model % n_heads != 0:
            raise ValueError(f"d_model ({d_model}) phải chia hết cho n_heads ({n_heads})")
        self.h     = n_heads
        self.d_k   = d_model // n_heads
        self.scale = self.d_k ** -0.5
        self.W_q   = nn.Linear(d_model, d_model, bias=False)
        self.W_kv  = nn.Linear(d_model, 2 * d_model, bias=False)
        self.W_out = nn.Linear(d_model, d_model)
        self.drop  = nn.Dropout(dropout)

    def forward(self, x: torch.Tensor, ctx: torch.Tensor) -> torch.Tensor:
        B, Tq, _ = x.shape
        _, Tk, _ = ctx.shape
        Q  = self.W_q(x).view(B, Tq, self.h, self.d_k).transpose(1, 2)
        kv = self.W_kv(ctx).view(B, Tk, 2, self.h, self.d_k).permute(2, 0, 3, 1, 4)
        K, V   = kv[0], kv[1]
        scores = (Q @ K.transpose(-2, -1)) * self.scale
        w      = self.drop(F.softmax(scores, dim=-1))
        out    = (w @ V).transpose(1, 2).reshape(B, Tq, -1)
        return self.W_out(out)


class _FFN(nn.Module):
    """Position-wise Feed-Forward Network: Linear → GELU → Dropout → Linear."""

    def __init__(self, d_model: int, d_ff: int, dropout: float) -> None:
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(d_model, d_ff),
            nn.GELU(),
            nn.Dropout(dropout),
            nn.Linear(d_ff, d_model),
            nn.Dropout(dropout),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.net(x)


class _EncoderBlock(nn.Module):
    """Encoder block: Self-Attention → Add&Norm → FFN → Add&Norm."""

    def __init__(self, d_model: int, n_heads: int, d_ff: int, dropout: float) -> None:
        super().__init__()
        self.attn  = _MultiHeadSelfAttn(d_model, n_heads, dropout)
        self.ff    = _FFN(d_model, d_ff, dropout)
        self.norm1 = nn.LayerNorm(d_model)
        self.norm2 = nn.LayerNorm(d_model)
        self.drop  = nn.Dropout(dropout)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        x = self.norm1(x + self.drop(self.attn(x)))
        x = self.norm2(x + self.drop(self.ff(x)))
        return x


class _DecoderBlock(nn.Module):
    """Decoder block (phi-hồi quy / non-autoregressive):
        Self-Attention (horizon steps attend nhau) →
        Cross-Attention (attend past encoder) →
        FFN → mỗi bước Add&Norm.
    """

    def __init__(self, d_model: int, n_heads: int, d_ff: int, dropout: float) -> None:
        super().__init__()
        self.self_attn  = _MultiHeadSelfAttn(d_model, n_heads, dropout)
        self.cross_attn = _MultiHeadCrossAttn(d_model, n_heads, dropout)
        self.ff         = _FFN(d_model, d_ff, dropout)
        self.norm1 = nn.LayerNorm(d_model)
        self.norm2 = nn.LayerNorm(d_model)
        self.norm3 = nn.LayerNorm(d_model)
        self.drop  = nn.Dropout(dropout)

    def forward(self, x: torch.Tensor, enc: torch.Tensor) -> torch.Tensor:
        x = self.norm1(x + self.drop(self.self_attn(x)))
        x = self.norm2(x + self.drop(self.cross_attn(x, enc)))
        x = self.norm3(x + self.drop(self.ff(x)))
        return x


# ══════════════════════════════════════════════════════════════════════════════
#  SpendingForecastTransformer — kiến trúc chính
# ══════════════════════════════════════════════════════════════════════════════

class SpendingForecastTransformer(nn.Module):
    """
    Transformer phi-hồi quy cho dự báo chi tiêu hàng ngày.

    Kiến trúc (xây dựng từ đầu, không dùng pretrained):
    ┌────────────────────────────────────────────────────────────────────────┐
    │ ENCODER (chuỗi lịch sử – window bước)                                 │
    │   past (amount + lịch + share) → Linear → + pos_enc                   │
    │   → N_ENC_LAYERS × EncoderBlock (Self-Attention + FFN + LayerNorm)    │
    │                                                                        │
    │ DECODER (tương lai – horizon bước, PHI-HỒI QUY)                      │
    │   future (lịch + share) → Linear → + pos_enc                          │
    │   → N_DEC_LAYERS × DecoderBlock:                                      │
    │       ① Self-Attention  (horizon bước attend lẫn nhau)                │
    │       ② Cross-Attention (← encoder memory: attend 30 bước lịch sử)   │
    │       ③ FFN + LayerNorm                                                │
    │   → Linear → (B, H) dự báo SONG SONG                                  │
    └────────────────────────────────────────────────────────────────────────┘

    Ưu điểm so với LSTM Seq2Seq:
    • Phi-hồi quy: 7 bước sinh đồng thời → KHÔNG tích luỹ lỗi autoregressive.
    • Global attention: decoder thấy TOÀN BỘ chuỗi lịch sử (không chỉ cuối).
    • Learnable positional encoding: tối ưu cho chuỗi ngắn (30/7 bước).
    • GELU + Post-LayerNorm: ổn định và hiệu quả khi huấn luyện.
    """

    def __init__(
        self,
        *,
        window: int,
        horizon: int,
        input_size: int,             # 1 amount + N_TIME_AND_CAT
        d_model: int = 64,
        n_heads: int = 4,
        n_enc_layers: int = 3,
        n_dec_layers: int = 2,
        d_ff: int = 256,
        dropout: float = 0.10,
        use_instance_norm: bool = True,
        inst_norm_recent_k: int = 14,
    ) -> None:
        super().__init__()
        self.window             = window
        self.horizon            = horizon
        self.input_size         = input_size
        self.use_instance_norm  = use_instance_norm
        self.inst_norm_recent_k = max(1, min(inst_norm_recent_k, window))

        # ── Encoder ──────────────────────────────────────────────────────
        self.enc_proj = nn.Linear(input_size, d_model)
        self.enc_pos  = nn.Parameter(torch.zeros(1, window, d_model))

        self.enc_blocks = nn.ModuleList([
            _EncoderBlock(d_model, n_heads, d_ff, dropout)
            for _ in range(n_enc_layers)
        ])
        self.enc_norm = nn.LayerNorm(d_model)

        # ── Decoder ──────────────────────────────────────────────────────
        # future input: không có kênh amount → (input_size - 1) đặc trưng
        self.dec_proj = nn.Linear(input_size - 1, d_model)
        self.dec_pos  = nn.Parameter(torch.zeros(1, horizon, d_model))

        self.dec_blocks = nn.ModuleList([
            _DecoderBlock(d_model, n_heads, d_ff, dropout)
            for _ in range(n_dec_layers)
        ])
        self.dec_norm = nn.LayerNorm(d_model)

        # ── Output ───────────────────────────────────────────────────────
        self.head = nn.Linear(d_model, 1)

        nn.init.trunc_normal_(self.enc_pos, std=0.02)
        nn.init.trunc_normal_(self.dec_pos, std=0.02)

    # ── Instance normalisation (RevIN-style) ─────────────────────────────
    def _inst_norm(
        self, x: torch.Tensor
    ) -> tuple[torch.Tensor, torch.Tensor, torch.Tensor]:
        """Chuẩn hoá kênh amount (index 0) theo recent_k bước cuối cửa sổ."""
        amt    = x[:, :, 0:1]
        anchor = amt[:, -self.inst_norm_recent_k:, :]
        mu     = anchor.mean(dim=1, keepdim=True)
        sig    = (anchor.var(dim=1, keepdim=True, unbiased=False) + 1e-6).sqrt()
        amt_n  = (amt - mu) / sig
        x_n    = torch.cat([amt_n, x[:, :, 1:]], dim=-1)
        return x_n, mu, sig

    # ── Forward ───────────────────────────────────────────────────────────
    def forward(
        self,
        x: torch.Tensor,                                # (B, W, F)
        decoder_time_feats: torch.Tensor | None = None, # (B, H, F-1)
        y_target: torch.Tensor | None = None,           # không dùng (phi-hồi quy)
        teacher_forcing_ratio: float = 0.0,              # không dùng (phi-hồi quy)
    ) -> torch.Tensor:                                  # (B, H)
        """
        x                 : (B, W, F)   — encoder input (global z-score space).
        decoder_time_feats: (B, H, F-1) — lịch + share cho H bước tương lai.
        Returns           : (B, H)      — dự báo trong global z-score space.
        """
        del y_target, teacher_forcing_ratio

        if decoder_time_feats is None:
            raise ValueError(
                "SpendingForecastTransformer cần decoder_time_feats (B, H, F-1)"
            )

        B = x.size(0)

        # ── Bước 1: Instance norm kênh amount ────────────────────────────
        if self.use_instance_norm:
            x_in, inst_mu, inst_sig = self._inst_norm(x)
        else:
            x_in, inst_mu, inst_sig = x, None, None

        # ── Bước 2: Encoder (self-attention trên chuỗi lịch sử) ─────────
        enc = self.enc_proj(x_in) + self.enc_pos
        for blk in self.enc_blocks:
            enc = blk(enc)
        enc = self.enc_norm(enc)                        # (B, W, d_model)

        # ── Bước 3: Decoder (cross-attention, phi-hồi quy) ──────────────
        dec = self.dec_proj(decoder_time_feats) + self.dec_pos
        for blk in self.dec_blocks:
            dec = blk(dec, enc)
        dec = self.dec_norm(dec)                        # (B, H, d_model)

        # ── Bước 4: Dự báo + undo instance norm ─────────────────────────
        y_inst = self.head(dec).squeeze(-1)             # (B, H)
        if inst_mu is not None:
            y_out = y_inst * inst_sig.view(B, 1) + inst_mu.view(B, 1)
        else:
            y_out = y_inst
        return y_out
