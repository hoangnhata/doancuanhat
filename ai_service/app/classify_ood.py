"""Rule-based OOD / vô nghĩa — chạy trước model."""
from __future__ import annotations

import re
import unicodedata

# Giao dịch hợp lệ dù ngắn (không có alternative rỗng — tránh match '')
_FINANCIAL_KEYWORDS = (
    "grab", "xang", "xăng", "cafe", "momo", "vcb", "bidv", "shopee", "lazada",
    "luong", "lương", "salary", "bonus", "refund", "cashback", "ship", "taxi",
    "vietcombank", "techcombank", "mbbank", "zalopay", "winmart",
    "tiền", "tien", "chi", "thu", "nhận", "nhan", "mua", "bán", "ban",
    "phở", "com", "uong", "uống", "phong", "phòng", "nhà", "nha",
    "tro", "trọ", "money_", "vnd",
)
_FINANCIAL_SHORT = frozenset({
    "cf", "ck", "mb", "tx", "dt", "đt", "be", "nha", "tro", "trọ", "ăn", "an",
    "k", "tr", "đ",
})

_KEYBOARD_ROWS = ("asdf", "qwer", "zxcv", "hjkl", "qwerty", "asdfasdf")

_ONLY_DIGITS = re.compile(r"^\d{4,}$")

_NON_FINANCE_PHRASES = (
    "hôm nay trời đẹp",
    "hom nay troi dep",
    "hello world",
    "đi ngủ",
    "di ngu",
    "chào bạn",
    "chao ban",
)

_SHORT_STOP = frozenset({"ok", "hmm", "uh", "ừ", "uk", "aa", "bb", "hi", "he"})

_MONEY_SURFACE = re.compile(
    r"(?:"
    r"\d[\d.,]*\s*(?:k|tr|nghìn|ngàn|triệu|vnd|đ|d)\b|"
    r"\d[\d.,]+\b|"
    r"<money_[^>\s]+>"
    r")",
    re.IGNORECASE,
)


def _norm(s: str) -> str:
    return unicodedata.normalize("NFC", s.lower().strip())


def _has_financial_context(text: str) -> bool:
    t = _norm(text)
    if "<money" in t or _MONEY_SURFACE.search(t):
        return True
    tokens = re.findall(r"[a-zà-ỹ0-9_]+", t, flags=re.IGNORECASE)
    tok_set = set(tokens)
    if tok_set & _FINANCIAL_SHORT:
        return True
    for tok in tokens:
        for kw in _FINANCIAL_KEYWORDS:
            if len(kw) >= 4 and (tok == kw or kw in tok):
                return True
    return False


def is_amount_only_text(text: str) -> bool:
    """Chỉ có số tiền (50k, 20tr, 15000000) — không đủ ngữ cảnh phân loại."""
    raw = (text or "").strip()
    if not raw:
        return False
    t = _norm(raw)
    if not _MONEY_SURFACE.search(t):
        return False
    remainder = _MONEY_SURFACE.sub("", t)
    remainder = re.sub(r"[^\wà-ỹ]+", " ", remainder, flags=re.IGNORECASE).strip()
    letters = re.sub(r"[^a-zà-ỹ]", "", remainder, flags=re.IGNORECASE)
    return len(letters) < 2


def is_ood_text(text: str) -> tuple[bool, str]:
    """
    Trả (is_ood, reason).
    Không reject các mẫu tài chính ngắn hợp lệ.
    """
    raw = (text or "").strip()
    if not raw:
        return True, "empty"

    t = _norm(raw)
    if is_amount_only_text(raw):
        return True, "amount_only"

    compact = re.sub(r"\s+", "", t)
    fin = _has_financial_context(t)

    if t in _SHORT_STOP or len(t) <= 2:
        if not fin:
            return True, "too_short"

    for phrase in _NON_FINANCE_PHRASES:
        if phrase in t and not fin:
            return True, "non_finance"

    if _ONLY_DIGITS.match(compact) and "<money" not in t:
        return True, "digits_only"

    letters = re.sub(r"[^a-zà-ỹ]", "", t, flags=re.IGNORECASE)
    if len(letters) >= 6 and not fin:
        low = letters.lower()
        if any(k in low for k in _KEYBOARD_ROWS) or low in _KEYBOARD_ROWS:
            return True, "random_chars"
        if len(set(low)) <= 4:
            return True, "low_entropy"

    return False, ""
