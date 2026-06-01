# -*- coding: utf-8 -*-
"""Audit classify_train_cleaned.csv — chạy: python audit_classify_dataset.py"""
from __future__ import annotations

import json
import re
from collections import Counter, defaultdict
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parent
CSV = ROOT / "classify_train_cleaned.csv"
OUT_JSON = ROOT / "classify_dataset_audit_full.json"
OUT_MD = ROOT / "DATASET_AUDIT.md"

ALL_LABELS = [
    "Ăn uống", "Di chuyển", "Mua sắm", "Nhà ở", "Hóa đơn",
    "Giải trí", "Du lịch", "Giáo dục", "Sức khỏe", "Gia đình",
    "Thú cưng", "Quà tặng", "Từ thiện", "Khác",
    "Lương", "Thưởng", "Freelance", "Đầu tư", "Bán hàng", "Thu nhập khác",
]

HARD_MARKERS = {
    "Bán hàng": ["khách", "bán", "ban hang", "cod", "doanh thu"],
    "Mua sắm": ["ram", "ssd", "linh kiện", "phụ kiện", "dt mới"],
    "Hóa đơn": ["phí chuyển", "phí ngân", "wifi", "điện", "nước"],
    "Nhà ở": ["trọ", "thuê phòng", "sơn tường", "cọc"],
    "Di chuyển": ["vé tàu", "xăng", "bảo hiểm xe", "gửi xe"],
    "Du lịch": ["hostel", "resort", "visa", "homestay", "tour"],
    "Gia đình": ["cho mẹ", "cho em", "ba mẹ", "về quê"],
    "Sức khỏe": ["khám", "thuốc cho bản thân", "nha khoa", "vitamin"],
    "Khác": ["linh tinh", "không phân loại", "mượn bạn"],
    "Thu nhập khác": ["hoàn tiền", "refund", "cashback", "cọc"],
}

_KW_EASY = re.compile(
    r"\b(grab|shopee|lazada|momo|vcb|ăn|phở|cafe|lương|bonus|freelance)\b",
    re.I,
)


def audit(df: pd.DataFrame) -> dict:
    df = df.copy()
    df["text"] = df["text"].astype(str).str.strip()
    df["label"] = df["label"].astype(str).str.strip()

    dup_text = int(df.duplicated(subset=["text"]).sum())
    dup_pair = int(df.duplicated(subset=["text", "label"]).sum())
    conflict = df.groupby("text")["label"].nunique()
    conflict_texts = conflict[conflict > 1]
    label_counts = df["label"].value_counts().to_dict()

    hard_cov: dict[str, dict] = {}
    for lbl, markers in HARD_MARKERS.items():
        sub = df[df["label"] == lbl]
        hits = sum(
            1 for t in sub["text"]
            if any(m in t.lower() for m in markers)
        )
        hard_cov[lbl] = {
            "total": int(len(sub)),
            "hard_marker_hits": hits,
            "ratio": round(hits / max(len(sub), 1), 3),
        }

    easy_ratio = float(
        df["text"].str.contains(_KW_EASY, regex=True, na=False).mean()
    )

    return {
        "total_rows": len(df),
        "num_classes": df["label"].nunique(),
        "per_label": {k: int(label_counts.get(k, 0)) for k in ALL_LABELS},
        "duplicate_text_rows": dup_text,
        "duplicate_text_label_rows": dup_pair,
        "conflicting_texts": int(len(conflict_texts)),
        "conflict_examples": [
            {"text": t, "labels": df[df["text"] == t]["label"].unique().tolist()}
            for t in list(conflict_texts.index[:10])
        ],
        "hard_coverage": hard_cov,
        "global_easy_keyword_ratio": round(easy_ratio, 4),
        "avg_text_len": round(df["text"].str.len().mean(), 1),
        "short_text_lt_12": int((df["text"].str.len() < 12).sum()),
    }


def main() -> None:
    if not CSV.is_file():
        raise FileNotFoundError(CSV)
    df = pd.read_csv(CSV, encoding="utf-8")
    before = len(df)
    df = df.drop_duplicates(subset=["text", "label"])
    bad = df.groupby("text")["label"].filter(lambda s: s.nunique() > 1)
    if len(bad):
        df = df[~df["text"].isin(bad.index.unique())]
    report = audit(df)
    report["rows_before_dedup"] = before
    report["rows_after_safe_dedup"] = len(df)

    OUT_JSON.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    lines = [
        "# Dataset audit — classify_train_cleaned.csv",
        "",
        f"- Rows: **{report['total_rows']}** ({report['num_classes']} classes)",
        f"- Duplicate text: {report['duplicate_text_rows']}",
        f"- Duplicate (text,label): {report['duplicate_text_label_rows']}",
        f"- Conflicting labels same text: **{report['conflicting_texts']}**",
        f"- Easy-keyword ratio: {report['global_easy_keyword_ratio']}",
        f"- Short text (<12 chars): {report['short_text_lt_12']}",
        "",
        "## Per class",
        "",
    ]
    for lbl in ALL_LABELS:
        n = report["per_label"].get(lbl, 0)
        hc = report["hard_coverage"].get(lbl, {})
        lines.append(f"- **{lbl}**: {n} samples, hard-marker ratio {hc.get('ratio', 0)}")
    OUT_MD.write_text("\n".join(lines), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    print("Wrote", OUT_JSON, OUT_MD)


if __name__ == "__main__":
    main()
