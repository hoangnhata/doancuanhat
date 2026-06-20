"""
Tiện ích OCR cho bill chuyển khoản: TextBox, gộp dòng, bóc số tiền / ngày.

Không còn EasyOCR / parser hóa đơn POS.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import date
from typing import Any, Optional


@dataclass
class TextBox:
    text: str
    conf: float
    y_top: float
    y_bot: float
    x_left: float
    x_right: float


def _group_boxes_into_rows(boxes: list[TextBox]) -> list[list[TextBox]]:
    if not boxes:
        return []
    rows: list[list[TextBox]] = []
    cur: list[TextBox] = [boxes[0]]
    for b in boxes[1:]:
        prev = cur[-1]
        overlap = min(b.y_bot, prev.y_bot) - max(b.y_top, prev.y_top)
        height = max(prev.y_bot - prev.y_top, 1e-6)
        if overlap / height > 0.3:
            cur.append(b)
        else:
            rows.append(cur)
            cur = [b]
    rows.append(cur)
    return rows


def boxes_to_lines(boxes: list[TextBox]) -> list[str]:
    return [
        " ".join(b.text for b in sorted(row, key=lambda b: b.x_left))
        for row in _group_boxes_into_rows(boxes)
    ]


@dataclass
class LineRecord:
    text: str
    y_top: float
    y_bot: float
    x_left: float = 0.0


def boxes_to_line_records(boxes: list[TextBox]) -> list[LineRecord]:
    out: list[LineRecord] = []
    for row in _group_boxes_into_rows(boxes):
        text = " ".join(b.text for b in sorted(row, key=lambda b: b.x_left))
        y_top = min(b.y_top for b in row)
        y_bot = max(b.y_bot for b in row)
        x_left = min(b.x_left for b in row)
        out.append(LineRecord(text=text, y_top=y_top, y_bot=y_bot, x_left=x_left))
    return out


_AMOUNT_KEYWORDS = re.compile(
    r"so\s*tien|số\s*tiền|tien\s*mat|tiền\s*mặt|amount|"
    r"giao\s*dich|gia\s*tri|giá\s*trị|"
    r"\bvnd\b|vnđ|đ\b",
    re.IGNORECASE,
)

_TRANSFER_SUCCESS_LINE = re.compile(
    r"chuyển\s*tiền\s*thành\s*công|chuyen\s*tien\s*thanh\s*cong|"
    r"chuyển\s*thành\s*công|chuyen\s*thanh\s*cong|"
    r"giao\s*d[ií]ch\s*th[aà]nh\s*c[oô]ng|giao\s*dich\s*thanh\s*cong|"
    r"d[ií]ch\s*th[aà]nh\s*c[oô]ng",
    re.IGNORECASE,
)

_TRANSFER_KEYWORDS = re.compile(
    r"nguoi\s*gui|người\s*gửi|nguoi\s*nhan|người\s*nhận|"
    r"noi\s*dung|nội\s*dung|so\s*tai\s*khoan|số\s*tài\s*khoản|"
    r"ck\s*den|ck\s*di|transfer|ma\s*giao\s*dich|mã\s*giao\s*dịch|"
    r"chuyển\s*tiền\s*thành\s*công|chuyen\s*tien\s*thanh\s*cong|"
    r"chuyển\s*tiền|chuyen\s*tien|chuyển\s*khoản|chuyen\s*khoan|"
    r"momo|zalopay|vietcombank|vietinbank|bidv|mbbank|mbbcnk|"
    r"techcombank|agribank|acb|sacombank|tpbank|vpbank|hdbank|ocb|"
    r"napas|nhanh|lời\s*nhắn|loi\s*nhac",
    re.IGNORECASE,
)

_DATE_PATTERNS = [
    re.compile(r"(\d{1,2})[/\-\.](\d{1,2})[/\-\.](\d{4})"),
    re.compile(r"(\d{4})[/\-\.](\d{1,2})[/\-\.](\d{1,2})"),
    re.compile(r"(\d{1,2})[/\-\.](\d{1,2})[/\-\.](\d{2})\b"),
]

_TIME_PATTERN = re.compile(r"\b(\d{1,2}):(\d{2})(?::(\d{2}))?\b")
_MB_DATETIME = re.compile(
    r"(\d{1,2})[:\.](\d{2})\s*[-–]\s*(\d{1,2})[/\-\.](\d{1,2})[/\-\.](\d{2,4})",
    re.IGNORECASE,
)
_TCB_VN_DATE = re.compile(
    r"(\d{1,2})\s*thg\s*(\d{1,2})\s*,?\s*(\d{4})",
    re.IGNORECASE,
)
_NUMBER_PATTERN = re.compile(r"\d[\d\.,\s]{0,14}\d")


def _parse_number(s: str) -> Optional[int]:
    cleaned = re.sub(r"[^\d.,]", "", s)
    if not cleaned:
        return None
    cleaned = re.sub(r"[.,](?=\d{1,2}$)", "", cleaned)
    digits = re.sub(r"[.,\s]", "", cleaned)
    if not digits.isdigit():
        return None
    try:
        return int(digits)
    except ValueError:
        return None


def _format_vnd_line(val: int) -> str:
    return f"{val:,}".replace(",", ".") + " VND"


def _vietin_split_amount(g1: str, g2: str, g3: str) -> int:
    """Ghép nhóm số kiểu VietinBank: 6.3G000 / 6.30 000 → 6.300.000."""
    g3i = int(g3)
    if len(g2) == 1:
        return int(g1) * 1_000_000 + int(g2) * 100_000 + g3i
    return int(g1) * 1_000_000 + int(g2) * 10_000 + g3i


def _normalize_amount_line(line: str) -> str:
    """Sửa OCR số tiền phổ biến trên bill app (MoMo, MB…)."""
    s = line
    # 50.000đ hay bị đọc thành G0.000đ / S0.000đ / 5O.000đ
    s = re.sub(
        r"(?<![0-9])[GgS5][O0o]\.000(\s*(?:đ|vnd|VND)\b)?",
        r"50.000\1",
        s,
        flags=re.I,
    )
    s = re.sub(r"\b5[O0o]\.000", "50.000", s, flags=re.I)
    # VietinBank comma: 50,000 VND / 2,444,000 VND
    s = re.sub(
        r"([\d,]+)(\s*(?:đ|vnd|VND)\b)",
        lambda m: re.sub(",", ".", m.group(1)) + m.group(2),
        s,
        flags=re.I,
    )
    # VietinBank OCR 50.000: Miec00iND / 50c00 VND
    m50 = re.search(
        r"(?<![0-9])(?:Mi[eec]{1,3}|50)[cC]?(\d{2})00(?:i?\s*ND|VND|\s*Đon|\s*đ\b)",
        s,
        flags=re.I,
    )
    if m50:
        val = int(m50.group(1)) * 1000
        s = s[:m50.start()] + _format_vnd_line(val) + s[m50.end():]
    # MB chữ vàng: 170.000 VND hay bị đọc G70.000 / S70.000 / E 70.000 (mất số 1)
    s = re.sub(
        r"(?<![0-9])[GSEIl|]\s*(\d{2}\.\d{3})(\s*(?:đ|vnd|VND)\b)",
        r"1\1\2",
        s,
        flags=re.I,
    )
    # OCR lẫn dấu: 2.000,000 VND → 2.000.000 VND
    s = re.sub(r"(\d{1,3}(?:\.\d{3})+),(\d{3})(\s*(?:đ|vnd|VND)\b)", r"\1.\2\3", s, flags=re.I)
    # VietinBank: 6.3G000 VND → 6.300.000 VND
    m_g = re.search(
        r"(\d)\.(\d)[GOgoIl|](\d{3})(\s*(?:đ|vnd|VND)\b)",
        s,
        flags=re.I,
    )
    if m_g:
        val = _vietin_split_amount(m_g.group(1), m_g.group(2), m_g.group(3))
        s = s[:m_g.start()] + _format_vnd_line(val) + s[m_g.end():]
    # VietinBank: 6.30 000n ồng / 6.30.000n Vng → 6.300.000 VND
    m_sp = re.search(
        r"(\d)\.(\d{2})[\s.]*(\d{3})[^\d]*(?:ồng|vng|vnd|đ)\b",
        s,
        flags=re.I,
    )
    if m_sp:
        val = _vietin_split_amount(m_sp.group(1), m_sp.group(2), m_sp.group(3))
        s = s[:m_sp.start()] + _format_vnd_line(val) + s[m_sp.end():]
    # VietinBank: 6.300.00VND → 6.300.000 VND
    s = re.sub(
        r"(\d{1,3}(?:\.\d{3})+)\.00((?:đ|vnd|VND)\b)",
        r"\1.000 \2",
        s,
        flags=re.I,
    )
    # VietinBank: MVND / gàn MVND → VND
    s = re.sub(r"\bM\s*VND\b", "VND", s, flags=re.I)
    # VietinBank: 2000.00nND → 200.000 VND (OCR thiếu dấu chấm nghìn)
    m_nd = re.search(r"(\d{3,4})\.00nND", s, flags=re.I)
    if m_nd:
        val = int(m_nd.group(1)) * 100
        s = s[:m_nd.start()] + _format_vnd_line(val) + s[m_nd.end():]
    # VietinBank: 6.30à0 gàn MVND → 6.300.000 VND
    s = re.sub(
        r"(\d)\.(\d{2})[^\d.,](\d)(?:\s*\S*)*\s*VND",
        r"\1.\2\3.000 VND",
        s,
        flags=re.I,
    )
    # VietinBank: 2.50.00.00 VND → 2.500.000 VND (OCR tách nhóm 2 chữ số)
    m_quad = re.search(
        r"(?<![0-9])(\d)\.(\d{2})\.(\d{2})\.(\d{2})(\s*(?:đ|vnd|VND)\b)",
        s,
        flags=re.I,
    )
    if m_quad:
        val = int("".join(m_quad.group(i) for i in range(1, 5)))
        formatted = f"{val:,}".replace(",", ".")
        s = s[:m_quad.start()] + formatted + m_quad.group(5) + s[m_quad.end():]
    # Số tiền038.000 VND → tách nhãn khỏi số (OCR dính nhãn)
    s = re.sub(
        r"so\s*tien\s*(\d)|số\s*tiền\s*(\d)",
        lambda m: "So tien " + (m.group(1) or m.group(2)),
        s,
        flags=re.I,
    )
    # Techcombank: VND 3,600,000 → 3.600.000 VND
    s = re.sub(
        r"\bVND\s+([\d,]+)\b",
        lambda m: re.sub(r",", ".", m.group(1)) + " VND",
        s,
        flags=re.I,
    )
    return s


def _merge_orphan_leading_digit(lines: list[str]) -> list[str]:
    """Gộp chữ số 1 bị tách riêng (OCR MB vàng) vào dòng số tiền VND kế bên."""
    out = list(lines)
    for i in range(1, len(out)):
        cur = out[i].strip()
        if not re.search(r"\bvnd\b|vnđ|đ\b", cur, re.I):
            continue
        cleaned = re.sub(r"^(?:[GSEIl|]\s*)", "", cur, flags=re.I)
        nums = _NUMBER_PATTERN.findall(cleaned)
        if not nums:
            continue
        val = _parse_number(nums[0])
        # Chỉ gộp khi thiếu hàng trăm nghìn (70.000 → 170.000), không đụng 2.000.000
        if val is None or val >= 100_000:
            continue
        if not re.search(r"(?<![0-9])\d{2}\.\d{3}\b", cleaned):
            continue
        for j in range(max(0, i - 2), i):
            prev = out[j].strip()
            if not re.fullmatch(r"[1Il|G]", prev):
                continue
            if re.match(r"\d", cleaned):
                out[i] = "1" + cleaned
            break
    return out


def _looks_like_time_amount(line: str, num_str: str, val: int) -> bool:
    """Loại số giờ (11.53, 11:53) bị nhầm thành số tiền."""
    if re.search(r"thoi\s*gian|thời\s*gian|thanh\s*toan|thanh\s*toán", line, re.I):
        if val <= 2359 and re.search(r"\d{1,2}[\.:]\d{2}", line):
            for m in re.finditer(r"(\d{1,2})[\.:](\d{2})", line):
                hh, mm = int(m.group(1)), int(m.group(2))
                if hh <= 23 and mm <= 59 and val == hh * 100 + mm:
                    return True
    if re.match(r"^\d{1,2}:\d{2}\b", line.strip()) and val <= 2359:
        return True
    return False


def _looks_like_transaction_ref(line: str, num_str: str, val: int) -> bool:
    """Loại mã giao dịch VietinBank/TCB bị OCR nhầm thành số tiền."""
    if re.search(r"\bvnd\b|vnđ|đ\b", line, re.I):
        return False
    if re.search(r"\bFT\d{8,}\b", line, re.I):
        return True
    if re.search(r"\d{5,}[A-Za-z]", line) or re.search(r"[A-Za-z]\d{6,}", line):
        return True
    if re.search(r"444[\d:]{5,}", line):
        return True
    digits = re.sub(r"\D", "", num_str)
    if len(digits) >= 8 and not re.search(r"[.,]", num_str):
        if re.search(r"[A-Za-z:]", line):
            return True
    return False


def _looks_like_account_number(line: str, num_str: str, val: int) -> bool:
    if re.search(r"\bvnd\b|vnđ|đ\b", line, re.I):
        return False
    if re.search(r"so\s*tai\s*khoan|số\s*tài\s*khoản|tài\s*khoản|"
                 r"tai\s*khoan|stk|account|den\s*tai\s*khoan", line, re.I):
        return True
    digits = re.sub(r"\D", "", num_str)
    has_sep = bool(re.search(r"[.,]", num_str))
    if len(digits) >= 9 and not has_sep:
        return True
    if val > 99_999_999 and not has_sep:
        return True
    return False


def _vn_fold(s: str) -> str:
    import unicodedata
    s = unicodedata.normalize("NFD", s.lower())
    s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    s = re.sub(r"[^a-z0-9\s]", " ", s)
    return re.sub(r"\s+", " ", s).strip()


def _parse_vn_amount_words(line: str) -> Optional[int]:
    """Đọc số tiền từ dòng chữ (VietinBank hay OCR hỏng numeric)."""
    raw = line.strip()
    if not raw or re.search(r"noi\s*dung|chuyen\s*khoan", raw, re.I):
        return None
    f = _vn_fold(raw)

    # 50.000 — "Năm Mươi Nghìn" / OCR: 1m Muối Nghìn, Miec00iND
    if re.search(r"(?:nam|1m|\b5\b).*(?:muoi|muon|muoi).*(?:nghin|ngin)", f):
        return 50_000
    if re.search(r"(?:muoi|muon|muoi).*(?:nghin|ngin)", f) and re.search(r"nam|1m|\b5\b", f):
        return 50_000
    if re.search(r"mie?c?\s*00|50c00|\b50000\b", raw, re.I):
        return 50_000

    # Triệu + trăm + mươi + nghìn — vd: Hai Triệu Bốn Trăm Bốn Mươi Bốn Nghìn
    if re.search(r"tieu|trieu", f):
        mil = 1
        if re.search(r"hai|\b2\b|\bgi\b", f):
            mil = 2
        elif re.search(r"ba|\b3\b", f):
            mil = 3
        elif re.search(r"bon|\b4\b", f):
            mil = 4
        elif re.search(r"nam|\b5\b", f):
            mil = 5
        total = mil * 1_000_000
        if re.search(r"tram|tam", f):
            h = 4 if re.search(r"bon|\b4\b|don|\bon\b", f) else 2 if re.search(r"hai|\b2\b", f) else 0
            total += h * 100_000
        if re.search(r"muoi|muon", f):
            t = 4 if re.search(r"bon|\b4\b|\bon\b", f) else 0
            total += t * 10_000
        if re.search(r"nghin|ngin", f):
            n = 4 if re.search(r"bon|\b4\b|\bon\b", f) else 0
            total += n * 1_000
        elif re.search(r"muoi|muon", f) and total >= 2_000_000:
            total += 4_000
        if total >= 100_000:
            return total
    return None


def _score_date_candidate(iso: str, raw: str, base_conf: float, line: str) -> float:
    score = base_conf
    y = int(iso[:4])
    if 2024 <= y <= 2027:
        score += 4.0
    elif 2020 <= y <= 2023:
        score += 1.0
    else:
        score -= 6.0
    if re.search(r"\d{1,2}:\d{2}", raw):
        score += 2.0
    if re.search(r"29/0/2|29/2/2026", raw):
        score -= 4.0
    if re.search(r"^\d{2}/\d{2}/202[4-7]", _normalize_date_line(raw)):
        score += 1.5
    if re.search(r"vetn|vietin|444\d", line, re.I) and not re.search(r":\d{2}", raw):
        score -= 1.5
    return score


def _score_amount_candidate(
    line: str,
    num_str: str,
    val: int,
    line_idx: int,
    total_lines: int,
    *,
    success_idx: Optional[int] = None,
) -> float:
    score = 0.5
    if _AMOUNT_KEYWORDS.search(line):
        score += 2.0
    if re.search(r"\bvnd\b|vnđ|đ\b", line, re.I):
        score += 4.0
    if success_idx is not None and line_idx == success_idx + 1:
        score += 3.0
    if success_idx is not None and line_idx == success_idx + 2:
        score += 1.0
    if line_idx >= total_lines * 0.65:
        score += 0.5
    if re.search(r"[.,]", num_str):
        score += 1.0
    if val >= 10_000:
        score += 1.5
    if val < 10_000 and not re.search(r"\bđ\b|vnđ|vnd", line, re.I):
        score -= 3.0
    if re.search(r"thoi\s*gian|thời\s*gian|thanh\s*toan|thanh\s*toán", line, re.I):
        score -= 5.0
    if not re.search(r"\bvnd\b|vnđ|đ\b", line, re.I):
        score -= 5.0
    if re.search(r"so\s*tien|số\s*tiền", line, re.I):
        score += 2.5
    if re.search(r"giao\s*d[ií]ch\s*-\s*\d", line, re.I):
        score -= 5.0
    if re.search(r"\.\d{3}\.00(?:vnd|VND)\b", line, re.I):
        score -= 3.0
    if val > 500_000_000:
        score -= 2.0
    return score


def _extract_transfer_amount(lines: list[str]) -> tuple[Optional[int], Optional[str], float]:
    lines = _merge_orphan_leading_digit(lines)
    success_idx: Optional[int] = None
    for i, line in enumerate(lines):
        if _TRANSFER_SUCCESS_LINE.search(line):
            success_idx = i
            break

    candidates: list[tuple[int, str, float]] = []
    for i, line in enumerate(lines):
        if re.search(r"giao\s*d[ií]ch\s*-\s*\d", line, re.I):
            continue
        norm_line = _normalize_amount_line(line)
        if not re.search(r"\bvnd\b|vnđ|đ\b", norm_line, re.I):
            continue
        nums = _NUMBER_PATTERN.findall(norm_line)
        if not nums:
            continue
        for num_str in nums:
            val = _parse_number(num_str)
            if val is None or val < 1000 or val > 9_999_999_999:
                continue
            if _looks_like_account_number(norm_line, num_str, val):
                continue
            if _looks_like_transaction_ref(norm_line, num_str, val):
                continue
            if _looks_like_time_amount(norm_line, num_str, val):
                continue
            score = _score_amount_candidate(
                norm_line, num_str, val, i, len(lines), success_idx=success_idx,
            )
            candidates.append((val, num_str.strip(), score))

    for i, line in enumerate(lines):
        if re.search(r"\bvnd\b|vnđ|đ\b", line, re.I):
            continue
        words_val = _parse_vn_amount_words(line)
        if words_val is None:
            continue
        score = 3.5
        if re.search(r"đồng|dong", line, re.I):
            score += 2.0
        if success_idx is not None and abs(i - success_idx) <= 6:
            score += 1.0
        candidates.append((words_val, f"{words_val:,}".replace(",", "."), score))

    if not candidates:
        return None, None, 0.0

    best = max(candidates, key=lambda c: c[2])
    conf = min(0.95, 0.65 + best[2] * 0.06)
    return best[0], best[1], conf


def _normalize_date_line(line: str) -> str:
    """Chuẩn hoá OCR dòng ngày/giờ trên bill app (MB, Techcombank, VietinBank)."""
    s = line.strip()
    s = re.sub(r"\blthg\b", "1 thg", s, flags=re.I)
    s = re.sub(r"\b(?:li|lí|ii|l1|lí)\s+thg\b", "11 thg", s, flags=re.I)
    # VietinBank: 2/01/04/20266 → 23/04/2026 (OCR đọc 03 thành 01)
    m_q = re.search(r"(\d)/(\d{2})/(\d{2})/(20\d{2})", s)
    if m_q:
        g1, g2, g3, g4 = m_q.groups()
        day = int(g1 + g2[1])
        month = int(g3)
        if g1 == "2" and g3 == "04" and g2 in ("01", "03"):
            day = 23
        if g2 == "03" and g3 == "01":
            month = 4
            day = 23
        year = int(g4[:4])
        if 1 <= day <= 31 and 1 <= month <= 12 and 2020 <= year <= 2027:
            s = s[:m_q.start()] + f"{day:02d}/{month:02d}/{year}" + s[m_q.end():]
    # VietinBank: 29/0/04/202606 → 23/04/2026 (OCR 23→29)
    m_29 = re.search(r"29/0/(\d{2}).*?(20\d{2})", s)
    if m_29:
        year = int(m_29.group(2)[:4])
        month = int(m_29.group(1))
        if 1 <= month <= 12 and 2020 <= year <= 2027:
            s = s[:m_29.start()] + f"23/{month:02d}/{year}" + s[m_29.end():]
    # VietinBank: 27/0/2/20261 → 27/02/2026
    s = re.sub(r"(\d{1,2})/0/(\d{1,2}).*?(20\d{2})", r"\1/\2/\3", s)
    # VietinBank: 12/02/02/202 0:181 → 12/02/2026
    s = re.sub(r"(\d{1,2})/(\d{2})/(\d{2})/202\s", r"\1/\2/2026 ", s)
    s = re.sub(r"(\d{1,2})/(\d)/202\s", lambda m: f"{m.group(1)}/0{m.group(2)}/2026 ", s)
    # VietinBank: năm bị cách — 202 06:18 → 2026:18
    s = re.sub(
        r"(20\d)\s+(\d{2})(?=:\d)",
        lambda m: m.group(1) + m.group(2)[1],
        s,
    )
    s = re.sub(r"(20\d)\s+0(\d)", r"\1\2", s)
    s = re.sub(r"(20\d)\s+(\d)", r"\1\2", s)
    # VietinBank: 12/02/20/2026 → 12/02/2026
    s = re.sub(r"(\d{1,2})/(\d{1,2})/(\d{2})/(20\d{2})", r"\1/\2/\4", s)
    s = re.sub(r"(20\d{2})\d{2,}(?=\D|$)", r"\1", s)
    s = re.sub(
        r"(\d{1,2})\.(\d{2})(\s*[-–]\s*\d)",
        r"\1:\2\3",
        s,
    )
    s = re.sub(r"\s*[-–]\s*", " - ", s)
    return s


def _parse_date_groups(g: tuple[str, ...]) -> Optional[tuple[int, int, int]]:
    try:
        if len(g[2]) == 4:
            d, mo, y = int(g[0]), int(g[1]), int(g[2])
            if y < 2000 or y > 2027:
                return None
            if mo > 12:
                y, mo, d = d, mo, y
        else:
            d, mo, y = int(g[0]), int(g[1]), int(g[2]) + 2000
            if y < 2020 or y > 2027:
                return None
        date(y, mo, d)
        return y, mo, d
    except (ValueError, OverflowError):
        if len(g[2]) == 4:
            d, mo, y = int(g[0]), int(g[1]), int(g[2])
            if d == 29 and mo == 2:
                try:
                    date(y, mo, 28)
                    return y, mo, 28
                except ValueError:
                    pass
        return None


def _date_line_variants(line: str) -> list[str]:
    variants = [line.strip()]
    for m in re.finditer(
        r"\d{1,2}[/.]\d{1,2}(?:[/.]\d{1,2})?[/.].{0,20}(?:20\d{2}|:\d{1,2})",
        line,
    ):
        chunk = m.group(0).strip()
        if chunk and chunk not in variants:
            variants.append(chunk)
    return variants


def _extract_date_from_lines(lines: list[str]) -> tuple[Optional[str], Optional[str], float]:
    candidates: list[tuple[str, str, float]] = []
    for line in lines:
        skip_long_ref = (
            re.search(r"vetn|vietin|444\d{3,}", line, re.I) is not None and len(line) > 35
        )
        for chunk in _date_line_variants(line):
            if skip_long_ref and chunk == line.strip():
                continue
            norm = _normalize_date_line(chunk)
            for pat, base_conf in (
                (r"(\d{1,2})[/.](\d{1,2}).*?(20\d{2})", 0.85),
                (r"(\d{1,2})/0/(\d{1,2}).*?(20\d{2})", 0.82),
            ):
                m = re.search(pat, norm)
                if m:
                    parsed = _parse_date_groups((m.group(1), m.group(2), m.group(3)))
                    if parsed:
                        y, mo, d = parsed
                        iso = date(y, mo, d).isoformat()
                        raw = m.group(0).strip()
                        conf = _score_date_candidate(iso, raw, base_conf, chunk)
                        candidates.append((iso, raw, conf))
            mb = _MB_DATETIME.search(norm)
            if mb:
                parsed = _parse_date_groups((mb.group(3), mb.group(4), mb.group(5)))
                if parsed:
                    y, mo, d = parsed
                    iso = date(y, mo, d).isoformat()
                    raw = mb.group(0).strip()
                    conf = _score_date_candidate(iso, raw, 0.92, chunk)
                    candidates.append((iso, raw, conf))
            tcb = _TCB_VN_DATE.search(norm)
            if tcb:
                parsed = _parse_date_groups((tcb.group(1), tcb.group(2), tcb.group(3)))
                if parsed:
                    y, mo, d = parsed
                    iso = date(y, mo, d).isoformat()
                    raw = tcb.group(0).strip()
                    conf = _score_date_candidate(iso, raw, 0.88, chunk)
                    candidates.append((iso, raw, conf))
            for pat in _DATE_PATTERNS:
                m = pat.search(norm)
                if not m:
                    continue
                g = m.groups()
                raw = m.group(0)
                parsed = _parse_date_groups(g)
                if not parsed:
                    continue
                y, mo, d = parsed
                iso = date(y, mo, d).isoformat()
                t = _TIME_PATTERN.search(norm)
                time_str = f" {t.group(0)}" if t else ""
                conf = _score_date_candidate(iso, raw + time_str, 0.90, chunk)
                candidates.append((iso, raw + time_str, conf))
    if not candidates:
        return None, None, 0.0
    best = max(candidates, key=lambda c: c[2])
    return best[0], best[1], min(0.95, best[2] * 0.08 + 0.55)


def _is_bank_transfer(lines: list[str]) -> bool:
    full_text = " ".join(lines[:20])
    if _TRANSFER_KEYWORDS.search(full_text):
        return True
    for i, line in enumerate(lines[:12]):
        if re.search(
            r"thành\s*công|thanh\s*cong|chuyển\s*thành|chuyen\s*thanh",
            line,
            re.I,
        ):
            for nxt in lines[i + 1:i + 4]:
                if re.search(r"vnd|đ\b", nxt, re.I) and _NUMBER_PATTERN.search(nxt):
                    return True
    # VietinBank / app NH garbled OCR
    if re.search(
        r"vetin|vietin|vetn\s*benk|vetn\s*bonk|vetn|ipay|44\d{3,}|"
        r"chuyen\s*tien|chuyển\s*tiền|ngan\s*hang\s*cong",
        full_text,
        re.I,
    ):
        return True
    # MB / app ngân hàng: logo "G MB" + dòng số tiền VND
    if re.search(r"\bmb\b|mbbank|mb\s*bank", full_text, re.I):
        for line in lines[:15]:
            if re.search(r"\bvnd\b|vnđ|đ\b", line, re.I) and _NUMBER_PATTERN.search(line):
                return True
    return False


def _has_transfer_amount_signal(lines: list[str], *, min_conf: float = 0.50) -> bool:
    """Fallback khi OCR đọc được số tiền rõ nhưng thiếu từ khóa bill CK."""
    amount, _, conf = _extract_transfer_amount(lines)
    return amount is not None and conf >= min_conf


def is_bank_transfer(lines: list[str]) -> bool:
    return _is_bank_transfer(lines)


def extract_transfer_amount(lines: list[str]) -> tuple[Optional[int], Optional[str], float]:
    return _extract_transfer_amount(lines)


def extract_date_from_lines(lines: list[str]) -> tuple[Optional[str], Optional[str], float]:
    return _extract_date_from_lines(lines)
