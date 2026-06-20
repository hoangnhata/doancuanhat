"""
Đánh giá OCR trên ẢNH THẬT theo TỪNG FIELD (không chỉ CER/Exact).

Cấu trúc thư mục test (mặc định cạnh file này, có thể đổi bằng --test-dir):
  receipt_test/      ảnh hóa đơn  (*.jpg/*.png) + nhãn
  transfer_test/     ảnh bill chuyển khoản + nhãn

Nhãn (chọn 1 trong 2 cách):
  1) labels.csv trong mỗi thư mục, cột:
       filename, amount, date, merchant, receiver, description
     (date dạng YYYY-MM-DD hoặc DD/MM/YYYY; field trống = bỏ qua khi tính)
  2) sidecar JSON cùng tên ảnh: anh01.jpg -> anh01.json
       {"amount":150000,"date":"2025-05-21","merchant":"HIGHLANDS",
        "receiver":"NGUYEN VAN A","description":"ca phe"}

Xuất:
  - In bảng: Amount / Date / Merchant / Receiver / Description Accuracy + CER/Exact dòng
  - Lưu report JSON + CSV chi tiết vào --out (mặc định ocr_logs/real_eval).

Chạy (từ ai_service):
  python data/evaluate_real.py --models-dir models --test-dir data
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import unicodedata
from datetime import datetime
from pathlib import Path
from typing import Any, Optional

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import pandas as pd  # noqa: E402
import torch  # noqa: E402
from PIL import Image  # noqa: E402

from app.ocr_eval import cer  # noqa: E402
from app.ocr_recognizer import load_recognizer_bundle  # noqa: E402
from app.transfer_parse import parse_transfer_image, TransferNotDetectedError  # noqa: E402

IMG_EXT = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}


# ─────────────────────────── Chuẩn hoá so khớp ──────────────────────────────

def _norm_text(s: Any) -> str:
    if s is None:
        return ""
    s = str(s)
    nf = unicodedata.normalize("NFD", s)
    nf = "".join(c for c in nf if unicodedata.category(c) != "Mn")
    return re.sub(r"\s+", " ", nf.lower().replace("đ", "d")).strip()


def _norm_date(s: Any) -> Optional[str]:
    if s is None or str(s).strip() == "":
        return None
    t = str(s).strip()
    for fmt in ("%Y-%m-%d", "%d/%m/%Y", "%d-%m-%Y", "%d.%m.%Y", "%d/%m/%y"):
        try:
            return datetime.strptime(t[:10], fmt).date().isoformat()
        except ValueError:
            continue
    return t


def _parse_amount(s: Any) -> Optional[int]:
    if s is None or str(s).strip() == "":
        return None
    digits = re.sub(r"[^0-9]", "", str(s))
    return int(digits) if digits else None


def _text_match(gt: str, pred: str, *, thr: float = 0.30) -> bool:
    """Khớp 'mềm': bằng nhau sau chuẩn hoá, hoặc chứa nhau, hoặc CER thấp."""
    g, p = _norm_text(gt), _norm_text(pred)
    if not g:
        return False
    if g == p:
        return True
    if g in p or p in g:
        return True
    return cer(g, p) <= thr


# ─────────────────────────── Đọc nhãn ───────────────────────────────────────

def _load_labels(folder: Path) -> dict[str, dict]:
    labels: dict[str, dict] = {}
    csv_path = folder / "labels.csv"
    if csv_path.is_file():
        df = pd.read_csv(csv_path, dtype=str).fillna("")
        for _, row in df.iterrows():
            fn = str(row.get("filename", "")).strip()
            if fn:
                labels[fn] = {k: row.get(k, "") for k in
                              ("amount", "date", "merchant", "receiver", "description")}
    # sidecar JSON (bổ sung / override)
    for img in folder.iterdir():
        if img.suffix.lower() in IMG_EXT:
            js = img.with_suffix(".json")
            if js.is_file():
                try:
                    labels[img.name] = json.loads(js.read_text(encoding="utf-8"))
                except Exception:
                    pass
    return labels


# ─────────────────────────── Đánh giá 1 thư mục ─────────────────────────────

def evaluate_folder(folder: Path, recognizer, *, kind: str) -> dict[str, Any]:
    labels = _load_labels(folder)
    images = [p for p in sorted(folder.iterdir()) if p.suffix.lower() in IMG_EXT]
    counters = {f: [0, 0] for f in ("amount", "date", "merchant", "receiver", "description")}
    rows: list[dict] = []

    for img_path in images:
        gt = labels.get(img_path.name)
        try:
            image = Image.open(img_path)
            res = parse_transfer_image(image, recognizer)
        except TransferNotDetectedError as e:
            rows.append({"file": img_path.name, "error": str(e), "is_transfer": False})
            continue
        except Exception as e:
            rows.append({"file": img_path.name, "error": str(e)})
            continue

        pred = {
            "amount": res.amount_vnd,
            "date": res.transaction_date,
            "merchant": None,
            "receiver": res.receiver,
            "description": res.description or res.note,
        }
        row: dict[str, Any] = {
            "file": img_path.name,
            "is_transfer": True,
            **{f"pred_{k}": v for k, v in pred.items()},
        }

        if gt:
            # amount
            g_amt = _parse_amount(gt.get("amount"))
            if g_amt is not None:
                counters["amount"][1] += 1
                ok = pred["amount"] == g_amt
                counters["amount"][0] += int(ok)
                row["amount_ok"] = ok
                row["gt_amount"] = g_amt
            # date
            g_date = _norm_date(gt.get("date"))
            if g_date:
                counters["date"][1] += 1
                ok = _norm_date(pred["date"]) == g_date
                counters["date"][0] += int(ok)
                row["date_ok"] = ok
                row["gt_date"] = g_date
            # merchant / receiver / description (so khớp mềm)
            for f in ("merchant", "receiver", "description"):
                gv = gt.get(f)
                if gv is not None and str(gv).strip():
                    counters[f][1] += 1
                    ok = _text_match(str(gv), str(pred[f] or ""))
                    counters[f][0] += int(ok)
                    row[f"{f}_ok"] = ok
                    row[f"gt_{f}"] = gv
        rows.append(row)

    acc = {f: (c[0] / c[1] if c[1] else None) for f, c in counters.items()}
    return {
        "kind": kind,
        "folder": str(folder),
        "n_images": len(images),
        "n_labeled": len(labels),
        "accuracy": acc,
        "counts": counters,
        "rows": rows,
    }


def _fmt_acc(v: Optional[float]) -> str:
    return "  n/a " if v is None else f"{v*100:6.2f}%"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--models-dir", type=str, default="models")
    ap.add_argument("--test-dir", type=str, default="data",
                    help="Thu muc chua receipt_test/ va transfer_test/")
    ap.add_argument("--receipt-dir", type=str, default="")
    ap.add_argument("--transfer-dir", type=str, default="")
    ap.add_argument("--out", type=str, default="")
    args = ap.parse_args()

    models_dir = Path(args.models_dir)
    if not models_dir.is_absolute():
        models_dir = ROOT / models_dir
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    recognizer = load_recognizer_bundle(models_dir, device=device)
    if recognizer is None:
        raise SystemExit(f"Khong tim thay model OCR scratch trong {models_dir} "
                         f"(can ocr_reco_model.pt + meta + charset).")

    test_dir = Path(args.test_dir)
    if not test_dir.is_absolute():
        test_dir = ROOT / test_dir
    receipt_dir = Path(args.receipt_dir) if args.receipt_dir else test_dir / "receipt_test"
    transfer_dir = Path(args.transfer_dir) if args.transfer_dir else test_dir / "transfer_test"

    reports = []
    if receipt_dir.is_dir():
        reports.append(evaluate_folder(receipt_dir, recognizer, kind="receipt"))
    else:
        print(f"[bo qua] khong co {receipt_dir}")
    if transfer_dir.is_dir():
        reports.append(evaluate_folder(transfer_dir, recognizer, kind="transfer"))
    else:
        print(f"[bo qua] khong co {transfer_dir}")

    if not reports:
        raise SystemExit("Khong co thu muc test nao. Tao receipt_test/ va/hoac transfer_test/.")

    print("\n" + "=" * 74)
    print(f"{'NHOM':10s} {'#anh':>5s} {'Amount':>8s} {'Date':>8s} "
          f"{'Merchant':>9s} {'Receiver':>9s} {'Desc':>8s}")
    print("-" * 74)
    for r in reports:
        a = r["accuracy"]
        print(f"{r['kind']:10s} {r['n_images']:5d} "
              f"{_fmt_acc(a['amount'])} {_fmt_acc(a['date'])} "
              f"{_fmt_acc(a['merchant'])} {_fmt_acc(a['receiver'])} {_fmt_acc(a['description'])}")
    print("=" * 74)

    out_dir = Path(args.out) if args.out else (models_dir / "ocr_logs" / "real_eval")
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "real_eval_report.json").write_text(
        json.dumps([{k: v for k, v in r.items() if k != "rows"} for r in reports],
                   indent=2, ensure_ascii=False), encoding="utf-8")
    for r in reports:
        pd.DataFrame(r["rows"]).to_csv(
            out_dir / f"real_eval_{r['kind']}.csv", index=False, encoding="utf-8")
    print(f"Report -> {out_dir}")
    if any(r["n_labeled"] == 0 for r in reports):
        print("\nLUU Y: chua co nhan (labels.csv hoac *.json) -> chi co du doan, "
              "khong tinh duoc accuracy. Xem cot pred_* trong CSV.")


if __name__ == "__main__":
    main()
