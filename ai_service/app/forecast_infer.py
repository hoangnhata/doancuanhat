from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Any, Optional, Sequence

import numpy as np
import torch
import torch.nn as nn

from .forecast_features import (
    N_CATEGORY,
    inference_decoder_time_feats,
    inference_encoder_matrix,
    parse_last_date,
    stack_encoder_feats,
    window_dates_ending_at,
)
from .forecast_net import SpendingForecastTransformer


@dataclass(frozen=True)
class ForecastBundle:
    model: nn.Module
    meta: dict[str, Any]
    device: torch.device

    @property
    def window(self) -> int:
        return int(self.meta["window"])

    @property
    def horizon(self) -> int:
        return int(self.meta["horizon"])


def _build_model(meta: dict[str, Any], device: torch.device) -> nn.Module:
    m: nn.Module = SpendingForecastTransformer(
        window=int(meta["window"]),
        horizon=int(meta["horizon"]),
        input_size=int(meta.get("input_size", 14)),
        d_model=int(meta.get("d_model", 64)),
        n_heads=int(meta.get("n_heads", 4)),
        n_enc_layers=int(meta.get("n_enc_layers", 3)),
        n_dec_layers=int(meta.get("n_dec_layers", 2)),
        d_ff=int(meta.get("d_ff", 256)),
        dropout=float(meta.get("dropout", 0.10)),
        use_instance_norm=bool(meta.get("use_instance_norm", True)),
        inst_norm_recent_k=int(meta.get("inst_norm_recent_k", 14)),
    )
    return m.to(device)


def load_forecast_bundle(
    models_dir: Path,
    device: Optional[torch.device] = None,
) -> Optional[ForecastBundle]:
    pt        = models_dir / "forecast_model.pt"
    meta_path = models_dir / "forecast_meta.json"
    if not pt.exists() or not meta_path.exists():
        return None
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    dev  = device or torch.device("cpu")
    m    = _build_model(meta, dev)
    try:
        state = torch.load(pt, map_location=dev, weights_only=True)
    except TypeError:
        state = torch.load(pt, map_location=dev)
    m.load_state_dict(state)
    m.eval()
    return ForecastBundle(model=m, meta=meta, device=dev)


def predict_horizon_vnd(
    bundle: ForecastBundle,
    daily_expenses_vnd: list[float],
    *,
    last_date: Optional[str] = None,
    category_shares_window: Optional[Sequence[Sequence[float]]] = None,
) -> list[int]:
    """
    Dự đoán `horizon` ngày tiếp theo (VND, làm tròn nguyên).

    Tham số:
        bundle             : ForecastBundle đã tải từ load_forecast_bundle().
        daily_expenses_vnd : chuỗi tổng chi tiêu mỗi ngày (VND), thứ tự thời gian.
                             Cần ít nhất `window` ngày.
        last_date          : ngày của quan sát cuối (YYYY-MM-DD).
                             Nếu None: dùng ngày hệ thống.
        category_shares_window: tuỳ chọn, độ dài WINDOW,
                             mỗi phần tử là 5 số share danh mục (food, transport, …).
    """
    w = bundle.window
    h = bundle.horizon
    if len(daily_expenses_vnd) < w:
        raise ValueError(f"Cần ít nhất {w} ngày dữ liệu, hiện có {len(daily_expenses_vnd)}")

    tail     = daily_expenses_vnd[-w:]
    mean_log = float(bundle.meta["mean_log"])
    std_log  = float(bundle.meta["std_log"])
    mc       = bundle.meta.get("mean_category")
    if mc is None or len(mc) != N_CATEGORY:
        raise ValueError("Meta thiếu mean_category (5 phần tử)")
    mean_cat = [float(v) for v in mc]
    last     = parse_last_date(last_date, date.today())

    # ── Xây encoder input ────────────────────────────────────────────────
    if category_shares_window is not None:
        if len(category_shares_window) != w:
            raise ValueError(f"category_shares_window cần đúng {w} phần tử")
        days   = window_dates_ending_at(last, w)
        dt_idx = np.array(days, dtype="datetime64[D]")
        lg     = np.log1p(np.maximum(np.asarray(tail, dtype=np.float64), 0.0))
        a      = ((lg - mean_log) / (std_log + 1e-8)).astype(np.float64)
        sh     = np.asarray(category_shares_window, dtype=np.float64)
        sh     = sh / np.maximum(sh.sum(axis=1, keepdims=True), 1e-9)
        enc    = stack_encoder_feats(a, dt_idx, sh)
    else:
        enc, _ = inference_encoder_matrix(
            tail_vnd=tail,
            mean_log=mean_log,
            std_log=std_log,
            mean_category=mean_cat,
            last_date=last_date,
        )

    # ── Xây decoder time features ────────────────────────────────────────
    dec_np = inference_decoder_time_feats(last, h, mean_cat)

    # ── Inference ────────────────────────────────────────────────────────
    t_x = torch.from_numpy(enc).unsqueeze(0).to(bundle.device)
    dec = torch.from_numpy(dec_np).unsqueeze(0).to(bundle.device)
    with torch.no_grad():
        y_norm = bundle.model(t_x, decoder_time_feats=dec).cpu().numpy().squeeze(0)

    # Denormalize: global z-score → log → VND
    y_log    = y_norm * (std_log + 1e-8) + mean_log
    pred_vnd = np.expm1(np.clip(y_log, 0.0, 25.0))
    return [int(round(float(v))) for v in pred_vnd.tolist()]
