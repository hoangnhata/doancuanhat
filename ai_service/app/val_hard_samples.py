"""Hard validation set — ~300–500 mẫu (ngắn, contrastive, OOD)."""
from __future__ import annotations

import sys
from pathlib import Path

_LEGACY_VAL_HARD: list[tuple[str, str]] = [
    # Ăn uống
    ("an trua 45k", "Ăn uống"),
    ("mua do an vat", "Ăn uống"),
    ("ăn tối 🍜", "Ăn uống"),
    ("grab food 90k", "Ăn uống"),
    ("coffee client meeting 200k", "Ăn uống"),
    ("nha hang sinh nhat 350k", "Ăn uống"),
    ("order tra sua 40k", "Ăn uống"),
    ("pho bo 60k", "Ăn uống"),
    # Di chuyển
    ("grab đi làm 80k", "Di chuyển"),
    ("GRAB 50K", "Di chuyển"),
    ("grab 🚗 50k", "Di chuyển"),
    ("do xang 150k", "Di chuyển"),
    ("xang 50k", "Di chuyển"),
    ("taxi san bay 350k", "Di chuyển"),
    ("phi gui xe 20k", "Di chuyển"),
    ("be bike di lam 25k", "Di chuyển"),
    # Mua sắm
    ("shopping 🛍️ 200k", "Mua sắm"),
    ("mua do shopee 250k", "Mua sắm"),
    ("mua son moi 120k", "Mua sắm"),
    ("cắt tóc barber 80k", "Mua sắm"),
    ("spa nail 250k", "Mua sắm"),
    ("mua ao sale 300k", "Mua sắm"),
    # Nhà ở
    ("tra tien phong", "Nhà ở"),
    ("pay rent 3tr", "Nhà ở"),
    ("ck tiền trọ", "Nhà ở"),
    ("tien nha thang nay 3tr", "Nhà ở"),
    ("thanh toan tien thue nha", "Nhà ở"),
    ("sua dieu hoa 500k", "Nhà ở"),
    # Hóa đơn
    ("nap dt 100k", "Hóa đơn"),
    ("đóng tiền điện xong nghèo luôn", "Hóa đơn"),
    ("wifi nha 200k", "Hóa đơn"),
    ("nuoc sinh hoat 120k", "Hóa đơn"),
    ("phi ngan hang 11k", "Hóa đơn"),
    ("nộp thuế TNCN 2tr", "Hóa đơn"),
    # Giải trí
    ("cafe ban be", "Giải trí"),
    ("cafe bạn bè cuối tuần 150k", "Giải trí"),
    ("xem phim avatar 120k", "Giải trí"),
    ("netflix thang 260k", "Giải trí"),
    ("karaoke đêm 500k", "Giải trí"),
    ("choi game nap the 200k", "Giải trí"),
    ("bowling cuoi tuan 150k", "Giải trí"),
    # Du lịch
    ("ve may bay 2tr", "Du lịch"),
    ("khach san nghi duong 3tr", "Du lịch"),
    ("tour da lat 5tr", "Du lịch"),
    ("visa du lich 3tr", "Du lịch"),
    ("mua qua luu niem 400k", "Du lịch"),
    ("thue xe du lich 600k", "Du lịch"),
    # Giáo dục
    ("hoc phi ky 2 8tr", "Giáo dục"),
    ("mua sach on thi 200k", "Giáo dục"),
    ("khoa online python 2tr", "Giáo dục"),
    ("gia su toan 500k", "Giáo dục"),
    ("cho con hoc phi 3tr", "Giáo dục"),
    ("hoc tieng anh 1tr2", "Giáo dục"),
    # Sức khỏe
    ("kham benh 500k", "Sức khỏe"),
    ("mua thuoc cam 80k", "Sức khỏe"),
    ("gym thang 600k", "Sức khỏe"),
    ("nho rang 1tr5", "Sức khỏe"),
    ("vitamin 150k", "Sức khỏe"),
    ("xet nghiem 300k", "Sức khỏe"),
    # Gia đình
    ("mẹ gửi tiền ăn", "Thu nhập khác"),
    ("trả mẹ tiền ăn", "Gia đình"),
    ("gui tien ve que 3tr", "Gia đình"),
    ("cho con tieu vat 200k", "Gia đình"),
    ("mua sua be 400k", "Gia đình"),
    ("lo cho ba me thuoc 1tr", "Gia đình"),
    # Thú cưng
    ("mua cat meo 100k", "Thú cưng"),
    ("tiem phong cho 300k", "Thú cưng"),
    ("thuc an royal canin 200k", "Thú cưng"),
    ("kham thu y 250k", "Thú cưng"),
    ("pet shop 400k", "Thú cưng"),
    ("mua do cho cho 150k", "Thú cưng"),
    # Quà tặng
    ("cho bạn quà sinh nhật 500k", "Quà tặng"),
    ("tặng hoa 8/3 200k", "Quà tặng"),
    ("phong bi cuoi 500k", "Quà tặng"),
    ("qua tet ong ba 2tr", "Quà tặng"),
    ("mung sinh nhat dong nghiep 200k", "Quà tặng"),
    ("gift card 300k", "Quà tặng"),
    # Từ thiện
    ("ung ho lu lut 500k", "Từ thiện"),
    ("quyen gop truong hoc 200k", "Từ thiện"),
    ("tu thien tre em 300k", "Từ thiện"),
    ("dong gop quy vac xin 100k", "Từ thiện"),
    ("giup nguoi kho khan 150k", "Từ thiện"),
    ("ung ho chua 200k", "Từ thiện"),
    # Khác
    ("50k", "Khác"),
    ("ủa mất tiền đâu vậy", "Khác"),
    ("grab hay cf nhỉ", "Khác"),
    ("linh tinh 80k", "Khác"),
    ("sua laptop 800k", "Khác"),
    ("phi khong ro 50k", "Khác"),
    # Lương
    ("luong thnag nay", "Lương"),
    ("salary received", "Lương"),
    ("luong thang nay ve roi 12tr", "Lương"),
    ("cty chuyen khoan luong 10tr", "Lương"),
    ("HR gui tien thang 9tr", "Lương"),
    ("payroll 15tr", "Lương"),
    ("nhan luong thang 5", "Lương"),
    # Thưởng
    ("nhan bonus", "Thưởng"),
    ("thuong du an 3tr", "Thưởng"),
    ("bonus quy 4 5tr", "Thưởng"),
    ("thuong tet 2tr", "Thưởng"),
    ("KPI dat nhan 2tr", "Thưởng"),
    ("chi bonus cho nhan vien 2tr", "Khác"),
    # Freelance
    ("freelance thiet ke logo 4tr", "Freelance"),
    ("nhan tien lam website 3tr", "Freelance"),
    ("client thanh toan invoice 5tr", "Freelance"),
    ("day kem online 600k", "Freelance"),
    ("shipper nhan cong 3tr", "Freelance"),
    ("lam them cuoi tuan 500k", "Freelance"),
    # Đầu tư
    ("co tuc VNM 2tr", "Đầu tư"),
    ("lai tiet kiem 500k", "Đầu tư"),
    ("lai gui ky han 300k", "Đầu tư"),
    ("profit trading 1tr", "Đầu tư"),
    ("thu lai trai phieu 400k", "Đầu tư"),
    ("cho thue nha 3tr", "Đầu tư"),
    # Bán hàng
    ("ban do cu 800k", "Bán hàng"),
    ("doanh thu shopee 2tr", "Bán hàng"),
    ("khach ck dat hang 1tr5", "Bán hàng"),
    ("thu tien ban hang 500k", "Bán hàng"),
    ("sell old laptop 5tr", "Bán hàng"),
    ("facebook ban quan ao 300k", "Bán hàng"),
    # Thu nhập khác
    ("nhận sinh nhật 500k", "Thu nhập khác"),
    ("nhan sinh nhat 500k", "Thu nhập khác"),
    ("ck momo 50k", "Thu nhập khác"),
    ("hoan tien don shopee 250k", "Thu nhập khác"),
    ("cashback the 120k", "Thu nhập khác"),
    ("refund grab food 45k", "Thu nhập khác"),
    ("được mừng cưới 1tr", "Thu nhập khác"),
    # Hard negatives / long / noise (label Khác hoặc theo rule)
    ("asdfasdf qwerty", "Khác"),
    ("hôm nay trời đẹp", "Khác"),
    ("hello world", "Khác"),
    ("123456", "Khác"),
    (
        "hôm nay tan ca muộn phải đặt grab bike từ khu công nghiệp về trọ mất gần 80k",
        "Di chuyển",
    ),
    ("toang cuoi thang vi bay mau 500k an delivery", "Ăn uống"),
    ("ờm chắc hôm nay lỡ order trà sữa 45k", "Ăn uống"),
    ("cf ban be 30k", "Giải trí"),
    ("ck tro 2tr5", "Nhà ở"),
    ("ck tiền trọ", "Nhà ở"),
    ("dt mới 15tr", "Mua sắm"),
    ("mb ck freelance", "Freelance"),
    ("đầu tư coin lời 2tr", "Đầu tư"),
    ("dt 100k", "Hóa đơn"),
    ("tx ve san bay 200k", "Di chuyển"),
    ("vcb +10tr", "Lương"),
    ("momo hoan 50k", "Thu nhập khác"),
    ("zalopay cashback 30k", "Thu nhập khác"),
    ("winmart 150k", "Mua sắm"),
    ("bhx 80k", "Mua sắm"),
    ("gs25 45k", "Ăn uống"),
    ("tcb phi 20k", "Hóa đơn"),
    ("bidv lai 100k", "Đầu tư"),
    ("tcb lai 80k", "Đầu tư"),
    ("du lich phu quoc 8tr", "Du lịch"),
    ("hoc online 500k", "Giáo dục"),
    ("quyen gop 100k", "Từ thiện"),
    # ── Metrics errors (2026-05) — ambiguous / short / typo ──
    ("chuyển khoản nhận từ khách hàng 4tr", "Bán hàng"),
    ("khách ck mua hàng 2tr", "Bán hàng"),
    ("nhận tiền bán đồ 800k", "Bán hàng"),
    ("nâng cấp RAM máy tính 5tr", "Mua sắm"),
    ("mua SSD laptop 2tr", "Mua sắm"),
    ("mua sạc dự phòng 200k", "Mua sắm"),
    ("mua linh kiện PC 1tr5", "Mua sắm"),
    ("phí chuyển tiền ngân hàng 10k", "Hóa đơn"),
    ("phí duy trì tài khoản 50k", "Hóa đơn"),
    ("phí internet banking 11k", "Hóa đơn"),
    ("sơn tường 2tr5", "Nhà ở"),
    ("sửa cửa phòng 300k", "Nhà ở"),
    ("đặt cọc phòng trọ 5tr", "Nhà ở"),
    ("cho mẹ mua thuốc 500k", "Gia đình"),
    ("gửi tiền sinh hoạt 1tr", "Gia đình"),
    ("vé tàu hỏa Sài Gòn - Đà Nẵng 500k", "Di chuyển"),
    ("vé xe khách về quê 350k", "Di chuyển"),
    ("bảo hiểm xe máy 200k", "Di chuyển"),
    ("gửi xe tháng 150k", "Di chuyển"),
    ("thuê phòng hostel bụi 200k", "Du lịch"),
    ("resort 5 sao Mũi Né 3tr", "Du lịch"),
    ("booking khách sạn Đà Lạt 2tr", "Du lịch"),
    ("visa du lich 3tr", "Du lịch"),
    ("mượn bạn 500k trả lại", "Khác"),
    ("chi tiêu không phân loại 500k", "Khác"),
    ("mua pin AA 30k", "Khác"),
    ("phí giấy tờ hành chính 300k", "Khác"),
    ("hoàn tiền momo 50k", "Thu nhập khác"),
    ("refund lazada 180k", "Thu nhập khác"),
    ("nhận lại tiền cọc 2tr", "Thu nhập khác"),
    ("cashback the 120k", "Thu nhập khác"),
    ("người thân gửi lại tiền 1tr", "Thu nhập khác"),
    ("ck phòng trọ", "Nhà ở"),
    ("mua dt", "Mua sắm"),
    ("đt mới 12tr", "Mua sắm"),
    ("cf sáng 35k", "Ăn uống"),
    ("grab food 90k", "Ăn uống"),
    ("ck freelance web 4tr", "Freelance"),
    ("lãi coin 500k", "Đầu tư"),
    ("lãi chứng khoán 2tr", "Đầu tư"),
    ("chi bonus cho nhan vien 2tr", "Khác"),
    ("nhận bonus quy 4 5tr", "Thưởng"),
    # OOD / noise
    ("asdfasdf qwerty", "Khác"),
    ("hôm nay trời đẹp", "Khác"),
]


def _load_catalog() -> list[tuple[str, str]]:
    data_dir = Path(__file__).resolve().parents[1] / "data"
    if str(data_dir) not in sys.path:
        sys.path.insert(0, str(data_dir))
    try:
        from val_hard_samples_catalog import build_val_hard_catalog  # type: ignore
        return build_val_hard_catalog()
    except ImportError:
        return []


def _merge_val_hard() -> list[tuple[str, str]]:
    seen: set[str] = set()
    out: list[tuple[str, str]] = []
    for block in (_LEGACY_VAL_HARD, _load_catalog()):
        for text, label in block:
            t = text.strip()
            if t and t not in seen:
                seen.add(t)
                out.append((t, label))
    return out


VAL_HARD_SAMPLES: list[tuple[str, str]] = _merge_val_hard()

