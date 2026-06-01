from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Optional

import torch
import torch.nn as nn

from .classify_net import CharCNNBiLSTMAttn
from .classify_ood import is_ood_text
from .text_preprocess import (
    PreprocessConfig,
    encode_text,
    load_preprocess_config,
    preprocess_text,
)


@dataclass(frozen=True)
class ClassifyBundle:
    model: nn.Module
    meta: dict[str, Any]
    vocab: dict[str, int]
    preprocess: PreprocessConfig
    device: torch.device

    @property
    def classes(self) -> list[str]:
        return list(self.meta["classes"])

    @property
    def max_len(self) -> int:
        return int(self.meta.get("max_len", 128))

    @property
    def pad_idx(self) -> int:
        return int(self.meta.get("pad_idx", 0))

    @property
    def unk_idx(self) -> int:
        return int(self.meta.get("unk_idx", 1))

    @property
    def confidence_threshold(self) -> float:
        return float(
            self.meta.get("confidence_threshold", self.meta.get("min_conf", 0.45))
        )


@dataclass(frozen=True)
class PredictResult:
    label: str
    confidence: float
    needs_review: bool
    probabilities: Optional[dict[str, float]] = None
    ood_reason: Optional[str] = None


def _build_model(meta: dict[str, Any], device: torch.device) -> nn.Module:
    arch = meta.get("architecture", "CharCNNBiLSTMAttn")
    if arch != "CharCNNBiLSTMAttn":
        raise ValueError(f"Unsupported architecture: {arch}. Retrain with CharCNNBiLSTMAttn.")
    m: nn.Module = CharCNNBiLSTMAttn(
        vocab_size=int(meta["vocab_size"]),
        num_classes=int(meta["num_classes"]),
        embed_dim=int(meta.get("embed_dim", 96)),
        num_filters=int(meta.get("num_filters", 64)),
        kernel_sizes=list(meta.get("kernel_sizes", [2, 3, 4, 5, 6])),
        lstm_hidden=int(meta.get("lstm_hidden", 128)),
        dropout=float(meta.get("dropout", 0.35)),
        pad_idx=int(meta.get("pad_idx", 0)),
    )
    return m.to(device)


def load_classify_bundle(
    models_dir: Path,
    device: Optional[torch.device] = None,
) -> Optional[ClassifyBundle]:
    pt = models_dir / "classify_model.pt"
    meta_path = models_dir / "classify_meta.json"
    vocab_path = models_dir / "classify_vocab.json"
    pre_path = models_dir / "classify_preprocess.json"

    if not pt.exists() or not meta_path.exists() or not vocab_path.exists():
        return None

    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    vocab = json.loads(vocab_path.read_text(encoding="utf-8"))
    preprocess = load_preprocess_config(pre_path)
    dev = device or torch.device("cpu")
    m = _build_model(meta, dev)

    try:
        state = torch.load(pt, map_location=dev, weights_only=True)
    except TypeError:
        state = torch.load(pt, map_location=dev)

    m.load_state_dict(state)
    m.eval()
    return ClassifyBundle(model=m, meta=meta, vocab=vocab, preprocess=preprocess, device=dev)


def _forward_probs(bundle: ClassifyBundle, raw_text: str) -> tuple[list[float], list[str]]:
    """Raw text → preprocess một lần → encode → model."""
    ids = encode_text(
        raw_text,
        bundle.vocab,
        bundle.max_len,
        bundle.preprocess,
        bundle.pad_idx,
        bundle.unk_idx,
    )
    x = torch.tensor([ids], dtype=torch.long, device=bundle.device)
    with torch.no_grad():
        logits = bundle.model(x)
        probs = torch.softmax(logits, dim=-1)[0].cpu().tolist()
    return probs, bundle.classes


def predict_proba(bundle: ClassifyBundle, text: str) -> dict[str, float]:
    probs, classes = _forward_probs(bundle, text)
    return {c: float(p) for c, p in zip(classes, probs)}


def predict(
    bundle: ClassifyBundle,
    text: str,
    *,
    threshold: Optional[float] = None,
    return_proba: bool = False,
    skip_ood: bool = False,
) -> PredictResult:
    thr = bundle.confidence_threshold if threshold is None else threshold

    if not skip_ood:
        ood, reason = is_ood_text(text)
        if ood:
            return PredictResult(
                label="Khác",
                confidence=0.0,
                needs_review=True,
                probabilities=None,
                ood_reason=reason,
            )

    probs, classes = _forward_probs(bundle, text)
    idx = int(max(range(len(probs)), key=lambda i: probs[i]))
    conf = float(probs[idx])
    label = classes[idx]
    needs_review = conf < thr
    if needs_review:
        label = "Khác"
    proba_dict = {c: float(p) for c, p in zip(classes, probs)} if return_proba else None
    return PredictResult(
        label=label,
        confidence=conf,
        needs_review=needs_review,
        probabilities=proba_dict,
        ood_reason=None,
    )


def batch_predict(
    bundle: ClassifyBundle,
    texts: list[str],
    *,
    threshold: Optional[float] = None,
) -> list[PredictResult]:
    return [predict(bundle, t, threshold=threshold) for t in texts]


def predict_top_label(bundle: ClassifyBundle, text: str) -> tuple[str, float]:
    """Argmax softmax — không ép Khác khi confidence thấp."""
    probs, classes = _forward_probs(bundle, text)
    idx = int(max(range(len(probs)), key=lambda i: probs[i]))
    return classes[idx], float(probs[idx])


def predict_category(
    bundle: ClassifyBundle,
    text: str,
    *,
    threshold: float = 0.0,
) -> tuple[str, float]:
    """API tương thích main.py."""
    thr = threshold if threshold > 0 else bundle.confidence_threshold
    r = predict(bundle, text, threshold=thr)
    return r.label, r.confidence
