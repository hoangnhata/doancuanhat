"""
Bóc tách người chuyển / người nhận trên bill chuyển khoản và suy ra EXPENSE / INCOME
theo tên user (fullName).
"""

from __future__ import annotations

import re
import unicodedata
from typing import Any, Optional

from .ocr_postprocess import correct_transfer_note
from .ocr_real import TextBox, _NUMBER_PATTERN, _parse_number

_TRANSFER_SUCCESS = re.compile(
    r"chuyển\s*tiền\s*thành\s*công|chuyen\s*tien\s*thanh\s*cong|"
    r"giao\s*dịch\s*thành\s*công|giao\s*dich\s*thanh\s*cong|"
    r"chuyển\s*tiền|chuyen\s*tien|chuyển\s*khoản|chuyen\s*khoan",
    re.IGNORECASE,
)

_TRANSFER_FOOTER = re.compile(
    r"cảm\s*ơn|cam\s*on|mbbank|mb\s*bank|mbbcnk|"
    r"thực\s*hiện\s*giao\s*dịch|thuc\s*hien\s*giao\s*dich|"
    r"chia\s*s[eé]|chie\s*s[aá]|luu\s*(anh|ảnh|mau|miu|donh|đnh)|"
    r"giao\s*d[iị]ch\s*(moi|mới)?|xem\s*them|đầu\s*tư|"
    r"doune|dcue|oa\s+dou",
    re.IGNORECASE,
)

# Vùng chi tiết bill app ngân hàng (trên banner / nút footer)
_DETAIL_Y_MIN = 0.30
_DETAIL_Y_MAX = 0.68
_NOTE_Y_MAX = 0.66
_FOOTER_Y_MIN = 0.72
# MoMo: Tin nhắn thường nằm thấp hơn (sát block Lưu người nhận)
_MOMO_NOTE_Y_MIN = 0.28
_MOMO_NOTE_Y_MAX = 0.86

_FOOTER_GARBAGE_NOTE = re.compile(
    r"oa\s+dou|dcue|doune|chia\s*s|luu\s*|giao\s*d[iị]ch|xem\s*them|đầu\s*tư",
    re.IGNORECASE,
)

_NOIDUNG_BODY = re.compile(
    r"(?:noi\s*dung|nội\s*dung)[:.\s]*(.*)$",
    re.IGNORECASE,
)

_TRANSFER_NOISE_LINE = re.compile(
    r"^\s*[-+]?\d+\s*$|"
    r"^\s*[a-zA-Z]\s*$|"
    r"^\s*vnd\s*$|"
    r"vetinbank|vietinbank|"
    r"^\d{1,2}:\d{2}",
    re.IGNORECASE,
)

_LABEL_RECIPIENT = re.compile(
    r"nguoi\s*nhan|người\s*nhận|ben\s*nhan|bên\s*nhận|"
    r"ten\s*tk\s*nhan|tên\s*tk\s*nhận|beneficiary|đến\s*tk|den\s*tk",
    re.IGNORECASE,
)

_LABEL_SENDER = re.compile(
    r"nguoi\s*gui|người\s*gửi|nguoi\s*chuyen|người\s*chuyển|"
    r"tu\s*tk|từ\s*tk|from\s*account|nguoi\s*chuyen\s*tien",
    re.IGNORECASE,
)

_CHUYEN_TIEN = re.compile(
    r"(?:chuyen|chuyển)\s*(?:khoan|tiền|tien)(?!\s*(?:thanh|thành))",
    re.IGNORECASE,
)

_BANK_GARBAGE = re.compile(
    r"bank|bonk|bbcnk|crcy|ctg|napas|vietin|vetin",
    re.IGNORECASE,
)

_DATE_IN_LINE = re.compile(
    r"\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4}|"
    r"\d{1,2}:\d{2}|^S-\d+",
    re.IGNORECASE,
)

_NAME_FROM_NOTE = re.compile(
    r"(?:noi\s*dung|nội\s*dung|loi\s*nhac|lời\s*nhắn|note)[:.\s]*"
    r"([A-Za-zÀ-ỹ][A-Za-zÀ-ỹ\s'.-]{3,55}?)\s+"
    r"(?:chuyen|chuyển)\s*(?:khoan|tiền|tien)",
    re.IGNORECASE,
)

_STANDALONE_CHUYEN = re.compile(
    r"^([A-Za-zÀ-ỹ][A-Za-zÀ-ỹ\s'.-]{3,55}?)\s+"
    r"(?:chuyen|chuyển)\s*(?:khoan|tiền|tien)",
    re.IGNORECASE,
)

_LABEL_MESSAGE = re.compile(
    r"(?:[t1l][i1l]?n|[t1l]in|tin)\s*nh[aắ]n|"
    r"loi\s*nh[aắ]n|lời\s*nhắn|"
    r"n+h?[aà]?n+\w*",
    re.IGNORECASE,
)

# Dòng OCR gộp nhãn + nội dung: "1in nhắnTano em 83", "Tn nhắnua sinh nhat"
_MOMO_MESSAGE_LINE = re.compile(
    r"^(?:[t1l][i1l]?n|[t1l]in|tin)\s*nh[aắ]n(.+)$",
    re.IGNORECASE,
)

_MOMO_FOOTER_LINE = re.compile(
    r"uu\s*nguoi|uu\s*người|luu\s*nguoi|luu\s*người|"
    r"vao\s*lan\s*sau|mai\s*lan\s*sau|"
    r"chia\s*ti[eèê]n|chuy[eể]n\s*th[aấ]n|chuy[eể]n\s*th[eê]m|"
    r"nguoi\s*nhan.*(?:de|để)\s*(?:ti|tìm|tim|lai|lại)|"
    r"người\s*nhận.*(?:de|để)\s*(?:ti|tìm|tim|lai|lại)",
    re.IGNORECASE,
)

# OCR hay gộp "Tin nhắn Tang" → "nhanano", "tinh nhan"...
_GARBLED_TIN_NHAN = re.compile(
    r"^n+h?[aà]?n+\w*\s+(.+)$",
    re.IGNORECASE,
)


def normalize_person_name(name: str) -> str:
    s = unicodedata.normalize("NFD", (name or "").strip())
    s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    s = re.sub(r"[^a-zA-Z\s]", " ", s)
    return re.sub(r"\s+", " ", s).lower().strip()


_VN_VOWELS = frozenset(
    "aeiouyăâêôơưáàảãạắằẳẵặấầẩẫậéèẻẽẹếềểễệíìỉĩịóòỏõọốồổỗộớờởỡợúùủũụứừửữựýỳỷỹỵ"
)


def _name_quality_score(name: str) -> float:
    """Điểm chất lượng tên — ưu tiên tên có tỷ lệ nguyên âm tự nhiên."""
    letters = [c.lower() for c in name if c.isalpha()]
    if not letters:
        return 0.0
    vowels = sum(1 for c in letters if c in _VN_VOWELS)
    return vowels / len(letters)


def names_match(a: str, b: str) -> bool:
    """So khớp tên người (bỏ dấu, không phân biệt hoa thường)."""
    ta = set(normalize_person_name(a).split())
    tb = set(normalize_person_name(b).split())
    if not ta or not tb:
        return False
    short, long = (ta, tb) if len(ta) <= len(tb) else (tb, ta)
    if len(short) >= 2 and short.issubset(long):
        return True
    inter = ta & tb
    if len(inter) >= 2:
        return True
    if len(inter) == 1 and max(len(ta), len(tb)) <= 2:
        return True
    # Khớp ≥ 60% token
    return len(inter) / max(len(ta), len(tb)) >= 0.6


def looks_like_person_name(text: str) -> bool:
    s = (text or "").strip()
    if len(s) < 5 or len(s) > 60:
        return False
    if _TRANSFER_NOISE_LINE.search(s):
        return False
    if _TRANSFER_SUCCESS.search(s) or _TRANSFER_FOOTER.search(s):
        return False
    if re.search(r"\d{4,}", s):
        return False
    if re.search(
        r"vnd|vietcombank|vietinbank|vetinbank|techcombank|bidv|agribank|mbbank|mbbcnk|"
        r"sacombank|tpbank|vpbank|crcy|ctg|napas",
        s,
        re.I,
    ):
        return False
    words = [w for w in re.split(r"\s+", s) if w]
    if len(words) < 2 or len(words) > 6:
        return False
    if len(words[0]) <= 1:
        return False
    if sum(1 for w in words if len(w) <= 1) >= 2:
        return False
    if all(len(w) <= 2 for w in words):
        return False
    substantive = sum(1 for w in words if len(w) >= 3)
    if substantive < min(2, len(words)):
        if len(words) != 3 or not any(len(w) >= 5 for w in words):
            return False
    alpha = sum(c.isalpha() for c in s)
    if alpha / max(len(s), 1) < 0.7:
        return False
    # Ít chữ thường lẫn lộn → thường là tên in hoa trên bill
    upper_words = sum(1 for w in words if w.isupper() or w[0].isupper())
    return upper_words >= max(1, len(words) - 1)


def _split_label_value(line: str) -> Optional[str]:
    for sep in (":", "—", "–", "-"):
        if sep in line:
            parts = line.split(sep, 1)
            if len(parts) == 2 and len(parts[1].strip()) >= 3:
                return parts[1].strip()
    parts = re.split(r"\s{2,}", line, maxsplit=1)
    if len(parts) == 2 and len(parts[1].strip()) >= 3:
        return parts[1].strip()
    return None


def _find_success_index(lines: list[str]) -> Optional[int]:
    for i, line in enumerate(lines):
        if _TRANSFER_SUCCESS.search(line):
            return i
    return None


def _find_amount_index(lines: list[str]) -> Optional[int]:
    for i, line in enumerate(lines):
        if re.search(r"vnd|đ\b", line, re.I):
            nums = _NUMBER_PATTERN.findall(line)
            for n in nums:
                v = _parse_number(n)
                if v and v >= 1000:
                    return i
        nums = _NUMBER_PATTERN.findall(line)
        for n in nums:
            v = _parse_number(n)
            if v and v >= 10_000:
                return i
    return None


def _find_footer_index(lines: list[str], start: int = 0) -> Optional[int]:
    for i in range(start, len(lines)):
        if _TRANSFER_FOOTER.search(lines[i]):
            return i
    return None


def _capital_name_runs(line: str) -> list[str]:
    """Tìm cụm IN HOA giống tên người trong dòng OCR nhiễu."""
    runs: list[str] = []
    pat = re.compile(
        r"(?:[A-ZÁÀẢÃẠĂẮẰẲẴẶÂẤẦẨẪẬĐÉÈẺẼẸÊẾỀỂỄỆÍÌỈĨỊÓÒỎÕỌÔỐỒỔỖỘƠỚỜỞỠỢÚÙỦŨỤƯỨỪỬỮỰÝỲỶỸỴ']+"
        r"(?:\s+[A-ZÁÀẢÃẠĂẮẰẲẴẶÂẤẦẨẪẬĐÉÈẺẼẸÊẾỀỂỄỆÍÌỈĨỊÓÒỎÕỌÔỐỒỔỖỘƠỚỜỞỠỢÚÙỦŨỤƯỨỪỬỮỰÝỲỶỸỴ']+){1,4})"
    )
    for m in pat.finditer(line):
        t = m.group(0).strip()
        if looks_like_person_name(t):
            runs.append(t)
    return runs


_NOTE_VOWELS = frozenset("aeiouyăâêôơưàáảãạèéẻẽẹìíỉĩịòóỏõọùúủũụ")


def _is_wordlike_token(tok: str) -> bool:
    """Token giống một từ thật (không phải nhiễu OCR như 'TUnO', 'S3')."""
    if len(tok) < 2 or not tok.isalpha():
        return False
    low = tok.lower()
    if not any(c in _NOTE_VOWELS for c in low):
        return False
    # Từ thật thường đồng nhất hoa/thường hoặc Title-case (Mung, mung, MUNG)
    return tok.islower() or tok.isupper() or tok.istitle()


def is_meaningful_note(text: Optional[str]) -> bool:
    """
    Ghi chú có ý nghĩa để phân loại — loại bỏ nhiễu OCR (vd. 'TUnO Te S3').

    Yêu cầu ≥ 1 token dài ≥ 3 ký tự giống từ thật, hoặc ≥ 2 token wordlike.
    """
    if not text:
        return False
    t = text.strip()
    if len(t) < 3:
        return False
    if _FOOTER_GARBAGE_NOTE.search(t) or _TRANSFER_FOOTER.search(t):
        return False
    tokens = [w for w in re.split(r"\s+", t) if w]
    wordlike = [w for w in tokens if _is_wordlike_token(w)]
    if not wordlike:
        return False
    if any(len(w) >= 3 for w in wordlike):
        return True
    return len(wordlike) >= 2


def _strip_name_suffix_noise(name: str) -> str:
    """Bỏ token đơn lẻ cuối dòng OCR (vd. 'HOANG MINH NHAT S' → 'HOANG MINH NHAT')."""
    words = name.split()
    while words and len(words[-1]) <= 1:
        words.pop()
    return " ".join(words)


def correct_recipient_name(name: str) -> str:
    """Sửa lỗi OCR tên người nhận phổ biến trên bill ngân hàng."""
    if not name:
        return name
    fixed = _strip_name_suffix_noise(name.strip())
    if re.match(r"^T[O0]\s+", fixed, re.IGNORECASE):
        fixed = "HO " + fixed.split(None, 1)[1]
    fixed = re.sub(r"\bPHỤ\s*THU\b", "THI THU", fixed, flags=re.IGNORECASE)
    fixed = re.sub(r"\bPHU\s*THU\b", "THI THU", fixed, flags=re.IGNORECASE)
    # OCR hay thiếu Y: QUNH → QUYNH (Hồ Thị Quỳnh...)
    fixed = re.sub(r"\bQUNH\b", "QUYNH", fixed, flags=re.IGNORECASE)
    fixed = re.sub(r"\bQUYNH\s+TANG\b", "QUYNH TRANG", fixed, flags=re.IGNORECASE)
    # OCR hay mất R cuối tên: TRANG → TANG (thường gặp sau Họ Thị)
    words = fixed.split()
    if len(words) >= 3 and words[-1].upper() == "TANG":
        if any(w.upper() == "THI" for w in words[:-1]):
            words[-1] = "TRANG"
            fixed = " ".join(words)
    return re.sub(r"\s+", " ", fixed).strip()


def _is_bank_garbage_name(name: str) -> bool:
    return bool(_BANK_GARBAGE.search(name))


def _has_explicit_sender_line(lines: list[str]) -> bool:
    for line in lines:
        if not _CHUYEN_TIEN.search(line):
            continue
        if re.search(
            r"noi\s*dung|nội\s*dung|loi\s*nhac|lời\s*nhắn|tin\s*nh[aắ]n",
            line,
            re.I,
        ):
            continue
        if _name_from_chuyen_line(line):
            return True
    return False


def _is_momo_bill(lines: list[str]) -> bool:
    joined = " ".join(lines)
    for line in lines:
        if re.search(r"momo|ví\s*momo|vi\s*momo", line, re.I):
            return True
        if re.search(r"giao\s*d[iị]ch\s*-\s*\d{10,}", line, re.I):
            return True
        # OCR hay bỏ dấu "-": "Giao dich 133129855532"
        if re.search(r"giao\s*d[iì]ch\s+\d{10,}", line, re.I):
            return True
        if re.search(r"bi[eê]n\s*lai\s*chuy[eê]n\s*ti[eê]n", line, re.I):
            return True
        if re.search(r"qu[aá]\s*giao\s*d[iị]ch", line, re.I):
            return True
    if re.search(r"giao\s*d[iị]ch\s*th[aà]nh\s*c[oô]ng", joined, re.I):
        if re.search(r"\d[\d.,]*\s*000\s*đ", joined, re.I):
            if re.search(
                r"nguoi\s*nhan|người\s*nhận|vietinbank|techcombank|mbbank",
                joined,
                re.I,
            ):
                return True
    return False


def _in_momo_note_zone(y_top: float, y_bot: float) -> bool:
    return y_top >= _MOMO_NOTE_Y_MIN and y_bot <= _MOMO_NOTE_Y_MAX


def _momo_line_index_ok(
    i: int,
    records: Optional[list[Any]],
) -> bool:
    if not records or i >= len(records):
        return True
    rec = records[i]
    return _in_momo_note_zone(rec.y_top, rec.y_bot)


def _extract_recipient_name_from_line(line: str) -> Optional[str]:
    """
    Tách TÊN thuần từ dòng có label người nhận (OCR hay dính label):
      'TNguời nhậnHO THI QUYNH TRANG' → 'HO THI QUYNH TRANG'
      'Người nhậnHO THI QUYNH TRANG'   → 'HO THI QUYNH TRANG'
    """
    s = (line or "").strip()
    if not s or _MOMO_FOOTER_LINE.search(s):
        return None
    if not re.search(r"nh[aậ]n", s, re.I):
        return None
    label = re.search(r"ngu.+?nh[aậ]n", s, re.I)
    if label:
        rest = s[label.end():]
    elif re.search(r"người\s*nhận", s, re.I):
        m = re.search(r"người\s*nhận", s, re.I)
        rest = s[m.end():] if m else s
    elif _LABEL_RECIPIENT.search(s):
        val = _split_label_value(s)
        rest = val if val else s
    else:
        return None
    rest = rest.lstrip(" :.\-–—")
    if not rest:
        return None
    name = _strip_name_suffix_noise(rest.strip())
    return name if looks_like_person_name(name) else None


def _strip_recipient_label(text: str) -> str:
    """Backward-compat wrapper — ưu tiên tách tên thuần."""
    extracted = _extract_recipient_name_from_line(text)
    if extracted:
        return extracted
    return (text or "").strip()


def _normalize_momo_message(body: str) -> str:
    body = correct_transfer_note(body.strip())
    # OCR gộp nhãn + "Qua": "ua sinh nhat" ← Qua sinh nhat
    if re.match(r"^ua\s+", body, re.I):
        body = "Qua " + body[3:].lstrip()
    # OCR: Tano / Tan0 ← Tang
    body = re.sub(r"^tan[o0]\b", "Tang", body, flags=re.I)
    body = re.sub(r"^tano\b", "Tang", body, flags=re.I)
    # OCR gộp "Tin nhắn Tang" → chỉ còn "em 83"
    if re.match(r"^em\s+\d", body, re.I):
        body = f"Tang {body}"
    body = re.sub(r"\bsinh\s+nhat\b", "sinh nhat", body, flags=re.I)
    return body.strip()


def _message_body_from_line(line: str) -> Optional[str]:
    raw = line.strip()
    if not raw or _MOMO_FOOTER_LINE.search(raw):
        return None
    if _looks_like_momo_message_line(raw):
        m = _MOMO_MESSAGE_LINE.match(raw)
        if m:
            return m.group(1).strip() or None
        gm = _GARBLED_TIN_NHAN.match(raw)
        if gm:
            return gm.group(1).strip() or None
        m2 = re.search(
            r"(?:[t1l][i1l]?n|[t1l]in|tin)\s*nh[aắ]n(.+)$",
            raw,
            re.I,
        )
        if m2:
            return m2.group(1).strip() or None
    # Chỉ dùng split label khi có dấu : rõ ràng (tránh cắt nhầm ngày)
    if ":" in raw and _LABEL_MESSAGE.search(raw):
        body = _split_label_value(raw)
        if body:
            return body.strip()
    return None


def _looks_like_momo_message_line(line: str) -> bool:
    raw = line.strip()
    if not raw or _MOMO_FOOTER_LINE.search(raw):
        return False
    return bool(
        _LABEL_MESSAGE.search(raw)
        or _GARBLED_TIN_NHAN.match(raw)
        or _MOMO_MESSAGE_LINE.match(raw)
    )


def _extract_momo_tin_nhan(
    lines: list[str],
    records: Optional[list[Any]] = None,
) -> Optional[str]:
    """MoMo: ghi chú ở mục Tin nhắn — label cùng dòng hoặc dòng ngay sau Ngân hàng."""
    bank_i: Optional[int] = None
    for i, line in enumerate(lines):
        if re.search(
            r"ngan\s*hang|ngân\s*hàng|n[eé]n\s*h[aà]n|vietinbank|vetinbank|"
            r"techcombank|mbbank|bidv|agribank|sacombank|tpbank|vpbank",
            line,
            re.I,
        ):
            bank_i = i

    for i, line in enumerate(lines):
        if not _momo_line_index_ok(i, records):
            continue
        raw = line.strip()
        if not _looks_like_momo_message_line(raw):
            continue
        body = _message_body_from_line(raw)
        if not body and i + 1 < len(lines):
            nxt = lines[i + 1].strip()
            if not _MOMO_FOOTER_LINE.search(nxt):
                body = nxt
        if body:
            body = _normalize_momo_message(body)
            if is_meaningful_note(body):
                return body

    if bank_i is not None:
        for j in range(bank_i + 1, min(bank_i + 4, len(lines))):
            if not _momo_line_index_ok(j, records):
                continue
            raw = lines[j].strip()
            if _MOMO_FOOTER_LINE.search(raw):
                break
            if _LABEL_RECIPIENT.search(raw) or _LABEL_SENDER.search(raw):
                continue
            if re.search(r"so\s*(?:the|tk|tai\s*khoan)|^\d{8,}", raw, re.I):
                continue
            if _looks_like_momo_message_line(raw):
                body = _message_body_from_line(raw)
            else:
                body = raw
            if body:
                body = _normalize_momo_message(body)
                if is_meaningful_note(body):
                    return body
    return None


def should_default_sender_to_user(
    lines: list[str],
    sender: Optional[str],
    recipient: Optional[str],
) -> bool:
    """Bill chuyển đi (MB / MoMo): không có người chuyển → mặc định bản thân."""
    if sender or not recipient:
        return False
    if _find_success_index(lines) is None:
        return False
    if _is_momo_bill(lines):
        return True
    return not _has_explicit_sender_line(lines)


def _in_detail_zone(y_top: float, y_bot: float) -> bool:
    return y_top >= _DETAIL_Y_MIN and y_bot <= _DETAIL_Y_MAX + 0.04


def _extract_noidung_note(records: list[Any]) -> Optional[str]:
    """
    VietinBank / app NH: dòng 'Nội dung ... chuyen' + dòng 'tien' bên dưới.
    """
    for i, rec in enumerate(records):
        if not _in_detail_zone(rec.y_top, rec.y_bot) or rec.y_top > _NOTE_Y_MAX:
            continue
        line = rec.text.strip()
        if not re.search(r"noi\s*dung|nội\s*dung", line, re.I):
            continue
        m = _NOIDUNG_BODY.search(line)
        body = (m.group(1).strip() if m else "").strip()
        body = re.sub(r"\s+\d\s*$", "", body)
        if re.search(r"(?:chuyen|chuyển)\s*$", body, re.I) and i + 1 < len(records):
            nxt = records[i + 1]
            if (
                _in_detail_zone(nxt.y_top, nxt.y_bot)
                and nxt.y_top <= _NOTE_Y_MAX
                and nxt.y_top - rec.y_bot < 0.05
            ):
                nt = re.sub(r"^[A-Z]\s+", "", nxt.text.strip())
                if re.match(r"^(?:tien|tiền)\b", nt, re.I):
                    body = f"{body} {nt.split()[0]}"
        if not body:
            continue
        body = correct_transfer_note(body)
        if is_meaningful_note(body):
            return body
    return None


def _extract_transfer_note(
    lines: list[str],
    start: int,
    end: int,
    records: Optional[list[Any]] = None,
) -> Optional[str]:
    """Ghi chú / lời nhắn trong khối chi tiết (không lấy nút footer)."""
    candidates: list[str] = []
    for idx in range(start, end):
        line = lines[idx].strip()
        if records is not None and idx < len(records):
            rec = records[idx]
            if not _in_detail_zone(rec.y_top, rec.y_bot) or rec.y_top > _NOTE_Y_MAX:
                continue
        if len(line) < 2 or len(line) > 60:
            continue
        if looks_like_person_name(line):
            continue
        if _TRANSFER_SUCCESS.search(line) or _TRANSFER_FOOTER.search(line):
            continue
        if _BANK_GARBAGE.search(line):
            continue
        if re.search(r"\bvnd\b|vnđ|đ\b", line, re.I):
            continue
        if _DATE_IN_LINE.search(line):
            continue
        digits = re.sub(r"\D", "", line)
        if len(digits) >= 8:
            continue
        if re.match(r"^[A-Z]\s", line) and len(line) < 4:
            continue
        line = correct_transfer_note(line)
        if not is_meaningful_note(line):
            continue
        candidates.append(line)
    return candidates[-1] if candidates else None


def _name_from_chuyen_line(line: str) -> Optional[str]:
    m = _NAME_FROM_NOTE.search(line)
    if m:
        return m.group(1).strip()
    m2 = _STANDALONE_CHUYEN.search(line)
    if m2:
        return m2.group(1).strip()
    return None


def extract_transfer_parties(
    lines: list[str],
    boxes: list[TextBox],
) -> dict[str, Any]:
    """
    Trích người chuyển, người nhận, mô tả từ các dòng OCR.
    """
    from .ocr_real import boxes_to_line_records

    result: dict[str, Any] = {
        "sender": None,
        "recipient": None,
        "description": None,
        "note": None,
    }
    records = boxes_to_line_records(boxes) if boxes else []
    if records:
        lines = [r.text for r in records]
    if not lines:
        return result

    # 1) Label rõ ràng — MoMo hay dính label + tên trên cùng dòng
    for line in lines:
        if _LABEL_RECIPIENT.search(line) or re.search(r"ngu.+?nh[aậ]n", line, re.I):
            val = _extract_recipient_name_from_line(line)
            if not val:
                val = _split_label_value(line)
                if val and not looks_like_person_name(val):
                    val = None
            if val and looks_like_person_name(val):
                result["recipient"] = val
        if _LABEL_SENDER.search(line):
            val = _split_label_value(line)
            if val and looks_like_person_name(val):
                result["sender"] = val

    # 2) Dòng chuyển tiền — MB: "TEN chuyen tien" = người chuyển;
    #    VietinBank: "Nội dung TEN chuyen tien" = người nhận trong nội dung
    for line in lines:
        if not _CHUYEN_TIEN.search(line):
            continue
        name = _name_from_chuyen_line(line)
        has_content_label = bool(
            re.search(r"noi\s*dung|nội\s*dung|loi\s*nhac|lời\s*nhắn", line, re.I)
        )
        if name:
            name_ok = looks_like_person_name(name)
            # VietinBank: tên trong dòng Nội dung là phần ghi chú, không phải người nhận
            if not has_content_label and not result["sender"] and name_ok:
                result["sender"] = name
        if _CHUYEN_TIEN.search(line):
            result["description"] = line.strip()

    # 3) Vùng giữa amount và footer (layout MB Bank / app ngân hàng)
    success_i = _find_success_index(lines)
    amount_i = _find_amount_index(lines)
    start = (amount_i or success_i or 0) + 1
    footer_i = _find_footer_index(lines, start)
    if records:
        for i, rec in enumerate(records):
            if i <= start:
                continue
            if rec.y_top >= _FOOTER_Y_MIN or _TRANSFER_FOOTER.search(rec.text):
                footer_i = i if footer_i is None else min(footer_i, i)
                break
    end = footer_i if footer_i is not None else len(lines)

    mid_names: list[str] = []
    for i in range(start, end):
        if records and not _in_detail_zone(records[i].y_top, records[i].y_bot):
            continue
        line = _strip_name_suffix_noise(lines[i].strip())
        extracted = _extract_recipient_name_from_line(line)
        if extracted:
            mid_names.append(extracted)
            continue
        if looks_like_person_name(line):
            mid_names.append(line)

    if mid_names and not result["recipient"]:
        # Tên lớn đầu khối chi tiết (MB Bank) thường là người nhận
        result["recipient"] = mid_names[0]
    if len(mid_names) >= 2 and not result["sender"]:
        for nm in mid_names[1:]:
            if not names_match(nm, result.get("recipient") or ""):
                result["sender"] = nm
                break

    # 4) Tên đứng riêng hoặc nhúng trong dòng nhiễu (VietinBank)
    noidung_idx: Optional[int] = None
    for i, line in enumerate(lines):
        if re.search(r"noi\s*dung|nội\s*dung", line, re.I) and _CHUYEN_TIEN.search(line):
            noidung_idx = i
            break

    standalone_names: list[str] = []
    for i, line in enumerate(lines):
        if records and not _in_detail_zone(records[i].y_top, records[i].y_bot):
            continue
        if noidung_idx is not None and i > noidung_idx:
            continue
        s = _strip_name_suffix_noise(line.strip())
        if looks_like_person_name(s):
            standalone_names.append(s)
    embedded_names: list[str] = []
    for i, line in enumerate(lines):
        if records and not _in_detail_zone(records[i].y_top, records[i].y_bot):
            continue
        if noidung_idx is not None and i > noidung_idx:
            continue
        embedded_names.extend(_capital_name_runs(line))
    all_names = standalone_names + [n for n in embedded_names if n not in standalone_names]

    def _line_position_score(name: str) -> int:
        """Tên thật thường nằm cuối dòng OCR nhiễu."""
        best = -1
        for line in lines:
            pos = line.rfind(name)
            if pos > best:
                best = pos
        return best

    mb_outgoing = (
        _find_success_index(lines) is not None
        and result["recipient"]
        and not _has_explicit_sender_line(lines)
        and noidung_idx is None
    )
    if result["recipient"] and not result["sender"] and not mb_outgoing:
        pool = [nm for nm in all_names if not names_match(nm, result["recipient"])]
        if pool:
            result["sender"] = max(
                pool,
                key=lambda n: (
                    _name_quality_score(n),
                    _line_position_score(n),
                    len(n.split()),
                    len(n),
                ),
            )
    elif not result["recipient"] and all_names:
        if result["sender"]:
            pool_r = [n for n in all_names if not names_match(n, result["sender"])]
            if pool_r:
                result["recipient"] = max(
                    pool_r,
                    key=lambda n: (_name_quality_score(n), len(n.split()), len(n)),
                )
        else:
            result["recipient"] = all_names[0]
            if len(all_names) > 1:
                for nm in all_names[1:]:
                    if not names_match(nm, result["recipient"]):
                        result["sender"] = nm
                        break

    # 5) Box cao nhất trong vùng giữa (tên người nhận in lớn trên MB)
    if not result["recipient"] and boxes:
        mid_boxes = [
            b for b in boxes
            if b.y_top >= 0.28 and b.y_bot <= 0.72
            and (b.y_bot - b.y_top) >= 0.025
        ]
        if mid_boxes:
            tallest = max(mid_boxes, key=lambda b: b.y_bot - b.y_top)
            t = tallest.text.strip()
            if looks_like_person_name(t):
                result["recipient"] = t

    if result["sender"] and _is_bank_garbage_name(result["sender"]):
        result["sender"] = None

    if result["recipient"]:
        cleaned = _extract_recipient_name_from_line(result["recipient"])
        if cleaned:
            result["recipient"] = correct_recipient_name(cleaned)
        elif looks_like_person_name(result["recipient"]):
            result["recipient"] = correct_recipient_name(
                _strip_recipient_label(result["recipient"])
            )
        else:
            result["recipient"] = None

    note = None
    if _is_momo_bill(lines):
        note = _extract_momo_tin_nhan(lines, records if records else None)
    if not note and records:
        note = _extract_noidung_note(records)
    if not note:
        note = _extract_transfer_note(lines, start, end, records if records else None)
    if note:
        note = correct_transfer_note(note)
        if is_meaningful_note(note):
            result["note"] = note
            if not result["description"] or _TRANSFER_SUCCESS.search(result["description"]):
                result["description"] = note

    if result["sender"] and not looks_like_person_name(result["sender"]):
        result["sender"] = None
    if result["sender"]:
        words = result["sender"].split()
        if sum(1 for w in words if len(w) <= 2) >= 2:
            result["sender"] = None

    return result


def resolve_transfer_type(
    user_name: Optional[str],
    sender: Optional[str],
    recipient: Optional[str],
) -> tuple[Optional[str], Optional[str], str]:
    """
    Trả về (transaction_type, category_hint, reason).
    user trùng người nhận → INCOME; trùng người chuyển → EXPENSE.
    """
    if not user_name or not user_name.strip():
        return None, None, "no_user_name"

    u = user_name.strip()
    s_match = bool(sender and names_match(u, sender))
    r_match = bool(recipient and names_match(u, recipient))

    if r_match and not s_match:
        return "INCOME", "Thu nhập khác", "user_is_recipient"
    if s_match and not r_match:
        return "EXPENSE", "Khác", "user_is_sender"
    if r_match:
        return "INCOME", "Thu nhập khác", "user_matches_recipient"
    if s_match:
        return "EXPENSE", "Khác", "user_matches_sender"
    return None, None, "user_name_no_match"
