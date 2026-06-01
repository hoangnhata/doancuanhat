# -*- coding: utf-8 -*-
"""Catalog ~400 hard validation samples — imported by app.val_hard_samples."""
from __future__ import annotations

# Contrastive / ambiguous pairs (explicit)
CONTRASTIVE: list[tuple[str, str]] = [
    ("grab food 80k", "Ăn uống"),
    ("grab đi làm 80k", "Di chuyển"),
    ("grab đi ăn với bạn 120k", "Ăn uống"),
    ("grab ra sân bay 350k", "Di chuyển"),
    ("hostel du lịch 2 ngày 400k", "Du lịch"),
    ("tiền phòng trọ tháng này 2tr5", "Nhà ở"),
    ("thuê khách sạn đi chơi 1tr2", "Du lịch"),
    ("thuê phòng dài hạn 3tr", "Nhà ở"),
    ("mua thuốc cho mẹ 500k", "Gia đình"),
    ("mua thuốc cho bản thân 80k", "Sức khỏe"),
    ("mua thuốc cho mình 120k", "Sức khỏe"),
    ("đưa mẹ đi khám 600k", "Gia đình"),
    ("khám bệnh cá nhân 500k", "Sức khỏe"),
    ("hoàn tiền momo 50k", "Thu nhập khác"),
    ("mượn bạn 500k trả lại", "Khác"),
    ("cashback shopee 30k", "Thu nhập khác"),
    ("chi phí linh tinh 200k", "Khác"),
    ("khách trả tiền đơn hàng 1tr5", "Bán hàng"),
    ("lương công ty chuyển khoản 12tr", "Lương"),
    ("nhận tiền freelance web 4tr", "Freelance"),
    ("nhận lại tiền cọc 2tr", "Thu nhập khác"),
    ("phí chuyển tiền ngân hàng 10k", "Hóa đơn"),
    ("chuyển khoản nhận từ khách hàng 4tr", "Bán hàng"),
    ("nâng cấp RAM máy tính 5tr", "Mua sắm"),
    ("sơn tường 2tr5", "Nhà ở"),
    ("vé tàu hỏa Sài Gòn Đà Nẵng 500k", "Di chuyển"),
    ("resort Mũi Né 3tr", "Du lịch"),
    ("thuê phòng hostel bụi 200k", "Du lịch"),
    ("ck tiền trọ", "Nhà ở"),
    ("dt mới 15tr", "Mua sắm"),
    ("mb ck freelance", "Freelance"),
    ("đầu tư coin lời 2tr", "Đầu tư"),
]

# Short / abbrev / slang
SHORT_ABB_VAL: list[tuple[str, str]] = [
    ("ck tiền trọ", "Nhà ở"),
    ("ck phòng trọ", "Nhà ở"),
    ("tiền trọ", "Nhà ở"),
    ("dt mới 15tr", "Mua sắm"),
    ("đt mới 15tr", "Mua sắm"),
    ("mua dt", "Mua sắm"),
    ("cf sáng", "Ăn uống"),
    ("cafe sáng", "Ăn uống"),
    ("tx grab", "Di chuyển"),
    ("grab food", "Ăn uống"),
    ("mb ck freelance", "Freelance"),
    ("ck freelance web", "Freelance"),
    ("lãi coin", "Đầu tư"),
    ("đầu tư coin lời", "Đầu tư"),
    ("lãi chứng khoán", "Đầu tư"),
    ("nap dt 100k", "Hóa đơn"),
]

# OOD / amount-only / non-finance
OOD_VAL: list[tuple[str, str]] = [
    ("50k", "Khác"),
    ("100000", "Khác"),
    ("20tr", "Khác"),
    ("hello world", "Khác"),
    ("hôm nay trời đẹp", "Khác"),
    ("asdfasdf qwerty", "Khác"),
    ("123456", "Khác"),
    ("ok", "Khác"),
    ("ừ", "Khác"),
]

# Per-class hard anchors (user list)
CLASS_HARD: list[tuple[str, str]] = [
    # Bán hàng
    ("khách chuyển khoản mua hàng 2tr", "Bán hàng"),
    ("khách ck tiền đơn 500k", "Bán hàng"),
    ("nhận tiền bán áo 300k", "Bán hàng"),
    ("nhận tiền bán laptop cũ 5tr", "Bán hàng"),
    ("thu tiền khách mua sản phẩm 1tr2", "Bán hàng"),
    ("bán đồ cũ trên chợ tốt 800k", "Bán hàng"),
    ("tiền khách thanh toán đơn 450k", "Bán hàng"),
    ("nhận tiền ship COD 600k", "Bán hàng"),
    # Mua sắm
    ("mua RAM laptop 2tr", "Mua sắm"),
    ("mua SSD 1tr5", "Mua sắm"),
    ("mua sạc dự phòng 200k", "Mua sắm"),
    ("mua bàn phím cơ 800k", "Mua sắm"),
    ("mua đồ gia dụng 500k", "Mua sắm"),
    # Hóa đơn
    ("trả tiền điện 400k", "Hóa đơn"),
    ("đóng tiền nước 120k", "Hóa đơn"),
    ("thanh toán wifi 260k", "Hóa đơn"),
    ("phí ngân hàng hàng tháng 50k", "Hóa đơn"),
    # Nhà ở
    ("sửa cửa phòng trọ 300k", "Nhà ở"),
    ("đặt cọc phòng trọ 5tr", "Nhà ở"),
    ("sửa điện nước trong phòng 200k", "Nhà ở"),
    ("đóng tiền nhà 3tr", "Nhà ở"),
    # Di chuyển
    ("mua bảo hiểm xe máy 200k", "Di chuyển"),
    ("gửi xe tháng 150k", "Di chuyển"),
    ("vé xe khách 250k", "Di chuyển"),
    ("đổ xăng 180k", "Di chuyển"),
    ("taxi ra sân bay 350k", "Di chuyển"),
    # Du lịch
    ("chi phí xin visa Thái Lan 1tr", "Du lịch"),
    ("đặt homestay Đà Lạt 800k", "Du lịch"),
    ("booking khách sạn 2tr", "Du lịch"),
    ("tour du lịch 5tr", "Du lịch"),
    # Gia đình
    ("gửi tiền sinh hoạt cho mẹ 1tr", "Gia đình"),
    ("tiền cho em gái đi học 500k", "Gia đình"),
    ("hỗ trợ bố mẹ 2tr", "Gia đình"),
    # Sức khỏe
    ("mua thuốc cho bản thân 80k", "Sức khỏe"),
    ("khám bệnh 500k", "Sức khỏe"),
    ("xét nghiệm máu 450k", "Sức khỏe"),
    ("đi nha khoa 1tr2", "Sức khỏe"),
    # Khác
    ("việc linh tinh 200k", "Khác"),
    ("chuyển tiền nhầm 100k", "Khác"),
    ("trả nợ bạn 500k", "Khác"),
    # Thu nhập khác
    ("refund lazada 180k", "Thu nhập khác"),
    ("nhận tiền hoàn đơn 250k", "Thu nhập khác"),
    ("hoàn tiền ngân hàng 90k", "Thu nhập khác"),
]

# Income/expense edge
INCOME_EDGE: list[tuple[str, str]] = [
    ("nhận lương tháng 5 12tr", "Lương"),
    ("luong thang 6 ve tk 15tr", "Lương"),
    ("thuong du an 3tr", "Thưởng"),
    ("nhận sinh nhật 500k", "Thu nhập khác"),
    ("cho bạn quà sinh nhật 500k", "Quà tặng"),
    ("tặng quà sinh nhật bạn 300k", "Quà tặng"),
]


def build_val_hard_catalog() -> list[tuple[str, str]]:
    seen: set[str] = set()
    out: list[tuple[str, str]] = []
    for block in (
        CONTRASTIVE,
        SHORT_ABB_VAL,
        OOD_VAL,
        CLASS_HARD,
        INCOME_EDGE,
    ):
        for text, label in block:
            t = text.strip()
            if t and t not in seen:
                seen.add(t)
                out.append((t, label))
    return out
