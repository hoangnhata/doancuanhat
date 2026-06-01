"""Đặc trưng lịch + danh mục cho dự báo chi tiêu."""

from __future__ import annotations

import math
from datetime import date, datetime, timedelta
from typing import Sequence

import numpy as np
import pandas as pd

CATEGORY_COLS = (
    "share_food",
    "share_transport",
    "share_shopping",
    "share_bills",
    "share_other",
)
N_CATEGORY = len(CATEGORY_COLS)  # 5

# Lịch: sin/cos thứ, cuối tuần, sin/cos tháng, sin/cos ngày trong tháng, xung đầu tháng
# early_month_pulse mã hoá xung suy giảm mượt cho ngày đầu tháng (tiền nhà, hoá đơn)
# vì sin/cos(dom) liên tục không phân biệt được spike ở dom=1 vs dom=31
N_CALENDAR = 8
# Tổng kênh không phải số tiền: lịch + share danh mục
N_TIME_AND_CAT = N_CALENDAR + N_CATEGORY  # 13


def dow_sin_cos(dt: pd.Series | pd.DatetimeIndex) -> tuple[np.ndarray, np.ndarray]:
    if isinstance(dt, pd.DatetimeIndex):
        dow = dt.dayofweek.astype(np.float64)
    else:
        dow = pd.to_datetime(dt).dt.dayofweek.astype(np.float64)
    ang = 2.0 * math.pi * (dow / 7.0)
    return np.sin(ang), np.cos(ang)


def is_weekend(dt: pd.Series | pd.DatetimeIndex) -> np.ndarray:
    if isinstance(dt, pd.DatetimeIndex):
        dow = dt.dayofweek
    else:
        dow = pd.to_datetime(dt).dt.dayofweek
    return (dow >= 5).astype(np.float64)


def month_sin_cos(dt: pd.Series | pd.DatetimeIndex) -> tuple[np.ndarray, np.ndarray]:
    if isinstance(dt, pd.DatetimeIndex):
        m = dt.month.astype(np.float64) - 1.0
    else:
        m = pd.to_datetime(dt).dt.month.astype(np.float64) - 1.0
    ang = 2.0 * math.pi * (m / 12.0)
    return np.sin(ang), np.cos(ang)


def dom_sin_cos(dt: pd.Series | pd.DatetimeIndex) -> tuple[np.ndarray, np.ndarray]:
    """sin/cos ngày trong tháng (1–31, chu kỳ 31)."""
    if isinstance(dt, pd.DatetimeIndex):
        d = dt.day.astype(np.float64) - 1.0
    else:
        d = pd.to_datetime(dt).dt.day.astype(np.float64) - 1.0
    ang = 2.0 * math.pi * (d / 31.0)
    return np.sin(ang), np.cos(ang)


def early_month_pulse(dt: pd.Series | pd.DatetimeIndex) -> np.ndarray:
    """Xung suy giảm mượt cho giai đoạn đầu tháng (dom=1–5).

    dom=1 có chi tiêu đột biến (tiền nhà, điện, internet) rồi suy giảm dần.
    Dùng exponential decay thay vì cờ nhị phân để model nhận gradient mượt,
    tránh phản ứng thái quá trên tập dữ liệu thưa (chỉ ~51 ngày dom=1/1551 ngày).

    Giá trị:
        dom=1 → 1.000  (peak)
        dom=2 → 0.607
        dom=3 → 0.368
        dom=4 → 0.223
        dom=5 → 0.135
        dom≥6 → 0.000  (baseline)
    """
    if isinstance(dt, pd.DatetimeIndex):
        day = dt.day.to_numpy(dtype=np.float64)
    else:
        day = pd.to_datetime(dt).dt.day.to_numpy(dtype=np.float64)
    pulse = np.exp(-0.5 * np.maximum(day - 1.0, 0.0))
    pulse[day > 5.0] = 0.0
    return pulse


def calendar_feats_numpy(dates: np.ndarray) -> np.ndarray:
    """dates: datetime64 → (T, 8) = [sin_dow, cos_dow, weekend, sin_month, cos_month, sin_dom, cos_dom, early_month_pulse]."""
    s = pd.to_datetime(dates)
    s1, c1 = dow_sin_cos(s)
    wk = is_weekend(s)
    ms, mc = month_sin_cos(s)
    ds, dc = dom_sin_cos(s)
    emp = early_month_pulse(s)
    return np.stack([s1, c1, wk, ms, mc, ds, dc, emp], axis=1).astype(np.float64)


def category_shares_from_df(df: pd.DataFrame) -> np.ndarray:
    """Đọc share từ CSV nếu đủ cột; không thì bootstrap theo thứ trong tuần."""
    if all(c in df.columns for c in CATEGORY_COLS):
        m = df[list(CATEGORY_COLS)].values.astype(np.float64)
        s = m.sum(axis=1, keepdims=True)
        s = np.maximum(s, 1e-9)
        return m / s
    return bootstrap_category_shares(df["date"])


def bootstrap_category_shares(dates: pd.Series) -> np.ndarray:
    """Prior share khi không có CSV: mỗi (thứ × tháng) khác nhau."""
    dt = pd.to_datetime(dates)
    dow = dt.dt.dayofweek.values.astype(int)
    month = dt.dt.month.values.astype(int)
    dom = dt.dt.day.values.astype(int)
    out = np.zeros((len(dates), N_CATEGORY), dtype=np.float64)
    for i in range(len(dates)):
        d, mo, day_m = int(dow[i]), int(month[i]), int(dom[i])
        logits = np.array([1.0, 0.55, 0.35, 0.22, 0.28], dtype=np.float64)
        logits[0] += 0.20 * math.sin(2.0 * math.pi * d / 7.0) + 0.08 * math.cos(2.0 * math.pi * d / 7.0)
        logits[1] += 0.18 * math.cos(2.0 * math.pi * (d + 1) / 7.0)
        logits[2] += 0.14 * math.sin(2.0 * math.pi * (d + 3) / 7.0)
        logits[3] += 0.10 * math.cos(2.0 * math.pi * d / 7.0)
        logits[4] += 0.08 * math.sin(2.0 * math.pi * (d - 1) / 7.0)
        if d >= 5:
            logits[0] += 0.24
            logits[1] -= 0.10
            logits[2] += 0.06 if d == 5 else 0.04
        mo_n = (mo - 1) / 11.0
        logits[0] += 0.06 * math.sin(2.0 * math.pi * mo / 12.0)
        logits[3] += 0.05 * math.cos(2.0 * math.pi * mo / 12.0)
        logits[4] += 0.04 * mo_n
        logits[2] += 0.04 * math.sin(2.0 * math.pi * day_m / 31.0)
        logits[4] += 0.03 * math.cos(2.0 * math.pi * day_m / 31.0)
        e = np.exp(logits - logits.max())
        out[i] = e / e.sum()
    return out


def stack_encoder_feats(amount_norm: np.ndarray, dates: np.ndarray, shares: np.ndarray) -> np.ndarray:
    """amount_norm: (T,), dates: (T,) datetime64, shares: (T, 5) → (T, 1+N_TIME_AND_CAT)."""
    cal = calendar_feats_numpy(dates)
    return np.concatenate([amount_norm.reshape(-1, 1), cal, shares], axis=1).astype(np.float32)


def decoder_time_feats_from_arrays(
    dates_future: np.ndarray,
    shares_future: np.ndarray,
) -> np.ndarray:
    """(H, N_CALENDAR + N_CATEGORY) = lịch + share."""
    cal = calendar_feats_numpy(dates_future)
    return np.concatenate([cal, shares_future.astype(np.float64)], axis=1).astype(np.float32)


def parse_last_date(last_date: str | date | datetime | None, fallback: date) -> date:
    if last_date is None:
        return fallback
    if isinstance(last_date, date) and not isinstance(last_date, datetime):
        return last_date
    if isinstance(last_date, datetime):
        return last_date.date()
    return pd.to_datetime(last_date).date()


def window_dates_ending_at(last_day: date, window: int) -> list[date]:
    return [last_day - timedelta(days=window - 1 - i) for i in range(window)]


def horizon_dates_after(last_day: date, horizon: int) -> list[date]:
    return [last_day + timedelta(days=k) for k in range(1, horizon + 1)]


def inference_encoder_matrix(
    *,
    tail_vnd: Sequence[float],
    mean_log: float,
    std_log: float,
    mean_category: Sequence[float],
    last_date: str | date | datetime | None,
) -> tuple[np.ndarray, np.ndarray]:
    """Xây encoder input (WINDOW, F) cho inference."""
    w = len(tail_vnd)
    last = parse_last_date(last_date, date.today())
    days = window_dates_ending_at(last, w)
    dt_idx = np.array(days, dtype="datetime64[D]")
    lg = np.log1p(np.maximum(np.asarray(tail_vnd, dtype=np.float64), 0.0))
    a = ((lg - mean_log) / (std_log + 1e-8)).astype(np.float64)
    mc = np.asarray(mean_category, dtype=np.float64).reshape(1, -1)
    if mc.size != N_CATEGORY:
        raise ValueError(f"mean_category cần {N_CATEGORY} phần tử")
    shares = np.repeat(mc, w, axis=0)
    enc = stack_encoder_feats(a, dt_idx, shares)
    return enc, dt_idx


def inference_decoder_time_feats(
    last_day: date,
    horizon: int,
    mean_category: Sequence[float],
) -> np.ndarray:
    """Ma trận (horizon, N_TIME_AND_CAT) cho các ngày dự báo."""
    days = horizon_dates_after(last_day, horizon)
    dt_idx = np.array(days, dtype="datetime64[D]")
    mc = np.asarray(mean_category, dtype=np.float64).reshape(1, -1)
    shares = np.repeat(mc, horizon, axis=0)
    return decoder_time_feats_from_arrays(dt_idx, shares)
