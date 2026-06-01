"""
Sinh dataset chi tiêu hàng ngày (VND) – 2021-01-01 → 2025-03-31
=================================================================
Mô phỏng chi tiêu hàng ngày của một người dùng đô thị Việt Nam với:
  - Xu hướng tăng dài hạn (lạm phát + tăng lương)
  - Pattern tuần: cuối tuần chi nhiều hơn, thứ Hai thấp nhất
  - Pattern tháng: ngày 1 tháng (đóng tiền nhà/bill), cuối tháng tiết kiệm
  - Pattern mùa: Tết (tăng mạnh trước + giảm trong), hè, cuối năm mua sắm
  - Các sự kiện: 11.11, Black Friday, lễ 30/4, nghỉ hè 2/9
  - Nhiễu lognormal thực tế
  - Danh mục share thay đổi theo loại ngày

Output: daily_spending_train.csv  (thay thế file hiện tại)
"""

from __future__ import annotations

import math
from datetime import date, timedelta
from pathlib import Path

import numpy as np
import pandas as pd

# ── Config ──────────────────────────────────────────────────────────────────
START        = date(2021, 1, 1)
END          = date(2025, 3, 31)
SEED         = 2024
OUT_PATH     = Path(__file__).parent / "daily_spending_train.csv"

# Mức chi tiêu trung bình (VND/ngày) theo năm – phản ánh lạm phát ~10%/năm
# và tăng thu nhập cá nhân
BASE_BY_YEAR = {
    2021: 155_000,
    2022: 173_000,
    2023: 192_000,
    2024: 212_000,
    2025: 230_000,
}

# Tết âm lịch (ngày mùng 1) các năm – tra chính xác
TET_DAY = {
    2021: date(2021, 2, 12),
    2022: date(2022, 2, 1),
    2023: date(2023, 1, 22),
    2024: date(2024, 2, 10),
    2025: date(2025, 1, 29),
}

# ── Helpers ──────────────────────────────────────────────────────────────────
rng = np.random.default_rng(SEED)


def days_to_tet(d: date, year: int) -> int:
    """Số ngày từ d đến mùng 1 Tết (âm). Âm = trước Tết, dương = sau Tết."""
    return (d - TET_DAY.get(year, date(year, 2, 1))).days


def tet_multiplier(d: date) -> float:
    """Hệ số chi tiêu theo khoảng cách Tết."""
    tet = TET_DAY.get(d.year)
    if tet is None:
        return 1.0
    delta = (d - tet).days  # âm = trước, dương = sau

    if -21 <= delta <= -14:
        # 3 tuần trước Tết: chuẩn bị, tăng nhẹ
        t = (delta + 21) / 7
        return 1.0 + t * 0.25
    elif -13 <= delta <= -7:
        # 2 tuần trước: mua sắm mạnh
        t = (delta + 13) / 7
        return 1.25 + t * 0.45   # 1.25 → 1.70
    elif -6 <= delta <= -1:
        # 1 tuần trước: mua sắm đỉnh điểm
        t = (delta + 6) / 6
        return 1.70 + t * 0.55   # 1.70 → 2.25
    elif delta == 0:
        # Mùng 1: ăn nhà, thăm gia đình → chi tiêu thấp nhưng thực tế
        return 0.50
    elif 1 <= delta <= 4:
        # Mùng 2–5: nghỉ lễ, đi chơi, lì xì → vừa phải
        return 0.65 + delta * 0.05
    elif 5 <= delta <= 14:
        # Mùng 6–15: hàng quán mở lại dần, phục hồi
        t = (delta - 5) / 10
        return 0.75 + t * 0.25   # 0.75 → 1.00
    elif 15 <= delta <= 30:
        # Sau Tết ~2 tuần: tiết kiệm sau kỳ Tết
        t = (delta - 15) / 15
        return 0.90 + t * 0.10   # 0.90 → 1.00
    else:
        return 1.0


def week_multiplier(dow: int) -> float:
    """0=Mon … 6=Sun"""
    return [0.88, 0.92, 0.96, 1.00, 1.10, 1.32, 1.22][dow]


def dom_multiplier(dom: int) -> float:
    """Day of month pattern."""
    if dom == 1:
        return 1.60   # Ngày đầu tháng: tiền nhà, internet, điện
    elif dom <= 3:
        return 1.28
    elif dom <= 5:
        return 1.15
    elif dom <= 10:
        return 1.06   # Giữa tháng: sau lương
    elif dom <= 20:
        return 1.00
    elif dom <= 25:
        return 0.94
    else:
        return 0.89   # Cuối tháng: cẩn thận chi tiêu


def month_multiplier(month: int, dom: int) -> float:
    """Seasonal pattern."""
    base = {
        1:  1.05,  # sau năm mới dương lịch
        2:  0.90,  # có Tết → handled bởi tet_multiplier
        3:  0.88,  # sau Tết thắt lưng buộc bụng
        4:  0.95,  # Giỗ tổ, 30/4 gần
        5:  1.02,  # du lịch 30/4 + 1/5
        6:  1.05,  # hè bắt đầu
        7:  1.08,  # hè đỉnh điểm
        8:  1.06,  # hè, chuẩn bị khai trường
        9:  1.10,  # khai trường, đồng phục, sách vở
        10: 1.02,
        11: 1.15,  # 11.11, Black Friday cuối tháng
        12: 1.25,  # Giáng Sinh, mua sắm cuối năm
    }[month]

    # Điều chỉnh theo ngày cụ thể trong tháng
    if month == 4 and 27 <= dom <= 30:
        base *= 1.3   # 30/4
    if month == 5 and dom == 1:
        base *= 1.25  # 1/5
    if month == 9 and dom == 2:
        base *= 1.20  # 2/9 quốc khánh
    if month == 11 and dom == 11:
        base *= 1.75  # 11.11 mua sắm online
    if month == 11 and 22 <= dom <= 25:
        base *= 1.35  # Black Friday
    if month == 12 and 20 <= dom <= 26:
        base *= 1.45  # Noel shopping
    if month == 12 and dom >= 27:
        base *= 1.55  # Chuẩn bị năm mới dương lịch

    return base


def base_amount(d: date) -> float:
    """Tính mức chi tiêu trung bình cho ngày d (VND)."""
    year = d.year
    dom = d.day
    month = d.month
    dow = d.weekday()

    # Nội suy tuyến tính theo ngày trong năm
    yday = d.timetuple().tm_yday
    days_in_year = 366 if (year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)) else 365
    frac = (yday - 1) / (days_in_year - 1)
    b_this = BASE_BY_YEAR.get(year, BASE_BY_YEAR[max(BASE_BY_YEAR)])
    b_next = BASE_BY_YEAR.get(year + 1, b_this * 1.10)
    base = b_this + (b_next - b_this) * frac

    mul = week_multiplier(dow) * dom_multiplier(dom) * month_multiplier(month, dom) * tet_multiplier(d)
    return base * mul


def category_shares(d: date, total_amount: float) -> np.ndarray:
    """
    Trả về [food, transport, shopping, bills, other] tổng = 1.
    Thay đổi theo loại ngày.
    """
    dow   = d.weekday()
    dom   = d.day
    month = d.month

    # Mức nền
    f  = 0.355   # food
    tr = 0.180   # transport
    sh = 0.175   # shopping
    bi = 0.145   # bills
    ot = 0.145   # other

    # Cuối tuần: ăn uống + mua sắm nhiều, đi lại ít
    if dow == 5:  # Thứ Bảy
        f  += 0.065; tr -= 0.055; sh += 0.040; bi -= 0.030; ot -= 0.020
    elif dow == 6:  # Chủ Nhật
        f  += 0.055; tr -= 0.050; sh += 0.035; bi -= 0.025; ot -= 0.015

    # Ngày 1 tháng: bills lớn
    if dom == 1:
        bi += 0.190; f -= 0.065; sh -= 0.065; tr -= 0.030; ot -= 0.030

    # Tết: trước – mua sắm; trong – ăn nhà
    tet = TET_DAY.get(d.year)
    if tet:
        delta = (d - tet).days
        if -7 <= delta <= -1:  # tuần trước Tết: mua đồ ăn, quà, quần áo
            f  += 0.050; sh += 0.085; tr -= 0.020; bi -= 0.060; ot -= 0.055
        elif 0 <= delta <= 5:  # ngày Tết: ăn nhà, đi thăm gia đình
            f  += 0.080; tr += 0.060; sh -= 0.070; bi -= 0.040; ot -= 0.030

    # Tháng 9 đầu: sách vở, đồng phục
    if month == 9 and dom <= 15:
        sh += 0.060; f -= 0.030; bi -= 0.020; ot -= 0.010

    # 11.11 / Black Friday: mua sắm online
    if month == 11 and dom == 11:
        sh += 0.210; f -= 0.075; tr -= 0.045; bi -= 0.050; ot -= 0.040
    if month == 11 and 22 <= dom <= 25:
        sh += 0.090; f -= 0.035; bi -= 0.030; ot -= 0.025

    # Tháng 12: mua sắm Noel, quà tặng
    if month == 12:
        sh += 0.060; f -= 0.025; bi -= 0.020; ot -= 0.015

    arr = np.array([f, tr, sh, bi, ot], dtype=np.float64)

    # Nhiễu thực tế
    arr += rng.normal(0, [0.022, 0.018, 0.022, 0.018, 0.018])
    arr = np.clip(arr, 0.04, 0.58)
    arr = arr / arr.sum()
    return arr


# ── Generate ─────────────────────────────────────────────────────────────────
rows = []
d = START
while d <= END:
    amt_mean = base_amount(d)

    # Log-normal noise: σ = 0.22 cho biến động ngày tự nhiên
    noise = rng.lognormal(0.0, 0.22)
    total = max(int(round(amt_mean * noise)), 50_000)   # tối thiểu 50k VND

    sh = category_shares(d, total)
    rows.append({
        "date"           : d.isoformat(),
        "total_expense_vnd": total,
        "share_food"     : round(sh[0], 6),
        "share_transport": round(sh[1], 6),
        "share_shopping" : round(sh[2], 6),
        "share_bills"    : round(sh[3], 6),
        "share_other"    : round(sh[4], 6),
    })
    d += timedelta(days=1)

df = pd.DataFrame(rows)
df.to_csv(OUT_PATH, index=False)

# ── Stats ────────────────────────────────────────────────────────────────────
print(f"✅ Đã sinh {len(df):,} ngày  ({df['date'].iloc[0]} → {df['date'].iloc[-1]})")
print(f"   mean  : {df['total_expense_vnd'].mean():>12,.0f} VND")
print(f"   median: {df['total_expense_vnd'].median():>12,.0f} VND")
print(f"   std   : {df['total_expense_vnd'].std():>12,.0f} VND")
print(f"   min   : {df['total_expense_vnd'].min():>12,.0f} VND")
print(f"   max   : {df['total_expense_vnd'].max():>12,.0f} VND")
print()
print("   Share trung bình:")
for col in ["share_food","share_transport","share_shopping","share_bills","share_other"]:
    print(f"     {col:20s}: {df[col].mean():.4f}")
print()

# Kiểm tra pattern Tết
for year in range(2021, 2026):
    tet = TET_DAY.get(year)
    if tet and START <= tet <= END:
        mask = (pd.to_datetime(df["date"]).dt.date >= tet - timedelta(days=3)) & \
               (pd.to_datetime(df["date"]).dt.date <= tet + timedelta(days=5))
        sub = df[mask]
        print(f"   Tết {year} (mùng1 = {tet}): min={sub['total_expense_vnd'].min():,}  max={sub['total_expense_vnd'].max():,}")
