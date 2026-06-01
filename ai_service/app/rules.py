from __future__ import annotations

import re


def rule_based_category(text: str) -> str:
    from .category_hints import hint_category

    hinted = hint_category(text)
    if hinted:
        return hinted

    t = (text or "").lower()

    if re.search(r"\b(ăn|uống|cơm|phở|bún|bánh mì|trà sữa|cafe|cà phê|quán)\b", t):
        return "Ăn uống"
    if re.search(r"\b(xăng|grab|uber|taxi|xe ôm|gửi xe|đi lại|di chuyển)\b", t):
        return "Di chuyển"
    if re.search(r"\b(đổ xăng|xăng xe|xăng)\b", t):
        return "Di chuyển"
    if re.search(r"\b(mua|sắm|shop|shopee|lazada|tiki|đặt hàng)\b", t):
        return "Mua sắm"
    if re.search(r"\b(áo|quần|giày|váy|thời trang)\b", t):
        return "Mua sắm"
    if re.search(r"\b(makeup|mỹ phẩm|son|kem|spa|làm đẹp)\b", t):
        return "Mua sắm"
    if re.search(r"\b(tiền nhà|thuê nhà|chung cư|nhà ở)\b", t):
        return "Nhà ở"
    if re.search(r"\b(điện|nước|internet|wifi|tiền nhà|hóa đơn)\b", t):
        return "Hóa đơn"
    if re.search(r"\b(phim|game|giải trí|karaoke|cafe|cà phê)\b", t):
        return "Giải trí"
    if re.search(r"\b(du lịch|khách sạn|vé máy bay|tour)\b", t):
        return "Du lịch"
    if re.search(r"\b(học|khóa|lớp|sách|giáo dục|học phí)\b", t):
        return "Giáo dục"
    if re.search(r"\b(thuốc|bệnh|khám|viện|y tế|sức khỏe)\b", t):
        return "Sức khỏe"
    if re.search(r"\b(con|bố|mẹ|gia đình|tiền gửi về)\b", t):
        return "Gia đình"
    if re.search(r"\b(chó|mèo|thú cưng|cát vệ sinh|hạt)\b", t):
        return "Thú cưng"
    if re.search(r"\b(quà|sinh nhật|tặng)\b", t):
        return "Quà tặng"
    if re.search(r"\b(từ thiện|quyên góp|ủng hộ)\b", t):
        return "Từ thiện"
    if re.search(r"\b(phí|lệ phí|ngân hàng|phí dịch vụ)\b", t):
        return "Hóa đơn"

    return "Khác"

