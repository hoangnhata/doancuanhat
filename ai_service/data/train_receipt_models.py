"""
Huấn luyện 4 model OCR v2 (amount, merchant, date, line).

Cải tiến v2:
- Architecture v2: SE+Res CNN + AdaptivePool + BiLSTM 3-layer 256-hidden
- IMG_H = 48 (thay vì 32)
- Mixed-precision training (AMP) trên CUDA
- LR warmup (5 ep) + CosineAnnealing
- Heavy augmentation: rotation, shear, noise, blur, erasing
- Lưu {field}_epoch_log.csv, loss plot, predictions, char errors, compare_models.csv

Chạy (từ ai_service):
  python data/gen_receipt_dataset.py --n 8000 --out-dir /content/receipt_ocr
  python data/train_receipt_models.py --epochs 60 --data-dir /content/receipt_ocr \\
         --models-dir /content/receipt_models --log-dir /content/receipt_models/ocr_logs
"""

from __future__ import annotations

import argparse
import contextlib
import copy
import json
import math
import random
import re
import sys
from pathlib import Path

import numpy as np
import pandas as pd
import torch
import torch.nn as nn
import torch.optim as optim
from PIL import Image, ImageFilter
from torch.utils.data import DataLoader, Dataset

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from app.ocr_charset import (
    AMOUNT_CHAR2IDX,
    AMOUNT_IDX2CHAR,
    AMOUNT_NUM_CLASSES,
    DATE_CHAR2IDX,
    DATE_IDX2CHAR,
    DATE_NUM_CLASSES,
    TEXT_CHAR2IDX,
    TEXT_IDX2CHAR,
    TEXT_NUM_CLASSES,
)
from app.ocr_eval import char_errors_to_dataframe, evaluate_field_on_df
from app.ocr_infer import FieldOcrBundle
from app.ocr_net import ReceiptLineCRNN


DATA_DIR = ROOT / "data" / "receipt_ocr"
MODELS_DIR = ROOT / "models"

IMG_H = 48
BATCH_SIZE_CPU = 32
VAL_RATIO = 0.12
SEED = 42


def _ctc_timesteps(img_w: int) -> int:
    """So buoc thoi gian dau ra CRNN v2 (4 lan pool width x2)."""
    return max(1, img_w // 16)


def _batch_size() -> int:
    return 64 if torch.cuda.is_available() else BATCH_SIZE_CPU


def field_model_exists(models_dir: Path, field: str) -> bool:
    prefix = FIELD_CONFIG[field]["prefix"]
    return (
        (models_dir / f"{prefix}_model.pt").is_file()
        and (models_dir / f"{prefix}_meta.json").is_file()
    )

FIELD_CONFIG: dict[str, dict] = {
    "amount": {
        "manifest": "manifest_amount.csv",
        "prefix": "ocr_amount",
        "char2idx": AMOUNT_CHAR2IDX,
        "idx2char": AMOUNT_IDX2CHAR,
        "num_classes": AMOUNT_NUM_CLASSES,
        "label_col": "label_text",
        "img_w": 224,
        "clean_label": lambda s: re.sub(r"[^0-9.,]", "", str(s)),
    },
    "merchant": {
        "manifest": "manifest_merchant.csv",
        "prefix": "ocr_merchant",
        "char2idx": TEXT_CHAR2IDX,
        "idx2char": TEXT_IDX2CHAR,
        "num_classes": TEXT_NUM_CLASSES,
        "label_col": "label_text",
        "img_w": 320,  # T=20, du cho merchant dai nhat (19 ky tu)
        "clean_label": lambda s: str(s).strip(),
    },
    "date": {
        "manifest": "manifest_date.csv",
        "prefix": "ocr_date",
        "char2idx": DATE_CHAR2IDX,
        "idx2char": DATE_IDX2CHAR,
        "num_classes": DATE_NUM_CLASSES,
        "label_col": "label_text",
        "img_w": 320,  # v2 CRNN: T = img_w//16 → cần >= 17 cho "DD/MM/YYYY  HH:MM"
        "clean_label": lambda s: str(s).strip(),
    },
    "line": {
        "manifest": "manifest_line.csv",
        "prefix": "ocr_line",
        "char2idx": TEXT_CHAR2IDX,
        "idx2char": TEXT_IDX2CHAR,
        "num_classes": TEXT_NUM_CLASSES,
        "label_col": "label_text",
        "img_w": 320,
        "clean_label": lambda s: str(s).strip(),
    },
}


# ─────────────────────────── Augmentation utils ──────────────────────────────

def _aug_pil(img: Image.Image, rng: random.Random) -> Image.Image:
    """Heavy PIL augmentation cho crop ảnh khi train."""
    # Rotation nhẹ ±3°
    if rng.random() < 0.4:
        angle = rng.uniform(-3.0, 3.0)
        img = img.rotate(angle, expand=False, fillcolor=255, resample=Image.BILINEAR)
    # Shear ngang nhẹ
    if rng.random() < 0.3:
        shear = rng.uniform(-0.08, 0.08)
        w, h = img.size
        c = shear * h / 2
        img = img.transform(
            img.size, Image.AFFINE, (1, shear, -c, 0, 1, 0),
            resample=Image.BILINEAR, fillcolor=255,
        )
    # Blur
    if rng.random() < 0.35:
        img = img.filter(ImageFilter.GaussianBlur(radius=rng.uniform(0.2, 0.9)))
    # Brightness / contrast
    if rng.random() < 0.5:
        img = img.point(lambda p: min(255, max(0, int(p * rng.uniform(0.80, 1.20)))))
    # Additive Gaussian noise
    if rng.random() < 0.4:
        arr = np.array(img, dtype=np.float32)
        arr += np.random.normal(0, rng.uniform(2, 10), arr.shape)
        img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    # Sharpen / unsharp
    if rng.random() < 0.2:
        img = img.filter(ImageFilter.SHARPEN)
    return img


def _random_erase(x: torch.Tensor, rng: random.Random) -> torch.Tensor:
    """Random erasing: che một vùng chữ nhật ngẫu nhiên."""
    if rng.random() > 0.25:
        return x
    _, h, w = x.shape
    eh = rng.randint(2, max(3, h // 3))
    ew = rng.randint(4, max(5, w // 4))
    y0 = rng.randint(0, max(0, h - eh))
    x0 = rng.randint(0, max(0, w - ew))
    x[:, y0:y0 + eh, x0:x0 + ew] = rng.choice([-1.0, 1.0])  # black or white patch
    return x


# ─────────────────────────── Dataset ─────────────────────────────────────────

class OcrDataset(Dataset):
    def __init__(
        self,
        frame: pd.DataFrame,
        root: Path,
        char2idx: dict[str, int],
        label_col: str,
        img_w: int,
        clean_label,
        augment: bool = False,
    ):
        self.frame = frame.reset_index(drop=True)
        self.root = root
        self.char2idx = char2idx
        self.label_col = label_col
        self.img_w = img_w
        self.clean_label = clean_label
        self.augment = augment
        self.rng = random.Random(SEED)

    def __len__(self) -> int:
        return len(self.frame)

    def __getitem__(self, idx: int):
        row = self.frame.iloc[idx]
        img_path = self.root / row["image_path"]
        try:
            img = Image.open(img_path).convert("L")
        except Exception:
            img = Image.new("L", (self.img_w, IMG_H), color=255)

        if self.augment:
            img = _aug_pil(img, self.rng)

        img = img.resize((self.img_w, IMG_H), Image.BILINEAR)
        arr = np.asarray(img, dtype=np.float32) / 255.0
        arr = (arr - 0.5) / 0.5
        x = torch.from_numpy(arr).unsqueeze(0)

        if self.augment:
            x = _random_erase(x, self.rng)

        label = self.clean_label(row[self.label_col])
        y_ids = [self.char2idx[c] for c in label if c in self.char2idx]
        y = torch.tensor(y_ids, dtype=torch.long)
        return x, y, len(y_ids)  # dung len(y) thuc te, khong phai len(label) goc


def collate(batch):
    xs, ys, lens = zip(*batch)
    return torch.stack(xs), torch.cat(ys), torch.tensor(lens, dtype=torch.long)


# ─────────────────────────── Scheduler ───────────────────────────────────────

def _warmup_cosine_lambda(epoch: int, warmup: int, total: int, eta_min_ratio: float = 0.05) -> float:
    if epoch < warmup:
        return (epoch + 1) / max(warmup, 1)
    progress = (epoch - warmup) / max(total - warmup, 1)
    cosine = 0.5 * (1.0 + math.cos(math.pi * progress))
    return cosine * (1.0 - eta_min_ratio) + eta_min_ratio


# ─────────────────────────── Loss plot ───────────────────────────────────────

def _plot_loss(history: list[dict], out_path: Path, field: str) -> None:
    try:
        import matplotlib.pyplot as plt
    except ImportError:
        return
    df = pd.DataFrame(history)
    plt.figure(figsize=(8, 4))
    plt.plot(df["epoch"], df["train_loss"], label="train", marker="o", ms=3)
    plt.plot(df["epoch"], df["val_loss"], label="val", marker="o", ms=3)
    plt.title(f"CTC Loss — {field}")
    plt.xlabel("epoch")
    plt.ylabel("loss")
    plt.legend()
    plt.grid(alpha=0.3)
    plt.tight_layout()
    plt.savefig(out_path, dpi=120)
    plt.close()


# ─────────────────────────── Core train function ─────────────────────────────

def train_field(
    field: str,
    epochs: int,
    patience: int,
    *,
    data_dir: Path,
    models_dir: Path,
    log_dir: Path | None = None,
) -> dict:
    cfg = FIELD_CONFIG[field]
    manifest = data_dir / cfg["manifest"]
    if not manifest.is_file():
        raise FileNotFoundError(f"Thieu {manifest} — chay gen_receipt_dataset.py truoc")

    df = pd.read_csv(manifest)
    max_t = _ctc_timesteps(cfg["img_w"])
    label_lens = df[cfg["label_col"]].astype(str).str.len()
    too_long = label_lens > max_t
    if too_long.any():
        n_bad = int(too_long.sum())
        worst = df.loc[too_long, cfg["label_col"]].astype(str).str.len().max()
        print(f"  [{field}] CANH BAO: {n_bad}/{len(df)} mau co label dai hon T={max_t} (max={worst}) — tang img_w!")
        df = df[~too_long].reset_index(drop=True)
        print(f"  [{field}] Con lai {len(df)} mau sau khi loc")

    rng = random.Random(SEED)
    idx = list(range(len(df)))
    rng.shuffle(idx)
    n_val = max(1, int(len(df) * VAL_RATIO))
    tr_df = df.iloc[idx[n_val:]].reset_index(drop=True)
    va_df = df.iloc[idx[:n_val]].reset_index(drop=True)

    bs = _batch_size()
    tr_loader = DataLoader(
        OcrDataset(tr_df, data_dir, cfg["char2idx"], cfg["label_col"],
                   cfg["img_w"], cfg["clean_label"], augment=True),
        batch_size=bs, shuffle=True, collate_fn=collate,
        drop_last=(len(tr_df) >= bs * 2), num_workers=0,
    )
    va_loader = DataLoader(
        OcrDataset(va_df, data_dir, cfg["char2idx"], cfg["label_col"],
                   cfg["img_w"], cfg["clean_label"], augment=False),
        batch_size=bs, shuffle=False, collate_fn=collate,
        num_workers=0,
    )

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    cnn_ch = (64, 128, 256, 256)
    lstm_h, lstm_l = 256, 3
    model = ReceiptLineCRNN(
        img_h=IMG_H, img_w=cfg["img_w"],
        cnn_channels=cnn_ch,
        lstm_hidden=lstm_h, lstm_layers=lstm_l,
        num_classes=cfg["num_classes"],
        dropout=0.2,
    ).to(device)

    use_amp = device.type == "cuda"
    scaler = None
    if use_amp:
        try:
            scaler = torch.amp.GradScaler("cuda")
            _autocast = lambda: torch.amp.autocast("cuda")
        except (AttributeError, TypeError):
            scaler = torch.cuda.amp.GradScaler()
            _autocast = torch.cuda.amp.autocast
    else:
        _autocast = contextlib.nullcontext

    ctc = nn.CTCLoss(blank=0, zero_infinity=True)
    opt = optim.AdamW(model.parameters(), lr=5e-4, weight_decay=1e-4)
    warmup_ep = max(3, epochs // 15)
    sched = optim.lr_scheduler.LambdaLR(
        opt,
        lr_lambda=lambda ep: _warmup_cosine_lambda(ep, warmup_ep, epochs),
    )

    def run_epoch(loader: DataLoader, train: bool) -> float:
        model.train(train)
        total, n = 0.0, 0
        with contextlib.nullcontext() if train else torch.no_grad():
            for x, y_flat, y_lens in loader:
                x = x.to(device); y_flat = y_flat.to(device); y_lens = y_lens.to(device)
                if train:
                    opt.zero_grad()
                with _autocast():
                    logits = model(x)
                    log_probs = logits.log_softmax(2).permute(1, 0, 2)
                    T = logits.size(1)
                    in_lens = torch.full((x.size(0),), T, dtype=torch.long, device=device)
                    loss = ctc(log_probs, y_flat, in_lens, y_lens)
                if train:
                    if scaler is not None:
                        scaler.scale(loss).backward()
                        scaler.unscale_(opt)
                        nn.utils.clip_grad_norm_(model.parameters(), 1.0)
                        scaler.step(opt)
                        scaler.update()
                    else:
                        loss.backward()
                        nn.utils.clip_grad_norm_(model.parameters(), 1.0)
                        opt.step()
                total += loss.item() * x.size(0)
                n += x.size(0)
        return total / max(n, 1)

    best_val, best_state, no_imp = 999.0, None, 0
    history: list[dict] = []
    log_dir = log_dir or (models_dir / "ocr_logs")
    log_dir.mkdir(parents=True, exist_ok=True)

    for ep in range(1, epochs + 1):
        tr = run_epoch(tr_loader, True)
        va = run_epoch(va_loader, False)
        sched.step()
        history.append({"epoch": ep, "train_loss": round(tr, 6), "val_loss": round(va, 6)})
        if va < best_val - 1e-5 and va > 1e-6:
            best_val = va
            best_state = copy.deepcopy(model.state_dict())
            no_imp = 0
        else:
            no_imp += 1
        if ep % 10 == 0 or ep == 1 or ep == warmup_ep:
            lr_now = sched.get_last_lr()[0]
            print(f"  [{field}] ep {ep:3d}  train={tr:.4f}  val={va:.4f}  lr={lr_now:.2e}")
        if no_imp >= patience:
            print(f"  [{field}] early stop ep {ep}")
            break

    pd.DataFrame(history).to_csv(log_dir / f"{field}_epoch_log.csv", index=False)
    _plot_loss(history, log_dir / f"{field}_loss.png", field)

    if best_state:
        model.load_state_dict(best_state)
    model.eval()

    # Post-train eval on validation
    bundle = FieldOcrBundle(
        name=field,
        model=model,
        meta={"img_h": IMG_H, "img_w": cfg["img_w"]},
        char2idx=cfg["char2idx"],
        idx2char=cfg["idx2char"],
        device=device,
    )
    amount_col = "amount_vnd" if field == "amount" else None
    eval_result = evaluate_field_on_df(
        bundle, va_df, data_dir,
        label_col=cfg["label_col"],
        amount_col=amount_col,
    )
    pd.DataFrame(eval_result.predictions).to_csv(
        log_dir / f"{field}_predictions.csv", index=False, encoding="utf-8",
    )
    char_errors_to_dataframe(eval_result.char_error_counter).to_csv(
        log_dir / f"{field}_char_errors.csv", index=False, encoding="utf-8",
    )
    m = eval_result.to_metrics_dict()
    print(f"  [{field}] exact={m['exact_acc']:.2%}  CER={m['mean_cer']:.4f}  WER={m['mean_wer']:.4f}")

    # Save model + meta
    models_dir.mkdir(parents=True, exist_ok=True)
    prefix = cfg["prefix"]
    meta = {
        "architecture": "receipt_line_crnn",
        "architecture_version": ReceiptLineCRNN.ARCHITECTURE_VERSION,
        "field": field,
        "img_h": IMG_H,
        "img_w": cfg["img_w"],
        "cnn_channels": list(cnn_ch),
        "lstm_hidden": lstm_h,
        "lstm_layers": lstm_l,
        "num_classes": cfg["num_classes"],
        "dropout": 0.2,
        "val_ctc_loss": round(best_val, 6),
        "train_samples": len(tr_df),
        "val_samples": len(va_df),
        **m,
    }
    torch.save(model.state_dict(), models_dir / f"{prefix}_model.pt")
    (models_dir / f"{prefix}_meta.json").write_text(
        json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8",
    )
    # Alias amount → ocr_model.pt (tương thích cũ)
    if field == "amount":
        torch.save(model.state_dict(), models_dir / "ocr_model.pt")
        (models_dir / "ocr_meta.json").write_text(
            json.dumps({**meta, "architecture": "receipt_amount_crnn"}, indent=2, ensure_ascii=False),
            encoding="utf-8",
        )
    print(f"  [{field}] saved -> {models_dir / (prefix + '_model.pt')}")
    return meta


# ─────────────────────────── Compare table ───────────────────────────────────

def _save_compare_table(all_meta: list[dict], log_dir: Path) -> None:
    log_dir.mkdir(parents=True, exist_ok=True)
    rows = []
    for m in all_meta:
        rows.append({
            "field": m["field"],
            "val_ctc_loss": m.get("val_ctc_loss"),
            "exact_acc": m.get("exact_acc"),
            "mean_cer": m.get("mean_cer"),
            "mean_wer": m.get("mean_wer"),
            "mean_confidence": m.get("mean_confidence"),
            "amount_exact_acc": m.get("amount_exact_acc"),
            "train_samples": m.get("train_samples"),
            "val_samples": m.get("val_samples"),
        })
    df = pd.DataFrame(rows).set_index("field")
    df.to_csv(log_dir / "compare_models.csv", encoding="utf-8")
    (log_dir / "compare_models.json").write_text(
        json.dumps(rows, indent=2, ensure_ascii=False), encoding="utf-8",
    )
    print("\n=== BANG SO SANH 4 MODEL ===")
    print(df.to_string())


# ─────────────────────────── CLI ─────────────────────────────────────────────

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--epochs", type=int, default=60)
    ap.add_argument("--patience", type=int, default=15)
    ap.add_argument("--fields", type=str, default="amount,merchant,date,line")
    ap.add_argument("--gen-n", type=int, default=0, help="Sinh dataset neu > 0")
    ap.add_argument("--data-dir", type=str, default="")
    ap.add_argument("--models-dir", type=str, default="")
    ap.add_argument("--log-dir", type=str, default="")
    ap.add_argument(
        "--skip-if-exists",
        action="store_true",
        help="Bo qua field da co .pt + .meta.json trong models-dir",
    )
    args = ap.parse_args()

    data_dir = Path(args.data_dir) if args.data_dir else DATA_DIR
    models_dir = Path(args.models_dir) if args.models_dir else MODELS_DIR
    log_dir = Path(args.log_dir) if args.log_dir else models_dir / "ocr_logs"
    print(f"DATA_DIR   = {data_dir.resolve()}")
    print(f"MODELS_DIR = {models_dir.resolve()}")
    print(f"LOG_DIR    = {log_dir.resolve()}")

    if args.gen_n > 0 or not (data_dir / "manifest.csv").is_file():
        sys.path.insert(0, str(ROOT / "data"))
        from gen_receipt_dataset import generate  # noqa: PLC0415
        n = args.gen_n if args.gen_n > 0 else 8000
        print(f"Generating {n} synthetic bills...")
        generate(n, seed=SEED, out_dir=data_dir)

    all_meta: list[dict] = []
    for field in args.fields.split(","):
        field = field.strip()
        if field not in FIELD_CONFIG:
            print(f"Skip unknown field: {field}")
            continue
        if args.skip_if_exists and field_model_exists(models_dir, field):
            meta_path = models_dir / f"{FIELD_CONFIG[field]['prefix']}_meta.json"
            meta = json.loads(meta_path.read_text(encoding="utf-8"))
            print(f"Skip [{field}] — da co model tai {models_dir}")
            all_meta.append(meta)
            continue
        print(f"\n{'='*55}\nTraining [{field}]...\n{'='*55}")
        meta = train_field(
            field, args.epochs, args.patience,
            data_dir=data_dir, models_dir=models_dir, log_dir=log_dir,
        )
        all_meta.append(meta)

    if all_meta:
        _save_compare_table(all_meta, log_dir)
        print(f"\nLogs + plots -> {log_dir}")


if __name__ == "__main__":
    main()
