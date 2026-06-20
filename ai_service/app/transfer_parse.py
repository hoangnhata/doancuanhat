"""
Parse bill chuyển khoản ngân hàng / ví — transfer-only.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date
from io import BytesIO
from typing import Any, Optional

from PIL import Image

from .category_hints import hint_category
from .classify_ood import is_amount_only_text
from .classify_infer import predict_top_label
from .ocr_postprocess import correct_transfer_note
from .ocr_real import (
    TextBox,
    _extract_date_from_lines,
    _extract_transfer_amount,
    _has_transfer_amount_signal,
    _is_bank_transfer,
    boxes_to_lines,
)
from .ocr_recognizer import RecognizerBundle
from .ocr_transfer import (
    extract_transfer_parties,
    is_meaningful_note,
    resolve_transfer_type,
    should_default_sender_to_user,
)
from .rules import rule_based_category
from .transaction_intent import adjust_category_for_type, infer_transaction_type
from .transfer_pipeline import recognize_transfer_lines


TRANSFER_NOT_DETECTED_MSG = "Không phải bill chuyển khoản"
_REVIEW_THRESH = 0.55


class TransferNotDetectedError(ValueError):
    """Ảnh không có dấu hiệu bill chuyển khoản ngân hàng / ví."""


class TransferRecognizerMissingError(RuntimeError):
    """Model CRNN recognizer chưa được load."""


@dataclass
class TransferParseResult:
    amount_vnd: Optional[int] = None
    transaction_date: Optional[str] = None
    sender: Optional[str] = None
    receiver: Optional[str] = None
    note: Optional[str] = None
    type: str = "EXPENSE"
    confidence: Optional[float] = None
    category: Optional[str] = None
    category_confidence: Optional[float] = None
    description: Optional[str] = None
    needs_review: bool = False
    raw_lines: list[str] = field(default_factory=list)
    ocr_engine: str = "crnn_scratch"
    raw: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        merchant = self.receiver
        if self.type == "INCOME" and self.sender:
            merchant = self.sender
        return {
            "amount_vnd": self.amount_vnd,
            "transaction_date": self.transaction_date,
            "sender": self.sender,
            "receiver": self.receiver,
            "note": self.note,
            "type": self.type,
            "confidence": self.confidence,
            "category": self.category,
            "category_confidence": self.category_confidence,
            "description": self.description,
            "needs_review": self.needs_review,
            "merchant": merchant,
            "raw_lines": self.raw_lines,
            "ocr_engine": self.ocr_engine,
            "raw": self.raw,
        }


def _categorize_note(
    text: str,
    classify: Any,
    *,
    force_type: Optional[str] = None,
) -> tuple[str, Optional[float], str, str, str]:
    from .parsers import normalize_note

    parsed = normalize_note(text)
    text_for_cls = parsed.cleaned_text
    conf: Optional[float] = None
    source = "rule"

    if is_amount_only_text(text_for_cls):
        cat = "Khác"
        source = "amount_only"
    else:
        hint = hint_category(text_for_cls)
        min_conf = 0.45
        if classify is not None:
            min_conf = float(
                classify.meta.get("confidence_threshold", classify.meta.get("min_conf", 0.45))
            )
        if hint:
            cat = hint
            source = "hint"
        elif classify is not None:
            top_cat, conf = predict_top_label(classify, text_for_cls)
            if conf >= min_conf:
                cat = top_cat
                source = "model"
            else:
                rb = rule_based_category(text_for_cls)
                cat = rb if rb != "Khác" else top_cat
                conf = None
                source = "rule"
        else:
            cat = rule_based_category(text_for_cls)

    tx_type = force_type or infer_transaction_type(text_for_cls, cat)
    cat = adjust_category_for_type(text_for_cls, cat, tx_type)
    desc = parsed.description or text_for_cls
    return cat, conf, tx_type, desc, source


def _overall_confidence(
    amount_conf: float,
    date_conf: float,
    person_conf: float,
    note_conf: float,
) -> float:
    parts = [c for c in (amount_conf, date_conf, person_conf, note_conf) if c > 0]
    if not parts:
        return 0.0
    return round(sum(parts) / len(parts), 4)


def _transfer_description(
    sender: Optional[str],
    receiver: Optional[str],
    note: Optional[str],
) -> str:
    if note:
        return note
    if sender and receiver:
        return f"Chuyen khoan: {sender} -> {receiver}"
    if receiver:
        return f"Chuyen khoan den {receiver}"
    if sender:
        return f"Chuyen khoan tu {sender}"
    return "Chuyen khoan"


def parse_transfer_from_boxes(
    boxes: list[TextBox],
    classify: Any = None,
    *,
    user_name: Optional[str] = None,
    default_date: Optional[str] = None,
) -> TransferParseResult:
    lines = boxes_to_lines(boxes)
    result = TransferParseResult(
        raw_lines=lines,
        raw={"all_lines": lines[:30], "is_bank_transfer": True},
    )

    if not lines:
        raise TransferNotDetectedError(TRANSFER_NOT_DETECTED_MSG)

    if not _is_bank_transfer(lines):
        raise TransferNotDetectedError(TRANSFER_NOT_DETECTED_MSG)

    parties = extract_transfer_parties(lines, boxes)
    sender = parties.get("sender") or None
    receiver = parties.get("recipient") or None
    note = parties.get("note") or None

    if note:
        note = correct_transfer_note(note)
        if not is_meaningful_note(note):
            note = None

    is_outgoing = False
    if should_default_sender_to_user(lines, sender, receiver):
        is_outgoing = True
        sender = (user_name or "Bản thân").strip()
        result.raw["sender_defaulted"] = True

    amount_vnd, raw_amount, amount_conf = _extract_transfer_amount(lines)
    iso_date, raw_date, date_conf = _extract_date_from_lines(lines)

    if iso_date is None:
        iso_date = default_date or date.today().isoformat()
        date_conf = date_conf or 0.0

    tx_type = "EXPENSE"
    resolved_type: Optional[str] = None
    if user_name:
        resolved_type, _, reason = resolve_transfer_type(user_name, sender, receiver)
        result.raw["transfer_type_reason"] = reason
        if resolved_type:
            tx_type = resolved_type
    if resolved_type is None and is_outgoing:
        tx_type = "EXPENSE"
        result.raw.setdefault("transfer_type_reason", "outgoing_default_expense")

    cat = "Khác"
    cat_conf: Optional[float] = None
    note_source: Optional[str] = None
    if note:
        cat, cat_conf, note_type, note_desc, note_source = _categorize_note(
            note, classify,
            force_type=tx_type if resolved_type or is_outgoing else None,
        )
        if not resolved_type and not is_outgoing:
            tx_type = note_type
        result.description = note_desc or note
        result.raw["category_source"] = note_source
    else:
        result.description = _transfer_description(sender, receiver, None)

    person_conf = 0.80 if sender or receiver else 0.0
    note_conf = 0.85 if note else 0.0

    result.amount_vnd = amount_vnd
    result.transaction_date = iso_date
    result.sender = sender
    result.receiver = receiver
    result.note = note
    result.type = tx_type
    result.category = cat
    result.category_confidence = round(cat_conf, 4) if cat_conf is not None else None
    result.confidence = _overall_confidence(amount_conf, date_conf, person_conf, note_conf)
    result.raw.update({
        "amount": raw_amount or "",
        "date": raw_date or "",
        "sender": sender or "",
        "recipient": receiver or "",
        "transfer_note": note or "",
    })

    transfer_cat_uncertain = bool(note and note_source not in ("hint",))
    result.needs_review = (
        amount_vnd is None
        or amount_conf < _REVIEW_THRESH
        or not sender and not receiver
        or transfer_cat_uncertain
    )
    return result


def parse_transfer_minimal_from_boxes(
    boxes: list[TextBox],
    *,
    default_date: Optional[str] = None,
) -> TransferParseResult:
    """OCR bill CK — chỉ trích số tiền và ngày (không parse người gửi/nhận/ghi chú)."""
    lines = boxes_to_lines(boxes)
    result = TransferParseResult(
        raw_lines=lines,
        raw={"all_lines": lines[:30], "is_bank_transfer": True, "ocr_mode": "amount_date_only"},
    )

    if not lines:
        raise TransferNotDetectedError(TRANSFER_NOT_DETECTED_MSG)
    if not _is_bank_transfer(lines) and not _has_transfer_amount_signal(lines):
        raise TransferNotDetectedError(TRANSFER_NOT_DETECTED_MSG)

    amount_vnd, raw_amount, amount_conf = _extract_transfer_amount(lines)
    iso_date, raw_date, date_conf = _extract_date_from_lines(lines)
    if iso_date is None and default_date:
        iso_date = default_date

    result.amount_vnd = amount_vnd
    result.transaction_date = iso_date
    result.confidence = _overall_confidence(amount_conf, date_conf, 0.0, 0.0)
    result.raw.update({"amount": raw_amount or "", "date": raw_date or ""})
    result.needs_review = (
        amount_vnd is None
        or amount_conf < _REVIEW_THRESH
        or iso_date is None
        or date_conf < _REVIEW_THRESH
    )
    return result


def parse_transfer_minimal_image(
    img: Image.Image,
    recognizer: RecognizerBundle,
    *,
    default_date: Optional[str] = None,
    min_conf: float = 0.0,
) -> TransferParseResult:
    if recognizer is None:
        raise TransferRecognizerMissingError(
            "Recognizer CRNN chua load — can ocr_reco_model.pt trong models/"
        )
    boxes = recognize_transfer_lines(img, recognizer, min_conf=min_conf)
    return parse_transfer_minimal_from_boxes(boxes, default_date=default_date)


def parse_transfer_minimal_bytes(
    data: bytes,
    recognizer: RecognizerBundle,
    *,
    default_date: Optional[str] = None,
    min_conf: float = 0.0,
) -> TransferParseResult:
    img = Image.open(BytesIO(data))
    if img.mode not in ("L", "RGB", "RGBA"):
        img = img.convert("RGB")
    elif img.mode == "RGBA":
        img = img.convert("RGB")
    return parse_transfer_minimal_image(
        img, recognizer, default_date=default_date, min_conf=min_conf,
    )


def parse_transfer_image(
    img: Image.Image,
    recognizer: RecognizerBundle,
    classify: Any = None,
    *,
    user_name: Optional[str] = None,
    default_date: Optional[str] = None,
    min_conf: float = 0.0,
) -> TransferParseResult:
    if recognizer is None:
        raise TransferRecognizerMissingError(
            "Recognizer CRNN chua load — can ocr_reco_model.pt trong models/"
        )
    boxes = recognize_transfer_lines(img, recognizer, min_conf=min_conf)
    return parse_transfer_from_boxes(
        boxes, classify, user_name=user_name, default_date=default_date,
    )


def parse_transfer_bytes(
    data: bytes,
    recognizer: RecognizerBundle,
    classify: Any = None,
    *,
    user_name: Optional[str] = None,
    default_date: Optional[str] = None,
    min_conf: float = 0.0,
) -> TransferParseResult:
    img = Image.open(BytesIO(data))
    if img.mode not in ("L", "RGB", "RGBA"):
        img = img.convert("RGB")
    elif img.mode == "RGBA":
        img = img.convert("RGB")
    return parse_transfer_image(
        img, recognizer, classify,
        user_name=user_name, default_date=default_date, min_conf=min_conf,
    )
