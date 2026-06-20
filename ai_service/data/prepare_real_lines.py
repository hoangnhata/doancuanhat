"""
Chuẩn bị DỮ LIỆU DÒNG THẬT từ ảnh hóa đơn/bill tự thu thập (data_train/).

Vào:  data_train/<merchant>/*.jpg|png|webp   (ảnh full, CHƯA có nhãn)
Ra:   data/real_lines/
        images/<merchant>__<stem>__<idx>.png   (mỗi dòng chữ 1 file)
        labels.csv  (image_path, text, conf, merchant, source)

Quy trình:
  1. Tách dòng bằng app/ocr_detect.detect_lines (xử lý ảnh cổ điển, không pretrain).
  2. (Tùy chọn --pseudo) Dùng recognizer CRNN ĐÃ TRAIN của chính dự án để điền nhãn
     gợi ý + độ tin cậy → bạn chỉ cần MỞ labels.csv sửa lại cho đúng (nhanh hơn gõ tay).
     Đây là self-training (tự huấn luyện), KHÔNG dùng model pretrain bên ngoài.
  3. Bạn rà soát labels.csv: sửa cột `text`, xóa dòng rác (logo, vạch, nhiễu).
     Chỉ những dòng có `text` KHÁC RỖNG mới được dùng khi train.

Chạy (từ ai_service):
  python data/prepare_real_lines.py --src data_train --out data/real_lines \\
         --models-dir models --pseudo
"""

from __future__ import annotations

import argparse
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import pandas as pd  # noqa: E402
from PIL import Image  # noqa: E402

from app.ocr_detect import detect_lines  # noqa: E402

IMG_EXT = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}


def _slug(name: str) -> str:
    nf = unicodedata.normalize("NFD", name)
    nf = "".join(c for c in nf if unicodedata.category(c) != "Mn")
    nf = nf.replace("đ", "d").replace("Đ", "D")
    out = "".join(c if (c.isalnum() or c in "-_") else "_" for c in nf)
    return out.strip("_")[:40] or "x"


def prepare(
    src: Path,
    out: Path,
    *,
    models_dir: Path | None = None,
    pseudo: bool = False,
    min_h: int = 12,
) -> Path:
    out = out.resolve()
    img_dir = out / "images"
    img_dir.mkdir(parents=True, exist_ok=True)

    recognizer = None
    if pseudo and models_dir is not None:
        try:
            import torch
            from app.ocr_recognizer import load_recognizer_bundle, recognize_batch  # noqa: F401
            from app.ocr_postprocess import correct_line  # noqa: F401
            dev = torch.device("cuda" if torch.cuda.is_available() else "cpu")
            recognizer = load_recognizer_bundle(models_dir, device=dev)
            if recognizer is None:
                print(f"[pseudo] Khong tim thay model trong {models_dir} -> de trong cot text")
        except Exception as e:
            print(f"[pseudo] Loi load recognizer: {e} -> de trong cot text")
            recognizer = None

    src = src.resolve()
    folders = [p for p in sorted(src.iterdir()) if p.is_dir()] if src.is_dir() else []
    if not folders and src.is_dir():
        folders = [src]  # ảnh để thẳng trong src

    rows: list[dict] = []
    total_imgs = 0
    for folder in folders:
        merchant = folder.name
        images = [p for p in sorted(folder.iterdir()) if p.suffix.lower() in IMG_EXT]
        for img_path in images:
            total_imgs += 1
            try:
                img = Image.open(img_path)
                img = img.convert("RGB") if img.mode not in ("L", "RGB") else img
            except Exception as e:
                print(f"  [bo qua] {img_path.name}: {e}")
                continue

            line_boxes = detect_lines(img)
            line_boxes = [lb for lb in line_boxes if (lb.y1 - lb.y0) >= min_h]

            # Pseudo-label cả ảnh 1 lần (batch) nếu có recognizer
            preds: list[tuple[str, float]] = []
            if recognizer is not None and line_boxes:
                from app.ocr_recognizer import recognize_batch
                from app.ocr_postprocess import correct_line
                raw = recognize_batch(recognizer, [lb.image for lb in line_boxes])
                preds = [(correct_line(t), c) for t, c in raw]

            stem = _slug(img_path.stem)
            for idx, lb in enumerate(line_boxes):
                rel = f"images/{_slug(merchant)}__{stem}__{idx:02d}.png"
                lb.image.save(out / rel, optimize=True)
                text, conf = (preds[idx] if idx < len(preds) else ("", 0.0))
                rows.append({
                    "image_path": rel,
                    "text": text,
                    "conf": round(float(conf), 4),
                    "merchant": merchant,
                    "source": img_path.name,
                })

    df = pd.DataFrame(rows)
    csv_path = out / "labels.csv"
    df.to_csv(csv_path, index=False, encoding="utf-8")

    print(f"\nOK  {total_imgs} anh -> {len(rows)} dong -> {img_dir}")
    print(f"    labels.csv -> {csv_path}")
    if recognizer is not None:
        hi = int((df["conf"] >= 0.80).sum()) if len(df) else 0
        print(f"    pseudo-label: {hi}/{len(df)} dong conf>=0.80 (nen tin), con lai HAY SUA tay")
    print("\nBUOC TIEP: mo labels.csv, sua cot `text` cho dung, xoa dong rac. "
          "Chi dong co text se duoc dung khi train (--real-dir).")
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", type=str, default="data_train")
    ap.add_argument("--out", type=str, default="data/real_lines")
    ap.add_argument("--models-dir", type=str, default="models")
    ap.add_argument("--pseudo", action="store_true",
                    help="Dien nhan goi y bang recognizer da train (de sua tay nhanh hon)")
    ap.add_argument("--min-h", type=int, default=12, help="Bo qua dong cao < min-h px")
    args = ap.parse_args()

    src = Path(args.src)
    if not src.is_absolute():
        src = ROOT / src
    out = Path(args.out)
    if not out.is_absolute():
        out = ROOT / out
    models_dir = Path(args.models_dir)
    if not models_dir.is_absolute():
        models_dir = ROOT / models_dir

    prepare(src, out, models_dir=models_dir, pseudo=args.pseudo, min_h=args.min_h)


if __name__ == "__main__":
    main()
