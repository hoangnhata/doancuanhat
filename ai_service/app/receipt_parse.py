"""
Orchestrator: ảnh hóa đơn → 5 field (amount, date, merchant, category, description).

Chiến lược:
  - PRIMARY: EasyOCR (nếu được cài) — hoạt động tốt trên ảnh thật, ảnh chụp, chuyển khoản
  - FALLBACK: CRNN models (nếu EasyOCR không có) — chỉ hoạt động tốt với ảnh synthetic
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date
from io import BytesIO
from typing import Any, Optional

from PIL import Image

from .ocr_infer import (
    ReceiptOcrBundles,
    parse_date_from_text,
    run_ocr_on_image,
)
from .receipt_layout import body_line_strips, split_receipt_regions
from .rules import rule_based_category


@dataclass
class FieldConfidence:
    amount: Optional[float] = None
    date: Optional[float] = None
    merchant: Optional[float] = None
    description: Optional[float] = None
    category: Optional[float] = None


@dataclass
class ReceiptParseResult:
    amount_vnd: Optional[int] = None
    transaction_date: Optional[str] = None
    merchant: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    type: str = "EXPENSE"
    category_confidence: Optional[float] = None
    field_confidence: FieldConfidence = field(default_factory=FieldConfidence)
    raw: dict[str, Any] = field(default_factory=dict)
    needs_review: bool = False
    ocr_engine: str = "crnn"

    def to_dict(self) -> dict[str, Any]:
        return {
            "amount_vnd": self.amount_vnd,
            "transaction_date": self.transaction_date,
            "merchant": self.merchant,
            "description": self.description,
            "category": self.category,
            "type": self.type,
            "category_confidence": self.category_confidence,
            "field_confidence": {
                "amount": self.field_confidence.amount,
                "date": self.field_confidence.date,
                "merchant": self.field_confidence.merchant,
                "description": self.field_confidence.description,
                "category": self.field_confidence.category,
            },
            "raw": self.raw,
            "needs_review": self.needs_review,
            "ocr_engine": self.ocr_engine,
        }


_INCOME_LABELS = {"Lương", "Thưởng", "Freelance", "Đầu tư", "Bán hàng", "Thu nhập khác"}
_REVIEW_THRESH = 0.55


def _get_classify():
    """Import lazy để tránh lỗi khi classify_infer chưa có."""
    try:
        from .classify_infer import ClassifyBundle, predict_top_label
        return ClassifyBundle, predict_top_label
    except ImportError:
        return None, None


def _classify_from_text(
    classify: Any,
    merchant: str,
    description: str,
) -> tuple[str, Optional[float], str]:
    text = f"{merchant} {description}".strip()
    if not text:
        return "Khác", None, "EXPENSE"

    from .category_hints import hint_category

    hint = hint_category(text)
    _, predict_top = _get_classify()
    conf: Optional[float] = None
    if hint:
        cat = hint
    elif classify is not None and predict_top is not None:
        try:
            min_conf = float(classify.meta.get("min_conf", 0.50))
            top_cat, conf = predict_top(classify, text)
            if conf >= min_conf:
                cat = top_cat
            else:
                rb = rule_based_category(text)
                cat = rb if rb != "Khác" else top_cat
                conf = None
        except Exception:
            cat = rule_based_category(text)
    else:
        cat = rule_based_category(text)

    tx_type = "INCOME" if cat in _INCOME_LABELS else "EXPENSE"
    return cat, conf, tx_type


# ─────────────────────────── EasyOCR PRIMARY path ────────────────────────────

def _parse_with_easyocr(
    img: Image.Image,
    classify: Any,
    default_date: Optional[str],
    gpu: bool,
) -> ReceiptParseResult:
    from .ocr_real import parse_receipt_easyocr

    ocr_res = parse_receipt_easyocr(img, gpu=gpu)
    result = ReceiptParseResult(ocr_engine="easyocr")
    fc = result.field_confidence

    result.amount_vnd = ocr_res.amount_vnd
    fc.amount = ocr_res.conf_amount
    result.raw["amount"] = ocr_res.raw_amount or ""
    result.raw["all_lines"] = ocr_res.all_lines[:20]  # debug
    result.raw["is_bank_transfer"] = ocr_res.is_bank_transfer

    result.merchant = ocr_res.merchant
    fc.merchant = ocr_res.conf_merchant
    result.raw["merchant"] = ocr_res.merchant or ""

    result.transaction_date = ocr_res.transaction_date
    fc.date = ocr_res.conf_date
    result.raw["date"] = ocr_res.raw_date or ""

    if result.transaction_date is None:
        result.transaction_date = default_date or date.today().isoformat()
        fc.date = 0.0

    result.description = ocr_res.description or result.merchant or "Chi tieu tu hoa don"
    fc.description = 0.75 if ocr_res.description else 0.0
    result.raw["description"] = result.description

    cat, cat_conf, tx_type = _classify_from_text(
        classify, result.merchant or "", result.description or ""
    )
    result.category = cat
    result.category_confidence = round(cat_conf, 4) if cat_conf is not None else None
    result.field_confidence.category = cat_conf
    result.type = tx_type

    result.needs_review = (
        result.amount_vnd is None
        or (fc.amount is not None and fc.amount < _REVIEW_THRESH)
        or (fc.merchant is not None and fc.merchant < _REVIEW_THRESH)
    )
    return result


# ─────────────────────────── CRNN FALLBACK path ──────────────────────────────

def _parse_with_crnn(
    img: Image.Image,
    ocr: ReceiptOcrBundles,
    classify: Any,
    default_date: Optional[str],
) -> ReceiptParseResult:
    """CRNN fallback — dùng khi EasyOCR không được cài."""
    from .ocr_infer import parse_amount_vnd_from_text

    regions = split_receipt_regions(img)
    result = ReceiptParseResult(ocr_engine="crnn")
    fc = result.field_confidence

    # Amount: chay tren footer (28% duoi cung)
    if ocr.amount is not None:
        raw_amt, conf_amt = run_ocr_on_image(ocr.amount, regions.footer)
        result.raw["amount"] = raw_amt
        fc.amount = conf_amt
        result.amount_vnd = parse_amount_vnd_from_text(raw_amt)

    # Merchant: header
    if ocr.merchant is not None:
        raw_m, conf_m = run_ocr_on_image(ocr.merchant, regions.header)
        result.raw["merchant"] = raw_m
        fc.merchant = conf_m
        result.merchant = raw_m.strip() or None

    # Date: header
    if ocr.date is not None:
        raw_d, conf_d = run_ocr_on_image(ocr.date, regions.header)
        result.raw["date"] = raw_d
        fc.date = conf_d
        result.transaction_date = parse_date_from_text(raw_d)

    if result.transaction_date is None:
        combined = " ".join(filter(None, [result.raw.get("date"), result.raw.get("merchant")]))
        result.transaction_date = parse_date_from_text(combined)
    if result.transaction_date is None:
        result.transaction_date = default_date or date.today().isoformat()
        fc.date = fc.date or 0.0

    # Description
    desc, conf_desc = "", 0.0
    if ocr.line is not None:
        for strip in body_line_strips(regions.body, max_lines=3):
            raw, conf = run_ocr_on_image(ocr.line, strip)
            raw = raw.strip()
            if raw and conf > conf_desc:
                desc, conf_desc = raw, conf
    result.raw["description"] = desc
    fc.description = conf_desc if desc else None
    result.description = desc or result.merchant or "Chi tieu tu hoa don"

    cat, cat_conf, tx_type = _classify_from_text(
        classify, result.merchant or "", result.description or ""
    )
    result.category = cat
    result.category_confidence = round(cat_conf, 4) if cat_conf is not None else None
    result.field_confidence.category = cat_conf
    result.type = tx_type

    result.needs_review = any([
        fc.amount is not None and fc.amount < _REVIEW_THRESH,
        result.amount_vnd is None,
        fc.merchant is not None and fc.merchant < _REVIEW_THRESH,
        fc.description is not None and fc.description < _REVIEW_THRESH,
    ])
    return result


# ─────────────────────────── Public API ──────────────────────────────────────

def parse_receipt_image(
    img: Image.Image,
    ocr: Optional[ReceiptOcrBundles] = None,
    classify: Any = None,
    *,
    default_date: Optional[str] = None,
    prefer_easyocr: bool = True,
    gpu: bool = False,
) -> ReceiptParseResult:
    """
    Parse ảnh hóa đơn → ReceiptParseResult.

    Tự động chọn engine:
      - EasyOCR (prefer_easyocr=True và đã cài) → tốt nhất cho ảnh thật
      - CRNN fallback (khi không có EasyOCR hoặc prefer_easyocr=False)
    """
    if prefer_easyocr:
        try:
            from .ocr_real import easyocr_available
            if easyocr_available():
                return _parse_with_easyocr(img, classify, default_date, gpu)
        except Exception as e:
            print(f"[receipt_parse] EasyOCR loi, fallback CRNN: {e}")

    # CRNN fallback
    if ocr is None:
        ocr = ReceiptOcrBundles(amount=None, merchant=None, date=None, line=None)
    return _parse_with_crnn(img, ocr, classify, default_date)


def parse_receipt_bytes(
    data: bytes,
    ocr: Optional[ReceiptOcrBundles] = None,
    classify: Any = None,
    *,
    prefer_easyocr: bool = True,
    **kwargs: Any,
) -> ReceiptParseResult:
    img = Image.open(BytesIO(data))
    if img.mode not in ("L", "RGB", "RGBA"):
        img = img.convert("RGB")
    elif img.mode == "RGBA":
        img = img.convert("RGB")
    return parse_receipt_image(img, ocr, classify, prefer_easyocr=prefer_easyocr, **kwargs)
