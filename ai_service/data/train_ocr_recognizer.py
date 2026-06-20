"""
Train 1 model OCR nhận dạng DÒNG CHỮ tổng quát — CRNN + CTC — TỪ ĐẦU (from scratch).

KHÔNG pretrain, KHÔNG finetune. Trọng số khởi tạo ngẫu nhiên, học hoàn toàn từ dữ
liệu synthetic sinh on-the-fly (data/gen_ocr_lines.py) — mặc định chỉ bill
chuyển khoản ngân hàng/ví (--bank-only).

Xuất artifact vào models/:
  ocr_reco_model.pt        state_dict
  ocr_reco_meta.json       cấu hình kiến trúc + metric val
  ocr_reco_charset.json    danh sách ký tự (blank=0, index 1..N)

Logs (log-dir):
  reco_epoch_log.csv, reco_loss.png, reco_predictions.csv, reco_char_errors.csv

Chạy (từ thư mục ai_service):
  python data/train_ocr_recognizer.py --epochs 24 --train-size 40000 \\
         --models-dir /content/receipt_models --log-dir /content/receipt_models/ocr_logs
"""

from __future__ import annotations

import argparse
import contextlib
import json
import math
import random
import sys
import time
from pathlib import Path

import numpy as np
import pandas as pd
import torch
import torch.nn as nn
import torch.optim as optim
from PIL import Image, ImageEnhance, ImageFilter
from torch.utils.data import DataLoader, Dataset

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "data"))

from app.ocr_charset import FULL_CHARSET  # noqa: E402
from app.ocr_eval import cer, exact_match, substitution_errors, wer  # noqa: E402
from app.ocr_net import ReceiptLineCRNN  # noqa: E402
from app.ocr_recognizer import (  # noqa: E402
    build_charset_maps,
    greedy_decode,
    preprocess_variable_width,
)
from gen_ocr_lines import render_line, sample_line  # noqa: E402

MODELS_DIR = ROOT / "models"

IMG_H = 48
MAX_W = 1024
# width_divisor = 8 → T = W // 8 (GẤP ĐÔI so với 16). Với dòng dài 40-60 ký tự,
# số timestep/ký tự ~2-3 → CTC đủ khe để căn ký tự & dấu tiếng Việt → hết nuốt chữ.
WIDTH_DIVISOR = 8
LSTM_HIDDEN = 384
LSTM_LAYERS = 3
SEED = 42

CHAR2IDX, IDX2CHAR = build_charset_maps(FULL_CHARSET)
NUM_CLASSES = len(FULL_CHARSET) + 1
MAX_LABEL = MAX_W // WIDTH_DIVISOR  # số ký tự tối đa CTC có thể căn (~128)


# ─────────────────────────── Dataset ─────────────────────────────────────────

def _encode_label(text: str) -> list[int]:
    ids = [CHAR2IDX[c] for c in text if c in CHAR2IDX]
    if len(ids) > MAX_LABEL:
        ids = ids[:MAX_LABEL]
    return ids


class SyntheticLineDataset(Dataset):
    """Sinh dòng chữ on-the-fly mỗi __getitem__ (vô hạn biến thể)."""

    def __init__(
        self,
        size: int,
        *,
        augment: bool = True,
        fixed: bool = False,
        seed: int = SEED,
        note_focus: float = 0.0,
        bank_only: bool = True,
    ):
        self.size = size
        self.augment = augment
        self.fixed = fixed       # True → val: cố định theo seed
        self.seed = seed
        self.note_focus = note_focus   # ép tỉ lệ ghi chú ngắn (finetune ghi chú)
        self.bank_only = bank_only

    def __len__(self) -> int:
        return self.size

    def _rng(self, idx: int) -> random.Random:
        if self.fixed:
            return random.Random(self.seed * 100003 + idx)
        return random.Random()   # train: ngẫu nhiên theo OS

    def __getitem__(self, idx: int):
        rng = self._rng(idx)
        for _ in range(4):
            text, kind = sample_line(
                rng, note_focus=self.note_focus, bank_only=self.bank_only,
            )
            ids = _encode_label(text)
            if text and ids:
                break
        else:
            text, ids = "0", _encode_label("0")
        img = render_line(text, rng, kind=kind, augment=self.augment)
        tensor, real_w = preprocess_variable_width(
            img, img_h=IMG_H, max_w=MAX_W, width_divisor=WIDTH_DIVISOR
        )
        return tensor.squeeze(0), real_w, torch.tensor(ids, dtype=torch.long), text


def _aug_real(img: Image.Image, rng: random.Random) -> Image.Image:
    """Augment NHẸ cho ảnh dòng thật (đã có nhiễu thật, chỉ thêm biến thể nhỏ)."""
    if rng.random() < 0.4:
        img = ImageEnhance.Brightness(img).enhance(rng.uniform(0.85, 1.15))
    if rng.random() < 0.4:
        img = ImageEnhance.Contrast(img).enhance(rng.uniform(0.85, 1.2))
    if rng.random() < 0.3:
        img = img.filter(ImageFilter.GaussianBlur(radius=rng.uniform(0.2, 0.7)))
    if rng.random() < 0.25:
        img = img.rotate(rng.uniform(-1.5, 1.5), expand=True, fillcolor=255, resample=Image.BILINEAR)
    if rng.random() < 0.3:
        arr = np.asarray(img, dtype=np.float32)
        arr += np.random.normal(0, rng.uniform(2, 8), arr.shape)
        img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    return img


class RealLineDataset(Dataset):
    """Dòng chữ THẬT (từ data_train) đã có nhãn text trong labels.csv."""

    def __init__(self, real_dir: Path, *, augment: bool = True, oversample: int = 1):
        self.root = Path(real_dir)
        csv = self.root / "labels.csv"
        if not csv.is_file():
            raise FileNotFoundError(f"Thieu {csv} — chay prepare_real_lines.py truoc")
        df = pd.read_csv(csv, dtype=str).fillna("")
        # chỉ giữ dòng có text (đã được rà/sửa) và ảnh tồn tại
        df = df[df["text"].astype(str).str.strip() != ""].reset_index(drop=True)
        keep = [i for i in range(len(df)) if (self.root / df.iloc[i]["image_path"]).is_file()]
        self.frame = df.iloc[keep].reset_index(drop=True)
        self.augment = augment
        self.oversample = max(1, int(oversample))

    def __len__(self) -> int:
        return len(self.frame) * self.oversample

    def __getitem__(self, idx: int):
        rng = random.Random(idx + int(time.time()) % 100000)
        row = self.frame.iloc[idx % len(self.frame)]
        try:
            img = Image.open(self.root / row["image_path"]).convert("L")
        except Exception:
            img = Image.new("L", (MAX_W, IMG_H), 255)
        if self.augment:
            img = _aug_real(img, rng)
        tensor, real_w = preprocess_variable_width(
            img, img_h=IMG_H, max_w=MAX_W, width_divisor=WIDTH_DIVISOR
        )
        text = str(row["text"]).strip()
        ids = _encode_label(text)
        if not ids:
            ids = _encode_label("0")
            text = "0"
        return tensor.squeeze(0), real_w, torch.tensor(ids, dtype=torch.long), text


class MixDataset(Dataset):
    """Trộn dòng synthetic (vô hạn) với dòng thật theo xác suất real_ratio."""

    def __init__(self, synth: Dataset, real: Dataset | None, real_ratio: float):
        self.synth = synth
        self.real = real if (real is not None and len(real) > 0) else None
        self.p = real_ratio if self.real is not None else 0.0

    def __len__(self) -> int:
        return len(self.synth)

    def __getitem__(self, idx: int):
        if self.real is not None and random.Random().random() < self.p:
            return self.real[random.Random().randrange(len(self.real))]
        return self.synth[idx]


def collate(batch):
    tensors, real_ws, labels, texts = zip(*batch)
    max_w = max(t.size(-1) for t in tensors)
    bs = len(tensors)
    x = torch.full((bs, 1, IMG_H, max_w), 1.0, dtype=torch.float32)
    for i, t in enumerate(tensors):
        x[i, :, :, : t.size(-1)] = t
    maxT = max_w // WIDTH_DIVISOR
    input_lengths = torch.tensor(
        [max(1, min(maxT, rw // WIDTH_DIVISOR)) for rw in real_ws], dtype=torch.long
    )
    target_lengths = torch.tensor([len(l) for l in labels], dtype=torch.long)
    targets = torch.cat(labels) if labels else torch.zeros(0, dtype=torch.long)
    return x, targets, input_lengths, target_lengths, list(texts)


# ─────────────────────────── Scheduler ───────────────────────────────────────

def _warmup_cosine(epoch: int, warmup: int, total: int, eta_min: float = 0.05) -> float:
    if epoch < warmup:
        return (epoch + 1) / max(warmup, 1)
    progress = (epoch - warmup) / max(total - warmup, 1)
    cosine = 0.5 * (1.0 + math.cos(math.pi * progress))
    return cosine * (1.0 - eta_min) + eta_min


# ─────────────────────────── Eval ────────────────────────────────────────────

@torch.no_grad()
def evaluate(model: nn.Module, loader: DataLoader, device: torch.device, max_batches: int | None = None):
    model.eval()
    cers, wers, exacts, confs = [], [], [], []
    preds: list[dict] = []
    err_counter: dict[str, int] = {}
    for bi, (x, _t, _il, _tl, texts) in enumerate(loader):
        if max_batches is not None and bi >= max_batches:
            break
        x = x.to(device)
        logits = model(x)                     # (B, T, C)
        probs = torch.softmax(logits, dim=-1)
        argmax = probs.argmax(dim=-1)
        for i in range(x.size(0)):
            ref = texts[i]
            hyp = greedy_decode(logits[i].cpu(), IDX2CHAR)
            nb = argmax[i] != 0
            conf = float(probs[i].max(dim=-1).values[nb].mean().item()) if bool(nb.any()) else 0.0
            c, w = cer(ref, hyp), wer(ref, hyp)
            cers.append(c); wers.append(w); confs.append(conf)
            exacts.append(1 if exact_match(ref, hyp) else 0)
            for a, b in substitution_errors(ref, hyp):
                key = f"{a or '∅'}->{b or '∅'}"
                err_counter[key] = err_counter.get(key, 0) + 1
            if len(preds) < 400:
                preds.append({"reference": ref, "prediction": hyp,
                              "cer": round(c, 4), "exact": bool(exacts[-1]),
                              "confidence": round(conf, 4)})
    n = max(len(cers), 1)
    metrics = {
        "exact_acc": sum(exacts) / n,
        "mean_cer": sum(cers) / n,
        "mean_wer": sum(wers) / n,
        "mean_confidence": sum(confs) / n,
        "n_samples": len(cers),
    }
    return metrics, preds, err_counter


def _plot_loss(history: list[dict], out_path: Path) -> None:
    try:
        import matplotlib.pyplot as plt
    except ImportError:
        return
    df = pd.DataFrame(history)
    fig, ax1 = plt.subplots(figsize=(8, 4))
    ax1.plot(df["epoch"], df["train_loss"], label="train_loss", marker="o", ms=3, color="tab:blue")
    ax1.plot(df["epoch"], df["val_loss"], label="val_loss", marker="o", ms=3, color="tab:orange")
    ax1.set_xlabel("epoch"); ax1.set_ylabel("CTC loss"); ax1.grid(alpha=0.3)
    ax2 = ax1.twinx()
    ax2.plot(df["epoch"], df["val_cer"], label="val_cer", marker="s", ms=3, color="tab:green")
    ax2.set_ylabel("val CER")
    lines1, lab1 = ax1.get_legend_handles_labels()
    lines2, lab2 = ax2.get_legend_handles_labels()
    ax1.legend(lines1 + lines2, lab1 + lab2, loc="upper right")
    plt.title("OCR recognizer (from scratch) — loss & CER")
    plt.tight_layout(); plt.savefig(out_path, dpi=120); plt.close()


# ─────────────────────────── Train ───────────────────────────────────────────

def train(
    *,
    epochs: int,
    train_size: int,
    val_size: int,
    batch_size: int,
    patience: int,
    lr: float,
    num_workers: int,
    models_dir: Path,
    log_dir: Path,
    dropout: float,
    real_dir: Path | None = None,
    real_ratio: float = 0.3,
    resume: bool = True,
    ckpt_dir: Path | None = None,
    max_minutes: float = 0.0,
    note_focus: float = 0.0,
    finetune: bool = False,
    bank_only: bool = True,
    from_scratch: bool = False,
    real_oversample: int = 25,
) -> dict:
    torch.manual_seed(SEED)
    random.seed(SEED)
    np.random.seed(SEED)
    t_start = time.monotonic()

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Device: {device}  |  num_classes={NUM_CLASSES}  charset={len(FULL_CHARSET)}")

    # Dữ liệu thật (tùy chọn) trộn vào synthetic
    real_ds = None
    if real_dir is not None and (Path(real_dir) / "labels.csv").is_file():
        try:
            real_ds = RealLineDataset(
                Path(real_dir), augment=True, oversample=real_oversample,
            )
            n_unique = len(real_ds.frame)
            print(
                f"Real lines: {n_unique} unique x oversample {real_ds.oversample} "
                f"= {len(real_ds)} slot/epoch | tron {real_ratio:.0%} batch"
            )
            if len(real_ds) == 0:
                print("  (labels.csv chua co dong nao co `text` -> bo qua real)")
                real_ds = None
        except Exception as e:
            print(f"  [real] bo qua: {e}")
            real_ds = None

    if note_focus > 0:
        print(f"NOTE_FOCUS = {note_focus:.0%} dong train la ghi chu ngan kieu that")
    if bank_only:
        print("BANK_ONLY = true — synthetic chi bill chuyen khoan/ngan hang/vi")
    synth_tr = SyntheticLineDataset(
        train_size, augment=True, fixed=False,
        note_focus=note_focus, bank_only=bank_only,
    )
    tr_dataset = MixDataset(synth_tr, real_ds, real_ratio)
    tr_loader = DataLoader(
        tr_dataset,
        batch_size=batch_size, shuffle=False, collate_fn=collate,
        num_workers=num_workers, drop_last=True, persistent_workers=num_workers > 0,
    )
    # Val: trộn 1 phần ghi chú để đo CER ghi chú (≤ 0.2 cho đại diện)
    va_loader = DataLoader(
        SyntheticLineDataset(
            val_size, augment=True, fixed=True,
            note_focus=min(0.2, note_focus), bank_only=bank_only,
        ),
        batch_size=batch_size, shuffle=False, collate_fn=collate,
        num_workers=num_workers, persistent_workers=num_workers > 0,
    )

    cnn_ch = (64, 128, 256, 256)
    lstm_h, lstm_l = LSTM_HIDDEN, LSTM_LAYERS
    model = ReceiptLineCRNN(
        img_h=IMG_H, img_w=320, cnn_channels=cnn_ch,
        lstm_hidden=lstm_h, lstm_layers=lstm_l,
        num_classes=NUM_CLASSES, dropout=dropout,
        width_divisor=WIDTH_DIVISOR,
    ).to(device)
    n_params = sum(p.numel() for p in model.parameters())
    print(f"Model params: {n_params/1e6:.2f}M")

    use_amp = device.type == "cuda"
    if use_amp:
        try:
            scaler = torch.amp.GradScaler("cuda")
            _autocast = lambda: torch.amp.autocast("cuda")
        except (AttributeError, TypeError):
            scaler = torch.cuda.amp.GradScaler()
            _autocast = torch.cuda.amp.autocast
    else:
        scaler = None
        _autocast = contextlib.nullcontext

    ctc = nn.CTCLoss(blank=0, zero_infinity=True)
    opt = optim.AdamW(model.parameters(), lr=lr, weight_decay=1e-4)
    warmup = max(2, epochs // 12)
    sched = optim.lr_scheduler.LambdaLR(opt, lr_lambda=lambda ep: _warmup_cosine(ep, warmup, epochs))

    log_dir.mkdir(parents=True, exist_ok=True)
    models_dir.mkdir(parents=True, exist_ok=True)
    ckpt_dir = Path(ckpt_dir) if ckpt_dir else models_dir
    ckpt_dir.mkdir(parents=True, exist_ok=True)
    ckpt_path = ckpt_dir / "ocr_reco_ckpt.pt"

    if from_scratch:
        resume = False
        finetune = False
        for stale in (
            ckpt_path,
            models_dir / "ocr_reco_model.pt",
            models_dir / "ocr_reco_meta.json",
            models_dir / "ocr_reco_charset.json",
        ):
            if stale.is_file():
                stale.unlink()
                print(f"FROM_SCRATCH: xoa {stale.name}")
        print("FROM_SCRATCH: khong resume, khong finetune, khong nap pretrained")

    best_cer, no_imp = 9.9, 0
    history: list[dict] = []
    start_epoch = 1

    # ── Resume / Finetune từ checkpoint ──
    # finetune=True: nạp TRỌNG SỐ model nhưng RESET lịch (epoch/optimizer/early-stop)
    #   → học được phân phối dữ liệu MỚI (vd. ghi chú chữ thường + d/m số đơn).
    # finetune=False (resume): tiếp tục đúng phiên cũ (Colab 2h20 chạy nhiều lần).
    finetune_active = False
    # Đã từng reset finetune chưa? (tránh reset lại khi chạy nhiều phiên Colab)
    already_finetuning = False
    if ckpt_path.is_file():
        try:
            already_finetuning = bool(
                torch.load(ckpt_path, map_location="cpu", weights_only=False)
                .get("finetune_active", False)
            )
        except Exception:
            already_finetuning = False

    src_ckpt = ckpt_path if ckpt_path.is_file() else (models_dir / "ocr_reco_model.pt")
    if finetune and not already_finetuning and src_ckpt.is_file():
        try:
            ck = torch.load(src_ckpt, map_location=device, weights_only=False)
            state = ck["model"] if isinstance(ck, dict) and "model" in ck else ck
            model.load_state_dict(state)
            finetune_active = True
            print(f"== FINETUNE: nap trong so tu {src_ckpt.name}, "
                  f"RESET lich train (epoch 1/{epochs}, optimizer/early-stop moi) ==")
        except Exception as e:
            print(f"[finetune] khong nap duoc trong so ({e}) -> train tu dau")
    elif resume and ckpt_path.is_file():
        try:
            ck = torch.load(ckpt_path, map_location=device, weights_only=False)
            model.load_state_dict(ck["model"])
            opt.load_state_dict(ck["opt"])
            sched.load_state_dict(ck["sched"])
            if scaler is not None and ck.get("scaler"):
                scaler.load_state_dict(ck["scaler"])
            best_cer = ck.get("best_cer", 9.9)
            no_imp = ck.get("no_imp", 0)
            history = ck.get("history", [])
            start_epoch = int(ck.get("epoch", 0)) + 1
            finetune_active = bool(ck.get("finetune_active", False))
            try:
                random.setstate(ck["py_rng"]); np.random.set_state(ck["np_rng"])
                torch.set_rng_state(ck["torch_rng"])
            except Exception:
                pass
            print(f"== RESUME tu checkpoint: epoch {start_epoch}/{epochs}, "
                  f"best_cer={best_cer:.4f}{' [finetune]' if finetune_active else ''} ==")
        except Exception as e:
            print(f"[resume] khong doc duoc checkpoint ({e}) -> train tu dau")

    def _save_ckpt(ep: int) -> None:
        torch.save({
            "epoch": ep, "model": model.state_dict(), "opt": opt.state_dict(),
            "sched": sched.state_dict(),
            "scaler": scaler.state_dict() if scaler is not None else None,
            "best_cer": best_cer, "no_imp": no_imp, "history": history,
            "finetune_active": finetune_active,
            "config": {"width_divisor": WIDTH_DIVISOR, "img_h": IMG_H, "max_w": MAX_W,
                       "lstm_hidden": LSTM_HIDDEN, "lstm_layers": LSTM_LAYERS,
                       "num_classes": NUM_CLASSES, "epochs": epochs},
            "py_rng": random.getstate(), "np_rng": np.random.get_state(),
            "torch_rng": torch.get_rng_state(),
        }, ckpt_path)

    def _save_artifacts(meta_extra: dict) -> None:
        """Lưu model deploy được (ocr_reco_*) — dùng được kể cả khi train dang dở."""
        torch.save(model.state_dict(), models_dir / "ocr_reco_model.pt")
        meta = {
            "architecture": "receipt_line_crnn",
            "architecture_version": ReceiptLineCRNN.ARCHITECTURE_VERSION,
            "from_scratch": True, "pretrained_used": False,
            "img_h": IMG_H, "img_w": 320, "max_w": MAX_W, "width_divisor": WIDTH_DIVISOR,
            "cnn_channels": list(cnn_ch), "lstm_hidden": lstm_h, "lstm_layers": lstm_l,
            "dropout": dropout, "num_classes": NUM_CLASSES, "charset_size": len(FULL_CHARSET),
            "params_million": round(n_params / 1e6, 3),
            **meta_extra,
        }
        (models_dir / "ocr_reco_meta.json").write_text(
            json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8")
        (models_dir / "ocr_reco_charset.json").write_text(
            json.dumps(FULL_CHARSET, ensure_ascii=False), encoding="utf-8")

    if start_epoch > epochs:
        print("Da train du epochs — khong con gi de lam.")

    stopped_early_time = False
    for ep in range(start_epoch, epochs + 1):
        model.train()
        running, seen = 0.0, 0
        for x, targets, in_lens, tgt_lens, _texts in tr_loader:
            x = x.to(device); targets = targets.to(device)
            in_lens = in_lens.to(device); tgt_lens = tgt_lens.to(device)
            opt.zero_grad()
            with _autocast():
                logits = model(x)                       # (B,T,C)
                log_probs = logits.log_softmax(2).permute(1, 0, 2)  # (T,B,C)
                loss = ctc(log_probs, targets, in_lens, tgt_lens)
            if scaler is not None:
                scaler.scale(loss).backward()
                scaler.unscale_(opt)
                nn.utils.clip_grad_norm_(model.parameters(), 5.0)
                scaler.step(opt); scaler.update()
            else:
                loss.backward()
                nn.utils.clip_grad_norm_(model.parameters(), 5.0)
                opt.step()
            running += loss.item() * x.size(0); seen += x.size(0)
        sched.step()
        train_loss = running / max(seen, 1)

        # Val loss + metrics
        model.eval()
        vloss, vseen = 0.0, 0
        with torch.no_grad():
            for x, targets, in_lens, tgt_lens, _texts in va_loader:
                x = x.to(device); targets = targets.to(device)
                in_lens = in_lens.to(device); tgt_lens = tgt_lens.to(device)
                logits = model(x)
                log_probs = logits.log_softmax(2).permute(1, 0, 2)
                vloss += ctc(log_probs, targets, in_lens, tgt_lens).item() * x.size(0)
                vseen += x.size(0)
        val_loss = vloss / max(vseen, 1)
        metrics, _, _ = evaluate(model, va_loader, device, max_batches=max(1, 64 // 1))

        history.append({
            "epoch": ep, "train_loss": round(train_loss, 5), "val_loss": round(val_loss, 5),
            "val_cer": round(metrics["mean_cer"], 5), "val_exact": round(metrics["exact_acc"], 5),
            "lr": round(sched.get_last_lr()[0], 7),
        })
        print(f"  ep {ep:3d}  train={train_loss:.4f}  val={val_loss:.4f}  "
              f"CER={metrics['mean_cer']:.4f}  exact={metrics['exact_acc']:.3f}  "
              f"lr={sched.get_last_lr()[0]:.2e}")

        improved = metrics["mean_cer"] < best_cer - 1e-4
        if improved:
            best_cer = metrics["mean_cer"]
            no_imp = 0
            # Lưu ngay model TỐT NHẤT (deploy được kể cả khi phiên bị ngắt)
            _save_artifacts({
                "epochs_run": ep, "best_val_cer": round(best_cer, 5),
                "val_exact_acc": round(metrics["exact_acc"], 5),
                "val_mean_cer": round(metrics["mean_cer"], 5),
                "val_mean_wer": round(metrics["mean_wer"], 5),
                "train_size_per_epoch": train_size, "val_size": val_size,
                "batch_size": batch_size, "real_mixed": real_ds is not None,
                "status": "in_progress",
            })
        else:
            no_imp += 1

        # Checkpoint sau MỖI epoch (để resume phiên sau)
        _save_ckpt(ep)

        elapsed_min = (time.monotonic() - t_start) / 60.0
        if no_imp >= patience:
            print(f"  early stop ep {ep} (best CER={best_cer:.4f})")
            break
        if max_minutes and elapsed_min >= max_minutes and ep < epochs:
            print(f"\n== HET NGAN SACH THOI GIAN ({elapsed_min:.1f}>{max_minutes} phut) "
                  f"sau epoch {ep}/{epochs}. Da luu checkpoint. ==")
            print("== CHAY LAI CELL TRAIN de tiep tuc (se resume tu epoch %d). ==" % (ep + 1))
            stopped_early_time = True
            break

    # Nạp lại model TỐT NHẤT đã lưu (ocr_reco_model.pt) để eval/đánh giá cuối
    best_pt = models_dir / "ocr_reco_model.pt"
    if best_pt.is_file():
        try:
            sd = torch.load(best_pt, map_location=device, weights_only=True)
            model.load_state_dict(sd)
        except Exception:
            pass
    model.eval()

    # Eval cuối cùng trên toàn bộ val
    final_metrics, preds, err_counter = evaluate(model, va_loader, device)
    pd.DataFrame(history).to_csv(log_dir / "reco_epoch_log.csv", index=False)
    _plot_loss(history, log_dir / "reco_loss.png")
    pd.DataFrame(preds).to_csv(log_dir / "reco_predictions.csv", index=False, encoding="utf-8")
    err_rows = sorted(err_counter.items(), key=lambda kv: kv[1], reverse=True)[:30]
    pd.DataFrame([{"error": k, "count": v} for k, v in err_rows]).to_csv(
        log_dir / "reco_char_errors.csv", index=False, encoding="utf-8")

    meta = {
        "architecture": "receipt_line_crnn",
        "architecture_version": ReceiptLineCRNN.ARCHITECTURE_VERSION,
        "from_scratch": True,
        "pretrained_used": False,
        "img_h": IMG_H,
        "img_w": 320,
        "max_w": MAX_W,
        "width_divisor": WIDTH_DIVISOR,
        "cnn_channels": list(cnn_ch),
        "lstm_hidden": lstm_h,
        "lstm_layers": lstm_l,
        "dropout": dropout,
        "num_classes": NUM_CLASSES,
        "charset_size": len(FULL_CHARSET),
        "params_million": round(n_params / 1e6, 3),
        "epochs_run": len(history),
        "best_val_cer": round(best_cer, 5),
        "val_exact_acc": round(final_metrics["exact_acc"], 5),
        "val_mean_cer": round(final_metrics["mean_cer"], 5),
        "val_mean_wer": round(final_metrics["mean_wer"], 5),
        "val_mean_confidence": round(final_metrics["mean_confidence"], 5),
        "train_size_per_epoch": train_size,
        "val_size": val_size,
        "batch_size": batch_size,
    }
    torch.save(model.state_dict(), models_dir / "ocr_reco_model.pt")
    (models_dir / "ocr_reco_meta.json").write_text(
        json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8")
    (models_dir / "ocr_reco_charset.json").write_text(
        json.dumps(FULL_CHARSET, ensure_ascii=False), encoding="utf-8")

    print("\n=== KET QUA (val) ===")
    print(f"  exact_acc = {final_metrics['exact_acc']:.4f}")
    print(f"  mean_CER  = {final_metrics['mean_cer']:.4f}")
    print(f"  mean_WER  = {final_metrics['mean_wer']:.4f}")
    print(f"  saved -> {models_dir / 'ocr_reco_model.pt'}")
    return meta


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--epochs", type=int, default=28)
    ap.add_argument("--train-size", type=int, default=80000, help="So mau sinh moi epoch")
    ap.add_argument("--val-size", type=int, default=3000)
    ap.add_argument("--batch-size", type=int, default=0, help="0 = auto (48 GPU / 16 CPU)")
    ap.add_argument("--patience", type=int, default=7)
    ap.add_argument("--lr", type=float, default=6e-4)
    ap.add_argument("--dropout", type=float, default=0.25)
    ap.add_argument("--num-workers", type=int, default=4)
    ap.add_argument("--models-dir", type=str, default="")
    ap.add_argument("--log-dir", type=str, default="")
    ap.add_argument("--ckpt-dir", type=str, default="",
                    help="Noi luu checkpoint resume (nen tro vao Drive de khong mat)")
    ap.add_argument("--real-dir", type=str, default="",
                    help="Thu muc real_lines (co labels.csv) de tron dong that vao train")
    ap.add_argument("--real-ratio", type=float, default=0.35,
                    help="Ti le sample lay tu dong that moi batch (0..1)")
    ap.add_argument("--max-minutes", type=float, default=0.0,
                    help="Dung sau epoch khi vuot nguong phut (Colab 2h20 -> dat ~130). Resume bang chay lai.")
    ap.add_argument("--note-focus", type=float, default=0.30,
                    help="Ti le dong train la ghi chu ngan kieu that (0..1)")
    ap.add_argument("--no-resume", action="store_true", help="Khong resume tu checkpoint")
    ap.add_argument("--finetune", action="store_true",
                    help="Nap trong so model cu nhung RESET lich train (epoch/early-stop) "
                         "de hoc du lieu MOI (vd. ghi chu d/m so don). Dung khi model da early-stop.")
    ap.add_argument(
        "--bank-only",
        action="store_true",
        default=True,
        help="Synthetic chi bill chuyen khoan/ngan hang/vi (train + val). Mac dinh: bat",
    )
    ap.add_argument(
        "--no-bank-only",
        action="store_true",
        help="Tat bank-only — sinh them dong POS/hoa don (khong khuyen nghi)",
    )
    ap.add_argument(
        "--from-scratch",
        action="store_true",
        help="Train moi tu random weights: khong resume/finetune, xoa checkpoint cu",
    )
    ap.add_argument(
        "--real-oversample",
        type=int,
        default=25,
        help="Nhan doi dong thật co nhan (95 dong -> 95x oversample slot/epoch)",
    )
    args = ap.parse_args()

    # Model lớn hơn (LSTM 384) + T gấp đôi → batch 48 an toàn cho T4 16GB
    bs = args.batch_size or (48 if torch.cuda.is_available() else 16)
    models_dir = Path(args.models_dir) if args.models_dir else MODELS_DIR
    log_dir = Path(args.log_dir) if args.log_dir else models_dir / "ocr_logs"
    ckpt_dir = Path(args.ckpt_dir) if args.ckpt_dir else models_dir
    real_dir = Path(args.real_dir) if args.real_dir else None
    print(f"MODELS_DIR = {models_dir.resolve()}")
    print(f"LOG_DIR    = {log_dir.resolve()}")
    print(f"CKPT_DIR   = {ckpt_dir.resolve()}")
    if real_dir:
        print(f"REAL_DIR   = {real_dir.resolve()}  (ratio={args.real_ratio})")
    if args.max_minutes:
        print(f"MAX_MINUTES= {args.max_minutes} (se dung + luu checkpoint khi vuot)")

    train(
        epochs=args.epochs, train_size=args.train_size, val_size=args.val_size,
        batch_size=bs, patience=args.patience, lr=args.lr,
        num_workers=args.num_workers, models_dir=models_dir, log_dir=log_dir,
        dropout=args.dropout, real_dir=real_dir, real_ratio=args.real_ratio,
        resume=not args.no_resume, ckpt_dir=ckpt_dir, max_minutes=args.max_minutes,
        note_focus=args.note_focus, finetune=args.finetune,
        bank_only=not args.no_bank_only,
        from_scratch=args.from_scratch,
        real_oversample=args.real_oversample,
    )


if __name__ == "__main__":
    main()
