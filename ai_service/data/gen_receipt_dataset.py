"""
Sinh dataset synthetic full bill + crop từng field (v2).

Cải tiến so với v1:
- 60 merchant names, 50 loại item → đa dạng hơn
- Amount crop = vùng số (nửa phải total line) → label khớp hoàn toàn với ảnh
- Date label = chuỗi ngày thực sự hiển thị trên ảnh (nhất quán format)
- Augment ảnh toàn bill: perspective, rotation, noise, blur
- Nhiều style bill: font size, màu mực, chiều rộng

Output:
  <out_dir>/
    images/full/*.png
    images/crops/amount|merchant|date|line/*.png
    manifest.csv
    manifest_amount.csv  (label_text = số tiền sạch, vd "150.000")
    manifest_merchant.csv
    manifest_date.csv    (label_text = chuoi ngay rendered, vd "21/05/2025" — KHONG co gio)
    manifest_line.csv
"""

from __future__ import annotations

import argparse
import math
import platform
import random
import subprocess
from datetime import date, timedelta
from pathlib import Path

import numpy as np
import pandas as pd
from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUT_DIR = ROOT / "data" / "receipt_ocr"


# ─────────────────────────── Content pools ──────────────────────────────────

MERCHANTS = [
    # Cà phê / Nước uống
    "HIGHLANDS COFFEE", "The Coffee House", "Starbucks Coffee", "Phuc Long Coffee",
    "Trung Nguyen Legend", "Cong Ca Phe", "Gong Cha", "TocoToco", "Ding Tea",
    "Phuc Long Tea", "Milano Coffee", "Urban Station",
    # Thức ăn nhanh
    "KFC Vietnam", "Lotteria", "Burger King", "Jollibee", "Popeyes",
    # Siêu thị / Cửa hàng tiện lợi
    "WinMart", "Big C", "LOTTE Mart", "Aeon", "Co.opmart",
    "Bach Hoa Xanh", "BHX", "FamilyMart", "Circle K", "MiniStop",
    "GS25", "7-Eleven",
    # Nhà hàng / Ăn uống
    "Pho 24", "Bun Bo Hue Mo Le", "Com Tam Sai Gon", "Quan Bun Mam",
    "Banh Mi Hoi An", "Lau Thai Mama", "Pizza 4Ps", "The Pizza Company",
    "Pho Thin", "Com Ga Ba Buoi", "Quan Nhau 99",
    # Giao đồ ăn / App
    "GrabFood", "ShopeeFood", "BeFood",
    # Xăng dầu
    "Petrolimex", "Shell Station", "Caltex", "BP Oil",
    # Dược phẩm
    "Guardian", "Pharmacity", "Long Chau", "NhaThuoc24",
    # Trung tâm thương mại / Siêu thị lớn
    "Vincom Center", "Parkson", "Satramart", "Emart",
    # Khác
    "Tap Hoa Lan", "Tap Hoa Minh Tuan", "Quan Com Binh Dan", "Tiem Banh ABC",
    "Spa Lavender", "Rạp CGV", "Lotte Cinema", "Tiki",
]

ITEMS = [
    # Đồ uống
    ("Ca phe sua da", 35000), ("Ca phe den", 25000), ("Tra dao cam sa", 55000),
    ("Matcha latte", 65000), ("Americano", 55000), ("Cappuccino", 65000),
    ("Tra xanh", 45000), ("Nuoc suoi Lavie", 12000), ("Pepsi lon", 15000),
    ("Coca Cola", 15000), ("Nuoc ep cam", 35000), ("Sinh to xoai", 45000),
    ("Tra sua tran chau", 48000), ("Bac xiu", 30000), ("Smoothie dau", 50000),
    # Đồ ăn
    ("Banh mi thit", 35000), ("Banh mi trung", 25000), ("Banh mi cha lua", 30000),
    ("Com tam suon bi cha", 65000), ("Bun bo Hue", 70000), ("Pho bo tai", 75000),
    ("Mi tom trung", 25000), ("Banh flan", 25000), ("Xoi xeo", 20000),
    ("Com ga Hoi An", 60000), ("Mi quang", 55000), ("Banh xeo", 65000),
    ("Hu tieu Nam Vang", 60000), ("Bun mam", 65000), ("Chao long", 45000),
    ("Lau thai", 150000), ("Bo nhung dam", 180000), ("Muc rang muoi", 85000),
    # Siêu thị
    ("Sua tuoi TH", 28000), ("Sua Vinamilk hop", 25000), ("Banh gao", 18000),
    ("Keo cao su", 8000), ("Dau go banh my", 32000), ("Snack Oishi", 12000),
    ("Xuc xich", 35000), ("Pho bo goi", 22000), ("Mien ga", 20000),
    # Xăng dầu / Dịch vụ
    ("Xang A95", 150000), ("Xang A92", 120000), ("Dau diesel", 100000),
    # Khác
    ("Khan giay", 45000), ("Kem danh rang", 35000), ("Xa bong tam", 50000),
]

ADDRESSES = [
    "123 Nguyen Hue, Q1, TP.HCM",
    "45 Le Loi, Q3, TP.HCM",
    "88 Tran Hung Dao, Ha Noi",
    "12 Phan Chu Trinh, Da Nang",
    "56 Ly Tu Trong, Q1, HCM",
    "99 Nguyen Thi Minh Khai, Q3",
    "10 Hai Ba Trung, Hoan Kiem, HN",
    "203 Hoang Van Thu, Phu Nhuan",
]

TOTAL_PREFIXES = [
    "TONG CONG", "TONG CONG:", "TỔNG CỘNG", "TOTAL", "THANH TOAN",
    "Thanh toan:", "Tong tien:", "So tien:", "AMOUNT:",
]

DATE_FORMATS = ["%d/%m/%Y", "%d-%m-%Y", "%d.%m.%Y"]

# Cache font theo size — tranh goi Path.is_file() hang nghin lan tren Colab/Drive
_FONT_CACHE: dict[int, ImageFont.FreeTypeFont | ImageFont.ImageFont] = {}
_FONTS_READY = False


def _font_candidates() -> list[str]:
    """Chi tra ve duong dan hop le theo OS — KHONG dung path Windows tren Linux/Colab."""
    if platform.system() == "Windows":
        return [
            "C:/Windows/Fonts/arial.ttf",
            "C:/Windows/Fonts/arialbd.ttf",
            "C:/Windows/Fonts/times.ttf",
            "C:/Windows/Fonts/cour.ttf",
        ]
    # Linux / Colab
    return [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf",
        "/usr/share/fonts/truetype/freefont/FreeSans.ttf",
    ]


def _safe_is_file(path: str) -> bool:
    try:
        return Path(path).is_file()
    except OSError:
        return False


def _ensure_system_fonts() -> None:
    """Colab: cai font neu chua co (chi chay 1 lan)."""
    global _FONTS_READY
    if _FONTS_READY:
        return
    _FONTS_READY = True
    if any(_safe_is_file(p) for p in _font_candidates()):
        return
    if platform.system() != "Windows":
        print("Cai font DejaVu cho Colab...")
        try:
            subprocess.run(
                ["apt-get", "install", "-y", "-qq", "fonts-dejavu-core", "fonts-liberation"],
                check=False,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except Exception:
            pass


def _load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    if size in _FONT_CACHE:
        return _FONT_CACHE[size]
    _ensure_system_fonts()
    for p in _font_candidates():
        if _safe_is_file(p):
            try:
                _FONT_CACHE[size] = ImageFont.truetype(p, size=size)
                return _FONT_CACHE[size]
            except Exception:
                continue
    _FONT_CACHE[size] = ImageFont.load_default()
    return _FONT_CACHE[size]


def _resolve_dirs(out_dir: Path) -> tuple[Path, Path, Path]:
    out = out_dir.resolve()
    return out, out / "images" / "full", out / "images" / "crops"


def _fmt_amount(vnd: int, rng: random.Random) -> str:
    """Định dạng số tiền — luôn là digits + dấu chấm/phẩy (không có 'VND')."""
    choice = rng.randint(0, 2)
    if choice == 0:
        return f"{vnd:,}".replace(",", ".")       # 150.000
    elif choice == 1:
        return f"{vnd:,}".replace(",", ",")       # 150,000
    else:
        return str(vnd)                           # 150000


def _apply_perspective(img: Image.Image, rng: random.Random, strength: float = 0.04) -> Image.Image:
    """Biến đổi perspective nhẹ."""
    w, h = img.size
    dx = rng.uniform(-strength * w, strength * w)
    dy = rng.uniform(-strength * h, strength * h)
    src = [(0, 0), (w, 0), (w, h), (0, h)]
    dst = [
        (dx, dy), (w - dx, dy),
        (w + dx, h - dy), (-dx, h + dy),
    ]
    coeffs = _perspective_coeffs(src, dst)
    return img.transform((w, h), Image.PERSPECTIVE, coeffs, Image.BILINEAR, fillcolor=255)


def _perspective_coeffs(src: list, dst: list) -> list[float]:
    """Tính perspective coefficients (8 tham số)."""
    import numpy as np  # noqa: PLC0415
    A = []
    b_vec = []
    for (x, y), (X, Y) in zip(src, dst):
        A += [[x, y, 1, 0, 0, 0, -X * x, -X * y],
              [0, 0, 0, x, y, 1, -Y * x, -Y * y]]
        b_vec += [X, Y]
    A_mat = np.array(A, dtype=np.float64)
    b_arr = np.array(b_vec, dtype=np.float64)
    try:
        res = np.linalg.solve(A_mat, b_arr)
    except np.linalg.LinAlgError:
        res = np.zeros(8)
    return res.tolist()


def _aug_full_bill(img: Image.Image, rng: random.Random) -> Image.Image:
    """Augment ảnh bill đầy đủ."""
    if rng.random() < 0.3:
        img = _apply_perspective(img, rng, strength=0.02)
    if rng.random() < 0.4:
        img = img.filter(ImageFilter.GaussianBlur(radius=rng.uniform(0.2, 0.8)))
    if rng.random() < 0.5:
        img = img.point(lambda p: min(255, max(0, int(p * rng.uniform(0.80, 1.15)))))
    if rng.random() < 0.3:
        arr = np.array(img, dtype=np.float32)
        arr += np.random.normal(0, rng.uniform(2, 8), arr.shape)
        img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    if rng.random() < 0.15:
        angle = rng.uniform(-1.5, 1.5)
        img = img.rotate(angle, expand=False, fillcolor=255)
    return img


def _aug_crop(img: Image.Image, rng: random.Random) -> Image.Image:
    """Augment nhẹ cho ảnh crop (augment riêng thêm)."""
    if rng.random() < 0.35:
        img = img.filter(ImageFilter.GaussianBlur(radius=rng.uniform(0.1, 0.5)))
    if rng.random() < 0.4:
        img = img.point(lambda p: min(255, max(0, int(p * rng.uniform(0.85, 1.10)))))
    if rng.random() < 0.25:
        arr = np.array(img, dtype=np.float32)
        arr += np.random.normal(0, rng.uniform(1, 6), arr.shape)
        img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    return img


def _render_full_bill(
    rng: random.Random,
    *,
    merchant: str,
    tx_date: date,
    items: list[tuple[str, int]],
    total_vnd: int,
    date_fmt: str,
) -> tuple[Image.Image, dict, str, str]:
    """
    Trả về (img, boxes, date_label, amount_label).

    boxes["amount"] = vùng chỉ chứa SỐ tiền (nửa phải dòng total).
    date_label = chuỗi ngày thực sự vẽ lên ảnh (bao gồm giờ).
    amount_label = chuỗi số tiền sạch (chỉ digits + . ,).
    """
    n_items = len(items)
    width = rng.randint(320, 400)
    height = 130 + n_items * 36 + 90
    bg = rng.randint(235, 255)
    img = Image.new("L", (width, height), color=bg)
    draw = ImageDraw.Draw(img)
    ink = rng.randint(0, 60)

    sz_title = rng.choice([20, 22, 24])
    sz_body = rng.choice([15, 17, 18])
    sz_small = 13
    f_title = _load_font(sz_title)
    f_body = _load_font(sz_body)
    f_small = _load_font(sz_small)

    y = 12
    # Merchant
    draw.text((width // 2, y), merchant, fill=ink, font=f_title, anchor="mt")
    y_merchant_top = y
    y += sz_title + 8

    # Address
    draw.text((width // 2, y), rng.choice(ADDRESSES), fill=ink + 50, font=f_small, anchor="mt")
    y += sz_small + 6

    # Date — chi hien thi ngay (10 ky tu: DD/MM/YYYY), khong kem gio
    date_str = tx_date.strftime(date_fmt)
    date_line = date_str
    draw.text((16, y), date_line, fill=ink, font=f_body)
    y_date_top, y_date_bot = y, y + sz_body + 6
    y = y_date_bot + 4

    draw.line([(12, y), (width - 12, y)], fill=ink + 90, width=1)
    y += 8

    # Items
    y_items_start = y
    for name, price in items:
        draw.text((16, y), name, fill=ink, font=f_body)
        draw.text((width - 14, y), _fmt_amount(price, rng), fill=ink, font=f_body, anchor="ra")
        y += 32
    y_items_end = y
    y += 4
    draw.line([(12, y), (width - 12, y)], fill=ink + 90, width=1)
    y += 10

    # Total line — prefix bên trái, số bên phải
    total_prefix = rng.choice(TOTAL_PREFIXES)
    amount_str = _fmt_amount(total_vnd, rng)
    draw.text((16, y), total_prefix, fill=ink, font=f_title)
    draw.text((width - 14, y), amount_str, fill=ink, font=f_title, anchor="ra")
    y_total_top = y
    y_total_bot = y + sz_title + 8

    # Optional: barcode-like footer
    if rng.random() < 0.4:
        y_bar = y_total_bot + 6
        draw.rectangle([(16, y_bar), (width - 16, y_bar + 8)], fill=ink + 100)

    # Amount crop = nửa phải của dòng total (chỉ chứa số)
    x_amount_start = width // 2
    boxes = {
        "merchant": (0, y_merchant_top, width, y_merchant_top + sz_title + 6),
        "date": (0, y_date_top, width, y_date_bot),
        "line": (0, y_items_start, width, min(y_items_start + 36, y_items_end)),
        "amount": (x_amount_start, y_total_top, width, y_total_bot),
        "header": (0, 0, width, y_items_start),
        "body": (0, y_items_start, width, y_items_end),
        "footer": (0, y_total_top - 6, width, height),
    }
    img = _aug_full_bill(img, rng)
    return img, boxes, date_line, amount_str


def generate(n: int, seed: int = 42, out_dir: Path | None = None) -> Path:
    out_dir = (out_dir or DEFAULT_OUT_DIR).resolve()
    out_root, full_dir, crop_dir = _resolve_dirs(out_dir)
    rng = random.Random(seed)

    for sub in ("amount", "merchant", "date", "line"):
        (crop_dir / sub).mkdir(parents=True, exist_ok=True)
    full_dir.mkdir(parents=True, exist_ok=True)
    print(f"Output dir: {out_root}")

    rows_main: list[dict] = []
    rows_amount: list[dict] = []
    rows_merchant: list[dict] = []
    rows_date: list[dict] = []
    rows_line: list[dict] = []

    base_day = date(2023, 1, 1)

    for i in range(n):
        merchant = rng.choice(MERCHANTS)
        tx_date = base_day + timedelta(days=rng.randint(0, 800))
        date_fmt = rng.choice(DATE_FORMATS)
        n_pick = rng.randint(1, 4)
        items = rng.sample(ITEMS, k=n_pick)
        total_vnd = sum(p for _, p in items)
        first_item = items[0][0]

        full, boxes, date_label, amount_label = _render_full_bill(
            rng,
            merchant=merchant,
            tx_date=tx_date,
            items=items,
            total_vnd=total_vnd,
            date_fmt=date_fmt,
        )

        stem = f"bill_{i:05d}"
        full.save(full_dir / f"{stem}.png", optimize=True)

        def _save_crop(key: str, sub: str, extra_aug: bool = False) -> str:
            x0, y0, x1, y1 = boxes[key]
            crop = full.crop((x0, y0, x1, max(y1, y0 + 4)))
            if extra_aug:
                crop = _aug_crop(crop, rng)
            rel = f"images/crops/{sub}/{stem}.png"
            crop.save(out_root / rel, optimize=True)
            return rel

        if (i + 1) % 500 == 0 or i == 0 or i + 1 == n:
            print(f"  ... {i + 1}/{n} bills")

        crop_amount = _save_crop("amount", "amount", extra_aug=True)
        crop_merchant = _save_crop("merchant", "merchant", extra_aug=True)
        crop_date = _save_crop("date", "date", extra_aug=True)
        crop_line = _save_crop("line", "line", extra_aug=True)

        desc = "; ".join(nm for nm, _ in items)

        rows_main.append({
            "image_path": f"images/full/{stem}.png",
            "amount_text": amount_label,
            "amount_vnd": total_vnd,
            "merchant": merchant,
            "transaction_date": tx_date.strftime("%d/%m/%Y"),
            "description": desc,
            "crop_amount": crop_amount,
            "crop_merchant": crop_merchant,
            "crop_date": crop_date,
            "crop_line": crop_line,
        })
        # amount_label đã là chuỗi số sạch (chỉ digits + . ,) — khớp với ảnh crop
        rows_amount.append({"image_path": crop_amount, "label_text": amount_label, "amount_vnd": total_vnd})
        rows_merchant.append({"image_path": crop_merchant, "label_text": merchant})
        # date_label = chuoi ngay rendered (vd "21/05/2025") — khop hoàn toàn voi anh crop
        rows_date.append({"image_path": crop_date, "label_text": date_label})
        rows_line.append({"image_path": crop_line, "label_text": first_item})

    pd.DataFrame(rows_main).to_csv(out_root / "manifest.csv", index=False, encoding="utf-8")
    pd.DataFrame(rows_amount).to_csv(out_root / "manifest_amount.csv", index=False, encoding="utf-8")
    pd.DataFrame(rows_merchant).to_csv(out_root / "manifest_merchant.csv", index=False, encoding="utf-8")
    pd.DataFrame(rows_date).to_csv(out_root / "manifest_date.csv", index=False, encoding="utf-8")
    pd.DataFrame(rows_line).to_csv(out_root / "manifest_line.csv", index=False, encoding="utf-8")
    print(f"OK  {n} full bills -> {full_dir}")
    print(f"OK  manifests    -> {out_root}")
    return out_root


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=8000)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--out-dir", type=str, default="",
                    help="Output dir (Colab: /content/receipt_ocr)")
    args = ap.parse_args()
    out = Path(args.out_dir) if args.out_dir else None
    generate(args.n, seed=args.seed, out_dir=out)


if __name__ == "__main__":
    main()
