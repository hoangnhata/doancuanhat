# -*- coding: utf-8 -*-
"""Tạo lại train_classify.ipynb từ template."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "train_classify.ipynb"


def md(s: str) -> dict:
    return {"cell_type": "markdown", "metadata": {}, "source": [line + "\n" for line in s.split("\n")]}


def code(s: str) -> dict:
    return {
        "cell_type": "code",
        "metadata": {},
        "source": [line + "\n" for line in s.split("\n")],
        "outputs": [],
        "execution_count": None,
    }


cells = [
    md("""# Phân loại giao dịch — From-scratch (CharCNN + BiLSTM + Attention)

**Không** dùng BERT / PhoBERT / HuggingFace pretrained.

- Embedding ký tự học từ đầu
- CNN: đặc trưng n-gram ký tự
- BiLSTM: ngữ cảnh trái/phải
- Attention: tập trung vị trí quan trọng
- Dataset: `data/classify_train_cleaned.csv` (~10k mẫu, cân bằng nhãn)"""),

    code("""# CELL 0 — Môi trường (Colab: mount Drive → copy sang /content)
# Bắt buộc chạy cell này TRƯỚC CELL 1.
# Train TRỰC TIẾP trên Drive dễ lỗi Errno 107 (FUSE ngắt) khi PyTorch khởi tạo optimizer.
import os
import subprocess
import sys
from pathlib import Path

os.environ.setdefault("TORCHDYNAMO_DISABLE", "1")
os.environ.setdefault("TORCH_COMPILE_DISABLE", "1")

for pkg in ["torch", "numpy", "pandas", "matplotlib", "scikit-learn", "tqdm"]:
    try:
        __import__(pkg.replace("-", "_"))
    except ImportError:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "-q", pkg])

ON_COLAB = False
DRIVE_ROOT = Path("/content/drive/MyDrive")
try:
    from google.colab import drive  # type: ignore
    drive.mount("/content/drive")
    ON_COLAB = True
    print("Google Drive mounted.")
except Exception:
    print("Chạy local (không Colab).")

_LIB = Path("app") / "classify_train_lib.py"


def find_ai_service_root() -> Path | None:
    cwd = Path.cwd().resolve()
    if (cwd / _LIB).is_file():
        return cwd
    fixed = [
        DRIVE_ROOT / "thesis" / "ai_service",
        DRIVE_ROOT / "Doantotnghiep2" / "ai_service",
        Path("/content/ai_service"),
    ]
    for cand in fixed:
        if (cand / _LIB).is_file():
            return cand.resolve()
    if ON_COLAB and DRIVE_ROOT.is_dir():
        for hit in DRIVE_ROOT.rglob("classify_train_lib.py"):
            if hit.parent.name == "app" and (hit.parent.parent / "data").is_dir():
                return hit.parent.parent.resolve()
    return None


DRIVE_AI_SERVICE = find_ai_service_root()
if DRIVE_AI_SERVICE is None:
    raise FileNotFoundError(
        "Không tìm thấy ai_service. Cần: app/classify_train_lib.py và data/\\n"
        "Trên Drive: MyDrive/thesis/ai_service/ → mount Drive, chạy lại CELL 0."
    )

LOCAL_WORK = Path("/content/ai_service_work")
DRIVE_SAVE_DIR = DRIVE_AI_SERVICE / "models"

if ON_COLAB and str(DRIVE_AI_SERVICE).startswith("/content/drive"):
    import shutil
    _ignore = shutil.ignore_patterns(
        "__pycache__", "*.pyc", ".ipynb_checkpoints", ".git", "*.pt"
    )
    if LOCAL_WORK.exists():
        shutil.rmtree(LOCAL_WORK)
    print("Copy Drive → local (tránh lỗi FUSE)...")
    shutil.copytree(DRIVE_AI_SERVICE, LOCAL_WORK, ignore=_ignore)
    WORK_ROOT = LOCAL_WORK
else:
    WORK_ROOT = DRIVE_AI_SERVICE

# Xóa cache import cũ nếu lỡ import từ Drive
for mod in list(sys.modules):
    if mod == "app" or mod.startswith("app."):
        del sys.modules[mod]

os.chdir(WORK_ROOT)
sys.path.insert(0, str(WORK_ROOT))

SAVE_DIR = (WORK_ROOT / "models").resolve()
SAVE_DIR.mkdir(parents=True, exist_ok=True)

ARTIFACT_NAMES = [
    "classify_model.pt",
    "classify_vocab.json",
    "classify_meta.json",
    "classify_preprocess.json",
    "classify_metrics.json",
]


def push_artifacts_to_drive() -> None:
    \"\"\"Sau train: copy artifact từ /content về Drive.\"\"\"
    if not ON_COLAB or not str(DRIVE_AI_SERVICE).startswith("/content/drive"):
        return
    import shutil
    DRIVE_SAVE_DIR.mkdir(parents=True, exist_ok=True)
    for name in ARTIFACT_NAMES:
        src = SAVE_DIR / name
        if src.is_file():
            shutil.copy2(src, DRIVE_SAVE_DIR / name)
            print("Saved to Drive:", DRIVE_SAVE_DIR / name)

import torch
if ON_COLAB and not torch.cuda.is_available():
    raise RuntimeError(
        "Chưa bật GPU. Menu: Runtime → Change runtime type → T4 GPU → Save, "
        "rồi Restart session và chạy lại CELL 0."
    )

import app  # noqa: F401
from app.classify_train_lib import TrainConfig, setup_torch_runtime  # noqa: F401

setup_torch_runtime(require_cuda=ON_COLAB)

print("ON_COLAB:", ON_COLAB)
print("DRIVE_AI_SERVICE:", DRIVE_AI_SERVICE)
print("WORK_ROOT (train here):", WORK_ROOT)
print("SAVE_DIR:", SAVE_DIR)
print("CSV exists:", (WORK_ROOT / "data" / "classify_train_cleaned.csv").is_file())"""),

    code("""# CELL 1 — Cấu hình train (Colab T4 ~15–25 phút)
from app.classify_train_lib import colab_train_config, run_training

CSV_PATH = WORK_ROOT / "data" / "classify_train_cleaned.csv"
if not CSV_PATH.is_file():
    raise FileNotFoundError(f"Thiếu {CSV_PATH}")

# batch_size=64, require_cuda=True, AMP (LSTM fp32), num_workers=0
cfg = colab_train_config(CSV_PATH, SAVE_DIR)
print("CSV:", CSV_PATH)
print("Save:", SAVE_DIR)
print("epochs:", cfg.epochs, "| batch:", cfg.batch_size, "| amp:", cfg.use_amp)"""),

    code("""# CELL 2 — Train (~15–25 phút trên T4). KHÔNG bấm Stop trừ khi cần dừng.
# Tiến trình: thanh epochs + log mỗi epoch. Checkpoint: models/classify_best.pt
try:
    metrics = run_training(cfg)
except KeyboardInterrupt:
    print("Đã dừng. Nếu có classify_best.pt có thể copy thủ công; chạy lại CELL 2 để train từ đầu.")
    raise

push_artifacts_to_drive()
print("Done. Local:", SAVE_DIR)
print("Drive:", DRIVE_SAVE_DIR)"""),

    code("""# CELL 3 — Learning curve (nếu có history)
import matplotlib.pyplot as plt
h = metrics.get("history", {})
if h:
    fig, ax = plt.subplots(1, 2, figsize=(12, 4))
    ax[0].plot(h["tr_loss"], label="train"); ax[0].plot(h["va_loss"], label="val")
    ax[0].set_title("Loss"); ax[0].legend()
    ax[1].plot(h["tr_acc"], label="train"); ax[1].plot(h["va_acc"], label="val")
    ax[1].set_title("Accuracy"); ax[1].legend()
    plt.show()"""),

    code("""# CELL 4 — Confusion matrix (validation)
import numpy as np
import matplotlib.pyplot as plt
from app.classify_train_lib import ALL_CATEGORIES

cm = np.array(metrics["validation"]["confusion_matrix"])
fig, ax = plt.subplots(figsize=(14, 12))
ax.imshow(cm, cmap="Blues")
ax.set_xticks(range(len(ALL_CATEGORIES)))
ax.set_xticklabels(ALL_CATEGORIES, rotation=45, ha="right", fontsize=8)
ax.set_yticks(range(len(ALL_CATEGORIES)))
ax.set_yticklabels(ALL_CATEGORIES, fontsize=8)
ax.set_title("Confusion Matrix — Validation")
plt.tight_layout()
plt.show()"""),

    code("""# CELL 5 — Smoke test inference (preprocess 1 lần + OOD)
from app.classify_infer import load_classify_bundle, predict

bundle = load_classify_bundle(SAVE_DIR)
assert bundle is not None, "Chưa có model — chạy CELL 2"

test_texts = [
    "ăn trưa 45k",
    "an trua 45k",
    "cf ban be 30k",
    "grab đi làm 80k",
    "grab food 90k",
    "ck tiền trọ",
    "luong thang nay ve roi",
    "salary received",
    "mẹ gửi tiền ăn",
    "trả mẹ tiền ăn",
    "asdfasdf qwerty",
    "hôm nay trời đẹp",
    "123456",
    "50k",
]

print(f"{'TEXT':<28} {'LABEL':<18} {'CONF':>6} {'REVIEW':>6}")
print("-" * 62)
for t in test_texts:
    r = predict(bundle, t)
    print(f"{t[:28]:<28} {r.label:<18} {r.confidence:>5.0%} {str(r.needs_review):>6}")"""),

    code("""# CELL 6 — Tải artifact về máy (Colab)
if ON_COLAB:
    from google.colab import files
    for name in [
        "classify_model.pt",
        "classify_vocab.json",
        "classify_meta.json",
        "classify_preprocess.json",
        "classify_metrics.json",
    ]:
        p = SAVE_DIR / name
        if p.exists():
            files.download(str(p))
else:
    print("Artifacts:", list(SAVE_DIR.glob("classify_*")))"""),

    md("""## Artifacts (copy vào `ai_service/models/`)

| File | Mô tả |
|------|--------|
| classify_model.pt | Trọng số CharCNN+BiLSTM+Attn |
| classify_vocab.json | char2idx |
| classify_meta.json | Nhãn, siêu tham số, threshold |
| classify_preprocess.json | Cấu hình tiền xử lý |
| classify_metrics.json | Val + val_hard metrics |

FastAPI `/api/categorize` tự load khi khởi động lại service."""),
]

nb = {
    "nbformat": 4,
    "nbformat_minor": 5,
    "metadata": {
        "kernelspec": {"display_name": "Python 3", "language": "python", "name": "python3"},
        "language_info": {"name": "python", "version": "3.10.0"},
    },
    "cells": cells,
}

OUT.write_text(json.dumps(nb, ensure_ascii=False, indent=1), encoding="utf-8")
print("Wrote", OUT)
