"""
Hậu xử lý (post-processing) văn bản OCR trên hóa đơn & bill chuyển khoản.

Recognizer CRNN+CTC đôi khi nhầm vài ký tự ở từ khóa quen thuộc
(VD "TgNG CeNG" → "TONG CONG", "Na OAND" → "VND", "D" → "Đ"). Module này sửa
lại các lỗi đó bằng:
  1. Chuẩn hoá ký hiệu tiền tệ (₫/d/đ, VND) và khoảng trắng quanh số.
  2. Sửa từ khóa hóa đơn/bill bằng từ điển + so khớp mờ (fuzzy) theo khoảng cách
     Levenshtein cho TỪ viết HOA (nơi hay lỗi nhất), tránh đụng vào tên riêng/số.

Hàm chính:
  correct_line(text)  → sửa 1 dòng OCR
  correct_amount_text(text), correct_date_text(text)  → chuẩn hoá field
"""

from __future__ import annotations

import re
import unicodedata

# ─────────────────────────── Từ điển từ khóa ────────────────────────────────
# key: dạng CHUẨN; value: các biến thể lỗi thường gặp (đã UPPER, bỏ dấu để so khớp)
CANON_KEYWORDS: dict[str, list[str]] = {
    "TỔNG CỘNG": ["TONG CONG", "TQNG CONG", "TGNG CONG", "TONGCONG", "TONG CQNG", "TONG CONC"],
    "TỔNG TIỀN": ["TONG TIEN", "TQNG TIEN", "TONG TIEM"],
    "THÀNH TIỀN": ["THANH TIEN", "THANHTIEN", "THANH TIEM"],
    "THANH TOÁN": ["THANH TOAN", "THANHTOAN", "THANH TOAM", "THANH TOAH"],
    "TỔNG THANH TOÁN": ["TONG THANH TOAN"],
    "TIỀN HÀNG": ["TIEN HANG", "TIENHANG"],
    "SỐ TIỀN": ["SO TIEN", "SOTIEN", "SO TIEM", "S0 TIEN"],
    "TIỀN MẶT": ["TIEN MAT", "TIENMAT"],
    "TỔNG": ["TGNG", "TQNG", "TONC"],
    "TOTAL": ["TOTA", "TOTL", "TOTAI", "TOTA'"],
    "SUBTOTAL": ["SUB TOTAL", "SUBTOTA"],
    "VAT": ["VA T", "VAI", "VA7"],
    "THUẾ GTGT": ["THUE GTGT", "THUEGTGT"],
    "GIẢM GIÁ": ["GIAM GIA", "GIAMGIA", "GIAM GLA"],
    "CHIẾT KHẤU": ["CHIET KHAU", "CHIETKHAU"],
    "PHÍ DỊCH VỤ": ["PHI DICH VU", "PHIDICHVU"],
    "PHỤ THU": ["PHU THU"],
    "NỘI DUNG": ["NOI DUNG", "N0I DUNG", "NOIDUNG", "NOI DUNC"],
    "NỘI DUNG CHUYỂN KHOẢN": ["NOI DUNG CHUYEN KHOAN", "NDCK"],
    "LỜI NHẮN": ["LOI NHAN", "LOINHAN"],
    "NGƯỜI NHẬN": ["NGUOI NHAN", "NGUOINHAN", "NGUOI NHAM"],
    "NGƯỜI GỬI": ["NGUOI GUI", "NGUOIGUI"],
    "NGÂN HÀNG": ["NGAN HANG", "NGANHANG"],
    "SỐ TÀI KHOẢN": ["SO TAI KHOAN", "SOTAIKHOAN", "STK"],
    "MÃ GIAO DỊCH": ["MA GIAO DICH", "MAGIAODICH", "MA GD"],
    "GIAO DỊCH": ["GIAO DICH", "GIAODICH", "GIAO DICN"],
    "THÀNH CÔNG": ["THANH CONG", "THANHCONG", "THANH CONC"],
    "GIAO DỊCH THÀNH CÔNG": ["GIAO DICH THANH CONG"],
    "THỜI GIAN": ["THOI GIAN", "THOIGIAN"],
    "NGÀY": ["NGAY", "NGAI"],
    "HÓA ĐƠN": ["HOA DON", "HOADON", "HOA DOM"],
    "VNĐ": ["VND", "VNĐ", "VN D", "VNB", "NA OAND", "WND", "VHD"],
}

# Map biến thể (đã normalize) → canonical
_VARIANT_TO_CANON: dict[str, str] = {}
for _canon, _variants in CANON_KEYWORDS.items():
    for _v in _variants:
        _VARIANT_TO_CANON[_v.upper()] = _canon
    _VARIANT_TO_CANON[_strip := _canon] = _canon  # giữ nguyên dạng chuẩn


def _no_accent_upper(s: str) -> str:
    nf = unicodedata.normalize("NFD", s)
    nf = "".join(c for c in nf if unicodedata.category(c) != "Mn")
    return nf.upper().replace("Đ", "D")


# Bảng tra theo dạng KHÔNG DẤU + HOA cho fuzzy
_CANON_NOACCENT: dict[str, str] = {}
for _canon in CANON_KEYWORDS:
    _CANON_NOACCENT[_no_accent_upper(_canon)] = _canon
for _canon, _variants in CANON_KEYWORDS.items():
    for _v in _variants:
        _CANON_NOACCENT.setdefault(_no_accent_upper(_v), _canon)


def _levenshtein(a: str, b: str) -> int:
    if a == b:
        return 0
    if not a:
        return len(b)
    if not b:
        return len(a)
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(cur[j - 1] + 1, prev[j] + 1, prev[j - 1] + (ca != cb)))
        prev = cur
    return prev[-1]


# ─────────────────────────── Chuẩn hoá tiền tệ ───────────────────────────────

_RE_MULTISPACE = re.compile(r"[ \t]{2,}")
# "d" hoặc "đ" đứng ngay sau chữ số (đơn vị đồng) → "đ"
_RE_DONG_SUFFIX = re.compile(r"(?<=\d)\s*[dđĐD]\b")
_RE_VND = re.compile(r"\b(?:VN[DĐB]|WND|VHD)\b", re.IGNORECASE)


def normalize_currency(text: str) -> str:
    t = text
    # Ký hiệu ₫ → đ
    t = t.replace("₫", "đ")
    # Chuẩn hoá "VND/VNĐ" viết sai
    t = _RE_VND.sub("VND", t)
    # "1500d" / "1500 D" → "1500đ" (đơn vị đồng sau số)
    t = _RE_DONG_SUFFIX.sub("đ", t)
    return t


# ─────────────────────────── Sửa từ khóa ─────────────────────────────────────

# Từ khóa ĐỨNG ĐỘC LẬP an toàn để sửa theo từng-từ (không trùng âm tiết tiếng Việt
# phổ biến → tránh phá từ đúng như "CỘNG", "TIỀN"...). Các cụm nhiều từ đã do
# _correct_multiword lo.
STANDALONE_FIX: dict[str, list[str]] = {
    "TOTAL": ["TOTAL", "TOTA", "TOTL", "TOTAI", "T0TAL", "TOTA'"],
    "SUBTOTAL": ["SUBTOTAL", "SUBTOTA", "SUBTOTL"],
    "VAT": ["VAT", "VA7", "VAI", "V4T"],
    "AMOUNT": ["AMOUNT", "AMQUNT", "AMOUN7"],
}
_STANDALONE_NA: dict[str, str] = {}
for _canon, _vs in STANDALONE_FIX.items():
    _STANDALONE_NA[_no_accent_upper(_canon)] = _canon
    for _v in _vs:
        _STANDALONE_NA.setdefault(_no_accent_upper(_v), _canon)


def _correct_word(word: str) -> str:
    """Sửa 1 token độc lập — CHỈ với tập STANDALONE_FIX (rủi ro thấp)."""
    core = word.strip(".,:;()-")
    if len(core) < 3:
        return word
    digits = sum(c.isdigit() for c in core)
    if digits and digits >= len(core) / 2:
        return word  # số / mã → giữ nguyên
    if core != core.upper():
        return word  # chỉ động vào token IN HOA
    na = _no_accent_upper(core)
    canon = _STANDALONE_NA.get(na)
    if canon is None and len(na) >= 5:
        best_d = 99
        for key, c in _STANDALONE_NA.items():
            if len(key) < 5 or abs(len(key) - len(na)) > 1:
                continue  # từ ngắn (VAT...) chỉ khớp chính xác, tránh phá tên riêng
            d = _levenshtein(na, key)
            if d <= 2 and d < best_d:
                canon, best_d = c, d
    if canon:
        prefix = word[: len(word) - len(word.lstrip(".,:;()-"))]
        suffix = word[len(word.rstrip(".,:;()-")):]
        return f"{prefix}{canon}{suffix}"
    return word


def _correct_multiword(text: str) -> str:
    """Thử khớp cụm 2-3 từ IN HOA với từ khóa nhiều chữ (TỔNG CỘNG, NGƯỜI NHẬN...)."""
    tokens = text.split(" ")
    n = len(tokens)
    i = 0
    out: list[str] = []
    multi = {k: v for k, v in _CANON_NOACCENT.items() if " " in v}
    while i < n:
        matched = False
        for span in (3, 2):
            if i + span <= n:
                chunk = " ".join(tokens[i:i + span])
                na = _no_accent_upper(chunk)
                # khớp trực tiếp hoặc fuzzy nhẹ
                cand = multi.get(na)
                if cand is None:
                    for key, canon in multi.items():
                        if abs(len(key) - len(na)) <= 2 and _levenshtein(na, key) <= 2:
                            cand = canon
                            break
                if cand and chunk.upper() == chunk and any(c.isalpha() for c in chunk):
                    out.append(cand)
                    i += span
                    matched = True
                    break
        if not matched:
            out.append(tokens[i])
            i += 1
    return " ".join(out)


def correct_line(text: str) -> str:
    """Hậu xử lý 1 dòng OCR: chuẩn hoá tiền tệ + sửa từ khóa hóa đơn/bill."""
    if not text:
        return text
    t = normalize_currency(text)
    t = _RE_MULTISPACE.sub(" ", t).strip()
    t = _correct_multiword(t)
    t = " ".join(_correct_word(w) for w in t.split(" "))
    t = _RE_MULTISPACE.sub(" ", t).strip()
    return t


def correct_lines(lines: list[str]) -> list[str]:
    return [correct_line(l) for l in lines]


# ─────────────────────────── Field-specific ─────────────────────────────────

_AMOUNT_FIX = {"O": "0", "o": "0", "l": "1", "I": "1", "B": "8", "S": "5", "Z": "2"}


def correct_amount_text(text: str) -> str:
    """Sửa nhầm chữ↔số trong CHUỖI chỉ chứa số tiền (O→0, l→1...)."""
    if not text:
        return text
    out = []
    for c in text:
        if c.isalpha() and c in _AMOUNT_FIX:
            out.append(_AMOUNT_FIX[c])
        else:
            out.append(c)
    return "".join(out)


def correct_date_text(text: str) -> str:
    """Chuẩn hoá ký tự ngày: O→0, ngăn cách lạ → '/'."""
    if not text:
        return text
    t = text.replace("O", "0").replace("o", "0").replace("l", "1").replace("I", "1")
    t = re.sub(r"[^0-9/\-.: ]", "", t)
    return t.strip()


# ─────────────────────────── Ghi chú chuyển khoản ───────────────────────────
# Model hay đọc sai ghi chú ngắn chữ thường trên app MB (font nhỏ):
#   mung me 8/3 → Trung/Tung/Puno me 83

_MUNG_OCR_WORDS = frozenset({
    "puno", "trung", "tung", "tme", "nung", "mung", "moi", "muno",
    "tuno", "prung", "pruno", "gui", "ngui", "mungo", "mmung",
})

_RE_NOTE_ME_DD = re.compile(
    r"^(?P<w>[A-Za-zÀ-ỹ]{2,10})\s+me\s+(?P<a>\d{1,2})(?P<b>\d{1,2})$",
    re.IGNORECASE,
)
_RE_NOTE_ME_SLASH = re.compile(
    r"^(?P<w>[A-Za-zÀ-ỹ]{2,10})\s+me\s+(?P<d>\d{1,2}/\d{1,2})$",
    re.IGNORECASE,
)


def _looks_like_mung_word(w: str) -> bool:
    w = w.lower()
    return w in _MUNG_OCR_WORDS or w.startswith(("tr", "tu", "pu", "mu", "ng"))


def correct_transfer_note(text: str) -> str:
    """
    Sửa lỗi OCR phổ biến trên dòng ghi chú bill chuyển khoản ngắn.
    Chỉ áp dụng cho chuỗi ngắn (≤ 50 ký tự), tránh đụng mô tả dài.
    """
    if not text:
        return text
    t = text.strip()
    if len(t) > 50 or len(t) < 3:
        return t

    # OCR hay đọc "me" thành "mme" / "m e"
    t = re.sub(r"\bmme\b", "me", t, flags=re.I)
    t = re.sub(r"\s+", " ", t)

    m = _RE_NOTE_ME_DD.match(t)
    if m and "/" not in t:
        w = m.group("w").lower()
        if _looks_like_mung_word(w):
            return f"mung me {m.group('a')}/{m.group('b')}"

    m2 = _RE_NOTE_ME_SLASH.match(t)
    if m2:
        w = m2.group("w").lower()
        if _looks_like_mung_word(w):
            return f"mung me {m2.group('d')}"

    # me + 2 số cuối không có dấu / (vd. "me 83", "muno me 83")
    if re.search(r"\bme\b", t, re.I) and "/" not in t:
        t2 = re.sub(r"(\d)(\d)\s*$", r"\1/\2", t)
        parts = t2.split()
        if parts and _looks_like_mung_word(parts[0]):
            parts[0] = "mung"
            t2 = " ".join(parts)
        if t2 != t:
            return t2

    return t
