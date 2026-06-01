# -*- coding: utf-8 -*-
"""
Hard-case + contrastive patterns — mỗi core 8–12 biến thể.
"""
from __future__ import annotations

import random
import re
import unicodedata
from typing import Iterable

SEED = 42
RNG = random.Random(SEED)

AMOUNTS = [
    "10k", "15k", "20k", "25k", "30k", "50k", "80k", "100k", "120k", "150k",
    "200k", "250k", "300k", "350k", "400k", "500k", "600k", "700k", "800k",
    "900k", "1tr", "1tr2", "1tr5", "2tr", "2tr5", "3tr", "4tr", "5tr", "8tr",
    "10tr", "12tr", "15tr", "15 triệu", "15000000", "15.000.000", "50.000", "350.000đ",
]

_PREFIX = ["", "hôm nay ", "vừa ", "ờm ", "cuối tuần ", "tháng này ", "05-05-2026 ", "hình như "]
_SUFFIX = ["", " rồi", " vừa xong", " nhé", " haiz", " thật", " luôn", " đấy"]


def _norm(s: str) -> str:
    return re.sub(r"\s+", " ", unicodedata.normalize("NFC", (s or "").strip()))


def _amt() -> str:
    return RNG.choice(AMOUNTS)


def _wrap(core: str, n: int = 10) -> list[str]:
    out: list[str] = []
    seen: set[str] = set()
    for _ in range(n * 4):
        body = core.format(a=_amt()) if "{a}" in core else core
        t = _norm(f"{RNG.choice(_PREFIX)}{body}{RNG.choice(_SUFFIX)}")
        if t and t not in seen:
            seen.add(t)
            out.append(t)
        if len(out) >= n:
            break
    return out[: max(n, 6)]


def _rows(label: str, cores: Iterable[str], per: int = 10) -> list[tuple[str, str]]:
    rows: list[tuple[str, str]] = []
    for c in cores:
        for t in _wrap(c, per):
            rows.append((t, label))
    return rows


BAN_HANG = [
    "chuyển khoản nhận từ khách hàng {a}",
    "khách chuyển khoản mua hàng {a}",
    "khách ck tiền đơn {a}",
    "nhận tiền bán áo {a}",
    "nhận tiền bán laptop cũ {a}",
    "thu tiền khách mua sản phẩm {a}",
    "khách trả tiền đơn hàng {a}",
    "bán đồ cũ trên chợ tốt {a}",
    "tiền khách thanh toán đơn {a}",
    "nhận tiền ship COD {a}",
    "khách ck mua hàng {a}",
    "doanh thu bán online {a}",
]

MUA_SAM = [
    "nâng cấp RAM máy tính {a}",
    "mua RAM laptop {a}",
    "mua SSD {a}",
    "mua sạc dự phòng {a}",
    "mua tai nghe bluetooth {a}",
    "mua linh kiện PC {a}",
    "mua phụ kiện điện thoại {a}",
    "mua bàn phím cơ {a}",
    "mua chuột máy tính {a}",
    "mua đồ gia dụng {a}",
    "dt mới {a}",
    "mua dt mới {a}",
    "đt mới {a}",
]

HOA_DON = [
    "phí chuyển tiền ngân hàng {a}",
    "phí duy trì tài khoản {a}",
    "phí SMS banking {a}",
    "phí internet banking {a}",
    "trả tiền điện {a}",
    "đóng tiền nước {a}",
    "thanh toán wifi {a}",
    "thanh toán hóa đơn điện thoại {a}",
    "phí ngân hàng hàng tháng {a}",
    "trả hóa đơn chung cư {a}",
]

NHA_O = [
    "sơn tường {a}",
    "sửa cửa phòng trọ {a}",
    "đặt cọc phòng trọ {a}",
    "tiền thuê trọ tháng này {a}",
    "sửa điện nước trong phòng {a}",
    "mua vật dụng sửa nhà {a}",
    "đóng tiền nhà {a}",
    "tiền phòng tháng này {a}",
    "sửa vòi nước {a}",
    "sửa điều hòa phòng trọ {a}",
    "ck tiền trọ {a}",
    "ck phòng trọ {a}",
]

DI_CHUYEN = [
    "mua bảo hiểm xe máy {a}",
    "gửi xe tháng {a}",
    "vé tàu hỏa Sài Gòn Đà Nẵng {a}",
    "vé xe khách {a}",
    "phí cầu đường {a}",
    "đổ xăng {a}",
    "grab đi làm {a}",
    "taxi ra sân bay {a}",
    "sửa xe máy {a}",
    "thay nhớt xe {a}",
]

DU_LICH = [
    "chi phí xin visa Thái Lan {a}",
    "thuê phòng hostel {a}",
    "đặt homestay Đà Lạt {a}",
    "resort Mũi Né {a}",
    "booking khách sạn {a}",
    "tour du lịch {a}",
    "vé máy bay đi du lịch {a}",
    "tiền ăn khi đi du lịch {a}",
    "chi phí nghỉ dưỡng {a}",
    "thuê xe đi du lịch {a}",
]

GIA_DINH = [
    "cho mẹ mua thuốc {a}",
    "gửi tiền sinh hoạt cho mẹ {a}",
    "tiền cho em gái đi học {a}",
    "gửi tiền về quê {a}",
    "hỗ trợ bố mẹ {a}",
    "tiền chăm sóc gia đình {a}",
    "đưa tiền cho em đóng học {a}",
    "mua đồ cho bố mẹ {a}",
    "tiền thuốc cho ba {a}",
    "gửi tiền phụ giúp gia đình {a}",
]

SUC_KHOE = [
    "mua thuốc cho bản thân {a}",
    "khám bệnh {a}",
    "xét nghiệm máu {a}",
    "đi nha khoa {a}",
    "mua vitamin {a}",
    "điều trị đau dạ dày {a}",
    "khám tổng quát {a}",
    "mua thuốc cảm {a}",
    "đi bệnh viện {a}",
    "tư vấn tâm lý {a}",
]

KHAC = [
    "mượn bạn {a} trả lại",
    "tiền trang trải sinh hoạt {a}",
    "phí làm giấy tờ hành chính {a}",
    "chi tiêu không phân loại {a}",
    "mua pin AA {a}",
    "việc linh tinh {a}",
    "chuyển tiền nhầm {a}",
    "trả nợ bạn {a}",
    "cho vay bạn {a}",
    "ghi chú không rõ {a}",
]

THU_NHAP_KHAC = [
    "hoàn tiền momo {a}",
    "refund lazada {a}",
    "nhận lại tiền cọc {a}",
    "cashback shopee {a}",
    "người thân gửi lại tiền {a}",
    "nhận tiền hoàn đơn {a}",
    "hoàn tiền ngân hàng {a}",
    "nhận khoản hỗ trợ {a}",
    "tiền được tặng {a}",
    "nhận tiền thưởng nhỏ không rõ nguồn {a}",
]

# Contrastive — câu gần nghĩa, label khác
CONTRASTIVE: list[tuple[str, str]] = [
    ("grab food {a}", "Ăn uống"),
    ("grab đi làm {a}", "Di chuyển"),
    ("grab đi ăn với bạn {a}", "Ăn uống"),
    ("grab ra sân bay {a}", "Di chuyển"),
    ("hostel du lịch 2 ngày {a}", "Du lịch"),
    ("tiền phòng trọ tháng này {a}", "Nhà ở"),
    ("thuê khách sạn đi chơi {a}", "Du lịch"),
    ("thuê phòng dài hạn {a}", "Nhà ở"),
    ("mua thuốc cho mẹ {a}", "Gia đình"),
    ("mua thuốc cho bản thân {a}", "Sức khỏe"),
    ("mua thuốc cho mình {a}", "Sức khỏe"),
    ("đưa mẹ đi khám {a}", "Gia đình"),
    ("khám bệnh cá nhân {a}", "Sức khỏe"),
    ("hoàn tiền momo {a}", "Thu nhập khác"),
    ("mượn bạn trả lại tiền {a}", "Khác"),
    ("cashback shopee {a}", "Thu nhập khác"),
    ("chi phí linh tinh {a}", "Khác"),
    ("khách trả tiền đơn hàng {a}", "Bán hàng"),
    ("lương công ty chuyển khoản {a}", "Lương"),
    ("nhận tiền freelance web {a}", "Freelance"),
    ("nhận lại tiền cọc {a}", "Thu nhập khác"),
]

SHORT_ABB = [
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
]


def _contrastive_rows(per: int = 8) -> list[tuple[str, str]]:
    rows: list[tuple[str, str]] = []
    for core, label in CONTRASTIVE:
        rows.extend((t, label) for t in _wrap(core, per))
    return rows


def strip_accents_no_tone(s: str) -> str:
    return "".join(
        c for c in unicodedata.normalize("NFD", s)
        if unicodedata.category(c) != "Mn"
    )


def generate_all_hard_rows(per_pattern: int = 10) -> list[tuple[str, str]]:
    rows: list[tuple[str, str]] = []
    rows.extend(_rows("Bán hàng", BAN_HANG, per_pattern))
    rows.extend(_rows("Mua sắm", MUA_SAM, per_pattern))
    rows.extend(_rows("Hóa đơn", HOA_DON, per_pattern))
    rows.extend(_rows("Nhà ở", NHA_O, per_pattern))
    rows.extend(_rows("Di chuyển", DI_CHUYEN, per_pattern))
    rows.extend(_rows("Du lịch", DU_LICH, per_pattern))
    rows.extend(_rows("Gia đình", GIA_DINH, per_pattern))
    rows.extend(_rows("Sức khỏe", SUC_KHOE, per_pattern))
    rows.extend(_rows("Khác", KHAC, per_pattern))
    rows.extend(_rows("Thu nhập khác", THU_NHAP_KHAC, per_pattern))
    rows.extend(_contrastive_rows(8))
    for text, label in SHORT_ABB:
        rows.append((text, label))
        rows.append((text + f" {_amt()}", label))
        rows.append((strip_accents_no_tone(text) + f" {_amt()}", label))
        rows.append((text.upper(), label))
    return rows
