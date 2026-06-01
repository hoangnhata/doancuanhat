"""
EasyOCR-based receipt parser — hoạt động trên ảnh thực, ảnh chụp, bill chuyển khoản.

Pipeline:
  1. EasyOCR phát hiện + nhận dạng TẤT CẢ text box trên ảnh
  2. Sắp xếp theo vị trí dọc (trên → dưới)
  3. Regex rules thông minh extract: amount, date, merchant, description

Hỗ trợ:
  - Bill POS (in nhiệt): GrabFood, Highlands, siêu thị, xăng…
  - Biên lai chuyển khoản ngân hàng (MoMo, VietcomBank, MB, ZaloPay…)
  - Ảnh chụp điện thoại, screenshot
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from datetime import date
from io import BytesIO
from pathlib import Path
from typing import Any, Optional

from PIL import Image


# ─────────────────────────── EasyOCR loader ──────────────────────────────────

_easyocr_reader = None  # lazy singleton


def _get_reader(gpu: bool = False):
    global _easyocr_reader
    if _easyocr_reader is None:
        import easyocr
        _easyocr_reader = easyocr.Reader(["vi", "en"], gpu=gpu, verbose=False)
    return _easyocr_reader


def easyocr_available() -> bool:
    try:
        import easyocr  # noqa: F401
        return True
    except ImportError:
        return False


# ─────────────────────────── Text extraction ─────────────────────────────────

@dataclass
class TextBox:
    text: str
    conf: float
    y_top: float   # vị trí dọc trên (0–1 relative to image height)
    y_bot: float
    x_left: float
    x_right: float


def extract_text_boxes(img: Image.Image, gpu: bool = False) -> list[TextBox]:
    """Chạy EasyOCR, trả về danh sách TextBox đã sort theo y."""
    reader = _get_reader(gpu)
    w, h = img.size
    # EasyOCR nhận numpy array
    import numpy as np
    arr = np.array(img.convert("RGB"))
    results = reader.readtext(arr, detail=1, paragraph=False)
    boxes: list[TextBox] = []
    for bbox, text, conf in results:
        xs = [p[0] for p in bbox]
        ys = [p[1] for p in bbox]
        boxes.append(TextBox(
            text=text.strip(),
            conf=float(conf),
            y_top=min(ys) / h,
            y_bot=max(ys) / h,
            x_left=min(xs) / w,
            x_right=max(xs) / w,
        ))
    boxes.sort(key=lambda b: b.y_top)
    return boxes


def boxes_to_lines(boxes: list[TextBox]) -> list[str]:
    """Gộp boxes cùng dòng, trả về list line text."""
    if not boxes:
        return []
    lines: list[list[TextBox]] = []
    cur: list[TextBox] = [boxes[0]]
    for b in boxes[1:]:
        prev = cur[-1]
        # cùng dòng nếu y_top của box mới nằm trong khoảng y của dòng hiện tại
        overlap = min(b.y_bot, prev.y_bot) - max(b.y_top, prev.y_top)
        height = max(prev.y_bot - prev.y_top, 1e-6)
        if overlap / height > 0.3:
            cur.append(b)
        else:
            lines.append(cur)
            cur = [b]
    lines.append(cur)
    # Sort từng dòng theo x, nối lại
    return [" ".join(b.text for b in sorted(row, key=lambda b: b.x_left)) for row in lines]


# ─────────────────────────── Pattern constants ───────────────────────────────

_AMOUNT_KEYWORDS = re.compile(
    r"tong\s*cong|tổng\s*cộng|thanh\s*toan|thanh\s*toán|total|"
    r"so\s*tien|số\s*tiền|tien\s*mat|tiền\s*mặt|amount|"
    r"tien\s*hang|tong\s*tien|tổng\s*tiền|giao\s*dich|"
    r"so\s*du|số\s*dư|phi\s*giao\s*dich|gia\s*tri",
    re.IGNORECASE,
)

_TRANSFER_KEYWORDS = re.compile(
    r"nguoi\s*gui|người\s*gửi|nguoi\s*nhan|người\s*nhận|"
    r"noi\s*dung|nội\s*dung|so\s*tai\s*khoan|số\s*tài\s*khoản|"
    r"ck\s*den|ck\s*di|transfer|ma\s*giao\s*dich|mã\s*giao\s*dịch|"
    r"momo|zalopay|vietcombank|vietinbank|bidv|mbbank|techcombank|"
    r"agribank|acb|sacombank|tpbank|vpbank|hdbank|ocb|"
    r"napas|nhanh|tiet\s*kiem",
    re.IGNORECASE,
)

_DATE_PATTERNS = [
    re.compile(r"(\d{1,2})[/\-\.](\d{1,2})[/\-\.](\d{4})"),
    re.compile(r"(\d{4})[/\-\.](\d{1,2})[/\-\.](\d{1,2})"),
    re.compile(r"(\d{1,2})[/\-\.](\d{1,2})[/\-\.](\d{2})\b"),
]

_TIME_PATTERN = re.compile(r"\b(\d{1,2}):(\d{2})(?::(\d{2}))?\b")

_NUMBER_PATTERN = re.compile(r"\d[\d\.,\s]{0,14}\d")

_MERCHANT_STOP = re.compile(
    r"\d{2}[/\-\.]\d{2}|so\s*hoa\s*don|invoice|receipt|"
    r"dia\s*chi|address|tel|phone|sdt|hotline|website|www\.",
    re.IGNORECASE,
)


# ─────────────────────────── Amount parser ───────────────────────────────────

def _parse_number(s: str) -> Optional[int]:
    """Chuỗi số → int, xử lý dấu . , và space."""
    # Xoa ky tu khong phai so / dau phan cach
    cleaned = re.sub(r"[^\d.,]", "", s)
    if not cleaned:
        return None
    # Xac dinh dau thap phan: neu dau cuoi la , hoac . va sau do co 2 chu so → decimal
    # VND khong co phan thap phan → bo qua phan thap phan
    cleaned = re.sub(r"[.,](?=\d{1,2}$)", "", cleaned)  # remove trailing decimal
    digits = re.sub(r"[.,\s]", "", cleaned)
    if not digits.isdigit():
        return None
    try:
        return int(digits)
    except ValueError:
        return None


def _extract_amount_from_lines(lines: list[str]) -> tuple[Optional[int], Optional[str], float]:
    """
    Trả về (amount_vnd, raw_text, confidence).
    Ưu tiên: dòng có keyword tổng tiền → số lớn nhất trong VND range.
    """
    candidates: list[tuple[int, str, float]] = []

    for i, line in enumerate(lines):
        nums = _NUMBER_PATTERN.findall(line)
        if not nums:
            continue
        has_kw = bool(_AMOUNT_KEYWORDS.search(line))
        for num_str in nums:
            val = _parse_number(num_str)
            if val is None or val < 1000 or val > 9_999_999_999:
                continue
            # Score: keyword match = +2, lớn hơn = ưu tiên, gần cuối bill = +1
            score = 0.5
            if has_kw:
                score += 2.0
            # Dòng cuối bill thường là tổng tiền
            if i >= len(lines) * 0.65:
                score += 0.5
            candidates.append((val, num_str.strip(), score))

    if not candidates:
        return None, None, 0.0

    # Chon candidate co score cao nhat; neu bang nhau chon so lon nhat
    best = max(candidates, key=lambda c: (c[2], c[0]))
    # Normalize confidence: keyword match → 0.92, khong keyword → 0.65
    conf = min(0.95, 0.60 + best[2] * 0.12)
    return best[0], best[1], conf


# ─────────────────────────── Date parser ─────────────────────────────────────

def _extract_date_from_lines(lines: list[str]) -> tuple[Optional[str], Optional[str], float]:
    """Trả về (iso_date, raw_text, confidence)."""
    from datetime import datetime

    for line in lines:
        for pat in _DATE_PATTERNS:
            m = pat.search(line)
            if not m:
                continue
            g = m.groups()
            raw = m.group(0)
            try:
                if len(g[2]) == 4:  # dd/mm/yyyy
                    d, mo, y = int(g[0]), int(g[1]), int(g[2])
                    if mo > 12:  # yyyy/mm/dd
                        y, mo, d = d, mo, y
                else:  # dd/mm/yy
                    d, mo, y = int(g[0]), int(g[1]), int(g[2]) + 2000
                iso = date(y, mo, d).isoformat()
                # Them thoi gian neu co
                t = _TIME_PATTERN.search(line)
                time_str = f" {t.group(0)}" if t else ""
                return iso, raw + time_str, 0.90
            except (ValueError, OverflowError):
                continue
    return None, None, 0.0


# ─────────────────────────── Merchant parser ─────────────────────────────────

def _extract_merchant(lines: list[str], boxes: list[TextBox]) -> tuple[str, float]:
    """
    Merchant thường ở dòng đầu tiên, chữ lớn nhất (có thể nhiều dòng).
    """
    if not boxes:
        return "", 0.0

    # Tim box co font lon nhat (height lon nhat) o 1/4 tren cua anh
    top_boxes = [b for b in boxes if b.y_top < 0.30]
    if not top_boxes:
        top_boxes = boxes[:min(5, len(boxes))]

    # Box co height lon nhat → tên cửa hàng
    tallest = max(top_boxes, key=lambda b: b.y_bot - b.y_top)

    # Lấy tất cả box cùng dòng với tallest
    row_boxes = [
        b for b in top_boxes
        if abs(b.y_top - tallest.y_top) < 0.06
        and b.conf > 0.4
    ]
    merchant_text = " ".join(b.text for b in sorted(row_boxes, key=lambda b: b.x_left))

    # Neu qua ngan, thu gop them dong tiep theo
    if len(merchant_text) < 3 and len(lines) > 1:
        for line in lines[:3]:
            if len(line) >= 3 and not _MERCHANT_STOP.search(line):
                merchant_text = line
                break

    conf = float(tallest.conf) if merchant_text else 0.0
    return merchant_text.strip(), min(conf, 0.90)


# ─────────────────────────── Description parser ──────────────────────────────

_ITEM_LINE = re.compile(
    r"\d{1,3}\.?\s*\d{3,}|"  # số có dấu .
    r"\bx\s*\d+\b|"           # x2, x3
    r"\d+\s*(phan|phần|cái|chai|ly|lon|kg|g\b|goi|gói)",
    re.IGNORECASE,
)

_NOISE_LINE = re.compile(
    r"^[\d\s\.,/:]+$|"  # dòng chỉ số
    r"^\*+$|"
    r"^-+$|"
    r"^=+$",
)


def _extract_description(lines: list[str], start_ratio: float = 0.25) -> str:
    """Trích xuất dòng mô tả sản phẩm / nội dung chuyển khoản."""
    items: list[str] = []
    for i, line in enumerate(lines):
        if len(line) < 3:
            continue
        if _NOISE_LINE.match(line.strip()):
            continue
        if _AMOUNT_KEYWORDS.search(line):
            continue
        # Uu tien dong co dang 'Ten san pham ... gia'
        if re.search(r"[a-zA-ZÀ-ỹ]", line) and not re.match(r"^\d", line):
            items.append(line)
        if len(items) >= 3:
            break

    # Neu la bill chuyen khoan, tim noi dung
    noidung_match = None
    for line in lines:
        m = re.search(r"(?:noi\s*dung|nội\s*dung|mo\s*ta|mô\s*tả)[:\s]+(.+)", line, re.IGNORECASE)
        if m and len(m.group(1)) > 2:
            noidung_match = m.group(1).strip()
            break

    if noidung_match:
        return noidung_match
    return "; ".join(items[:2]) if items else ""


# ─────────────────────────── Bank transfer detector ──────────────────────────

def _is_bank_transfer(lines: list[str]) -> bool:
    """Phát hiện biên lai chuyển khoản ngân hàng / ví điện tử."""
    full_text = " ".join(lines[:15])
    return bool(_TRANSFER_KEYWORDS.search(full_text))


def _extract_bank_transfer(lines: list[str], boxes: list[TextBox]) -> dict[str, Any]:
    """Parser đặc biệt cho biên lai chuyển khoản."""
    result: dict[str, Any] = {}
    for i, line in enumerate(lines):
        lo = line.lower()
        # So tien
        if re.search(r"so\s*tien|số\s*tiền|amount|gia\s*tri|giá\s*trị", lo):
            nums = _NUMBER_PATTERN.findall(line)
            for n in nums:
                v = _parse_number(n)
                if v and v >= 1000:
                    result["amount"] = v
                    result["amount_raw"] = n
                    break
        # Noi dung
        if re.search(r"noi\s*dung|nội\s*dung|mo\s*ta|mô\s*tả|note|rem", lo):
            m = re.split(r"[:\s]+", line, maxsplit=2)
            if len(m) >= 2 and len(m[-1]) > 2:
                result["description"] = m[-1].strip()
        # Nguoi nhan / Cua hang
        if re.search(r"nguoi\s*nhan|người\s*nhận|ten\s*tk|tên\s*tk|beneficiary", lo):
            m2 = re.split(r"[:\s]+", line, maxsplit=2)
            if len(m2) >= 2 and len(m2[-1]) > 2:
                result["merchant"] = m2[-1].strip()
    return result


# ─────────────────────────── Main parser ─────────────────────────────────────

@dataclass
class RealOcrResult:
    amount_vnd: Optional[int] = None
    transaction_date: Optional[str] = None
    merchant: Optional[str] = None
    description: Optional[str] = None
    raw_amount: Optional[str] = None
    raw_date: Optional[str] = None
    conf_amount: float = 0.0
    conf_date: float = 0.0
    conf_merchant: float = 0.0
    all_lines: list[str] = field(default_factory=list)
    is_bank_transfer: bool = False


def parse_receipt_easyocr(
    img: Image.Image,
    *,
    gpu: bool = False,
    min_conf: float = 0.30,
) -> RealOcrResult:
    """
    Pipeline chính:
    1. EasyOCR detect text
    2. Parse amount, date, merchant, description
    """
    boxes = extract_text_boxes(img, gpu=gpu)
    # Loc box co confidence thap
    boxes = [b for b in boxes if b.conf >= min_conf]
    lines = boxes_to_lines(boxes)
    result = RealOcrResult(all_lines=lines)

    if not lines:
        return result

    # Detect bank transfer
    result.is_bank_transfer = _is_bank_transfer(lines)

    if result.is_bank_transfer:
        bt = _extract_bank_transfer(lines, boxes)
        result.amount_vnd = bt.get("amount")
        result.raw_amount = bt.get("amount_raw")
        result.conf_amount = 0.85 if result.amount_vnd else 0.0
        result.description = bt.get("description")
        result.merchant = bt.get("merchant")

    # Amount (chạy cả với bank transfer để fill gap)
    if result.amount_vnd is None:
        amt, raw_amt, conf_amt = _extract_amount_from_lines(lines)
        result.amount_vnd = amt
        result.raw_amount = raw_amt
        result.conf_amount = conf_amt

    # Date
    iso_date, raw_date, conf_date = _extract_date_from_lines(lines)
    result.transaction_date = iso_date
    result.raw_date = raw_date
    result.conf_date = conf_date

    # Merchant (nếu chưa có từ bank transfer)
    if not result.merchant:
        merchant, conf_m = _extract_merchant(lines, boxes)
        result.merchant = merchant or None
        result.conf_merchant = conf_m

    # Description
    if not result.description:
        result.description = _extract_description(lines)

    return result


def parse_receipt_bytes_easyocr(
    data: bytes,
    *,
    gpu: bool = False,
) -> RealOcrResult:
    img = Image.open(BytesIO(data))
    if img.mode not in ("RGB", "L"):
        img = img.convert("RGB")
    return parse_receipt_easyocr(img, gpu=gpu)
