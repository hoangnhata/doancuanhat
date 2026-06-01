"""
Huấn luyện from-scratch — dùng trong notebook / CLI.
"""
from __future__ import annotations

import copy
import json
import os
import random
import re
import time
from collections import Counter
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional

try:
    from tqdm.auto import tqdm
except ImportError:
    def tqdm(it, **kwargs):  # type: ignore[misc]
        return it

import numpy as np
import pandas as pd
import torch
import torch.nn as nn
import torch.optim as optim
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
)
from sklearn.model_selection import train_test_split
from torch.utils.data import DataLoader, Dataset, WeightedRandomSampler

from .classify_net import CharCNNBiLSTMAttn
from .text_preprocess import (
    DEFAULT_PREPROCESS,
    PreprocessConfig,
    build_vocab,
    encode_text,
    preprocess_text,
    save_preprocess_config,
    strip_vietnamese_accents,
)
from .val_hard_samples import VAL_HARD_SAMPLES

ALL_CATEGORIES = [
    "Ăn uống", "Di chuyển", "Mua sắm", "Nhà ở", "Hóa đơn",
    "Giải trí", "Du lịch", "Giáo dục", "Sức khỏe", "Gia đình",
    "Thú cưng", "Quà tặng", "Từ thiện", "Khác",
    "Lương", "Thưởng", "Freelance", "Đầu tư", "Bán hàng", "Thu nhập khác",
]

NOISY_PREFIX = ["ờm ", "à ", "uh ", "kiểu ", "hình như "]
NOISY_SUFFIX = [" rồi", " haiz", " vcl", " nhỉ", " :("]
EMOJI_BY_LABEL = {
    "Ăn uống": "🍜",
    "Di chuyển": "🚗",
    "Mua sắm": "🛍️",
    "Giải trí": "🎬",
}

# Augmentation viết tắt hai chiều (train only)
ABB_AUG_PAIRS: list[tuple[str, str]] = [
    ("cafe", "cf"),
    ("cà phê", "cf"),
    ("chuyen khoan", "ck"),
    ("chuyển khoản", "ck"),
    ("dien thoai", "dt"),
    ("điện thoại", "dt"),
    ("taxi", "tx"),
    ("tien tro", "tro"),
    ("tiền trọ", "tro"),
    ("vietcombank", "vcb"),
    ("mbbank", "mb"),
    ("triệu", "tr"),
    ("trieu", "tr"),
    ("freelance", "fl"),
    ("đầu tư", "dau tu"),
    ("lãi", "lai"),
    ("grab food", "grab"),
]
_SLANG_PREFIX = ["ờm ", "à ", "uh ", "kiểu ", "hình như ", "tí ", "hơi "]
_SLANG_SUFFIX = [" rồi", " haiz", " vcl", " nhỉ", " :(", " á", " đấy", " luôn"]

_RE_K_AUG = re.compile(r"(\d{1,4})\s*k\b", re.IGNORECASE)
_RE_TR_AUG = re.compile(r"(\d{1,2})\s*tr\b", re.IGNORECASE)
_RE_M_AUG = re.compile(r"(\d{1,2})\s*m\b", re.IGNORECASE)

# Sai dấu nhẹ (train only)
_TONE_SWAPS = [("ă", "a"), ("â", "a"), ("đ", "d"), ("ơ", "o"), ("ư", "u")]


class FocalLoss(nn.Module):
    def __init__(
        self,
        weight: Optional[torch.Tensor] = None,
        gamma: float = 2.0,
        label_smoothing: float = 0.0,
    ):
        super().__init__()
        self.gamma = gamma
        self.weight = weight
        self.label_smoothing = label_smoothing

    def forward(self, logits: torch.Tensor, targets: torch.Tensor) -> torch.Tensor:
        ce = nn.functional.cross_entropy(
            logits,
            targets,
            weight=self.weight,
            label_smoothing=self.label_smoothing,
            reduction="none",
        )
        pt = torch.exp(-ce)
        return (((1 - pt) ** self.gamma) * ce).mean()


@dataclass
class TrainConfig:
    csv_path: Path
    save_dir: Path
    embed_dim: int = 96
    num_filters: int = 64
    kernel_sizes: tuple[int, ...] = (2, 3, 4, 5, 6)
    lstm_hidden: int = 128
    max_len: int = 128
    dropout: float = 0.35
    batch_size: int = 64
    epochs: int = 80
    patience: int = 12
    lr: float = 3e-4
    weight_decay: float = 1e-4
    label_smoothing: float = 0.05
    val_ratio: float = 0.12
    aug_copies: int = 3
    confidence_threshold: float = 0.45
    early_stop_metric: str = "hard_macro_f1"  # hard_macro_f1 | val_acc
    use_focal_loss: bool = False
    focal_gamma: float = 2.0
    seed: int = 42
    use_class_weights: bool = True
    use_amp: bool = True
    num_workers: int = 0
    pin_memory: bool = True
    require_cuda: bool = False
    log_interval: int = 1


def setup_torch_runtime(*, require_cuda: bool = False) -> torch.device:
    """Colab: bật GPU (T4). Tránh torch.compile/dynamo lỗi FUSE Drive."""
    os.environ.setdefault("TORCHDYNAMO_DISABLE", "1")
    os.environ.setdefault("TORCH_COMPILE_DISABLE", "1")
    if torch.cuda.is_available():
        torch.backends.cudnn.benchmark = True
        dev = torch.device("cuda")
        _safe_print(f"GPU: {torch.cuda.get_device_name(0)}")
    else:
        dev = torch.device("cpu")
        if require_cuda:
            raise RuntimeError(
                "Không có GPU. Colab: menu Runtime → Change runtime type → T4 GPU, "
                "rồi Restart session và chạy lại CELL 0."
            )
        _safe_print("WARNING: CPU — train rất chậm (~giờ). Nên bật GPU trên Colab.")
    return dev


def colab_train_config(csv_path: Path, save_dir: Path) -> TrainConfig:
    """Cấu hình tối ưu cho Colab T4 (~15–25 phút / 80 epoch)."""
    return TrainConfig(
        csv_path=csv_path,
        save_dir=save_dir,
        batch_size=64,
        epochs=80,
        patience=12,
        aug_copies=3,
        confidence_threshold=0.45,
        use_amp=True,
        num_workers=0,  # Colab: 2 workers đôi khi treo; pin_memory đủ cho T4
        pin_memory=True,
        require_cuda=True,
        log_interval=1,
    )


def _safe_print(msg: str) -> None:
    try:
        print(msg)
    except UnicodeEncodeError:
        print(msg.encode("ascii", errors="replace").decode("ascii"))


def set_seed(seed: int) -> None:
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(seed)


def _encode_texts_tensor(
    texts: list[str],
    vocab: dict[str, int],
    max_len: int,
    preprocess_cfg: PreprocessConfig,
    pad_idx: int,
    unk_idx: int,
    desc: str = "encode",
) -> torch.Tensor:
    rows = [
        encode_text(t, vocab, max_len, preprocess_cfg, pad_idx, unk_idx)
        for t in tqdm(texts, desc=desc, leave=False)
    ]
    return torch.tensor(rows, dtype=torch.long)


class ExpenseDataset(Dataset):
    def __init__(
        self,
        texts: list[str],
        labels: list[int],
        vocab: dict[str, int],
        max_len: int,
        cfg: PreprocessConfig,
        *,
        desc: str = "encode",
    ):
        self.cfg = cfg
        self.max_len = max_len
        self.vocab = vocab
        self.pad_idx = vocab["<PAD>"]
        self.unk_idx = vocab["<UNK>"]
        self.x = _encode_texts_tensor(
            texts, vocab, max_len, cfg, self.pad_idx, self.unk_idx, desc=desc
        )
        self.y = torch.tensor(labels, dtype=torch.long)

    def __len__(self) -> int:
        return len(self.y)

    def __getitem__(self, idx: int) -> tuple[torch.Tensor, torch.Tensor]:
        return self.x[idx], self.y[idx]


def _vary_money_raw(text: str, rng: random.Random) -> str:
    """Biến thể tiền trên raw text (trước preprocess)."""
    t = text

    def repl_k(m: re.Match) -> str:
        n = m.group(1)
        return rng.choice([
            f"{n}k", f"{n}K", f"{n}kđ", f"{n}k vnd",
            f"{int(n) * 1000:,}".replace(",", "."),
            f"{int(n) * 1000:,}".replace(",", ","),
            f"{int(n) * 1000}",
            f"{n} nghìn", f"{n} ngàn", f"{n} nghin",
        ])

    def repl_tr(m: re.Match) -> str:
        n = m.group(1)
        return rng.choice([
            f"{n}tr", f"{n}TR", f"{n} triệu", f"{n} trieu",
            f"{int(n) * 1_000_000:,}".replace(",", "."),
            f"{int(n) * 1_000_000}",
        ])

    if _RE_K_AUG.search(t) and rng.random() < 0.4:
        t = _RE_K_AUG.sub(repl_k, t, count=1)
    elif _RE_TR_AUG.search(t) and rng.random() < 0.35:
        t = _RE_TR_AUG.sub(repl_tr, t, count=1)
    elif _RE_M_AUG.search(t) and rng.random() < 0.2:
        m = _RE_M_AUG.search(t)
        if m:
            n = int(m.group(1))
            t = _RE_M_AUG.sub(
                rng.choice([f"{n} triệu", f"{n * 1_000_000}", f"{n}tr"]),
                t,
                count=1,
            )
    return t


def _vary_tone_raw(text: str, rng: random.Random) -> str:
    if rng.random() > 0.12:
        return text
    chars = list(text)
    for i, ch in enumerate(chars):
        for a, b in _TONE_SWAPS:
            if ch == a and rng.random() < 0.15:
                chars[i] = b
                break
    return "".join(chars)


def _vary_abbrev_raw(text: str, rng: random.Random) -> str:
    t = f" {text.lower()} "
    for a, b in ABB_AUG_PAIRS:
        if rng.random() < 0.2 and f" {a} " in t:
            t = t.replace(f" {a} ", f" {b} ", 1)
        elif rng.random() < 0.2 and f" {b} " in t:
            t = t.replace(f" {b} ", f" {a} ", 1)
    return t.strip()


def augment_train_text(text: str, label: str, rng: random.Random) -> str:
    """Augmentation chỉ train — preprocess đúng một lần ở cuối."""
    t = text
    if rng.random() < 0.38:
        t = strip_vietnamese_accents(t)
    if rng.random() < 0.12:
        t = _vary_tone_raw(t, rng)
    if rng.random() < 0.25:
        t = t.lower()
    if rng.random() < 0.3:
        t = _vary_money_raw(t, rng)
    if rng.random() < 0.25:
        t = _vary_abbrev_raw(t, rng)
    if rng.random() < 0.2 and len(t) > 5:
        chars = list(t)
        i = rng.randrange(len(chars))
        del chars[i]
        t = "".join(chars)
    if rng.random() < 0.15 and len(t) > 4:
        chars = list(t)
        i = rng.randrange(len(chars) - 1)
        chars[i], chars[i + 1] = chars[i + 1], chars[i]
        t = "".join(chars)
    if rng.random() < 0.15:
        t = rng.choice(_SLANG_PREFIX + NOISY_PREFIX) + t
    if rng.random() < 0.15:
        t = t + rng.choice(_SLANG_SUFFIX + NOISY_SUFFIX)
    if rng.random() < 0.1:
        t = re.sub(r"\b(ăn|an)\b", rng.choice(["an", "ăn", "Ăn"]), t, count=1, flags=re.I)
    if rng.random() < 0.08:
        t = t.replace("  ", " ")
    if rng.random() < 0.1:
        em = EMOJI_BY_LABEL.get(label, "")
        if em:
            t = t + " " + em
    if rng.random() < 0.1:
        t = t.upper() if rng.random() < 0.5 else t
    if rng.random() < 0.08:
        t = re.sub(r"([,.!?])+", lambda m: m.group(1) * rng.randint(1, 2), t, count=1)
    return preprocess_text(t)


def load_dataframe(csv_path: Path) -> pd.DataFrame:
    df = pd.read_csv(csv_path, encoding="utf-8")
    df["text"] = df["text"].astype(str).str.strip()
    df["label"] = df["label"].astype(str).str.strip()
    df = df[df["text"].str.len() > 0]
    df = df[df["label"].isin(ALL_CATEGORIES)]
    df = df.drop_duplicates(subset=["text", "label"])
    conflicts = df.groupby("text")["label"].nunique()
    bad = conflicts[conflicts > 1].index
    if len(bad):
        df = df[~df["text"].isin(bad)]
    return df.reset_index(drop=True)


def build_label_maps(df: pd.DataFrame) -> tuple[dict[str, int], dict[int, str]]:
    present = set(df["label"].unique())
    missing = present - set(ALL_CATEGORIES)
    if missing:
        raise ValueError(f"Nhãn không hợp lệ trong CSV: {missing}")
    l2i = {lbl: i for i, lbl in enumerate(ALL_CATEGORIES)}
    i2l = {i: lbl for lbl, i in l2i.items()}
    return l2i, i2l


def evaluate(
    model: nn.Module,
    loader: DataLoader,
    device: torch.device,
    num_classes: int,
    class_names: list[str],
) -> dict[str, Any]:
    model.eval()
    preds, trues = [], []
    with torch.no_grad():
        for xb, yb in loader:
            xb = xb.to(device)
            logits = model(xb)
            preds.extend(logits.argmax(-1).cpu().tolist())
            trues.extend(yb.tolist())

    acc = accuracy_score(trues, preds)
    macro_f1 = f1_score(trues, preds, average="macro", zero_division=0)
    weighted_f1 = f1_score(trues, preds, average="weighted", zero_division=0)
    prec = precision_score(trues, preds, average="macro", zero_division=0)
    rec = recall_score(trues, preds, average="macro", zero_division=0)
    label_ids = list(range(num_classes))
    cm = confusion_matrix(trues, preds, labels=label_ids)
    per_class_acc: dict[str, float] = {}
    for i, name in enumerate(class_names):
        mask = [t == i for t in trues]
        if any(mask):
            correct = sum(1 for t, p in zip(trues, preds) if t == i and p == i)
            per_class_acc[name] = correct / sum(mask)
        else:
            per_class_acc[name] = 0.0

    return {
        "accuracy": float(acc),
        "macro_f1": float(macro_f1),
        "weighted_f1": float(weighted_f1),
        "precision_macro": float(prec),
        "recall_macro": float(rec),
        "confusion_matrix": cm.tolist(),
        "classification_report": classification_report(
            trues,
            preds,
            labels=label_ids,
            target_names=class_names,
            zero_division=0,
        ),
        "per_class_accuracy": per_class_acc,
        "predictions": preds,
        "true": trues,
    }


def _top_confused_pairs(
    cm: list[list[int]],
    class_names: list[str],
    top_n: int = 15,
) -> list[dict[str, Any]]:
    pairs: list[tuple[int, int, int]] = []
    for i in range(len(cm)):
        for j in range(len(cm[i])):
            if i != j and cm[i][j] > 0:
                pairs.append((cm[i][j], i, j))
    pairs.sort(reverse=True)
    out = []
    for count, i, j in pairs[:top_n]:
        out.append({
            "true": class_names[i],
            "predicted": class_names[j],
            "count": count,
        })
    return out


def _confidence_stats(probs_list: list[list[float]]) -> dict[str, float]:
    if not probs_list:
        return {}
    max_probs = [max(p) for p in probs_list]
    return {
        "mean_max_confidence": float(np.mean(max_probs)),
        "median_max_confidence": float(np.median(max_probs)),
        "min_max_confidence": float(min(max_probs)),
        "pct_below_045": float(sum(1 for x in max_probs if x < 0.45) / len(max_probs)),
    }


def _collect_errors(
    texts: list[str],
    trues: list[int],
    preds: list[int],
    probs_list: list[list[float]],
    class_names: list[str],
    max_items: int = 40,
) -> list[dict[str, Any]]:
    errors = []
    for t, yt, yp, pr in zip(texts, trues, preds, probs_list):
        if yt != yp:
            errors.append({
                "text": t,
                "true": class_names[yt],
                "predicted": class_names[yp],
                "confidence": float(max(pr)),
            })
    errors.sort(key=lambda x: x["confidence"])
    return errors[:max_items]


def evaluate_detailed(
    model: nn.Module,
    texts: list[str],
    labels: list[int],
    vocab: dict[str, int],
    max_len: int,
    preprocess_cfg: PreprocessConfig,
    device: torch.device,
    class_names: list[str],
) -> dict[str, Any]:
    ds = ExpenseDataset(texts, labels, vocab, max_len, preprocess_cfg)
    dl = DataLoader(ds, batch_size=64, shuffle=False)
    base = evaluate(model, dl, device, len(class_names), class_names)
    probs_all: list[list[float]] = []
    model.eval()
    with torch.no_grad():
        for xb, _ in dl:
            xb = xb.to(device)
            logits = model(xb)
            probs = torch.softmax(logits, dim=-1).cpu().tolist()
            probs_all.extend(probs)

    base["top_confused_pairs"] = _top_confused_pairs(
        base["confusion_matrix"], class_names
    )
    base["confidence_stats"] = _confidence_stats(probs_all)
    base["errors"] = _collect_errors(
        texts, base["true"], base["predictions"], probs_all, class_names
    )
    low_conf = []
    for t, pr, yt in zip(texts, probs_all, base["true"]):
        conf = max(pr)
        if conf < 0.45:
            low_conf.append({
                "text": t,
                "true": class_names[yt],
                "predicted": class_names[int(np.argmax(pr))],
                "confidence": float(conf),
            })
    base["low_confidence_samples"] = low_conf[:30]
    wrong_high = [
        e for e in base["errors"]
        if e.get("confidence", 0) >= 0.5
    ]
    wrong_high.sort(key=lambda x: -x["confidence"])
    base["hardest_mistakes"] = wrong_high[:20]
    return base


def _make_dataloader(
    ds: Dataset,
    cfg: TrainConfig,
    device: torch.device,
    *,
    shuffle: bool = False,
    sampler: Optional[WeightedRandomSampler] = None,
) -> DataLoader:
    pin = cfg.pin_memory and device.type == "cuda"
    kwargs: dict[str, Any] = {
        "batch_size": cfg.batch_size,
        "pin_memory": pin,
        "num_workers": max(cfg.num_workers, 0),
    }
    if sampler is not None:
        return DataLoader(ds, sampler=sampler, **kwargs)
    return DataLoader(ds, shuffle=shuffle, **kwargs)


def _ensure_save_dir(save_dir: Path) -> Path:
    """Đường dẫn tuyệt đối + tạo thư mục (tránh lỗi torch.save trên Windows)."""
    d = save_dir.expanduser().resolve()
    d.mkdir(parents=True, exist_ok=True)
    return d


def run_training(cfg: TrainConfig) -> dict[str, Any]:
    set_seed(cfg.seed)
    device = setup_torch_runtime(require_cuda=cfg.require_cuda)
    cfg.save_dir = _ensure_save_dir(cfg.save_dir)
    preprocess_cfg = DEFAULT_PREPROCESS
    t0 = time.perf_counter()

    df = load_dataframe(cfg.csv_path)
    label2idx, idx2label = build_label_maps(df)
    num_classes = len(label2idx)
    class_names = [idx2label[i] for i in range(num_classes)]

    texts = df["text"].tolist()
    labels = [label2idx[l] for l in df["label"]]

    X_train, X_val, y_train, y_val = train_test_split(
        texts, labels, test_size=cfg.val_ratio, random_state=cfg.seed, stratify=labels
    )

    _safe_print("Augment train...")
    rng_aug = random.Random(cfg.seed)
    aug_texts, aug_labels = [], []
    for t, y in tqdm(
        list(zip(X_train, y_train)),
        desc="augment",
        leave=False,
    ):
        aug_texts.append(t)
        aug_labels.append(y)
        for _ in range(cfg.aug_copies):
            aug_texts.append(augment_train_text(t, idx2label[y], rng_aug))
            aug_labels.append(y)

    _safe_print("Build vocab...")
    vocab = build_vocab(aug_texts + X_val)
    pad_idx, unk_idx = vocab["<PAD>"], vocab["<UNK>"]

    train_ds = ExpenseDataset(
        aug_texts, aug_labels, vocab, cfg.max_len, preprocess_cfg, desc="train encode"
    )
    val_ds = ExpenseDataset(
        X_val, y_val, vocab, cfg.max_len, preprocess_cfg, desc="val encode"
    )

    hard_texts = [t for t, _ in VAL_HARD_SAMPLES]
    hard_labels = [label2idx.get(l, label2idx["Khác"]) for _, l in VAL_HARD_SAMPLES]
    hard_ds = ExpenseDataset(
        hard_texts, hard_labels, vocab, cfg.max_len, preprocess_cfg, desc="hard encode"
    )

    sampler: Optional[WeightedRandomSampler] = None
    class_weights: Optional[torch.Tensor] = None
    if cfg.use_class_weights:
        orig_counts = Counter(y_train)
        weights = [1.0 / max(orig_counts.get(i, 1), 1) for i in range(num_classes)]
        aug_counts = Counter(aug_labels)
        sample_w = [1.0 / max(aug_counts.get(y, 1), 1) for y in aug_labels]
        sampler = WeightedRandomSampler(sample_w, num_samples=len(sample_w), replacement=True)
        class_weights = torch.tensor(weights, dtype=torch.float, device=device)
        class_weights = class_weights * (len(weights) / class_weights.sum())

    train_dl = _make_dataloader(train_ds, cfg, device, sampler=sampler)
    val_dl = _make_dataloader(val_ds, cfg, device)
    _ = hard_ds  # dùng khi evaluate_detailed

    n_batches = len(train_dl)
    _safe_print(
        f"Train {len(train_ds)} | Val {len(val_ds)} | batches/epoch {n_batches} | "
        f"prep {time.perf_counter() - t0:.1f}s"
    )

    if device.type == "cuda":
        torch.cuda.empty_cache()

    model = CharCNNBiLSTMAttn(
        vocab_size=len(vocab),
        num_classes=num_classes,
        embed_dim=cfg.embed_dim,
        num_filters=cfg.num_filters,
        kernel_sizes=list(cfg.kernel_sizes),
        lstm_hidden=cfg.lstm_hidden,
        dropout=cfg.dropout,
        pad_idx=pad_idx,
    ).to(device)

    if cfg.use_focal_loss:
        criterion: nn.Module = FocalLoss(
            weight=class_weights,
            gamma=cfg.focal_gamma,
            label_smoothing=cfg.label_smoothing,
        )
    else:
        criterion = nn.CrossEntropyLoss(
            weight=class_weights,
            label_smoothing=cfg.label_smoothing,
        )
    optimizer = optim.AdamW(model.parameters(), lr=cfg.lr, weight_decay=cfg.weight_decay)
    scheduler = optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=cfg.epochs, eta_min=cfg.lr * 0.01)
    use_amp = cfg.use_amp and device.type == "cuda"
    scaler = torch.amp.GradScaler("cuda", enabled=use_amp)
    pin_memory = cfg.pin_memory and device.type == "cuda"

    best_val_acc = 0.0
    best_hard_macro_f1 = 0.0
    best_score = 0.0
    best_state: Optional[dict[str, Any]] = None
    patience_cnt = 0
    history: dict[str, list[float]] = {"tr_loss": [], "tr_acc": [], "va_loss": [], "va_acc": []}
    ckpt_path = cfg.save_dir / "classify_checkpoint.pt"
    _ensure_save_dir(cfg.save_dir)

    def run_epoch(loader: DataLoader, train: bool, *, show_batches: bool = False) -> tuple[float, float]:
        model.train(train)
        total_loss, correct, n = 0.0, 0, 0
        it = (
            tqdm(loader, desc="train batches", leave=False)
            if show_batches and train
            else loader
        )
        for xb, yb in it:
            xb = xb.to(device, non_blocking=pin_memory)
            yb = yb.to(device, non_blocking=pin_memory)
            optimizer.zero_grad(set_to_none=True)
            try:
                with torch.amp.autocast("cuda", enabled=use_amp):
                    logits = model(xb)
                loss = criterion(logits.float(), yb)
                if train:
                    scaler.scale(loss).backward()
                    scaler.unscale_(optimizer)
                    nn.utils.clip_grad_norm_(model.parameters(), 1.0)
                    scaler.step(optimizer)
                    scaler.update()
            except RuntimeError as e:
                msg = str(e).lower()
                if "out of memory" in msg:
                    if device.type == "cuda":
                        torch.cuda.empty_cache()
                    raise RuntimeError(
                        f"GPU hết bộ nhớ — giảm batch_size (hiện {cfg.batch_size}): {e}"
                    ) from e
                raise
            total_loss += loss.item() * len(yb)
            correct += (logits.argmax(-1) == yb).sum().item()
            n += len(yb)
        return total_loss / max(n, 1), correct / max(n, 1)

    interrupted = False
    try:
        epoch_bar = tqdm(range(1, cfg.epochs + 1), desc="epochs")
        for epoch in epoch_bar:
            ep_start = time.perf_counter()
            tr_loss, tr_acc = run_epoch(train_dl, True, show_batches=True)
            va_loss, va_acc = run_epoch(val_dl, False)
            scheduler.step()
            for k, v in zip(history, [tr_loss, tr_acc, va_loss, va_acc]):
                history[k].append(v)

            # Hard val nhanh mỗi epoch (subset) để chọn checkpoint
            hard_quick = evaluate(
                model,
                DataLoader(hard_ds, batch_size=64, shuffle=False),
                device,
                num_classes,
                class_names,
            )
            hard_f1 = hard_quick["macro_f1"]
            if cfg.early_stop_metric == "hard_macro_f1":
                score = hard_f1
            else:
                score = va_acc

            improved = score > best_score
            if va_acc > best_val_acc:
                best_val_acc = va_acc
            if hard_f1 > best_hard_macro_f1:
                best_hard_macro_f1 = hard_f1

            if improved:
                best_score = score
                best_state = copy.deepcopy(model.state_dict())
                patience_cnt = 0
                _ensure_save_dir(cfg.save_dir)
                torch.save(best_state, cfg.save_dir / "classify_best.pt")
            else:
                patience_cnt += 1

            torch.save(
                {
                    "epoch": epoch,
                    "model": model.state_dict(),
                    "best_val_acc": best_val_acc,
                    "best_state": best_state,
                    "history": history,
                },
                ckpt_path,
            )

            if epoch % cfg.log_interval == 0 or improved:
                ep_sec = time.perf_counter() - ep_start
                postfix = dict(
                    tr=f"{tr_acc:.3f}",
                    va=f"{va_acc:.3f}",
                    hf1=f"{hard_f1:.3f}",
                    best=f"{best_score:.3f}",
                    sec=f"{ep_sec:.0f}",
                    pat=patience_cnt,
                )
                if hasattr(epoch_bar, "set_postfix"):
                    epoch_bar.set_postfix(**postfix)
                _safe_print(
                    f"Epoch {epoch}/{cfg.epochs} "
                    f"train_acc={tr_acc:.4f} val_acc={va_acc:.4f} "
                    f"best={best_val_acc:.4f} ({ep_sec:.0f}s)"
                )

            if patience_cnt >= cfg.patience:
                _safe_print(f"Early stop @ epoch {epoch}")
                break
    except KeyboardInterrupt:
        interrupted = True
        _safe_print("KeyboardInterrupt — lưu checkpoint tốt nhất (nếu có)...")

    if best_state:
        model.load_state_dict(best_state)
    elif interrupted:
        raise RuntimeError(
            "Train bị dừng trước epoch đầu tiên hoàn thành. "
            "Bật GPU (T4), chạy lại CELL 0→2; không bấm Stop khi đang epoch."
        )

    val_metrics = evaluate_detailed(
        model, X_val, y_val, vocab, cfg.max_len, preprocess_cfg, device, class_names
    )
    hard_metrics = evaluate_detailed(
        model, hard_texts, hard_labels, vocab, cfg.max_len, preprocess_cfg, device, class_names
    )

    cfg.save_dir.mkdir(parents=True, exist_ok=True)
    torch.save(model.state_dict(), cfg.save_dir / "classify_model.pt")
    (cfg.save_dir / "classify_vocab.json").write_text(
        json.dumps(vocab, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    save_preprocess_config(cfg.save_dir / "classify_preprocess.json", preprocess_cfg)

    meta = {
        "architecture": "CharCNNBiLSTMAttn",
        "from_scratch": True,
        "pretrained_used": False,
        "fine_tuned": False,
        "classes": class_names,
        "label2idx": label2idx,
        "num_classes": num_classes,
        "vocab_size": len(vocab),
        "embed_dim": cfg.embed_dim,
        "num_filters": cfg.num_filters,
        "kernel_sizes": list(cfg.kernel_sizes),
        "lstm_hidden": cfg.lstm_hidden,
        "max_len": cfg.max_len,
        "dropout": cfg.dropout,
        "pad_idx": pad_idx,
        "unk_idx": unk_idx,
        "confidence_threshold": cfg.confidence_threshold,
        "min_conf": cfg.confidence_threshold,
        "best_val_acc": round(best_val_acc, 4),
        "best_hard_macro_f1": round(best_hard_macro_f1, 4),
        "early_stop_metric": cfg.early_stop_metric,
        "train_samples": len(aug_texts),
        "train_samples_original": len(X_train),
        "val_samples": len(val_ds),
        "hard_val_samples": len(hard_texts),
        "training_date": datetime.now(timezone.utc).isoformat(),
        "class_weights_from": "original_train_distribution",
    }
    (cfg.save_dir / "classify_meta.json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    metrics_report = {
        "validation": val_metrics,
        "validation_hard": hard_metrics,
        "history": history,
        "label_distribution": dict(Counter(df["label"])),
        "val_hard_count": len(VAL_HARD_SAMPLES),
    }
    for key in ("validation", "validation_hard"):
        m = metrics_report[key]
        m.pop("predictions", None)
        m.pop("true", None)
    (cfg.save_dir / "classify_metrics.json").write_text(
        json.dumps(metrics_report, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    total_min = (time.perf_counter() - t0) / 60.0
    _safe_print(f"Device: {device} | Total: {total_min:.1f} min | interrupted={interrupted}")
    _safe_print(
        f"Val accuracy: {val_metrics['accuracy']:.4f}  macro F1: {val_metrics['macro_f1']:.4f}"
    )
    _safe_print(
        f"Hard val accuracy: {hard_metrics['accuracy']:.4f}  macro F1: {hard_metrics['macro_f1']:.4f}"
    )
    _safe_print("--- Validation report ---")
    _safe_print(val_metrics["classification_report"])
    _safe_print("--- Hard validation report ---")
    _safe_print(hard_metrics["classification_report"])

    _write_improvement_report(cfg.save_dir, metrics_report, cfg)
    return metrics_report


def _write_improvement_report(
    save_dir: Path,
    metrics: dict[str, Any],
    cfg: TrainConfig,
) -> None:
    v = metrics["validation"]
    h = metrics["validation_hard"]
    lines = [
        "# Classify model — improvement report",
        "",
        f"- Train CSV: `{cfg.csv_path}`",
        f"- Dropout: {cfg.dropout} | LR: {cfg.lr} | Label smoothing: {cfg.label_smoothing}",
        f"- Confidence threshold: {cfg.confidence_threshold}",
        "",
        "## Validation",
        f"- accuracy: {v['accuracy']:.4f}",
        f"- macro F1: {v['macro_f1']:.4f}",
        f"- weighted F1: {v['weighted_f1']:.4f}",
        f"- pct confidence < 0.45: {v.get('confidence_stats', {}).get('pct_below_045', 0):.4f}",
        "",
        "## Hard validation",
        f"- accuracy: {h['accuracy']:.4f}",
        f"- macro F1: {h['macro_f1']:.4f}",
        "",
        "## Top confused (val)",
    ]
    for p in v.get("top_confused_pairs", [])[:10]:
        lines.append(f"- {p['true']} → {p['predicted']}: {p['count']}")
    lines.append("")
    lines.append("## Remaining errors (hard val)")
    for e in h.get("errors", [])[:15]:
        lines.append(
            f"- `{e['text']}` true={e['true']} pred={e['predicted']} conf={e['confidence']:.3f}"
        )
    body = "\n".join(lines)
    (save_dir / "IMPROVEMENT_REPORT.md").write_text(body, encoding="utf-8")
    (save_dir / "MODEL_IMPROVEMENT_REPORT.md").write_text(body, encoding="utf-8")
    data_dir = Path(__file__).resolve().parents[1] / "data"
    try:
        (data_dir / "MODEL_IMPROVEMENT_REPORT.md").write_text(body, encoding="utf-8")
    except OSError:
        pass


def run_grid_search(
    csv_path: Path,
    save_dir: Path,
    *,
    quick_epochs: int = 25,
    require_cuda: bool = False,
) -> dict[str, Any]:
    """
    Grid nhỏ — chọn theo hard_val macro F1.
    quick_epochs: epoch mỗi combo (Colab: 25–40; local smoke: 8).
    """
    # 64 full combos quá lâu — dùng lưới rút gọn 12 điểm (Colab ~3–5h) hoặc full_grid=True
    reduced = [
        (0.30, 2e-4, 0.05),
        (0.30, 3e-4, 0.05),
        (0.35, 3e-4, 0.05),
        (0.35, 2e-4, 0.03),
        (0.35, 3e-4, 0.08),
        (0.40, 3e-4, 0.05),
        (0.25, 3e-4, 0.05),
        (0.35, 5e-4, 0.05),
        (0.35, 1e-4, 0.05),
        (0.30, 3e-4, 0.00),
        (0.35, 3e-4, 0.03),
        (0.30, 2e-4, 0.08),
    ]
    full_grid = [
        (d, l, s)
        for d in [0.25, 0.30, 0.35, 0.40]
        for l in [1e-4, 2e-4, 3e-4, 5e-4]
        for s in [0.0, 0.03, 0.05, 0.08]
    ]
    combos = full_grid if os.environ.get("CLASSIFY_FULL_GRID") == "1" else reduced

    best: Optional[dict[str, Any]] = None
    results: list[dict[str, Any]] = []

    for dr, lr, ls in combos:
        sub = save_dir / f"grid_d{dr}_lr{lr}_ls{ls}"
        sub.mkdir(parents=True, exist_ok=True)
        cfg = TrainConfig(
            csv_path=csv_path,
            save_dir=sub,
            dropout=dr,
            lr=lr,
            label_smoothing=ls,
            epochs=quick_epochs,
            patience=8,
            require_cuda=require_cuda,
            early_stop_metric="hard_macro_f1",
        )
        _safe_print(f"Grid: dropout={dr} lr={lr} smooth={ls}")
        try:
            m = run_training(cfg)
        except Exception as exc:
            _safe_print(f"  FAILED: {exc}")
            continue
        hv = m["validation_hard"]
        row = {
            "dropout": dr,
            "lr": lr,
            "label_smoothing": ls,
            "val_acc": m["validation"]["accuracy"],
            "val_macro_f1": m["validation"]["macro_f1"],
            "hard_acc": hv["accuracy"],
            "hard_macro_f1": hv["macro_f1"],
            "hard_pct_low_conf": hv.get("confidence_stats", {}).get("pct_below_045", 0),
            "save_dir": str(sub),
        }
        results.append(row)
        def _rank(r: dict) -> tuple:
            over = len([e for e in hv.get("errors", []) if e.get("confidence", 0) >= 0.7])
            return (
                r["hard_macro_f1"],
                r["hard_acc"],
                r["val_macro_f1"],
                -r["hard_pct_low_conf"],
                -over,
            )

        if best is None or _rank(row) > _rank(best):
            best = row

    out = {"results": results, "best": best}
    (save_dir / "grid_search_results.json").write_text(
        json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    if best:
        _safe_print(
            f"Best grid: d={best['dropout']} lr={best['lr']} ls={best['label_smoothing']} "
            f"hard_f1={best['hard_macro_f1']:.4f}"
        )
    return out
