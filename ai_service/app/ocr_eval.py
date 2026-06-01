"""Đánh giá OCR: CER, exact match, phân tích lỗi ký tự."""

from __future__ import annotations

from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Optional

import pandas as pd
import torch
from PIL import Image

from .ocr_infer import FieldOcrBundle, greedy_ctc_decode, preprocess_line_image, run_ocr_on_image


def _levenshtein(a: str, b: str) -> int:
    if a == b:
        return 0
    if not a:
        return len(b)
    if not b:
        return len(a)
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            ins = cur[j - 1] + 1
            dele = prev[j] + 1
            sub = prev[j - 1] + (ca != cb)
            cur.append(min(ins, dele, sub))
        prev = cur
    return prev[-1]


def cer(reference: str, hypothesis: str) -> float:
    """Character Error Rate = edit_distance / len(ref)."""
    ref = reference or ""
    hyp = hypothesis or ""
    if not ref:
        return 0.0 if not hyp else 1.0
    return _levenshtein(ref, hyp) / len(ref)


def _levenshtein_words(a: list[str], b: list[str]) -> int:
    n, m = len(a), len(b)
    dp = [[0] * (m + 1) for _ in range(n + 1)]
    for i in range(n + 1):
        dp[i][0] = i
    for j in range(m + 1):
        dp[0][j] = j
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            cost = 0 if a[i - 1] == b[j - 1] else 1
            dp[i][j] = min(dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + cost)
    return dp[n][m]


def wer(reference: str, hypothesis: str) -> float:
    """Word Error Rate (tách theo khoảng trắng)."""
    ref_w = (reference or "").split()
    hyp_w = (hypothesis or "").split()
    if not ref_w:
        return 0.0 if not hyp_w else 1.0
    return _levenshtein_words(ref_w, hyp_w) / len(ref_w)


def exact_match(reference: str, hypothesis: str) -> bool:
    return (reference or "").strip() == (hypothesis or "").strip()


def substitution_errors(reference: str, hypothesis: str) -> list[tuple[str, str]]:
    """Trả về các cặp (ref_char, hyp_char) bị thay thế (alignment đơn giản)."""
    ref, hyp = reference or "", hypothesis or ""
    n, m = len(ref), len(hyp)
    dp = [[0] * (m + 1) for _ in range(n + 1)]
    for i in range(n + 1):
        dp[i][0] = i
    for j in range(m + 1):
        dp[0][j] = j
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            cost = 0 if ref[i - 1] == hyp[j - 1] else 1
            dp[i][j] = min(
                dp[i - 1][j] + 1,
                dp[i][j - 1] + 1,
                dp[i - 1][j - 1] + cost,
            )
    subs: list[tuple[str, str]] = []
    i, j = n, m
    while i > 0 and j > 0:
        if ref[i - 1] == hyp[j - 1]:
            i -= 1
            j -= 1
        elif dp[i][j] == dp[i - 1][j - 1] + 1:
            subs.append((ref[i - 1], hyp[j - 1]))
            i -= 1
            j -= 1
        elif dp[i][j] == dp[i - 1][j] + 1:
            subs.append((ref[i - 1], ""))
            i -= 1
        else:
            subs.append(("", hyp[j - 1]))
            j -= 1
    while i > 0:
        subs.append((ref[i - 1], ""))
        i -= 1
    while j > 0:
        subs.append(("", hyp[j - 1]))
        j -= 1
    return [(a, b) for a, b in subs if a != b]


@dataclass
class FieldEvalResult:
    field: str
    n_samples: int
    exact_acc: float
    mean_cer: float
    mean_wer: float
    mean_confidence: float
    amount_exact_acc: Optional[float] = None
    predictions: list[dict[str, Any]] = field(default_factory=list)
    char_error_counter: Counter = field(default_factory=Counter)

    def to_metrics_dict(self) -> dict[str, Any]:
        return {
            "field": self.field,
            "n_samples": self.n_samples,
            "exact_acc": round(self.exact_acc, 4),
            "mean_cer": round(self.mean_cer, 4),
            "mean_wer": round(self.mean_wer, 4),
            "mean_confidence": round(self.mean_confidence, 4),
            "amount_exact_acc": round(self.amount_exact_acc, 4) if self.amount_exact_acc is not None else None,
        }


def evaluate_field_on_df(
    bundle: FieldOcrBundle,
    df: pd.DataFrame,
    data_root: Path,
    *,
    label_col: str = "label_text",
    amount_col: Optional[str] = None,
    max_samples: Optional[int] = None,
) -> FieldEvalResult:
    """Đánh giá model trên dataframe validation."""
    from .ocr_infer import parse_amount_vnd_from_text

    rows = df if max_samples is None else df.head(max_samples)
    preds: list[dict[str, Any]] = []
    cers: list[float] = []
    wers: list[float] = []
    exact = 0
    confs: list[float] = []
    err_counter: Counter = Counter()
    amt_exact = 0
    amt_total = 0

    for _, row in rows.iterrows():
        img_path = data_root / row["image_path"]
        ref = str(row[label_col]).strip()
        img = Image.open(img_path).convert("L")
        hyp, conf = run_ocr_on_image(bundle, img)
        confs.append(conf)
        cers.append(cer(ref, hyp))
        wers.append(wer(ref, hyp))
        if exact_match(ref, hyp):
            exact += 1
        for pair in substitution_errors(ref, hyp):
            err_counter[f"{pair[0] or '∅'}→{pair[1] or '∅'}"] += 1

        item: dict[str, Any] = {
            "image_path": row["image_path"],
            "reference": ref,
            "prediction": hyp,
            "cer": round(cer(ref, hyp), 4),
            "exact": exact_match(ref, hyp),
            "confidence": round(conf, 4),
        }
        if amount_col and amount_col in row and pd.notna(row[amount_col]):
            gt_amt = int(row[amount_col])
            pred_amt = parse_amount_vnd_from_text(hyp)
            item["amount_gt"] = gt_amt
            item["amount_pred"] = pred_amt
            item["amount_exact"] = pred_amt == gt_amt
            amt_total += 1
            if pred_amt == gt_amt:
                amt_exact += 1
        preds.append(item)

    n = max(len(rows), 1)
    return FieldEvalResult(
        field=bundle.name,
        n_samples=len(rows),
        exact_acc=exact / n,
        mean_cer=float(sum(cers) / n),
        mean_wer=float(sum(wers) / n),
        mean_confidence=float(sum(confs) / n),
        amount_exact_acc=(amt_exact / amt_total) if amt_total else None,
        predictions=preds,
        char_error_counter=err_counter,
    )


def char_errors_to_dataframe(counter: Counter, top_k: int = 20) -> pd.DataFrame:
    rows = [{"error": k, "count": v} for k, v in counter.most_common(top_k)]
    if not rows:
        return pd.DataFrame(columns=["error", "count"])
    return pd.DataFrame(rows)


def split_val_df(
    df: pd.DataFrame,
    *,
    val_ratio: float = 0.12,
    seed: int = 42,
) -> pd.DataFrame:
    """Chia validation giống train_receipt_models.py (shuffle + val_ratio)."""
    import random

    rng = random.Random(seed)
    idx = list(range(len(df)))
    rng.shuffle(idx)
    n_val = max(1, int(len(df) * val_ratio))
    return df.iloc[idx[:n_val]].reset_index(drop=True)


def compare_models_table(metrics_list: list[dict[str, Any]]) -> pd.DataFrame:
    return pd.DataFrame(metrics_list).set_index("field")
