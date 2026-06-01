from __future__ import annotations

import json
import re
from dataclasses import dataclass
from datetime import date, datetime
from io import BytesIO
from pathlib import Path
from typing import Any, Optional

import numpy as np
import torch
import torch.nn as nn
from PIL import Image

from .ocr_charset import (
    AMOUNT_CHAR2IDX,
    AMOUNT_IDX2CHAR,
    AMOUNT_NUM_CLASSES,
    DATE_CHAR2IDX,
    DATE_IDX2CHAR,
    DATE_NUM_CLASSES,
    TEXT_CHAR2IDX,
    TEXT_IDX2CHAR,
    TEXT_NUM_CLASSES,
)
from .ocr_net import ReceiptLineCRNN, ReceiptLineCRNN_v1
from .receipt_layout import body_line_strips, split_receipt_regions


@dataclass(frozen=True)
class FieldOcrBundle:
    name: str
    model: nn.Module
    meta: dict[str, Any]
    char2idx: dict[str, int]
    idx2char: dict[int, str]
    device: torch.device

    @property
    def img_h(self) -> int:
        return int(self.meta.get("img_h", 32))

    @property
    def img_w(self) -> int:
        return int(self.meta.get("img_w", 160))


# Giữ tương thích import cũ
OcrBundle = FieldOcrBundle


@dataclass(frozen=True)
class ReceiptOcrBundles:
    amount: Optional[FieldOcrBundle]
    merchant: Optional[FieldOcrBundle]
    date: Optional[FieldOcrBundle]
    line: Optional[FieldOcrBundle]


_FIELD_SPECS: dict[str, tuple[str, dict[str, int], dict[int, str], int]] = {
    "amount": ("ocr_amount", AMOUNT_CHAR2IDX, AMOUNT_IDX2CHAR, AMOUNT_NUM_CLASSES),
    "merchant": ("ocr_merchant", TEXT_CHAR2IDX, TEXT_IDX2CHAR, TEXT_NUM_CLASSES),
    "date": ("ocr_date", DATE_CHAR2IDX, DATE_IDX2CHAR, DATE_NUM_CLASSES),
    "line": ("ocr_line", TEXT_CHAR2IDX, TEXT_IDX2CHAR, TEXT_NUM_CLASSES),
}

# Alias file cũ
_LEGACY_AMOUNT = ("ocr", AMOUNT_CHAR2IDX, AMOUNT_IDX2CHAR, AMOUNT_NUM_CLASSES)


def _build_model(meta: dict[str, Any], num_classes: int, device: torch.device) -> nn.Module:
    version = int(meta.get("architecture_version", 1))
    if version >= 2:
        cls = ReceiptLineCRNN
        defaults = dict(cnn_channels=(64, 128, 256, 256), lstm_hidden=256,
                        lstm_layers=3, dropout=0.2, img_h=48)
    else:
        cls = ReceiptLineCRNN_v1
        defaults = dict(cnn_channels=(32, 64, 128, 256), lstm_hidden=128,
                        lstm_layers=2, dropout=0.15, img_h=32)

    m: nn.Module = cls(
        img_h=int(meta.get("img_h", defaults["img_h"])),
        img_w=int(meta.get("img_w", 160)),
        cnn_channels=tuple(meta.get("cnn_channels", defaults["cnn_channels"])),
        lstm_hidden=int(meta.get("lstm_hidden", defaults["lstm_hidden"])),
        lstm_layers=int(meta.get("lstm_layers", defaults["lstm_layers"])),
        num_classes=int(meta.get("num_classes", num_classes)),
        dropout=float(meta.get("dropout", defaults["dropout"])),
    )
    return m.to(device)


def _load_field(
    models_dir: Path,
    field: str,
    device: torch.device,
) -> Optional[FieldOcrBundle]:
    prefix, c2i, i2c, n_cls = _FIELD_SPECS[field]
    pt = models_dir / f"{prefix}_model.pt"
    meta_path = models_dir / f"{prefix}_meta.json"

    if field == "amount" and not pt.exists():
        pt = models_dir / "ocr_model.pt"
        meta_path = models_dir / "ocr_meta.json"
        prefix = "ocr"

    if not pt.exists() or not meta_path.exists():
        return None

    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    m = _build_model(meta, n_cls, device)
    try:
        state = torch.load(pt, map_location=device, weights_only=True)
    except TypeError:
        state = torch.load(pt, map_location=device)
    m.load_state_dict(state)
    m.eval()
    return FieldOcrBundle(
        name=field, model=m, meta=meta,
        char2idx=c2i, idx2char=i2c, device=device,
    )


def load_receipt_ocr_bundles(
    models_dir: Path,
    device: Optional[torch.device] = None,
) -> ReceiptOcrBundles:
    dev = device or torch.device("cpu")
    return ReceiptOcrBundles(
        amount=_load_field(models_dir, "amount", dev),
        merchant=_load_field(models_dir, "merchant", dev),
        date=_load_field(models_dir, "date", dev),
        line=_load_field(models_dir, "line", dev),
    )


def load_ocr_bundle(
    models_dir: Path,
    device: Optional[torch.device] = None,
) -> Optional[FieldOcrBundle]:
    """Tương thích API cũ — trả về model amount."""
    bundles = load_receipt_ocr_bundles(models_dir, device)
    return bundles.amount


def preprocess_line_image(img: Image.Image, *, img_h: int, img_w: int) -> torch.Tensor:
    g = img.convert("L").resize((img_w, img_h), Image.BILINEAR)
    arr = np.asarray(g, dtype=np.float32) / 255.0
    arr = (arr - 0.5) / 0.5
    return torch.from_numpy(arr).unsqueeze(0).unsqueeze(0)


def greedy_ctc_decode(
    logits: torch.Tensor,
    idx2char: dict[int, str],
) -> str:
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


def run_ocr_on_image(
    bundle: FieldOcrBundle,
    img: Image.Image,
) -> tuple[str, float]:
    x = preprocess_line_image(img, img_h=bundle.img_h, img_w=bundle.img_w)
    x = x.to(bundle.device)
    with torch.no_grad():
        logits = bundle.model(x).squeeze(0)
        probs = torch.softmax(logits, dim=-1)
        conf = float(probs.max(dim=-1).values.mean().item())
        raw = greedy_ctc_decode(logits.cpu(), bundle.idx2char)
    return raw, conf


def parse_amount_vnd_from_text(text: str) -> Optional[int]:
    """Parse số tiền VND từ chuỗi OCR.

    Xử lý các định dạng:
      "150.000", "150,000", "1.500.000", "150000", "150.000 VND"
    Loại bỏ phần prefix không phải số (vd "TONG CONG 150.000").
    """
    if not text:
        return None
    t = text.strip()
    # Tìm chuỗi số cuối cùng trong text (số + dấu phân cách)
    candidates = re.findall(r"[\d][0-9.,]*", t)
    if not candidates:
        return None
    # Thử từng candidate từ dài nhất (thường là số tiền thật)
    candidates.sort(key=len, reverse=True)
    for cand in candidates:
        # Xác định dấu thập phân: nếu 3 chữ số sau dấu cuối → thousands sep
        cand = cand.rstrip(".,")
        if not cand:
            continue
        # Xóa tất cả dấu . và , (thousands separators trong VND)
        digits = re.sub(r"[.,]", "", cand)
        if not digits or not digits.isdigit():
            continue
        try:
            val = int(digits)
        except ValueError:
            continue
        # Lọc giá trị hợp lý: 1.000 VND → 9.999.999.999 VND
        if 1000 <= val <= 9_999_999_999:
            return val
    # Fallback: strip all non-digit
    digits = re.sub(r"[^0-9]", "", t)
    if not digits:
        return None
    try:
        val = int(digits)
    except ValueError:
        return None
    return val if 1000 <= val <= 9_999_999_999 else None


def parse_date_from_text(text: str) -> Optional[str]:
    """Trả về YYYY-MM-DD nếu parse được."""
    if not text:
        return None
    t = text.strip()
    for fmt in ("%d/%m/%Y", "%d-%m-%Y", "%d.%m.%Y", "%d/%m/%y", "%Y-%m-%d"):
        try:
            return datetime.strptime(t[:10] if len(t) > 10 else t, fmt).date().isoformat()
        except ValueError:
            continue
    m = re.search(r"(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})", t)
    if not m:
        return None
    d, mo, y = int(m.group(1)), int(m.group(2)), int(m.group(3))
    if y < 100:
        y += 2000
    try:
        return date(y, mo, d).isoformat()
    except ValueError:
        return None


def predict_amount_vnd(
    bundle: FieldOcrBundle,
    img: Image.Image,
    *,
    use_bottom_crop: bool = True,
) -> tuple[Optional[int], str, float]:
    from .receipt_layout import split_receipt_regions

    work = split_receipt_regions(img).footer if use_bottom_crop else img
    raw, conf = run_ocr_on_image(bundle, work)
    return parse_amount_vnd_from_text(raw), raw, conf


def predict_amount_from_bytes(
    bundle: FieldOcrBundle,
    data: bytes,
    **kwargs: Any,
) -> tuple[Optional[int], str, float]:
    img = Image.open(BytesIO(data))
    return predict_amount_vnd(bundle, img, **kwargs)
