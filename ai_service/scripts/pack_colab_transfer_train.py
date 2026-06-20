"""
Đóng gói folder upload Google Drive để train OCR bill chuyển khoản trên Colab.

Chạy (từ ai_service):
  python scripts/pack_colab_transfer_train.py

Ra: colab_upload/ai_service.zip (~ vài chục MB, không có model OCR cũ)
Upload zip lên Drive, giải nén thành MyDrive/thesis/ai_service/
"""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "colab_upload"
BUNDLE = OUT / "ai_service"

APP_FILES = [
    "__init__.py",
    "ocr_charset.py",
    "ocr_net.py",
    "ocr_eval.py",
    "ocr_recognizer.py",
    "ocr_detect.py",
    "ocr_postprocess.py",
    "transfer_parse.py",
    "transfer_pipeline.py",
    "ocr_transfer.py",
    "ocr_real.py",
    "transaction_intent.py",
    "category_hints.py",
    "classify_infer.py",
    "classify_net.py",
    "classify_ood.py",
    "text_preprocess.py",
    "parsers.py",
    "rules.py",
]

DATA_FILES = [
    "gen_ocr_lines.py",
    "train_ocr_recognizer.py",
    "prepare_real_lines.py",
    "transfer_label_seeds.py",
    "extract_vietin_bill_crops.py",
    "prep_colab_train_data.py",
    "evaluate_real.py",
]

CLASSIFY_MODELS = [
    "classify_model.pt",
    "classify_vocab.json",
    "classify_meta.json",
    "classify_preprocess.json",
]


def _copy(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def main() -> None:
    prep = ROOT / "data" / "prep_colab_train_data.py"
    if prep.is_file():
        subprocess.run([sys.executable, str(prep)], cwd=ROOT, check=True)

    if OUT.exists():
        shutil.rmtree(OUT)
    BUNDLE.mkdir(parents=True)
    (BUNDLE / "models").mkdir()
    (BUNDLE / "app").mkdir()
    (BUNDLE / "data").mkdir()

    _copy(ROOT / "train_ocr_from_scratch.ipynb", BUNDLE / "train_ocr_from_scratch.ipynb")

    for name in APP_FILES:
        p = ROOT / "app" / name
        if p.is_file():
            _copy(p, BUNDLE / "app" / name)

    for name in DATA_FILES:
        p = ROOT / "data" / name
        if p.is_file():
            _copy(p, BUNDLE / "data" / name)

    src_train = ROOT / "data_train"
    if src_train.is_dir():
        shutil.copytree(src_train, BUNDLE / "data_train")

    real = ROOT / "data" / "real_lines"
    if real.is_dir() and (real / "labels.csv").is_file():
        shutil.copytree(real, BUNDLE / "data" / "real_lines")

    for name in CLASSIFY_MODELS:
        p = ROOT / "models" / name
        if p.is_file():
            _copy(p, BUNDLE / "models" / name)

    zip_path = OUT / "ai_service.zip"
    if zip_path.is_file():
        zip_path.unlink()
    shutil.make_archive(str(OUT / "ai_service"), "zip", BUNDLE)

    mb = zip_path.stat().st_size / (1024 * 1024)
    print(f"OK: {zip_path} ({mb:.1f} MB)")
    print("Upload -> MyDrive/thesis/ -> giai nen -> mo train_ocr_from_scratch.ipynb")


if __name__ == "__main__":
    main()
