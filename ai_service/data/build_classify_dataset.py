# -*- coding: utf-8 -*-
"""
Phân tích, làm sạch, mở rộng classify_train.csv → classify_train_cleaned.csv
Chạy: python data/build_classify_dataset.py
"""
from __future__ import annotations

import json
import math
import random
import re
import unicodedata
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import pandas as pd

from classify_hard_patterns import generate_all_hard_rows

ROOT = Path(__file__).resolve().parent
HARD_PATTERN_ROWS = generate_all_hard_rows(per_pattern=12)
SRC_CSV = ROOT / "classify_train.csv"
SRC_FALLBACK = ROOT / "classify_train_cleaned.csv"
EDGE_CSV = ROOT / "classify_edge_cases.csv"
OUT_CSV = ROOT / "classify_train_cleaned.csv"
REPORT_BEFORE = ROOT / "classify_dataset_report_before.md"
REPORT_AFTER = ROOT / "classify_dataset_report_after.md"
STATS_JSON = ROOT / "classify_dataset_stats.json"

TARGET_PER_LABEL = 500
SEED = 42
RNG = random.Random(SEED)

ALL_LABELS = [
    "Ăn uống", "Di chuyển", "Mua sắm", "Nhà ở", "Hóa đơn",
    "Giải trí", "Du lịch", "Giáo dục", "Sức khỏe", "Gia đình",
    "Thú cưng", "Quà tặng", "Từ thiện", "Khác",
    "Lương", "Thưởng", "Freelance", "Đầu tư", "Bán hàng", "Thu nhập khác",
]

AMOUNTS = [
    "15k", "18k", "20k", "25k", "30k", "35k", "40k", "45k", "50k", "55k", "60k",
    "70k", "80k", "90k", "100k", "120k", "150k", "180k", "200k", "250k", "300k",
    "350k", "400k", "450k", "500k", "600k", "700k", "800k", "900k", "1tr", "1tr2",
    "1,5tr", "2tr", "2tr5", "3tr", "5tr", "8tr", "10tr", "12tr", "15tr",
    "50.000", "50,000", "50k vnd", "50kđ", "50000", "350.000đ",
]

# Giới hạn lặp semantic / template
MAX_PER_SKELETON = 3
MAX_KEYWORD_RATIO = 0.35  # tỉ lệ mẫu chứa từ khóa "dễ" tối đa sau clean


def strip_accents(s: str) -> str:
    return "".join(
        c for c in unicodedata.normalize("NFD", s)
        if unicodedata.category(c) != "Mn"
    )


def normalize_text(text: str) -> str:
    return re.sub(r"\s+", " ", unicodedata.normalize("NFC", (text or "").strip()))


def amount_skeleton(text: str) -> str:
    """Khung câu sau khi thay mọi số tiền → <AMT>."""
    t = strip_accents(normalize_text(text).lower())
    t = re.sub(r"\d{4}-\d{2}-\d{2}|\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4}", "<DATE>", t)
    t = re.sub(
        r"\d{1,3}(?:[.,]\d{3})*(?:[.,]\d+)?\s*(?:k|nghin|nghìn|ngàn|ngan|tr|triệu|trieu|trăm|đ|vnd|vnđ)?",
        "<AMT>",
        t,
        flags=re.IGNORECASE,
    )
    t = re.sub(r"(<AMT>\s*)+", "<AMT> ", t)
    t = re.sub(r"\s+", " ", t).strip()
    return t


def read_edge_cases() -> list[tuple[str, str]]:
    if not EDGE_CSV.is_file():
        return []
    rows: list[tuple[str, str]] = []
    for line in EDGE_CSV.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or line.startswith("text,"):
            continue
        if "," not in line:
            continue
        text, label = line.rsplit(",", 1)
        text, label = text.strip(), label.strip()
        if text and label in ALL_LABELS:
            rows.append((text, label))
    return rows


def load_raw() -> pd.DataFrame:
    src = SRC_CSV if SRC_CSV.is_file() else SRC_FALLBACK
    if not src.is_file():
        raise FileNotFoundError(f"Missing {SRC_CSV} and {SRC_FALLBACK}")
    df = pd.read_csv(src, encoding="utf-8")
    df["text"] = df["text"].astype(str).str.strip()
    df["label"] = df["label"].astype(str).str.strip()
    edge = read_edge_cases()
    if edge:
        df = pd.concat([df, pd.DataFrame(edge, columns=["text", "label"])], ignore_index=True)
    df = df[df["text"].str.len() > 0]
    df = df[df["label"].isin(ALL_LABELS)]
    return df


@dataclass
class DatasetStats:
    total_rows: int
    num_labels: int
    label_counts: dict[str, int]
    exact_dup_rows: int
    conflict_texts: int
    missing_text: int
    missing_label: int
    avg_text_len: float
    duplicate_pct: float
    unique_text_pct: float
    vocab_size: int
    imbalance_ratio: float
    top_skeleton_repeats: list[tuple[str, int]]
    keyword_leakage: dict[str, dict[str, float]]

    def to_dict(self) -> dict:
        return {
            "total_rows": self.total_rows,
            "num_labels": self.num_labels,
            "label_counts": self.label_counts,
            "exact_dup_rows": self.exact_dup_rows,
            "conflict_texts": self.conflict_texts,
            "missing_text": self.missing_text,
            "missing_label": self.missing_label,
            "avg_text_len": round(self.avg_text_len, 2),
            "duplicate_pct": round(self.duplicate_pct, 4),
            "unique_text_pct": round(self.unique_text_pct, 4),
            "vocab_size": self.vocab_size,
            "imbalance_ratio": round(self.imbalance_ratio, 3),
            "top_skeleton_repeats": self.top_skeleton_repeats[:15],
            "keyword_leakage": self.keyword_leakage,
        }


KEYWORD_HINTS: dict[str, list[str]] = {
    "Lương": ["lương", "luong", "salary"],
    "Thưởng": ["thưởng", "thuong", "bonus"],
    "Ăn uống": ["ăn", "an ", "cơm", "phở", "food", "cafe", "cf "],
    "Di chuyển": ["grab", "xăng", "xang", "taxi", "xe "],
    "Hóa đơn": ["điện", "dien", "nước", "nuoc", "wifi", "hóa đơn"],
    "Quà tặng": ["quà", "qua ", "tặng", "tang ", "mừng"],
    "Thu nhập khác": ["hoàn", "hoan", "refund", "cashback", "nhận"],
}


def compute_stats(df: pd.DataFrame, phase: str) -> DatasetStats:
    label_counts = df["label"].value_counts().to_dict()
    counts = list(label_counts.values()) or [1]
    imb = max(counts) / max(min(counts), 1)

    sk = df.apply(lambda r: (amount_skeleton(r["text"]), r["label"]), axis=1)
    sk_counter = Counter(sk)
    top_sk = [(f"{s}|{l}", c) for (s, l), c in sk_counter.most_common(20) if c > 5]

    conflicts = int((df.groupby("text")["label"].nunique() > 1).sum())
    exact_dup = int(df.duplicated(subset=["text", "label"]).sum())
    unique_text = df["text"].nunique() / max(len(df), 1)

    vocab = set("".join(df["text"].tolist()))

    kw_leak: dict[str, dict[str, float]] = {}
    for lbl, hints in KEYWORD_HINTS.items():
        sub = df[df["label"] == lbl]
        if len(sub) == 0:
            continue
        hit = sum(
            1
            for t in sub["text"]
            if any(h in strip_accents(t.lower()) for h in hints)
        )
        kw_leak[lbl] = {"keyword_hit_ratio": round(hit / len(sub), 3), "n": len(sub)}

    return DatasetStats(
        total_rows=len(df),
        num_labels=df["label"].nunique(),
        label_counts={k: int(v) for k, v in sorted(label_counts.items())},
        exact_dup_rows=exact_dup,
        conflict_texts=conflicts,
        missing_text=int((df["text"] == "").sum()),
        missing_label=int((~df["label"].isin(ALL_LABELS)).sum()),
        avg_text_len=float(df["text"].str.len().mean()),
        duplicate_pct=1.0 - unique_text,
        unique_text_pct=unique_text,
        vocab_size=len(vocab),
        imbalance_ratio=imb,
        top_skeleton_repeats=top_sk,
        keyword_leakage=kw_leak,
    )


def write_report(stats: DatasetStats, path: Path, title: str) -> None:
    lines = [
        f"# {title}",
        "",
        f"- **Tổng dòng:** {stats.total_rows:,}",
        f"- **Số nhãn:** {stats.num_labels}",
        f"- **Độ dài text TB:** {stats.avg_text_len:.1f} ký tự",
        f"- **% text unique:** {stats.unique_text_pct * 100:.1f}%",
        f"- **Duplicate row (text+label):** {stats.exact_dup_rows}",
        f"- **Text trùng khác label (conflict):** {stats.conflict_texts}",
        f"- **Imbalance ratio (max/min):** {stats.imbalance_ratio:.2f}",
        f"- **Vocabulary size (ký tự):** {stats.vocab_size}",
        "",
        "## Phân bố label",
        "",
        "| Label | Count |",
        "|-------|------:|",
    ]
    for lbl in ALL_LABELS:
        lines.append(f"| {lbl} | {stats.label_counts.get(lbl, 0)} |")
    lines.extend(["", "## Skeleton lặp nhiều (template risk)", ""])
    for sk, c in stats.top_skeleton_repeats[:12]:
        lines.append(f"- `{sk}` → **{c}** lần")
    lines.extend(["", "## Keyword leakage (tỉ lệ mẫu chứa từ “dễ đoán”)", ""])
    for lbl, info in stats.keyword_leakage.items():
        lines.append(f"- **{lbl}:** {info['keyword_hit_ratio']*100:.0f}% ({info['n']} mẫu)")
    path.write_text("\n".join(lines), encoding="utf-8")


def resolve_conflicts(df: pd.DataFrame) -> pd.DataFrame:
    """Text trùng nhãn khác nhau → giữ nhãn phổ biến nhất, bỏ bản còn lại."""
    rows = []
    for text, grp in df.groupby("text"):
        if len(grp) == 1:
            rows.append(grp.iloc[0])
            continue
        lbl = grp["label"].value_counts().index[0]
        rows.append(grp[grp["label"] == lbl].iloc[0])
    return pd.DataFrame(rows).reset_index(drop=True)


def cap_skeleton_duplicates(df: pd.DataFrame, max_per: int = MAX_PER_SKELETON) -> pd.DataFrame:
    kept: list[dict] = []
    bucket: dict[tuple[str, str], int] = defaultdict(int)
    # Ưu tiên câu dài / đa dạng hơn
    df = df.copy()
    df["_len"] = df["text"].str.len()
    df = df.sort_values("_len", ascending=False)
    for _, row in df.iterrows():
        key = (amount_skeleton(row["text"]), row["label"])
        if bucket[key] >= max_per:
            continue
        bucket[key] += 1
        kept.append({"text": row["text"], "label": row["label"]})
    return pd.DataFrame(kept)


def drop_keyword_heavy(df: pd.DataFrame, label: str, hints: list[str], max_ratio: float) -> pd.DataFrame:
    sub = df[df["label"] == label]
    rest = df[df["label"] != label]
    if sub.empty:
        return df

    def has_kw(t: str) -> bool:
        tl = strip_accents(t.lower())
        return any(h in tl for h in hints)

    flagged = [(i, has_kw(t)) for i, t in zip(sub.index, sub["text"])]
    kw_rows = sub.loc[[i for i, f in flagged if f]]
    non_kw = sub.loc[[i for i, f in flagged if not f]]

    limit = max(1, int(len(sub) * max_ratio))
    if len(kw_rows) > limit:
        kw_rows = kw_rows.sample(n=limit, random_state=SEED)
    return pd.concat([rest, non_kw, kw_rows], ignore_index=True)


_ABB_SWAP = [
    ("chuyển khoản", "ck"), ("chuyen khoan", "ck"),
    ("điện thoại", "dt"), ("dien thoai", "dt"),
    ("cafe", "cf"), ("cà phê", "cf"),
    ("triệu", "tr"), ("trieu", "tr"),
    ("ngàn", "k"), ("nghìn", "k"),
]
_TYPO_SWAPS = [("trọ", "tro"), ("mới", "moi"), ("lãi", "lai"), ("đầu tư", "dau tu")]


def augment_sample(text: str, label: str) -> list[tuple[str, str]]:
    """Biến thể nhẹ — typo, viết tắt, tiền, không dấu."""
    out: list[tuple[str, str]] = []
    t = text

    if RNG.random() < 0.3:
        out.append((strip_accents(t), label))
    if RNG.random() < 0.25:
        out.append((t.lower(), label))
    if RNG.random() < 0.2:
        out.append((t.upper() if RNG.random() < 0.5 else t, label))
    if RNG.random() < 0.15 and len(t) < 80:
        emojis = {"Ăn uống": " 🍜", "Di chuyển": " 🚗", "Mua sắm": " 🛍️", "Giải trí": " 🎬"}.get(label, "")
        if emojis:
            out.append((t + emojis, label))
    if RNG.random() < 0.2:
        out.append((re.sub(r"(\d+)k\b", r"\1K", t, flags=re.I), label))
    if RNG.random() < 0.18:
        out.append((re.sub(r"(\d+)tr\b", r"\1 triệu", t, flags=re.I), label))
    if RNG.random() < 0.15:
        tl = f" {t.lower()} "
        for a, b in _ABB_SWAP:
            if RNG.random() < 0.35 and a in tl:
                out.append((normalize_text(tl.replace(a, b, 1).strip()), label))
            elif RNG.random() < 0.35 and b in tl:
                out.append((normalize_text(tl.replace(b, a, 1).strip()), label))
    if RNG.random() < 0.12:
        for a, b in _TYPO_SWAPS:
            if a in t:
                out.append((t.replace(a, b), label))
                break
    if RNG.random() < 0.1 and len(t) > 6:
        chars = list(t)
        i = RNG.randrange(len(chars))
        del chars[i]
        out.append(("".join(chars), label))
    return [(normalize_text(a), b) for a, b in out if a and normalize_text(a) != normalize_text(t)]


# ── Curated generation (realistic, đa phong cách) ─────────────────────────────

def _pick_amount() -> str:
    return RNG.choice(AMOUNTS)


def gen_pools() -> dict[str, list[str]]:
    """Mẫu gốc đa dạng — không lặp template Be Xk."""
    pools: dict[str, list[str]] = {}

    pools["Ăn uống"] = [
        "grab 50k", "ăn tối 🍜", "an trua 45k", "order trà sữa",
        "hôm nay tan học muộn đặt grab food về mất gần 80k",
        "ờm chắc hôm nay lỡ order trà sữa {a}",
        "canteen trường {a}", "bữa trưa VP {a}", "coffee meeting nhẹ {a}",
        "cf với team {a}", "ăn vặt cuối tuần {a}", "nấu cơm nhà tốn nguyên liệu {a}",
        "shopeefood giao về {a}", "buffet tối bạn bè {a}", "phở tái nạm sáng {a}",
        "5/5 đi ăn lẩu {a}", "cuối tháng ăn mì gói survival {a}",
        "toang ví bay màu vì đồ ăn delivery {a}", "GRAB FOOD {a}",
    ]
    pools["Di chuyển"] = [
        "grab 50k", "grab 🚗", "GRAB 50K", "Grab 50K",
        "đi grab từ trường về nhà {a}", "xăng xe máy {a}", "do xang {a}",
        "claim tiền taxi khách hàng {a}", "taxi sân bay {a}", "gửi xe chung cư {a}",
        "vé bus về quê {a}", "phạt giao thông {a}", "sửa lốp xe {a}",
        "grab office về nhà muộn {a}", "be bike đi làm {a}", "xanh sm {a}",
        "phí cầu đường {a}", "đăng kiểm {a}",
    ]
    pools["Mua sắm"] = [
        "shopping 🛍️", "mua do shopee {a}", "mua đồ an vat {a}",
        "cắt tóc barber {a}", "spa nail {a}", "mua áo sale {a}",
        "lazada flash sale {a}", "mua sim dt {a}", "order phụ kiện điện thoại {a}",
        "mua son môi {a}", "sắm đồ cuối tuần {a}",
    ]
    pools["Nhà ở"] = [
        "ck tiền thuê trọ {a}", "pay rent {a}", "tra tien phong {a}",
        "thanh toán tiền thuê nhà tháng 5", "đóng tiền thuê phòng xong nghèo luôn",
        "tiền nhà tháng 6 {a}", "sửa điều hòa {a}", "mua quạt {a}", "gas bếp {a}",
    ]
    pools["Hóa đơn"] = [
        "nap dt 100k", "nạp tiền điện thoại {a}", "đóng tiền điện xong nghèo luôn",
        "thanh toán tiền điện tháng 5", "tiền điện EVN {a}", "wifi nhà {a}",
        "nước sinh hoạt {a}", "phí ngân hàng {a}", "nộp thuế TNCN {a}",
        "quên mất vừa đóng tiền điện", "hoa don internet {a}",
    ]
    pools["Giải trí"] = [
        "xem phim {a}", "netflix tháng {a}", "karaoke đêm {a}", "chơi game nạp thẻ {a}",
        "steam mua game {a}", "vé concert {a}", "cafe ngồi chơi {a}",
        "bowling cuối tuần {a}", "câu cá {a}",
    ]
    pools["Du lịch"] = [
        "vé máy bay {a}", "khách sạn {a}", "tour {a}", "visa du lịch {a}",
        "thuê xe du lịch {a}", "ăn uống chuyến đi {a}", "mua quà lưu niệm {a}",
    ]
    pools["Giáo dục"] = [
        "học phí kỳ 2 {a}", "mua sách ôn thi {a}", "khóa online {a}",
        "cho con học phí {a}", "gia sư {a}", "học tiếng Anh {a}",
    ]
    pools["Sức khỏe"] = [
        "khám bệnh {a}", "mua thuốc cảm {a}", "nhổ răng {a}", "gym tháng {a}",
        "bảo hiểm y tế {a}", "xét nghiệm {a}",
    ]
    pools["Gia đình"] = [
        "gửi tiền về quê {a}", "cho con tiêu vặt {a}", "mua sữa bé {a}",
        "tiền ăn cả nhà {a}", "trả mẹ tiền ăn {a}", "lo cho ba mẹ thuốc {a}",
        "mua đồ cho con {a}", "tiền học con {a}", "viện phí cha {a}",
    ]
    pools["Thú cưng"] = [
        "mua cát mèo {a}", "tiêm phòng chó {a}", "thức ăn Royal Canin {a}",
        "khám thú y {a}", "pet shop {a}",
    ]
    pools["Quà tặng"] = [
        "cho bạn quà sn {a}", "tặng hoa 8/3 {a}", "phong bì cưới {a}",
        "mừng tân gia {a}", "quà tết {a}", "gift card {a}",
    ]
    pools["Từ thiện"] = [
        "ủng hộ lũ lụt {a}", "quyên góp {a}", "góp quỹ {a}",
    ]
    pools["Khác"] = [
        "50k", "linh tinh {a}", "phí không rõ {a}", "sửa laptop {a}",
        "ủa mất tiền đâu vậy", "grab hay cf nhỉ",
    ]
    pools["Lương"] = [
        "cty vừa chuyển khoản {a}", "HR vừa gửi tiền {a}", "tiền tháng này về tk {a}",
        "tk tăng bất thường sáng nay {a}", "vcb +{a} lương", "mb nhận tiền công ty {a}",
        "salary received {a}", "payroll {a}", "kỳ lương 15 hàng tháng {a}",
        "nhận tiền công tháng {a}",  # giữ một phần trực tiếp
    ]
    pools["Thưởng"] = [
        "bonus quý {a}", "thưởng dự án xong {a}", "KPI đạt nhận {a}",
        "cty thưởng tết {a}", "thuong du an {a}",
    ]
    pools["Freelance"] = [
        "nhận tiền thiết kế logo {a}", "client thanh toán invoice {a}",
        "freelance website {a}", "dạy kèm {a}", "shipper nhận công {a}",
    ]
    pools["Đầu tư"] = [
        "cổ tức {a}", "lãi tiết kiệm {a}", "lãi gửi kỳ hạn {a}", "profit trading {a}",
    ]
    pools["Bán hàng"] = [
        "bán đồ cũ {a}", "doanh thu shopee {a}", "khách ck đặt hàng {a}",
        "thu tiền bán hàng {a}",
    ]
    pools["Thu nhập khác"] = [
        "nhận sinh nhật {a}", "nhan sinh nhat {a}", "hoàn tiền đơn {a}",
        "cashback {a}", "refund {a}", "mẹ ck cho {a}", "nhận lại cọc {a}",
        "được mừng cưới {a}", "tiền mừng nhận {a}",
    ]

    # Expand {a} placeholders
    expanded: dict[str, list[str]] = {}
    for lbl, templates in pools.items():
        texts: list[str] = []
        for tpl in templates:
            if "{a}" in tpl:
                for _ in range(8):
                    texts.append(tpl.replace("{a}", _pick_amount()))
            else:
                if any(c.isdigit() for c in tpl):
                    texts.append(tpl)
                else:
                    for _ in range(3):
                        texts.append(f"{tpl} {_pick_amount()}")
        expanded[lbl] = texts
    return expanded


# Hard negatives & ambiguous (cặp có chủ đích)
HARD_NEGATIVES: list[tuple[str, str]] = [
    ("mẹ gửi tiền ăn", "Thu nhập khác"),
    ("trả mẹ tiền ăn", "Gia đình"),
    ("nhận quà sinh nhật 500k", "Thu nhập khác"),
    ("tặng quà sinh nhật bạn 500k", "Quà tặng"),
    ("nhận tiền mừng cưới 1tr", "Thu nhập khác"),
    ("mừng cưới bạn 1tr", "Quà tặng"),
    ("nhận lương 10tr", "Lương"),
    ("chi lương nhân viên 10tr", "Khác"),
    ("coffee client meeting 200k", "Ăn uống"),
    ("cafe bạn bè cuối tuần 150k", "Giải trí"),
    ("coffee work expense 180k", "Ăn uống"),
    ("grab hay cf nhỉ", "Khác"),
    ("pay tiền phòng", "Nhà ở"),
    ("pay rent 3tr", "Nhà ở"),
    ("ck tiền thuê trọ", "Nhà ở"),
    ("ck tiền trọ", "Nhà ở"),
    ("ck tro 2tr5", "Nhà ở"),
    ("dt mới 15tr", "Mua sắm"),
    ("dt moi 15tr", "Mua sắm"),
    ("mb ck freelance", "Freelance"),
    ("đầu tư coin lời 2tr", "Đầu tư"),
    ("dau tu coin loi 2tr", "Đầu tư"),
    ("ck nhận mừng cưới", "Thu nhập khác"),
]

# Combinatorial diversity (tránh Be 20k / Be 30k)
_STYLE_PREFIX = {
    "Ăn uống": ["", "đặt ", "order ", "ăn ", "uống ", "nhậu ", "nấu "],
    "Di chuyển": ["", "đi ", "book ", "thanh toán ", "trả ", "chi phí "],
    "Mua sắm": ["", "mua ", "sắm ", "order ", "chốt đơn "],
}
_ITEM_VARIANTS: dict[str, list[str]] = {
    "Ăn uống": [
        "cơm tấm", "phở bò", "bún chả", "trà sữa", "cà phê", "pizza", "lẩu", "sushi",
        "bánh mì", "đồ ăn vặt", "cơm hộp", "grab food", "shopeefood", "canteen",
    ],
    "Di chuyển": [
        "grab bike", "grab car", "be", "xanh sm", "xe bus", "xe khách", "taxi",
        "xăng xe", "gửi xe", "vé metro", "cầu đường", "sửa xe", "đăng kiểm",
    ],
    "Mua sắm": [
        "áo thun", "giày", "túi", "son", "tai nghe", "ốp lưng", "quần jean",
        "đồ gia dụng", "nồi chiên", "shopee", "lazada",
        "dt mới", "điện thoại mới", "iphone", "macbook",
    ],
    "Hóa đơn": ["điện", "nước", "wifi", "internet", "gas", "nạp dt", "sim", "phí bank"],
    "Giải trí": ["phim", "netflix", "game", "karaoke", "bowling", "concert", "spotify"],
    "Nhà ở": ["thuê trọ", "tiền trọ", "ck tiền trọ", "thuê nhà", "sửa nhà", "nội thất", "gas bếp", "quạt"],
    "Giáo dục": ["học phí", "sách", "khóa học", "gia sư", "đồ dùng học"],
    "Sức khỏe": ["khám bệnh", "thuốc", "nha khoa", "gym", "vitamin"],
    "Gia đình": ["ba mẹ", "con", "ông bà", "tiền về quê", "sữa bé"],
    "Thú cưng": ["thức ăn chó", "cát mèo", "thú y", "tiêm phòng"],
    "Quà tặng": ["sinh nhật", "cưới", "tết", "hoa", "quà bạn"],
    "Từ thiện": ["ủng hộ", "quyên góp", "từ thiện", "giúp đỡ"],
    "Khác": ["linh tinh", "phát sinh", "không rõ", "sửa đồ"],
    "Lương": [
        "khoản cty chuyển", "tiền công ty", "payroll", "lương kỳ",
        "HR chuyển", "tk nhận tiền tháng",
    ],
    "Thưởng": ["bonus", "thưởng dự án", "KPI", "thưởng tết", "incentive"],
    "Freelance": ["logo", "website", "content", "dạy kèm", "chụp ảnh", "video", "mb ck freelance", "freelance"],
    "Đầu tư": ["cổ tức", "lãi tiết kiệm", "trái phiếu", "cho thuê", "coin", "crypto", "đầu tư coin"],
    "Bán hàng": ["bán đồ cũ", "shopee", "doanh thu", "khách ck"],
    "Thu nhập khác": [
        "hoàn tiền", "cashback", "refund", "nhận mừng", "nhận quà", "cọc trả lại",
    ],
}


def combinatorial_generate(label: str, n: int) -> list[str]:
    items = _ITEM_VARIANTS.get(label, [label])
    prefixes = _STYLE_PREFIX.get(label, ["", "chi ", "trả ", ""])
    ctx = [
        "", "hôm nay ", "cuối tuần ", "ờm ", "vừa ", "tối qua ",
        "tháng này ", "05-05-2026 ", "cuối tháng ",
    ]
    out: list[str] = []
    suffixes = [
        "", " rồi", " vừa xong", " lần này", " hơi đau ví", " thật", " nhé",
        " luôn", " xong", " đấy", " á", " haiz",
    ]
    for _ in range(n * 4):
        p = RNG.choice(prefixes)
        it = RNG.choice(items)
        c = RNG.choice(ctx)
        a = _pick_amount()
        s = RNG.choice(suffixes)
        t = normalize_text(f"{c}{p}{it} {a}{s}")
        out.append(t)
    return out


EDGE_SHORT_LONG: list[tuple[str, str]] = [
    ("ck tiền trọ", "Nhà ở"),
    ("dt mới 15tr", "Mua sắm"),
    ("mb ck freelance", "Freelance"),
    ("đầu tư coin lời 2tr", "Đầu tư"),
    ("50k", "Khác"),
    ("ủa mất tiền đâu vậy", "Khác"),
    (
        "hôm nay tan ca muộn phải đặt grab bike từ khu công nghiệp về trọ "
        "mất gần 80k chắc tháng sau đi bus cho đỡ tốn",
        "Di chuyển",
    ),
    ("2026-05-05 thanh toán học phí", "Giáo dục"),
    ("05-05-2026 điện", "Hóa đơn"),
    ("tháng 5 cuối tháng đóng tiền điện luôn", "Hóa đơn"),
]


def instantiate_templates(pools: dict[str, list[str]]) -> list[tuple[str, str]]:
    rows: list[tuple[str, str]] = []
    for lbl, texts in pools.items():
        for t in texts:
            rows.append((normalize_text(t), lbl))
    return rows


def _try_add(
    out: list[tuple[str, str]],
    seen: set[str],
    sk_count: Counter,
    text: str,
    label: str,
    skeleton_cap: int,
) -> bool:
    t = normalize_text(text)
    if not t or t in seen:
        return False
    sk = amount_skeleton(t)
    if sk_count[sk] >= skeleton_cap:
        return False
    seen.add(t)
    sk_count[sk] += 1
    out.append((t, label))
    return True


def fill_to_target(
    existing: list[tuple[str, str]],
    label: str,
    target: int,
    skeleton_cap: int = MAX_PER_SKELETON,
) -> list[tuple[str, str]]:
    out = [(t, l) for t, l in existing if l == label]
    seen = {t for t, _ in out}
    sk_count: Counter = Counter(amount_skeleton(t) for t, _ in out)

    # Ưu tiên giữ hard-pattern (skeleton_cap cao hơn)
    for t, l in HARD_PATTERN_ROWS:
        if l == label:
            _try_add(out, seen, sk_count, t, label, skeleton_cap=12)

    pools_once = gen_pools()
    for t in pools_once.get(label, []):
        if len(out) >= target:
            break
        _try_add(out, seen, sk_count, t, label, skeleton_cap)

    for t in combinatorial_generate(label, target * 4):
        if len(out) >= target:
            break
        _try_add(out, seen, sk_count, t, label, skeleton_cap)

    attempts = 0
    while len(out) < target and attempts < target * 8:
        attempts += 1
        base = combinatorial_generate(label, 1)[0]
        _try_add(out, seen, sk_count, base, label, skeleton_cap)
        for v, _ in augment_sample(base, label):
            if len(out) >= target:
                break
            _try_add(out, seen, sk_count, v, label, skeleton_cap)

    while len(out) < target:
        t = combinatorial_generate(label, 1)[0]
        if not _try_add(out, seen, sk_count, t, label, skeleton_cap + 2):
            t = f"{t} ({len(out)})"
            _try_add(out, seen, sk_count, t, label, skeleton_cap + 2)
    return out[:target]


def _inject_hard_patterns(df: pd.DataFrame, max_per_label: int = 40) -> pd.DataFrame:
    """Thay một phần mẫu generic bằng hard-pattern chưa có trong CSV."""
    by_label: dict[str, list[tuple[str, str]]] = defaultdict(list)
    for t, l in HARD_PATTERN_ROWS:
        t = normalize_text(t)
        if t and l in ALL_LABELS:
            by_label[l].append((t, l))

    existing = set(zip(df["text"], df["label"]))
    rows = df.to_dict("records")
    for lbl in ALL_LABELS:
        candidates = [(t, l) for t, l in by_label.get(lbl, []) if (t, l) not in existing]
        if not candidates:
            continue
        RNG.shuffle(candidates)
        add = candidates[:max_per_label]
        if not add:
            continue
        # Bỏ bớt mẫu cũ cùng nhãn (ưu tiên xóa câu dài / không chứa marker hard)
        idxs = [i for i, r in enumerate(rows) if r["label"] == lbl]
        drop_n = min(len(add), len(idxs) // 4)
        for i in sorted(RNG.sample(idxs, drop_n), reverse=True):
            rows.pop(i)
        for t, l in add:
            rows.append({"text": t, "label": l})
            existing.add((t, l))

    out = pd.DataFrame(rows)
    # Cân lại đúng 500/nhãn
    balanced: list[dict] = []
    for lbl in ALL_LABELS:
        sub = [r for r in rows if r["label"] == lbl]
        if len(sub) > TARGET_PER_LABEL:
            sub = RNG.sample(sub, TARGET_PER_LABEL)
        elif len(sub) < TARGET_PER_LABEL:
            sub.extend(
                {"text": t, "label": l}
                for t, l in fill_to_target([], lbl, TARGET_PER_LABEL, skeleton_cap=5)
            )
            sub = sub[:TARGET_PER_LABEL]
        balanced.extend(sub)
    return pd.DataFrame(balanced)


def build_clean_dataset() -> pd.DataFrame:
    raw = load_raw()
    stats_before = compute_stats(raw, "before")
    write_report(stats_before, REPORT_BEFORE, "Báo cáo dataset TRƯỚC khi xử lý")

    df = raw.drop_duplicates(subset=["text", "label"]).copy()
    df = resolve_conflicts(df)
    df = cap_skeleton_duplicates(df, MAX_PER_SKELETON)

    for lbl, hints in KEYWORD_HINTS.items():
        if lbl in ("Lương", "Thưởng", "Thu nhập khác"):
            df = drop_keyword_heavy(df, lbl, hints, MAX_KEYWORD_RATIO)

    rows: list[tuple[str, str]] = list(zip(df["text"], df["label"]))
    rows.extend(HARD_PATTERN_ROWS)
    rows.extend(HARD_NEGATIVES)
    rows.extend(EDGE_SHORT_LONG)
    rows.extend(instantiate_templates(gen_pools()))

    # Balance
    balanced: list[tuple[str, str]] = []
    by_label: dict[str, list[tuple[str, str]]] = defaultdict(list)
    for t, l in rows:
        t = normalize_text(t)
        if t and l in ALL_LABELS:
            by_label[l].append((t, l))

    for lbl in ALL_LABELS:
        balanced.extend(fill_to_target(by_label[lbl], lbl, TARGET_PER_LABEL, skeleton_cap=4))

    final_df = pd.DataFrame(balanced, columns=["text", "label"]).drop_duplicates(subset=["text", "label"])
    final_df = resolve_conflicts(final_df)

    # Đủ 500 / nhãn
    topped: list[tuple[str, str]] = []
    for lbl in ALL_LABELS:
        sub = list(zip(final_df[final_df["label"] == lbl]["text"], final_df[final_df["label"] == lbl]["label"]))
        topped.extend(fill_to_target(sub, lbl, TARGET_PER_LABEL, skeleton_cap=3))
    final_df = pd.DataFrame(topped, columns=["text", "label"]).drop_duplicates(subset=["text", "label"])
    final_df = resolve_conflicts(final_df)

    final_df = _inject_hard_patterns(final_df, max_per_label=45)

    records = final_df.to_dict("records")
    RNG.shuffle(records)
    final_df = pd.DataFrame(records)

    stats_after = compute_stats(final_df, "after")
    write_report(stats_after, REPORT_AFTER, "Báo cáo dataset SAU khi xử lý (production-ready)")
    STATS_JSON.write_text(
        json.dumps({"before": stats_before.to_dict(), "after": stats_after.to_dict()}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    return final_df


def main() -> None:
    print("Loading and analyzing...")
    final_df = build_clean_dataset()
    final_df.to_csv(OUT_CSV, index=False, encoding="utf-8")
    print(f"Wrote {OUT_CSV} ({len(final_df)} rows)")
    print(f"Reports: {REPORT_BEFORE.name}, {REPORT_AFTER.name}")
    dist = final_df["label"].value_counts().to_dict()
    (ROOT / "classify_label_distribution.json").write_text(
        json.dumps({k: int(dist.get(k, 0)) for k in ALL_LABELS}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    hard_in_final = sum(
        1 for t in final_df["text"] if any(t == ht for ht, _ in HARD_PATTERN_ROWS)
    )
    audit = {
        "total_rows": len(final_df),
        "per_label": {k: int(dist.get(k, 0)) for k in ALL_LABELS},
        "hard_pattern_source_rows": len(HARD_PATTERN_ROWS),
        "hard_rows_in_final_approx": hard_in_final,
        "duplicate_text_label": int(final_df.duplicated(subset=["text", "label"]).sum()),
    }
    (ROOT / "classify_dataset_audit.json").write_text(
        json.dumps(audit, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print("Audit:", audit)


if __name__ == "__main__":
    main()
