"""
Sinh dữ liệu DÒNG CHỮ synthetic (on-the-fly) — **bill chuyển khoản ngân hàng/ví**.

Mặc định chỉ sinh dòng liên quan CK (số tiền, ngày giờ, người gửi/nhận, nội dung,
mã GD, ngân hàng, trạng thái). Hóa đơn POS chỉ khi `include_pos=True` / `--include-pos`.

Mỗi dòng:
  - render bằng nhiều font / cỡ chữ / đậm-nhạt khác nhau
  - augment nặng: perspective, xoay nhẹ, blur, nhiễu, sáng/tương phản, nén lại,
    kẻ ngang (viền bảng), che 1 phần (random erase), đảo màu (chữ sáng nền tối)
  - nhãn = đúng chuỗi text được vẽ (chỉ dùng ký tự thuộc FULL_CHARSET)

Dùng trong train_ocr_recognizer.py qua SyntheticLineDataset (render mỗi __getitem__),
hoặc dump ra file để kiểm tra/backup bằng make_file_dataset().
"""

from __future__ import annotations

import argparse
import platform
import random
import subprocess
from datetime import date, timedelta
from io import BytesIO
from pathlib import Path
from typing import Optional

import numpy as np
import pandas as pd
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUT_DIR = ROOT / "data" / "ocr_lines"

# Ký tự cho phép — phải khớp app/ocr_charset.FULL_CHARSET
ALLOWED = set(
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    "aàáảãạăằắẳẵặâầấẩẫậeèéẻẽẹêềếểễệiìíỉĩịoòóỏõọôồốổỗộơờớởỡợuùúủũụưừứửữựyỳýỷỹỵđ"
    "AÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬEÈÉẺẼẸÊỀẾỂỄỆIÌÍỈĨỊOÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢUÙÚỦŨỤƯỪỨỬỮỰYỲÝỶỸỴĐ"
    "0123456789 .,-/:()&'+%*#@_₫"
)


def sanitize(text: str) -> str:
    """Bỏ ký tự ngoài charset, gộp khoảng trắng."""
    out = "".join(ch for ch in text if ch in ALLOWED)
    return " ".join(out.split())


# ─────────────────────────── Content pools (bill chuyển khoản) ─────────────

BANKS = [
    "MB Bank", "MB_Ngân hàng Quân đội", "VietinBank", "VietinBank iPay",
    "Vietcombank", "VCB Digibank", "BIDV", "BIDV SmartBanking",
    "Techcombank", "Techcombank Mobile", "Agribank", "Agribank E-Mobile",
    "TPBank", "TPBank Mobile", "VPBank", "VPBank NEO",
    "ACB", "ACB ONE", "Sacombank", "Sacombank Pay",
    "OCB", "HDBank", "SHB", "SeABank", "MSB", "LienVietPostBank",
    "Ngân hàng TMCP Ngoại Thương VN", "Ngân hàng Công Thương Việt Nam (CTG)",
    "VietQR", "Napas",
]

WALLET_APPS = [
    "MoMo", "Ví MoMo", "ZaloPay", "Ví ZaloPay", "Viettel Money",
    "ViettelPay", "ShopeePay", "VNPAY", "Payoo",
]

BANK_APPS = [
    "MB Bank", "VietinBank iPay", "VCB Digibank", "BIDV SmartBanking",
    "Techcombank Mobile", "TPBank Mobile", "VPBank NEO", "ACB ONE",
    "Sacombank Pay", "Agribank E-Mobile",
]

PERSON_NAMES = [
    "NGUYEN VAN AN", "TRAN THI BICH", "LE HOANG NAM", "PHAM MINH TUAN",
    "VO THI HONG", "DANG QUOC BAO", "BUI THI THU", "HOANG VAN LONG",
    "NGUYEN THI MAI", "DO THANH SON", "VU THI LAN", "PHAN VAN HUNG",
    "Nguyễn Văn An", "Trần Thị Bích", "Lê Hoàng Nam", "Phạm Minh Tuấn",
    # Tên thật từ bill người dùng (MB / VietinBank iPay)
    "HOANG MINH NHAT", "HO THI THU HUONG", "HO PHỤ THU HUONG",
    "HO HOANG ANH", "HO PHU THU HUONG", "NGUYEN VAN A", "TRAN THI B",
]

VIETIN_IPAY_LABELS = [
    "Từ tài khoản", "Đến tài khoản", "Ngân hàng", "Số tiền", "Phí", "Nội dung",
    "Miễn phí", "Kết quả giao dịch", "Tải về", "Chia sẻ", "Lưu danh bạ",
]

VIETIN_BANK_LINES = list(dict.fromkeys(BANKS + WALLET_APPS + BANK_APPS))

AMOUNT_WORDS_VN = [
    "Một Triệu Đồng", "Hai Triệu Đồng", "Hai Triệu Năm Trăm Nghìn Đồng",
    "Sáu Triệu Ba Trăm Nghìn Đồng", "Năm Trăm Nghìn Đồng", "Một Triệu Đồng",
    "Ba Trăm Nghìn Đồng", "Một Triệu Bốn Trăm Nghìn Đồng",
    "Một Triệu Hai Trăm Nghìn Đồng", "Bảy Trăm Nghìn Đồng",
]

_EXTRA_TRANSFER_NOTES = [
    "ck tien tro", "ck tien nha", "tra tien phong", "tra tien dien",
    "tra tien nuoc", "gui tien cho me", "me gui tien", "tien sinh hoat",
    "tien an tuan nay", "thanh toan hoc phi", "dong tien hoc", "mua sach",
    "tien xang xe", "tien dien thoai", "nap tien dien thoai",
    "chuyen tien mua do", "tien luong", "hoan tien", "dat coc", "dat coc phong",
]

TRANSFER_NOTES = [
    "tien an trua", "tien an sang", "tra tien an", "tra no ban",
    "chuyen tien cho ban", "tra no", "tien dien nuoc thang 6",
    "chuyen tien an trua", "thanh toan tien nha thang 5", "tra no",
    "tien dien thang 4", "chuyen khoan mua hang", "ung ho", "tien hoc phi",
    "thanh toan don hang 12345", "cam on ban", "tien cafe", "gui me",
    "chuyen tien dien nuoc", "MUA HANG SHOPEE", "hoan tien",
    "Chuyển tiền ăn tối", "Thanh toán hóa đơn", "Tiền thuê phòng",
    "thanh toan tien dien nuoc thang 6 nam 2025",
    "chuyen khoan tien hoc phi ky 1 cho con",
    "Nguyen Van An chuyen tien an sang cam on",
    "tra tien hang dat coc don 88123 cam on shop",
    "Thanh toan hoa don dien thoai va internet thang 5",
    "chuyen tien mua ve may bay Ha Noi Sai Gon",
    "tien dat phong khach san 2 dem cuoi tuan",
    "Hoan tra tien ban be di an lau hom truoc",
    "chuyen khoan tien luong nhan vien thang 4",
    "thanh toan tien thue mat bang quy 2 nam nay",
] + _EXTRA_TRANSFER_NOTES

# Ghi chú NGẮN kiểu thật trên app ngân hàng (MB/VietinBank...) — viết thường,
# không nhãn, hay kèm mảnh ngày (8/3, 20/10). Đây là loại model đọc kém nhất.
STANDALONE_NOTES = [
    "mung me 8/3", "mung me 20/10", "qua 8/3 cho me", "mung sinh nhat",
    "chuc mung sinh nhat", "mung tan gia", "mung cuoi", "li xi tet",
    "gui me", "gui ba", "gui con", "cho em", "cho me", "bo cho con",
    "tra no", "tra tien", "tra tien an", "tra tien ban", "hoan tien ban",
    "tien an", "tien an trua", "tien an sang", "tien cafe", "tien tra sua",
    "tien nuoc", "tien dien", "tien dien thang 5", "tien nuoc thang 6",
    "tien tro", "tien tro thang 7", "tien nha", "tien phong", "dat coc phong",
    "tien hoc", "hoc phi", "hoc phi ky 1", "tien hoc them", "tien sach vo",
    "mua do an", "mua hang", "mua sam", "mua ca phe", "tien ship",
    "chuyen khoan", "ck tien an", "ck tra no", "chuyen tien", "thanh toan",
    "thanh toan don hang", "thanh toan hoa don", "tt tien dien",
    "ung ho", "ung ho quy", "tu thien", "gop quy lop",
    "cam on ban", "cam on ban nhe", "cam on shop", "cam on nhe",
    "8/3", "20/10", "20/11", "tet 2026", "luong thang 6", "thuong tet",
    "tien xang", "tien gui xe", "tien taxi", "ve xe", "ve may bay",
    "Mung me 8/3", "Gui me", "Tien an trua", "Chuc mung sinh nhat",
    "tien me gui", "me gui con", "anh gui em", "chi gui em", "ba gui con",
    "ck tien tro", "ck tien nha", "tra tien phong", "tra tien dien",
    "tra tien nuoc", "gui tien cho me", "me gui tien", "tien sinh hoat",
    "tien an tuan nay", "thanh toan hoc phi", "dong tien hoc", "mua sach",
    "tien xang xe", "tien dien thoai", "nap tien dien thoai",
    "chuyen tien mua do", "tien luong", "dat coc", "dat coc phong",
]

DATE_FMTS = ["%d/%m/%Y", "%d-%m-%Y", "%d.%m.%Y"]

BANK_SUCCESS_LINES = [
    "Chuyen tien thanh cong", "Chuyển tiền thành công",
    "Giao dich thanh cong", "Giao dịch thành công",
    "GIAO DICH THANH CONG", "CHUYEN TIEN THANH CONG",
    "Thanh toan thanh cong", "Thanh toán thành công",
    "Chuyen khoan thanh cong", "Chuyển khoản thành công",
]

BANK_FOOTER_LINES = [
    "Chia se", "Chia sẻ", "Luu anh", "Lưu ảnh", "Luu mau", "Lưu mẫu",
    "Tải về", "Tai ve", "Giao dich moi", "Giao dịch mới", "GIAO DICH MOI",
    "Xem them", "Xem thêm", "Hoan thanh", "Hoàn thành", "Lưu danh bạ",
    "Chia se bill", "Chia sẻ biên lai", "Luu anh giao dich", "Lưu ảnh giao dịch",
    "Miễn phí", "Mien phi", "Chuyển thêm", "Chia tiền",
]

BANK_LABEL_LINES = [
    "Nguoi nhan", "Người nhận", "Nguoi gui", "Người gửi",
    "Nguoi chuyen", "Người chuyển", "Noi dung", "Nội dung",
    "Loi nhan", "Lời nhắn", "So tai khoan", "Số tài khoản",
    "Ngan hang", "Ngân hàng", "Ma giao dich", "Mã giao dịch",
    "Thoi gian", "Thời gian", "So tien", "Số tiền",
    "Tu tai khoan", "Từ tài khoản", "Den tai khoan", "Đến tài khoản",
    "Beneficiary", "From account", "To account",
]

GENERIC_PHRASES = [
    "Bien lai chuyen tien", "Biên lai chuyển tiền", "Giao dich thanh cong",
    "GIAO DICH THANH CONG", "Chuyen tien thanh cong", "Chuyển tiền thành công",
    "Giao dịch đã được xử lý thành công", "Ket qua giao dich",
    "Kết quả giao dịch", "Cam on ban", "Cảm ơn bạn",
]


# ─────────────────────────── Fonts ──────────────────────────────────────────

_FONT_CACHE: dict[tuple[str, int], ImageFont.FreeTypeFont] = {}
_FONTS_READY = False
_FONT_PATHS: list[str] = []


def _font_path_candidates() -> list[str]:
    if platform.system() == "Windows":
        base = "C:/Windows/Fonts/"
        return [
            base + "arial.ttf", base + "arialbd.ttf", base + "times.ttf",
            base + "timesbd.ttf", base + "cour.ttf", base + "courbd.ttf",
            base + "tahoma.ttf", base + "tahomabd.ttf", base + "verdana.ttf",
            base + "segoeui.ttf", base + "calibri.ttf", base + "consola.ttf",
        ]
    return [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSerif-Regular.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf",
        "/usr/share/fonts/truetype/freefont/FreeSans.ttf",
        "/usr/share/fonts/truetype/freefont/FreeMono.ttf",
        "/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf",
    ]


def _safe_is_file(p: str) -> bool:
    try:
        return Path(p).is_file()
    except OSError:
        return False


def _ensure_fonts() -> None:
    """Cài thêm font trên Colab/Linux (chỉ 1 lần) để đa dạng kiểu chữ."""
    global _FONTS_READY, _FONT_PATHS
    if _FONTS_READY:
        return
    _FONTS_READY = True
    _FONT_PATHS = [p for p in _font_path_candidates() if _safe_is_file(p)]
    if not _FONT_PATHS and platform.system() != "Windows":
        try:
            subprocess.run(
                ["apt-get", "install", "-y", "-qq",
                 "fonts-dejavu", "fonts-liberation", "fonts-freefont-ttf", "fonts-noto-core"],
                check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
        except Exception:
            pass
        _FONT_PATHS = [p for p in _font_path_candidates() if _safe_is_file(p)]


def _get_font(rng: random.Random, size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    _ensure_fonts()
    if not _FONT_PATHS:
        return ImageFont.load_default()
    path = rng.choice(_FONT_PATHS)
    key = (path, size)
    if key not in _FONT_CACHE:
        try:
            _FONT_CACHE[key] = ImageFont.truetype(path, size=size)
        except Exception:
            _FONT_CACHE[key] = ImageFont.load_default()
    return _FONT_CACHE[key]


# ─────────────────────────── Amount formatting ──────────────────────────────

def _fmt_amount(vnd: int, rng: random.Random) -> str:
    big = vnd >= 100_000
    r = rng.random()
    if big:
        # Số lớn: hầu như luôn có dấu phân cách hàng nghìn (120.000 / 1.200.000 / 371.000.000)
        s = f"{vnd:,}".replace(",", ".") if r < 0.6 else f"{vnd:,}"
    else:
        if r < 0.4:
            s = f"{vnd:,}".replace(",", ".")
        elif r < 0.7:
            s = f"{vnd:,}"
        else:
            s = str(vnd)
    suffix = rng.choice(["", "", "đ", " đ", " VND", " VNĐ", "₫", " ₫", "d", " đồng"])
    sign = rng.choice(["", "", "", "+", "-"]) if rng.random() < 0.2 else ""
    return f"{sign}{s}{suffix}"


def _rand_amount(rng: random.Random) -> int:
    """Số tiền VND — bias bill CK: 55% <1tr, 30% 1–10tr, 12% 10–100tr, 3% >100tr."""
    r = rng.random()
    if r < 0.55:
        val = rng.randint(10, 999) * 1_000          # 10.000 – 999.000
    elif r < 0.85:
        base = rng.randint(1, 9) * 1_000_000
        val = base + rng.randint(0, 9) * 100_000    # 1.000.000 – 9.900.000
    elif r < 0.97:
        val = rng.randint(10, 99) * 1_000_000       # 10 – 99 triệu
    else:
        val = rng.randint(100, 999) * 1_000_000     # 100 – 999 triệu
    return max(10_000, val // 1_000 * 1_000)


_PERSON_HO = [
    "NGUYEN", "TRAN", "LE", "PHAM", "HOANG", "HUYNH", "PHAN", "VU", "VO", "DANG", "BUI", "DO",
]
_PERSON_MID = [
    "VAN", "THI", "MINH", "QUOC", "HOANG", "NGOC", "THU", "THANH", "GIA", "ANH",
]
_PERSON_FIRST = [
    "AN", "BINH", "HUNG", "NAM", "NHAT", "MAI", "HUONG", "LAN", "LINH", "TUAN", "LONG", "SON",
]


def _rand_person_name(rng: random.Random) -> str:
    parts = [rng.choice(_PERSON_HO)]
    if rng.random() < 0.88:
        parts.append(rng.choice(_PERSON_MID))
    parts.append(rng.choice(_PERSON_FIRST))
    if rng.random() < 0.12:
        parts.append(rng.choice(_PERSON_FIRST))
    return " ".join(parts)


def _pick_person_name(rng: random.Random) -> str:
    """60% tên sinh tự động, 40% từ PERSON_NAMES."""
    if rng.random() < 0.60:
        return _rand_person_name(rng)
    return rng.choice(PERSON_NAMES)


def _rand_account_number(rng: random.Random) -> str:
    r = rng.random()
    if r < 0.22:
        return "".join(rng.choice("0123456789") for _ in range(rng.randint(9, 14)))
    if r < 0.38:
        return "9704" + "".join(rng.choice("0123456789") for _ in range(8))
    if r < 0.54:
        return "1903" + "".join(rng.choice("0123456789") for _ in range(8))
    if r < 0.66:
        return "***" + "".join(rng.choice("0123456789") for _ in range(4))
    return "".join(rng.choice("0123456789") for _ in range(rng.randint(8, 12)))


def _rand_date(rng: random.Random) -> date:
    base = date(2022, 1, 1)
    return base + timedelta(days=rng.randint(0, 1400))


# Từ ghi chú mở đầu bằng chữ THƯỜNG (model hay bịa chữ hoa đầu dòng → cần nhiều mẫu)
_NOTE_LEAD_WORDS = [
    "mung", "me", "mua", "mung", "moi", "mai", "minh", "mot",
    "gui", "gop", "goi", "gia", "qua", "cho", "tra", "tien",
    "an", "ung", "ho", "li", "nha", "ngay", "nho", "nuoc",
]
_NOTE_TAIL_WORDS = [
    "me", "ba", "con", "em", "anh", "chi", "ban", "co", "chu",
    "no", "an", "sang", "trua", "toi", "nha", "tro", "hoc",
    "xang", "cafe", "tra sua", "do an", "sinh nhat", "8/3", "20/10",
]


def _rand_short_date(rng: random.Random) -> str:
    """Mảnh ngày kiểu ghi chú — THIÊN VỀ số 1 chữ số (8/3, 1/6, 2/9) để học dấu '/'."""
    d = rng.randint(1, 9) if rng.random() < 0.7 else rng.randint(1, 28)
    m = rng.randint(1, 9) if rng.random() < 0.7 else rng.randint(1, 12)
    return f"{d}/{m}"


def _compose_standalone_note(rng: random.Random) -> tuple[str, str]:
    """Ghi chú ngắn KHÔNG nhãn, kiểu thật trên app ngân hàng (mung me 8/3...).

    Tăng mạnh 2 dạng model hay sai:
      - ghi chú CHỮ THƯỜNG mở đầu (chống bịa chữ hoa đầu dòng)
      - mảnh ngày d/m SỐ ĐƠN (chống nuốt dấu '/')
    """
    r = rng.random()
    if r < 0.30:
        # Ghép lead + tail chữ thường, đôi khi kèm ngày số đơn
        note = f"{rng.choice(_NOTE_LEAD_WORDS)} {rng.choice(_NOTE_TAIL_WORDS)}"
        if rng.random() < 0.45 and "/" not in note:
            note = f"{note} {_rand_short_date(rng)}"
    elif r < 0.45:
        # Ghi chú có mảnh ngày số đơn (mung me 8/3, qua 1/6 cho me...)
        lead = rng.choice(["mung me", "qua", "qua tang", "li xi", "chuc mung",
                            "gui me", "mung", "tang me", "cho me"])
        note = f"{lead} {_rand_short_date(rng)}"
    elif r < 0.55:
        # Chỉ d/m đứng riêng — số đơn nhiều
        note = _rand_short_date(rng)
    else:
        note = rng.choice(STANDALONE_NOTES)

    # Đôi khi ghép tên + ghi chú (vd. 'an gui me', 'nam tra no')
    if rng.random() < 0.15:
        nm = _pick_person_name(rng).split()[-1].lower()
        note = f"{nm} {note}"
    # Giữ phần lớn ở dạng CHỮ THƯỜNG (chỉ ~12% viết hoa đầu)
    if rng.random() < 0.12:
        note = note[:1].upper() + note[1:]
    else:
        note = note.lower()
    return sanitize(note), "bank_note"


# ─────────────────────────── Line text sampler ──────────────────────────────

MAX_LINE_CHARS = 60


def _sample_transfer_amount(rng: random.Random) -> tuple[str, str]:
    """Số tiền đa dạng định dạng (50.000 VND, + 50.000 VND, Số tiền giao dịch...)."""
    vnd = _rand_amount(rng)
    dot = f"{vnd:,}".replace(",", ".")
    comma = f"{vnd:,}"
    space = f"{vnd:,}".replace(",", " ")
    r = rng.random()
    if r < 0.08:
        text = str(vnd)
    elif r < 0.14:
        text = dot
    elif r < 0.20:
        text = comma
    elif r < 0.26:
        text = f"{comma} VND"
    elif r < 0.32:
        text = f"{dot} VND"
    elif r < 0.38:
        text = f"{dot} VNĐ"
    elif r < 0.44:
        text = f"{space} VND"
    elif r < 0.50:
        text = f"VND {comma}"
    elif r < 0.56:
        sign = rng.choice(["+", "-"])
        text = f"{sign}{dot}đ"
    elif r < 0.62:
        sign = rng.choice(["+", "-"])
        text = f"{sign} {dot} VND"
    elif r < 0.70:
        label = rng.choice(["So tien", "Số tiền", "Amount", "Gia tri GD"])
        text = f"{label} {_fmt_amount(vnd, rng)}"
    elif r < 0.78:
        text = f"Số tiền giao dịch: {dot} VND"
    elif r < 0.86:
        text = f"Bạn đã chuyển {dot} VND"
    elif r < 0.93:
        text = f"Đã nhận {dot} VND"
    else:
        text = _fmt_amount(vnd, rng)
    return sanitize(text), "bank_amount"


def _sample_bank_datetime(rng: random.Random) -> tuple[str, str]:
    d = _rand_date(rng).strftime(rng.choice(DATE_FMTS))
    t = f"{rng.randint(0,23):02d}:{rng.randint(0,59):02d}"
    if rng.random() < 0.45:
        t += f":{rng.randint(0,59):02d}"
    r = rng.random()
    if r < 0.35:
        text = f"{d} {t}"
    elif r < 0.55:
        label = rng.choice(["Thoi gian", "Thời gian", "Ngay chuyen", "Ngày chuyển"])
        text = f"{label}: {d} {t}"
    elif r < 0.75:
        text = f"{d.replace('/', '-')} {t}"
    else:
        code = "".join(rng.choice("0123456789ABCDEF") for _ in range(rng.randint(8, 14)))
        text = f"{d} {t} {code}"
    return sanitize(text), "bank_meta"


def _sample_bank_person(rng: random.Random) -> tuple[str, str]:
    name = _pick_person_name(rng)
    r = rng.random()
    if r < 0.35:
        return sanitize(name), "bank_person"
    label = rng.choice([
        "Nguoi nhan", "Người nhận", "Nguoi gui", "Người gửi",
        "Ten nguoi nhan", "Tên người nhận", "Beneficiary", "Toi",
        "Tu tai khoan", "Từ tài khoản", "Den tai khoan", "Đến tài khoản",
    ])
    return sanitize(f"{label}: {name}"), "bank_person"


def _sample_bank_note_block(rng: random.Random) -> tuple[str, str]:
    r = rng.random()
    if r < 0.35:
        return _compose_standalone_note(rng)
    if r < 0.55:
        return _compose_bank_noidung(rng)
    label = rng.choice(["Noi dung", "Nội dung", "Loi nhan", "Lời nhắn", "Tin nhan", "Tin nhắn"])
    note = rng.choice(TRANSFER_NOTES + STANDALONE_NOTES)
    if rng.random() < 0.4:
        note = note.lower()
    return sanitize(f"{label}: {note}"), "bank_note"


def _sample_bank_meta_block(rng: random.Random) -> tuple[str, str]:
    r = rng.random()
    if r < 0.35:
        code = "".join(rng.choice("0123456789") for _ in range(rng.randint(10, 16)))
        pre = rng.choice(["FT", "MB", "VCB", "TXN", ""])
        label = rng.choice(["Ma giao dich", "Mã giao dịch", "Ma GD", "Trans ID"])
        return sanitize(f"{label}: {pre}{code}"), "bank_meta"
    if r < 0.55:
        acc = _rand_account_number(rng)
        fmt = rng.random()
        if fmt < 0.12:
            text = acc
        elif fmt < 0.24:
            text = f"TK: {acc}"
        elif fmt < 0.36:
            text = f"STK: {acc}"
        elif fmt < 0.55:
            label = rng.choice(["So tai khoan", "Số tài khoản", "STK", "Account", "So the/TK"])
            text = f"{label}: {acc}"
        else:
            text = f"Số tài khoản: {acc}"
        return sanitize(text), "bank_meta"
    if r < 0.75:
        label = rng.choice(["Ngan hang", "Ngân hàng", "Bank", "Ngan hang nhan"])
        pool = BANKS + WALLET_APPS
        return sanitize(f"{label}: {rng.choice(pool)}"), "bank_meta"
    ref = "".join(rng.choice("0123456789") for _ in range(rng.randint(10, 18)))
    label = rng.choice(["Ma tham chieu", "Mã tham chiếu", "So tham chieu"])
    return sanitize(f"{label}: {ref}"), "bank_meta"


def _sample_bank_success(rng: random.Random) -> tuple[str, str]:
    line = rng.choice(BANK_SUCCESS_LINES)
    if rng.random() < 0.4 and "!" not in line:
        line += "!"
    return sanitize(line), "bank_success"


def _sample_bank_footer(rng: random.Random) -> tuple[str, str]:
    r = rng.random()
    if r < 0.55:
        return sanitize(rng.choice(BANK_FOOTER_LINES)), "bank_footer"
    if r < 0.80:
        return sanitize(rng.choice(BANK_LABEL_LINES)), "bank_label"
    return sanitize(rng.choice(BANK_APPS + WALLET_APPS)), "bank_label"


def sample_line(
    rng: random.Random,
    note_focus: float = 0.0,
    *,
    bank_only: bool = True,
    include_pos: bool = False,
) -> tuple[str, str]:
    """Trả về (text, kind). Mặc định chỉ bill chuyển khoản / ví.

    note_focus: xác suất ép ghi chú ngắn (mung me 8/3, tra no...).
    include_pos: sinh hóa đơn POS (legacy) — không dùng khi train CK.
    """
    if include_pos and not bank_only:
        if note_focus > 0.0 and rng.random() < note_focus:
            text, kind = _compose_standalone_note(rng)
        else:
            text, kind = _sample_line_raw(rng)
    else:
        if note_focus > 0.0 and rng.random() < note_focus:
            text, kind = _compose_standalone_note(rng)
        else:
            text, kind = _sample_line_bank_only(rng)
    if len(text) > MAX_LINE_CHARS:
        text = text[:MAX_LINE_CHARS].rstrip()
    return text, kind


def _compose_bank_noidung(rng: random.Random) -> tuple[str, str]:
    """Dòng Nội dung kiểu VietinBank: 'Nội dung TEN chuyen tien' / ghép tên + ghi chú."""
    label = rng.choice(["Noi dung", "Nội dung", "Nội dung CK", "NOI DUNG"])
    r = rng.random()
    if r < 0.35:
        name = _pick_person_name(rng)
        tail = rng.choice(["chuyen tien", "chuyen", "chuyen khoan", "chuyển tiền"])
        text = f"{label} {name} {tail}"
    elif r < 0.55:
        note = rng.choice(STANDALONE_NOTES).lower()
        text = f"{label} {note}"
    else:
        note = rng.choice(TRANSFER_NOTES)
        text = f"{label}: {note}"
    return sanitize(text), "bank_noidung"


def _compose_bank_long_line(rng: random.Random) -> tuple[str, str]:
    """Dòng dài chỉ liên quan bill chuyển khoản."""
    mode = rng.randint(0, 4)
    if mode == 0:
        label = rng.choice(["Noi dung", "Nội dung", "Nội dung CK", "Lời nhắn"])
        text, kind = f"{label}: {rng.choice(TRANSFER_NOTES)}", "bank_note"
    elif mode == 1:
        label = rng.choice(["Nguoi nhan", "Người nhận", "NGUOI NHAN"])
        text, kind = f"{label}: {_pick_person_name(rng)} - {rng.choice(BANKS)}", "bank_person"
    elif mode == 2:
        label = rng.choice(["So tien giao dich", "Số tiền giao dịch", "Gia tri GD"])
        text, kind = f"{label}: {_fmt_amount(_rand_amount(rng), rng)}", "bank_amount"
    elif mode == 3:
        text, kind = _compose_bank_noidung(rng)
    else:
        code = "".join(rng.choice("0123456789ABCDEF") for _ in range(rng.randint(10, 16)))
        label = rng.choice(["Ma giao dich", "Mã giao dịch", "Ma tham chieu"])
        text, kind = f"{label}: {code}", "bank_meta"
    text = sanitize(text)
    if len(text) < 20:
        text = sanitize(f"{text} {rng.choice(BANK_SUCCESS_LINES)}")
    if len(text) > 60:
        text = text[:60].rstrip()
    return text, kind


def _sample_vietin_ipay_line(rng: random.Random) -> tuple[str, str]:
    """Dòng kiểu VietinBank iPay (ảnh thật hay gặp — chữ xanh số tiền, banner xanh)."""
    r = rng.random()
    if r < 0.14:
        line = rng.choice(BANK_SUCCESS_LINES)
        return sanitize(line + ("!" if "!" not in line else "")), "bank_vietin_success"
    if r < 0.28:
        return sanitize(_fmt_amount(_rand_amount(rng), rng)), "bank_vietin_amount"
    if r < 0.38:
        return sanitize(rng.choice(AMOUNT_WORDS_VN)), "bank_vietin_amount_words"
    if r < 0.52:
        return sanitize(_pick_person_name(rng)), "bank_vietin_name"
    if r < 0.62:
        return sanitize(rng.choice(VIETIN_BANK_LINES)), "bank_vietin_bank"
    if r < 0.72:
        nm = _pick_person_name(rng).split()[0]
        note = f"{nm} {rng.choice(['chuyen tien', 'chuyen khoan', 'chuyen tien cho ban'])}"
        if rng.random() < 0.35:
            label = rng.choice(["Nội dung", "Noi dung", "Nội dung:"])
            note = f"{label} {note}"
        return sanitize(note), "bank_vietin_note"
    if r < 0.80:
        return sanitize("Miễn phí"), "bank_vietin_fee"
    if r < 0.88:
        d = _rand_date(rng).strftime(rng.choice(DATE_FMTS))
        t = f"{rng.randint(0,23):02d}:{rng.randint(0,59):02d}"
        return sanitize(f"{d} {t}"), "bank_vietin_meta"
    return sanitize(rng.choice(VIETIN_IPAY_LABELS)), "bank_vietin_label"


def _sample_line_bank_only(rng: random.Random) -> tuple[str, str]:
    """
    Phân bố bill chuyển khoản:
      20% số tiền | 15% ngày giờ | 20% người gửi/nhận | 25% nội dung/ghi chú
      10% mã GD/STK/NH | 5% trạng thái | 5% footer/label
    (+ nhánh VietinBank iPay / dòng dài CK)
    """
    if rng.random() < 0.12:
        return _sample_vietin_ipay_line(rng)
    if rng.random() < 0.10:
        return _compose_bank_long_line(rng)

    r = rng.random()
    if r < 0.20:
        return _sample_transfer_amount(rng)
    if r < 0.35:
        return _sample_bank_datetime(rng)
    if r < 0.55:
        return _sample_bank_person(rng)
    if r < 0.80:
        return _sample_bank_note_block(rng)
    if r < 0.90:
        return _sample_bank_meta_block(rng)
    if r < 0.95:
        return _sample_bank_success(rng)
    return _sample_bank_footer(rng)


# ── LEGACY POS (chỉ khi sample_line(..., include_pos=True)) ─────────────────

_LEGACY_MERCHANTS = [
    "WINMART", "HIGHLANDS COFFEE", "BACH HOA XANH", "Circle K", "PHO 24",
]
_LEGACY_ITEMS = ["Ca phe sua da", "Bun bo Hue", "Com tam suon", "Banh mi thit"]
_LEGACY_TOTAL_PREFIXES = ["TONG CONG", "TỔNG CỘNG", "THANH TOAN", "VAT 10%"]
_LEGACY_ADDRESSES = ["123 Nguyen Hue, Q1, TP.HCM", "Tel: 028 3822 1234"]
_LEGACY_RECEIPT_EXTRA = ["VAT", "GIAM GIA", "Phi dich vu", "Tien thua"]


def _compose_long_line_pos(rng: random.Random) -> tuple[str, str]:
    mode = rng.randint(0, 3)
    if mode == 0:
        return sanitize(f"{rng.choice(_LEGACY_ITEMS)} {_fmt_amount(_rand_amount(rng), rng)}"), "item"
    if mode == 1:
        return sanitize(f"{rng.choice(_LEGACY_TOTAL_PREFIXES)} {_fmt_amount(_rand_amount(rng), rng)}"), "total"
    if mode == 2:
        return sanitize(rng.choice(_LEGACY_MERCHANTS)), "merchant"
    return sanitize(f"{rng.choice(_LEGACY_MERCHANTS)} - {rng.choice(_LEGACY_ADDRESSES)}"), "address"


def _sample_line_raw(rng: random.Random) -> tuple[str, str]:
    """kind ∈ {merchant,address,item,total,date,bank_amount,bank_person,
    bank_note,bank_meta,phrase,amount_only,extra}.

    Cân bằng độ dài: ~35% là dòng dài 20-60 ký tự (chống lỗi dòng dài).
    """
    if rng.random() < 0.35:
        return _compose_long_line_pos(rng)

    r = rng.random()

    if r < 0.08:
        label = rng.choice(_LEGACY_RECEIPT_EXTRA)
        return sanitize(f"{label} {_fmt_amount(_rand_amount(rng), rng)}"), "extra"

    if r < 0.18:
        return sanitize(rng.choice(_LEGACY_MERCHANTS)), "merchant"

    if r < 0.28:
        return sanitize(rng.choice(_LEGACY_ADDRESSES)), "address"

    if r < 0.48:
        item = rng.choice(_LEGACY_ITEMS)
        return sanitize(f"{item} {_fmt_amount(_rand_amount(rng), rng)}"), "item"

    if r < 0.58:
        prefix = rng.choice(_LEGACY_TOTAL_PREFIXES)
        return sanitize(f"{prefix} {_fmt_amount(_rand_amount(rng), rng)}"), "total"

    if r < 0.68:
        return _sample_bank_datetime(rng)

    if r < 0.74:  # bank: số tiền
        label = rng.choice(["So tien", "Số tiền", "So tien:", "Số tiền:",
                            "Amount", "Gia tri GD", "Giá trị giao dịch", "Số tiền GD"])
        amt = _fmt_amount(_rand_amount(rng), rng)
        return sanitize(f"{label} {amt}"), "bank_amount"

    if r < 0.82:  # bank: người nhận / gửi
        label = rng.choice(["Nguoi nhan", "Người nhận", "Nguoi gui", "Người gửi",
                            "Ten nguoi nhan", "Tên người nhận", "Beneficiary", "Toi"])
        name = rng.choice(PERSON_NAMES)
        return sanitize(f"{label}: {name}"), "bank_person"

    if r < 0.89:  # bank: nội dung
        label = rng.choice(["Noi dung", "Nội dung", "Nội dung CK", "Mo ta", "Mô tả",
                            "Loi nhan", "Lời nhắn", "Message"])
        note = rng.choice(TRANSFER_NOTES)
        return sanitize(f"{label}: {note}"), "bank_note"

    if r < 0.95:  # bank: meta (mã GD, ngân hàng, STK, thời gian)
        kind = rng.random()
        if kind < 0.3:
            code = "".join(rng.choice("0123456789") for _ in range(rng.randint(8, 14)))
            pre = rng.choice(["FT", "MB", "VCB", "TXN", ""])
            label = rng.choice(["Ma giao dich", "Mã giao dịch", "Ma GD", "Trans ID", "So tham chieu"])
            return sanitize(f"{label}: {pre}{code}"), "bank_meta"
        if kind < 0.6:
            label = rng.choice(["Ngan hang", "Ngân hàng", "Tai khoan nguon", "Bank"])
            return sanitize(f"{label}: {rng.choice(BANKS)}"), "bank_meta"
        if kind < 0.85:
            acc = "".join(rng.choice("0123456789") for _ in range(rng.randint(8, 14)))
            label = rng.choice(["So tai khoan", "Số tài khoản", "STK", "Account"])
            return sanitize(f"{label}: {acc}"), "bank_meta"
        d = _rand_date(rng).strftime(rng.choice(DATE_FMTS))
        t = f"{rng.randint(0,23):02d}:{rng.randint(0,59):02d}:{rng.randint(0,59):02d}"
        label = rng.choice(["Thoi gian", "Thời gian", "Ngay GD", "Ngày giao dịch"])
        return sanitize(f"{label}: {d} {t}"), "bank_meta"

    if r < 0.985:  # generic phrase
        return sanitize(rng.choice(GENERIC_PHRASES)), "phrase"

    # amount only
    return sanitize(_fmt_amount(_rand_amount(rng), rng)), "amount_only"


# ─────────────────────────── Augmentation ───────────────────────────────────

def _perspective_coeffs(src, dst) -> list[float]:
    A, b = [], []
    for (x, y), (X, Y) in zip(src, dst):
        A += [[x, y, 1, 0, 0, 0, -X * x, -X * y],
              [0, 0, 0, x, y, 1, -Y * x, -Y * y]]
        b += [X, Y]
    try:
        res = np.linalg.solve(np.array(A, dtype=np.float64), np.array(b, dtype=np.float64))
    except np.linalg.LinAlgError:
        return [1, 0, 0, 0, 1, 0, 0, 0]
    return res.tolist()


def _motion_blur(img: Image.Image, rng: random.Random) -> Image.Image:
    """Mô phỏng rung tay khi chụp — chủ yếu theo phương ngang."""
    arr = np.asarray(img, dtype=np.float32)
    k = rng.randint(3, 9)
    horizontal = rng.random() < 0.8
    acc = np.zeros_like(arr)
    for i in range(k):
        shift = i - k // 2
        acc += np.roll(arr, shift, axis=1 if horizontal else 0)
    acc /= k
    return Image.fromarray(np.clip(acc, 0, 255).astype(np.uint8))


def _jpeg_recompress(img: Image.Image, rng: random.Random) -> Image.Image:
    """Nén JPEG chất lượng thấp → artifact giống ảnh gửi qua chat/zalo."""
    buf = BytesIO()
    try:
        img.convert("L").save(buf, format="JPEG", quality=rng.randint(30, 80))
        buf.seek(0)
        return Image.open(buf).convert("L")
    except Exception:
        return img


def _augment(img: Image.Image, rng: random.Random, bg: int) -> Image.Image:
    w, h = img.size
    # Perspective nhẹ — giảm để không méo dấu /, .
    if rng.random() < 0.22:
        mx, my = w * 0.025, h * 0.06
        dx1, dy1 = rng.uniform(-mx, mx), rng.uniform(-my, my)
        dx2, dy2 = rng.uniform(-mx, mx), rng.uniform(-my, my)
        src = [(0, 0), (w, 0), (w, h), (0, h)]
        dst = [(dx1, dy1), (w + dx2, dy1), (w + dx2, h + dy2), (dx1, h + dy2)]
        img = img.transform((w, h), Image.PERSPECTIVE,
                            _perspective_coeffs(src, dst), Image.BILINEAR, fillcolor=bg)
    # Xoay nhẹ
    if rng.random() < 0.4:
        img = img.rotate(rng.uniform(-2.0, 2.0), expand=True, fillcolor=bg, resample=Image.BILINEAR)
    # Motion blur HOẶC gaussian blur (không cùng lúc để tránh mất nét quá mức)
    rb = rng.random()
    if rb < 0.18:
        img = _motion_blur(img, rng)
    elif rb < 0.48:
        img = img.filter(ImageFilter.GaussianBlur(radius=rng.uniform(0.2, 0.85)))
    # Sáng / tương phản
    if rng.random() < 0.55:
        img = img.point(lambda p: int(min(255, max(0, p * rng.uniform(0.78, 1.18) + rng.uniform(-12, 12)))))
    # Giảm độ phân giải (giống chụp xa)
    if rng.random() < 0.25:
        scale = rng.uniform(0.6, 0.85)
        sw, sh = max(8, int(w * scale)), max(6, int(h * scale))
        img = img.resize((sw, sh), Image.BILINEAR).resize((w, h), Image.BILINEAR)
    # Nhiễu Gaussian
    if rng.random() < 0.40:
        arr = np.asarray(img, dtype=np.float32)
        arr += np.random.normal(0, rng.uniform(2, 9), arr.shape)
        img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    # JPEG recompress (cuối cùng)
    if rng.random() < 0.35:
        img = _jpeg_recompress(img, rng)
    return img


# ─────────────────────────── Render ─────────────────────────────────────────

def render_line(
    text: str,
    rng: random.Random,
    *,
    kind: str = "generic",
    augment: bool = True,
) -> Image.Image:
    """Render 1 dòng chữ → ảnh grayscale 'L' (chiều rộng thay đổi theo nội dung)."""
    text = text or " "
    size = rng.randint(24, 46)
    inverted = False
    if kind.startswith("bank_vietin"):
        if kind == "bank_vietin_amount":
            size = rng.randint(30, 44)
        elif kind == "bank_vietin_amount_words":
            size = rng.randint(22, 32)
        elif kind == "bank_vietin_success":
            size = rng.randint(20, 28)
        else:
            size = rng.randint(20, 34)
    font = _get_font(rng, size)

    # Đo kích thước text
    tmp = Image.new("L", (10, 10), 255)
    d0 = ImageDraw.Draw(tmp)
    try:
        bbox = d0.textbbox((0, 0), text, font=font)
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
        off_x, off_y = bbox[0], bbox[1]
    except Exception:
        tw, th = d0.textlength(text, font=font), size
        off_x, off_y = 0, 0
    tw = max(int(tw), 8)
    th = max(int(th), 8)

    pad_x = rng.randint(6, 28)
    pad_y = rng.randint(5, 16)
    W, H = tw + pad_x * 2, th + pad_y * 2

    if not inverted:
        inverted = rng.random() < 0.06
    if kind.startswith("bank_vietin"):
        inverted = False
        bg = rng.randint(235, 255)
        if kind == "bank_vietin_success":
            bg = rng.randint(210, 235)  # nền xanh nhạt
            ink = rng.randint(15, 45)
        elif kind == "bank_vietin_amount":
            ink = rng.randint(20, 50)   # mô phỏng chữ xanh đậm
        elif kind == "bank_vietin_amount_words":
            ink = rng.randint(25, 55)
        else:
            ink = rng.randint(0, 65)
    elif inverted:
        bg = rng.randint(0, 55)
        ink = rng.randint(200, 255)
    else:
        bg = rng.randint(220, 255)
        ink = rng.randint(0, 70)

    img = Image.new("L", (W, H), color=bg)
    draw = ImageDraw.Draw(img)

    # Gradient nền nhẹ (mô phỏng ánh sáng không đều)
    if rng.random() < 0.3:
        grad = np.tile(np.linspace(-rng.uniform(8, 28), rng.uniform(8, 28), W), (H, 1))
        base = np.asarray(img, dtype=np.float32) + grad
        img = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8))
        draw = ImageDraw.Draw(img)

    draw.text((pad_x - off_x, pad_y - off_y), text, fill=ink, font=font)

    # Kẻ ngang (viền bảng / dòng gạch dưới) đôi khi
    if rng.random() < 0.12:
        ly = rng.choice([rng.randint(0, 3), H - rng.randint(1, 3)])
        draw.line([(0, ly), (W, ly)], fill=ink, width=1)

    if augment:
        img = _augment(img, rng, bg=bg)

    return img


# ─────────────────────────── File dataset (tùy chọn) ────────────────────────

def make_file_dataset(
    n: int,
    seed: int = 42,
    out_dir: Optional[Path] = None,
    *,
    bank_only: bool = True,
    include_pos: bool = False,
) -> Path:
    """Dump n dòng ra file PNG + manifest_lines.csv (để xem mẫu / backup zip)."""
    out_dir = (out_dir or DEFAULT_OUT_DIR).resolve()
    img_dir = out_dir / "images"
    img_dir.mkdir(parents=True, exist_ok=True)
    rng = random.Random(seed)
    rows: list[dict] = []
    for i in range(n):
        text, kind = sample_line(rng, bank_only=bank_only, include_pos=include_pos)
        if not text:
            continue
        img = render_line(text, rng, kind=kind, augment=True)
        rel = f"images/line_{i:06d}.png"
        img.save(out_dir / rel, optimize=True)
        rows.append({"image_path": rel, "text": text, "kind": kind})
        if (i + 1) % 2000 == 0 or i + 1 == n:
            print(f"  ... {i + 1}/{n} dong")
    pd.DataFrame(rows).to_csv(out_dir / "manifest_lines.csv", index=False, encoding="utf-8")
    print(f"OK  {len(rows)} dong -> {out_dir}")
    return out_dir


def debug_print_samples(n: int = 100, seed: int = 42) -> None:
    """In mẫu synthetic để kiểm tra phân phối kind/text."""
    rng = random.Random(seed)
    print(f"=== DEBUG {n} synthetic samples (bank_only=True) ===")
    for _ in range(n):
        text, kind = sample_line(rng, bank_only=True)
        print(f"{kind} | {text}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=4000, help="So dong mau dump ra file")
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--out-dir", type=str, default="")
    ap.add_argument(
        "--include-pos",
        action="store_true",
        help="Them hoa don POS/siêu thị (legacy). Mac dinh: chi bill chuyen khoan.",
    )
    ap.add_argument(
        "--debug-samples",
        type=int,
        default=0,
        metavar="N",
        help="In N dong synthetic mau (kind | text) va thoat",
    )
    args = ap.parse_args()
    if args.debug_samples > 0:
        debug_print_samples(args.debug_samples, seed=args.seed)
        return
    out = Path(args.out_dir) if args.out_dir else None
    make_file_dataset(
        args.n, seed=args.seed, out_dir=out,
        bank_only=not args.include_pos,
        include_pos=args.include_pos,
    )


if __name__ == "__main__":
    main()
