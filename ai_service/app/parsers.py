from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import date, timedelta
from typing import Optional


_AMOUNT_RE = re.compile(
    r"(?P<num>\d{1,3}(?:[.,]\d{3})*(?:[.,]\d+)?)\s*(?P<unit>k|nghìn|ngàn|tr|triệu|trăm|đ|vnđ|vnd)?",
    flags=re.IGNORECASE,
)

_DATE_IN_TEXT = re.compile(
    r"(?:\bngày\s+)?(\d{1,2})[/\-\.](\d{1,2})[/\-\.](\d{2,4})\b",
    flags=re.IGNORECASE,
)

_DATE_PREFIX = re.compile(
    r"^\s*(?:ngày\s+)?\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4}\s*",
    flags=re.IGNORECASE,
)

_RELATIVE_DATES: dict[str, int] = {
    "hôm qua": -1,
    "hom qua": -1,
    "hôm kia": -2,
    "hom kia": -2,
    "ngày mai": 1,
    "ngay mai": 1,
    "hôm nay": 0,
    "hom nay": 0,
}


@dataclass(frozen=True)
class ParsedNote:
    cleaned_text: str
    amount: Optional[int]
    description: str
    assumed_date: date


def _amount_from_match(m: re.Match[str]) -> Optional[int]:
    num = m.group("num")
    unit = m.group("unit")
    num_digits = re.sub(r"[.,]", "", num)
    if not num_digits.isdigit():
        return None
    if unit:
        u = unit.lower()
        if u in ("k", "nghìn", "ngàn"):
            num_digits += "000"
        elif u in ("tr", "triệu"):
            num_digits += "000000"
        elif u == "trăm":
            num_digits += "00"
    try:
        return int(num_digits)
    except ValueError:
        return None


def _text_without_dates(text: str) -> str:
    """Bỏ dd/mm/yyyy để không nhầm 29, 05, 2026 thành số tiền."""
    t = _DATE_IN_TEXT.sub(" ", text or "")
    for phrase in _RELATIVE_DATES:
        t = re.sub(rf"\b{re.escape(phrase)}\b", " ", t, flags=re.IGNORECASE)
    return re.sub(r"\s+", " ", t).strip()


def extract_amount_vnd(text: str) -> Optional[int]:
    """
    Trích số tiền VND. Ưu tiên token có đơn vị (k, tr, ...), không lấy số trong ngày tháng.
    """
    if not text:
        return None

    best: Optional[int] = None
    best_score = -1

    for scope in (_text_without_dates(text), text):
        for m in _AMOUNT_RE.finditer(scope):
            val = _amount_from_match(m)
            if val is None or val <= 0:
                continue
            unit = (m.group("unit") or "").lower()
            score = 0
            if unit:
                score += 100
            if val >= 10_000:
                score += 20
            elif val >= 1_000:
                score += 10
            elif val < 100 and not unit:
                # Số nhỏ không đơn vị (29, 05, 6...) — thường là ngày, bỏ qua
                continue
            score += min(len(str(val)), 8)
            if score > best_score:
                best_score = score
                best = val
        if best is not None:
            break

    return best


def extract_date_from_note(text: str, *, today: Optional[date] = None) -> Optional[date]:
    """Trích ngày giao dịch từ câu tự nhiên (dd/mm/yyyy hoặc hôm qua, ...)."""
    if not text:
        return None
    base = today or date.today()
    t = text.strip().lower()

    for phrase, delta in _RELATIVE_DATES.items():
        if re.search(rf"\b{re.escape(phrase)}\b", t):
            return base + timedelta(days=delta)

    m = _DATE_IN_TEXT.search(text)
    if not m:
        return None
    d, mo, y = int(m.group(1)), int(m.group(2)), int(m.group(3))
    if y < 100:
        y += 2000
    try:
        return date(y, mo, d)
    except ValueError:
        return None


def _strip_date_from_text(text: str) -> str:
    """Bỏ ngày (đầu/cuối/giữa câu) để mô tả gọn — không cắt nhầm số trong năm."""
    t = text.strip()
    for phrase in _RELATIVE_DATES:
        t = re.sub(rf"\b{re.escape(phrase)}\b", "", t, flags=re.IGNORECASE)
    t = _DATE_IN_TEXT.sub(" ", t)
    t = re.sub(r"\bngày\b", " ", t, flags=re.IGNORECASE)
    t = _DATE_PREFIX.sub("", t)
    t = re.sub(r"\s+", " ", t).strip(" ,;")
    return t or text.strip()


def _strip_amount_from_text(text: str, amount: Optional[int]) -> str:
    """Chỉ xóa đúng token tiền đã trích (vd. 500k), không xóa số trong ngày/năm."""
    if amount is None:
        return text
    t = text
    for m in _AMOUNT_RE.finditer(text):
        if _amount_from_match(m) == amount:
            t = (t[: m.start()] + t[m.end() :]).strip()
            break
    return re.sub(r"\s+", " ", t).strip(" ,;")


def normalize_note(text: str, *, today: Optional[date] = None) -> ParsedNote:
    t = (text or "").strip()
    base = today or date.today()
    tx_date = extract_date_from_note(t, today=base)
    if tx_date is None:
        tx_date = base

    amt = extract_amount_vnd(t)

    desc = _strip_date_from_text(t)
    desc = _strip_amount_from_text(desc, amt)
    if not desc:
        desc = _strip_date_from_text(t) or t

    return ParsedNote(
        cleaned_text=t,
        amount=amt,
        description=desc,
        assumed_date=tx_date,
    )
