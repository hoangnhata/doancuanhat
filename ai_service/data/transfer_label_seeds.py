"""
Sửa pseudo-label bill chuyển khoản trước khi upload Colab / train.

Chạy: python data/transfer_label_seeds.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import pandas as pd  # noqa: E402

REAL_DIR = ROOT / "data" / "real_lines"
CSV = REAL_DIR / "labels.csv"

# Regex sửa trên mọi ảnh (text hiện tại -> text chuẩn)
GLOBAL_FIXES: list[tuple[str, str]] = [
    (r"^Tung me 83$", "mung me 8/3"),
    (r"^Chuyển tiền thành côngi?$", "Chuyển tiền thành công!"),
    (r"^(\d{1,3}(?:,\d{3})+) VND$", lambda m: m.group(1).replace(",", ".") + " VND"),
    (r"^(\d{1,3}(?:\.\d{3})+) VND$", lambda m: m.group(0)),  # giữ dạng 1.000.000
]

# Theo file ảnh: pattern -> replacement
SEEDS: dict[str, list[tuple[str, str]]] = {
    "2ccf28fd-bcad-4302-9248-2033ea28b4d8.jpg": [
        (r"HO PHỤ THU HUONG", "HO THI THU HUONG"),
        (r"mung me 8/3|Tung me", "mung me 8/3"),
    ],
    "37101e09-93d0-4f43-944d-4b14bee7bfad.jpg": [
        (r"SK HOANM|SK HOANG", "HO HOANG ANH"),
        (r"Nội dung", "Nội dung"),
    ],
}

JUNK_PATTERNS = [
    r"^Cr$", r"^Crg$", r"^G-?$", r"^V$", r"^A$", r"^S$", r"^C$", r"^N$",
    r"^CO OE$", r"^CO$", r"^EISAE$", r"^-$", r"^7$", r"^22 inn$",
    r"C oa doune", r"Shin ph", r"M t Vaun", r"S tauc", r"Kối guá",
    r"NNố", r"KCON$", r"1 tueng", r"1hng hinga", r"Vietinbonk",
    r"Cảm ơn bon", r"Chie Sá Luu", r"K-MB$",
]


def _is_junk(text: str) -> bool:
    t = text.strip()
    if not t:
        return True
    if len(t) <= 2 and not re.search(r"\d{3}", t):
        return True
    for pat in JUNK_PATTERNS:
        if re.search(pat, t, re.I):
            return True
    return False


def apply_seeds(df: pd.DataFrame) -> pd.DataFrame:
    changed = 0
    cleared = 0

    for idx, row in df.iterrows():
        cur = str(row["text"]).strip()
        new = cur
        for pat, repl in GLOBAL_FIXES:
            if callable(repl):
                m = re.match(pat, cur)
                if m:
                    new = repl(m)
            elif re.search(pat, cur, re.I):
                new = repl

        src = str(row["source"])
        if src in SEEDS:
            for pat, repl in SEEDS[src]:
                if re.search(pat, new, re.I):
                    new = repl

        if new != cur:
            df.at[idx, "text"] = new
            df.at[idx, "conf"] = 1.0
            changed += 1

    for idx, row in df.iterrows():
        if _is_junk(str(row["text"])):
            if str(row["text"]).strip():
                cleared += 1
            df.at[idx, "text"] = ""
            df.at[idx, "conf"] = 0.0

    print(f"Seeds: {changed} dong sua, {cleared} dong rac bo text")
    return df


def main() -> None:
    if not CSV.is_file():
        print(f"Chua co {CSV} — chay prepare_real_lines.py truoc")
        return
    df = pd.read_csv(CSV).fillna("")
    df = apply_seeds(df)
    labeled = (df["text"].astype(str).str.strip() != "").sum()
    df.to_csv(CSV, index=False, encoding="utf-8")
    print(f"Luu {CSV}: {labeled}/{len(df)} dong co text")


if __name__ == "__main__":
    main()
