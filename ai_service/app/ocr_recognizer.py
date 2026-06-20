"""
Recognizer DÒNG CHỮ tổng quát — CRNN + CTC (train from scratch).

1 model duy nhất đọc mọi loại dòng chữ trên hóa đơn / bill chuyển khoản, thay cho
4 model field riêng. Dùng full charset tiếng Việt + số + ký hiệu (app/ocr_charset).

Artifact (trong models/):
  ocr_reco_model.pt      state_dict
  ocr_reco_meta.json     img_h, cnn_channels, lstm_*, dropout, charset_ref...
  ocr_reco_charset.json  danh sách ký tự (index 1..N, blank=0)

Ảnh dòng có chiều rộng thay đổi → resize giữ tỉ lệ theo chiều cao cố định, pad phải.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

import numpy as np
import torch
import torch.nn as nn
from PIL import Image

from .ocr_net import ReceiptLineCRNN

RECO_PREFIX = "ocr_reco"

DEFAULT_IMG_H = 48
DEFAULT_MIN_W = 32
DEFAULT_MAX_W = 1024
WIDTH_DIVISOR = 16  # mặc định back-compat; bundle đọc giá trị thực từ meta


@dataclass
class RecognizerBundle:
    model: nn.Module
    meta: dict
    charset: list[str]
    char2idx: dict[str, int]
    idx2char: dict[int, str]
    device: torch.device

    @property
    def img_h(self) -> int:
        return int(self.meta.get("img_h", DEFAULT_IMG_H))

    @property
    def max_w(self) -> int:
        return int(self.meta.get("max_w", DEFAULT_MAX_W))

    @property
    def width_divisor(self) -> int:
        return int(self.meta.get("width_divisor", WIDTH_DIVISOR))


def build_charset_maps(charset: list[str]) -> tuple[dict[str, int], dict[int, str]]:
    char2idx = {c: i + 1 for i, c in enumerate(charset)}
    idx2char = {i + 1: c for i, c in enumerate(charset)}
    return char2idx, idx2char


def _build_model(meta: dict, num_classes: int, device: torch.device) -> nn.Module:
    m = ReceiptLineCRNN(
        img_h=int(meta.get("img_h", DEFAULT_IMG_H)),
        img_w=int(meta.get("img_w", 320)),
        cnn_channels=tuple(meta.get("cnn_channels", (64, 128, 256, 256))),
        lstm_hidden=int(meta.get("lstm_hidden", 256)),
        lstm_layers=int(meta.get("lstm_layers", 3)),
        num_classes=num_classes,
        dropout=float(meta.get("dropout", 0.2)),
        width_divisor=int(meta.get("width_divisor", WIDTH_DIVISOR)),
    )
    return m.to(device)


def load_recognizer_bundle(
    models_dir: Path,
    device: Optional[torch.device] = None,
) -> Optional[RecognizerBundle]:
    """Load recognizer tổng quát. Trả None nếu chưa có artifact."""
    dev = device or torch.device("cpu")
    pt = models_dir / f"{RECO_PREFIX}_model.pt"
    meta_path = models_dir / f"{RECO_PREFIX}_meta.json"
    charset_path = models_dir / f"{RECO_PREFIX}_charset.json"
    if not (pt.exists() and meta_path.exists() and charset_path.exists()):
        return None

    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    charset = json.loads(charset_path.read_text(encoding="utf-8"))
    if isinstance(charset, dict):  # cho phép {"charset": [...]}
        charset = charset.get("charset", [])
    char2idx, idx2char = build_charset_maps(charset)
    num_classes = len(charset) + 1

    model = _build_model(meta, num_classes, dev)
    try:
        state = torch.load(pt, map_location=dev, weights_only=True)
    except TypeError:
        state = torch.load(pt, map_location=dev)
    model.load_state_dict(state)
    model.eval()
    return RecognizerBundle(
        model=model, meta=meta, charset=charset,
        char2idx=char2idx, idx2char=idx2char, device=dev,
    )


# ─────────────────────────── Preprocess ─────────────────────────────────────

def preprocess_variable_width(
    img: Image.Image,
    *,
    img_h: int = DEFAULT_IMG_H,
    min_w: int = DEFAULT_MIN_W,
    max_w: int = DEFAULT_MAX_W,
    width_divisor: int = WIDTH_DIVISOR,
) -> tuple[torch.Tensor, int]:
    """Resize giữ tỉ lệ về chiều cao img_h, pad phải về bội số width_divisor.

    Trả (tensor (1,1,H,W), real_width) — real_width là chiều rộng có chữ (trước pad).
    """
    g = img.convert("L")
    w, h = g.size
    new_w = max(min_w, int(round(w * (img_h / max(h, 1)))))
    new_w = min(new_w, max_w)
    g = g.resize((new_w, img_h), Image.BILINEAR)
    pad_w = ((new_w + width_divisor - 1) // width_divisor) * width_divisor
    arr = np.full((img_h, pad_w), 255.0, dtype=np.float32)
    arr[:, :new_w] = np.asarray(g, dtype=np.float32)
    arr = (arr / 255.0 - 0.5) / 0.5
    tensor = torch.from_numpy(arr).unsqueeze(0).unsqueeze(0)
    return tensor, new_w


# ─────────────────────────── Decode ─────────────────────────────────────────

def greedy_decode(logits: torch.Tensor, idx2char: dict[int, str]) -> str:
    """logits: (T, num_classes) → chuỗi (CTC greedy collapse, blank=0)."""
    ids = logits.argmax(dim=-1).tolist()
    prev = -1
    chars: list[str] = []
    for idx in ids:
        if idx == 0:
            prev = -1
            continue
        if idx == prev:
            continue
        prev = idx
        ch = idx2char.get(idx)
        if ch:
            chars.append(ch)
    return "".join(chars).strip()


@torch.no_grad()
def recognize(bundle: RecognizerBundle, img: Image.Image) -> tuple[str, float]:
    """Nhận dạng 1 dòng → (text, confidence)."""
    div = bundle.width_divisor
    x, real_w = preprocess_variable_width(
        img, img_h=bundle.img_h, max_w=bundle.max_w, width_divisor=div
    )
    x = x.to(bundle.device)
    logits = bundle.model(x).squeeze(0)            # (T, C)
    probs = torch.softmax(logits, dim=-1)
    # Chỉ tính confidence trên số timestep thực (real_w // width_divisor)
    t_real = max(1, min(logits.size(0), real_w // div))
    sub = probs[:t_real]
    argmax = sub.argmax(dim=-1)
    nonblank = argmax != 0
    if bool(nonblank.any()):
        conf = float(sub.max(dim=-1).values[nonblank].mean().item())
    else:
        conf = float(sub.max(dim=-1).values.mean().item())
    text = greedy_decode(logits[:t_real].cpu(), bundle.idx2char)
    return text, conf


@torch.no_grad()
def recognize_batch(bundle: RecognizerBundle, imgs: list[Image.Image]) -> list[tuple[str, float]]:
    """Nhận dạng nhiều dòng (pad chung theo batch để chạy nhanh)."""
    if not imgs:
        return []
    div = bundle.width_divisor
    prepared = [
        preprocess_variable_width(im, img_h=bundle.img_h, max_w=bundle.max_w, width_divisor=div)
        for im in imgs
    ]
    real_ws = [rw for _, rw in prepared]
    max_w = max(t.size(-1) for t, _ in prepared)
    batch = torch.full((len(prepared), 1, bundle.img_h, max_w), 1.0, dtype=torch.float32)
    for i, (t, _) in enumerate(prepared):
        batch[i, :, :, : t.size(-1)] = t
    batch = batch.to(bundle.device)
    logits = bundle.model(batch)                   # (B, T, C)
    probs = torch.softmax(logits, dim=-1)
    out: list[tuple[str, float]] = []
    for i in range(len(prepared)):
        t_real = max(1, min(logits.size(1), real_ws[i] // div))
        sub = probs[i, :t_real]
        argmax = sub.argmax(dim=-1)
        nonblank = argmax != 0
        if bool(nonblank.any()):
            conf = float(sub.max(dim=-1).values[nonblank].mean().item())
        else:
            conf = float(sub.max(dim=-1).values.mean().item())
        text = greedy_decode(logits[i, :t_real].cpu(), bundle.idx2char)
        out.append((text, conf))
    return out
