"""
Crop vùng chữ từ screenshot VietinBank iPay (layout cố định) → bổ sung real_lines.

Detect_lines thường chỉ bắt vài dòng status bar; script này crop theo tỷ lệ ảnh
để có nhãn số tiền / tên / nội dung đúng cho train.

Chạy: python data/extract_vietin_bill_crops.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import pandas as pd  # noqa: E402
from PIL import Image  # noqa: E402

OUT = ROOT / "data" / "real_lines"
IMG_DIR = OUT / "images"
CSV = OUT / "labels.csv"

# Vùng crop (y0,y1,x0,x1) theo tỷ lệ ảnh — VietinBank iPay portrait
REGIONS: list[tuple[str, float, float, float, float]] = [
    ("datetime", 0.158, 0.205, 0.52, 0.96),
    ("success", 0.205, 0.255, 0.10, 0.90),
    ("from_name", 0.332, 0.378, 0.42, 0.95),
    ("to_name", 0.392, 0.438, 0.42, 0.95),
    ("bank", 0.448, 0.498, 0.42, 0.95),
    ("amount", 0.508, 0.572, 0.35, 0.95),
    ("amount_words", 0.568, 0.628, 0.35, 0.95),
    ("fee", 0.618, 0.668, 0.42, 0.95),
    ("note", 0.662, 0.728, 0.10, 0.95),
]

# Nhãn chuẩn theo file ảnh (đọc từ bill thật)
BILL_TEXT: dict[str, dict[str, str]] = {
    "8b6b11af-d329-4137-9e5e-8e05a74e8744.jpg": {
        "datetime": "28/01/2026 19:18",
        "success": "Chuyển tiền thành công!",
        "from_name": "HO THI THU HUONG",
        "to_name": "HOANG MINH NHAT",
        "bank": "MB_Ngân hàng Quân đội",
        "amount": "1.000.000 VND",
        "amount_words": "Một Triệu Đồng",
        "fee": "Miễn phí",
        "note": "HO THI THU HUONG chuyen tien",
    },
    "b7866e87-fc7a-48cf-bc20-ef24b2982529.jpg": {
        "datetime": "12/02/2026 07:14",
        "success": "Chuyển tiền thành công!",
        "from_name": "HO THI THU HUONG",
        "to_name": "HOANG MINH NHAT",
        "bank": "MB_Ngân hàng Quân đội",
        "amount": "2.000.000 VND",
        "amount_words": "Hai Triệu Đồng",
        "fee": "Miễn phí",
        "note": "HO THI THU HUONG chuyen tien",
    },
    "d7874c2f-5865-477c-b462-fdc28ff1685b.jpg": {
        "datetime": "27/02/2026 07:33",
        "success": "Chuyển tiền thành công!",
        "from_name": "HO THI THU HUONG",
        "to_name": "HOANG MINH NHAT",
        "bank": "MB_Ngân hàng Quân đội",
        "amount": "2.500.000 VND",
        "amount_words": "Hai Triệu Năm Trăm Nghìn Đồng",
        "fee": "Miễn phí",
        "note": "HO THI THU HUONG chuyen tien",
    },
    "f1ac215a-c77d-49d0-af37-1710174bc701.jpg": {
        "datetime": "09/04/2026 21:15",
        "success": "Chuyển tiền thành công!",
        "from_name": "HOANG MINH NHAT",
        "to_name": "HO THI THU HUONG",
        "bank": "Ngân hàng Công Thương Việt Nam (CTG)",
        "amount": "6.300.000 VND",
        "amount_words": "Sáu Triệu Ba Trăm Nghìn Đồng",
        "fee": "Miễn phí",
        "note": "HOANG MINH NHAT chuyen tien",
    },
}

SRC_ROOT = ROOT / "data_train"


def _slug(name: str) -> str:
    return re.sub(r"[^a-zA-Z0-9_-]+", "_", name)[:48]


def extract() -> int:
    IMG_DIR.mkdir(parents=True, exist_ok=True)
    rows: list[dict] = []
    added = 0

    def _find_image(name: str) -> Path | None:
        direct = SRC_ROOT / name
        if direct.is_file():
            return direct
        for p in SRC_ROOT.rglob(name):
            if p.is_file():
                return p
        return None

    for src_name, fields in BILL_TEXT.items():
        src_path = _find_image(src_name)
        if src_path is None:
            print(f"  [skip] khong co {src_name}")
            continue
        img = Image.open(src_path).convert("RGB")
        w, h = img.size
        stem = _slug(src_name.replace(".jpg", ""))

        for region_key, y0, y1, x0, x1 in REGIONS:
            text = fields.get(region_key, "").strip()
            if not text:
                continue
            box = (
                int(x0 * w), int(y0 * h), int(x1 * w), int(y1 * h),
            )
            crop = img.crop(box)
            if crop.width < 20 or crop.height < 8:
                continue
            rel = f"images/vietin_{stem}__{region_key}.png"
            crop.save(OUT / rel, optimize=True)
            rows.append({
                "image_path": rel,
                "text": text,
                "conf": 1.0,
                "merchant": src_path.parent.name,
                "source": src_name,
            })
            added += 1

    if not rows:
        return 0

    if CSV.is_file():
        old = pd.read_csv(CSV).fillna("")
        # bỏ crop vietin cũ trùng prefix
        old = old[~old["image_path"].astype(str).str.contains("vietin_", na=False)]
        df = pd.concat([old, pd.DataFrame(rows)], ignore_index=True)
    else:
        df = pd.DataFrame(rows)

    df.to_csv(CSV, index=False, encoding="utf-8")
    print(f"OK them {added} crop VietinBank iPay -> {CSV}")
    print(f"   Tong labels: {len(df)} | co text: {(df['text'].astype(str).str.strip()!='').sum()}")
    return added


if __name__ == "__main__":
    extract()
