"""
Chuẩn bị TOÀN BỘ dữ liệu train Colab (52 bill + real_lines + seeds).

Chạy từ ai_service:
  python data/prep_colab_train_data.py
"""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def run(cmd: list[str]) -> None:
    print("\n>>", " ".join(cmd))
    subprocess.check_call(cmd, cwd=ROOT)


def main() -> None:
    py = sys.executable
    src = ROOT / "data_train"
    real = ROOT / "data" / "real_lines"

    if not src.is_dir():
        raise SystemExit(f"Khong thay {src}")

    # Tạo lại real_lines từ data_train mới (BIDV/MB/Momo/...)
    if real.exists():
        shutil.rmtree(real)
    real.mkdir(parents=True)

    run([
        py, "data/prepare_real_lines.py",
        "--src", str(src),
        "--out", str(real),
        "--models-dir", str(ROOT / "models"),
        "--pseudo",
    ])
    run([py, "data/extract_vietin_bill_crops.py"])
    run([py, "data/transfer_label_seeds.py"])

    import pandas as pd
    df = pd.read_csv(real / "labels.csv").fillna("")
    n = (df["text"].astype(str).str.strip() != "").sum()
    print(f"\n=== SAN SANG TRAIN: {n}/{len(df)} dong co text ===")
    print("Tiep: python scripts/pack_colab_transfer_train.py")


if __name__ == "__main__":
    main()
