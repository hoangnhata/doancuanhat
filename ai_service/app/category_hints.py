"""Gợi ý danh mục từ từ khóa — ưu tiên câu ngắn / viết tắt trước khi fallback Khác."""
from __future__ import annotations

import re
import unicodedata

# (pattern, label) — thứ tự quan trọng: cụ thể trước, chung sau
_HINT_RULES: list[tuple[re.Pattern[str], str]] = []


def _add(pattern: str, label: str) -> None:
    _HINT_RULES.append((re.compile(pattern, re.IGNORECASE), label))


# --- Thu nhập (cụ thể trước Thu nhập khác) ---
_add(r"\b(freelance|freelancer|fl\s|gig\s|side\s*job)\b", "Freelance")
_add(r"\b(mb\s+ck\s+freelance|ck\s+freelance|nhận\s+freelance)\b", "Freelance")
_add(r"\b(làm\s+website|lam\s+website|thiết\s+kế\s+logo|thiet\s+ke\s+logo)\b", "Freelance")
_add(r"\b(dạy\s+kèm|day\s+kem|gia\s+sư\s+online|content\s+writer|viết\s+content)\b", "Freelance")
_add(r"\b(client\s+thanh\s+toán|invoice\s+freelance|project\s+freelance)\b", "Freelance")

_add(r"\b(đầu\s+tư|dau\s+tu|coin|crypto|bitcoin|eth\b|trade\s+coin)\b", "Đầu tư")
_add(r"\b(lời\s+coin|loi\s+coin|lãi\s+coin|lai\s+coin|profit\s+trading)\b", "Đầu tư")
_add(r"\b(cổ\s+tức|co\s+tuc|trái\s+phiếu|trai\s+phieu|lãi\s+tiết\s+kiệm|lai\s+tiet\s+kiem)\b", "Đầu tư")
_add(r"\b(cho\s+thuê\s+nhà|cho\s+thue\s+nha|thu\s+lãi|thu\s+lai)\b", "Đầu tư")

_add(r"\b(lương|luong|salary|payroll|khoản\s+cty\s+chuyển)\b", "Lương")
_add(r"\b(thưởng|thuong|bonus|kpi)\b", "Thưởng")
_add(r"\b(bán\s+đồ\s+cũ|ban\s+do\s+cu|doanh\s+thu|bán\s+hàng|ban\s+hang)\b", "Bán hàng")
_add(
    r"\b(hoàn\s+tiền|hoan\s+tien|refund|cashback|nhận\s+mừng|nhan\s+mung|nhận\s+quà|nhan\s+qua)\b",
    "Thu nhập khác",
)

# --- Chi tiêu: nhà ở / trọ (trước Khác) ---
_add(r"\b(ck\s+tiền\s+trọ|ck\s+tien\s+tro|ck\s+trọ|ck\s+tro)\b", "Nhà ở")
_add(r"\b(tiền\s+trọ|tien\s+tro|thuê\s+trọ|thue\s+tro|phòng\s+trọ|phong\s+tro)\b", "Nhà ở")
_add(r"\b(tiền\s+nhà|tien\s+nha|thuê\s+nhà|thue\s+nha|pay\s+rent|tra\s+tien\s+phong)\b", "Nhà ở")
_add(r"\b(chung\s+cư|sửa\s+nhà|sua\s+nha|nội\s+thất|noi\s+that|máy\s+giặt|may\s+giat)\b", "Nhà ở")

# --- Mua sắm: viết tắt dt / điện thoại mới ---
_add(r"\b(dt\s+mới|dt\s+moi|đt\s+mới|đt\s+moi|dien\s+thoai\s+moi)\b", "Mua sắm")
_add(r"\b(mua\s+dt\s+mới|mua\s+dt\s+moi|mua\s+điện\s+thoại\s+mới|mua\s+dien\s+thoai)\b", "Mua sắm")
_add(r"\b(iphone|samsung\s+mới|macbook|laptop\s+mới|ipad)\b", "Mua sắm")
_add(r"\b(shopee|lazada|tiki|order\s+phụ\s+kiện|chốt\s+đơn|mua\s+son|mua\s+giày)\b", "Mua sắm")

# --- Hóa đơn: nạp dt (không phải mua máy) ---
_add(r"\b(nạp\s+dt|nap\s+dt|nạp\s+tiền\s+điện\s+thoại|cước\s+điện\s+thoại)\b", "Hóa đơn")
_add(r"\b(đóng\s+tiền\s+điện|dong\s+tien\s+dien|tiền\s+điện|tien\s+dien|wifi|internet)\b", "Hóa đơn")

_add(r"\b(ăn|uống|cơm|phở|bún|quán|cafe|trà\s+sữa|grab\s+food)\b", "Ăn uống")
_add(r"\b(xăng|grab|uber|taxi|be\s+bike|gửi\s+xe)\b", "Di chuyển")
_add(r"\b(phim|netflix|game|karaoke|giải\s+trí)\b", "Giải trí")
_add(r"\b(du\s+lịch|khách\s+sạn|vé\s+máy\s+bay|tour)\b", "Du lịch")
_add(r"\b(học\s+phí|sách|khóa\s+học|giáo\s+dục)\b", "Giáo dục")
_add(r"\b(khám|thuốc|bệnh|viện|gym|sức\s+khỏe)\b", "Sức khỏe")
_add(r"\b(ba\s+mẹ|con\s|cô|chú|gia\s+đình)\b", "Gia đình")
_add(r"\b(chó|mèo|thú\s+cưng|pet\s+shop)\b", "Thú cưng")
_add(r"\b(tặng|quà|sinh\s+nhật|mừng\s+cưới)\b", "Quà tặng")
_add(r"\b(mừng\s+mẹ|mung\s+me|mừng\s+me|8/3|8\.3)\b", "Quà tặng")
_add(r"\b(từ\s+thiện|quyên\s+góp|ủng\s+hộ)\b", "Từ thiện")
_add(r"\b(phí\s+ngân\s+hàng|phí\s+bank|phí\s+dịch\s+vụ)\b", "Hóa đơn")
_add(r"\b(phí\s+chuyển\s+tiền|phi\s+chuyen\s+tien|phí\s+ck|phí\s+giao\s+dịch)\b", "Hóa đơn")
_add(r"\b(chuyển\s+khoản\s+nhận\s+từ\s+khách|khách\s+ck|khách\s+trả\s+tiền|nhận\s+tiền\s+khách)\b", "Bán hàng")
_add(r"\b(nâng\s+cấp\s+ram|mua\s+ssd|linh\s+kiện\s+pc|sạc\s+dự\s+phòng)\b", "Mua sắm")
_add(r"\b(sơn\s+tường|đặt\s+cọc\s+phòng|sửa\s+cửa\s+phòng)\b", "Nhà ở")
_add(r"\b(hostel|homestay|resort|booking\s+khách\s+sạn|visa\s+du)\b", "Du lịch")
_add(r"\b(vé\s+tàu|vé\s+xe\s+khách|bảo\s+hiểm\s+xe|gửi\s+xe\s+tháng)\b", "Di chuyển")
_add(r"\b(cho\s+mẹ\s+mua\s+thuốc|gửi\s+tiền\s+sinh\s+hoạt|tiền\s+cho\s+em)\b", "Gia đình")
_add(r"\b(mượn\s+bạn\s+trả\s+lại|chi\s+tiêu\s+không\s+phân\s+loại|mua\s+pin\s+aa)\b", "Khác")


def _norm(text: str) -> str:
    return unicodedata.normalize("NFC", (text or "").strip().lower())


def hint_category(text: str) -> str | None:
    """Trả nhãn nếu khớp rule; None nếu không."""
    t = _norm(text)
    if not t:
        return None
    for pat, label in _HINT_RULES:
        if pat.search(t):
            return label
    return None


def infer_income_subcategory(text: str) -> str | None:
    """Khi loại INCOME nhưng nhãn đang là Khác / Thu nhập khác."""
    t = _norm(text)
    for pat, label in _HINT_RULES:
        if label in {"Lương", "Thưởng", "Freelance", "Đầu tư", "Bán hàng", "Thu nhập khác"}:
            if pat.search(t):
                return label
    return None
