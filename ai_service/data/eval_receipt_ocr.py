"""
Báo cáo đánh giá OCR đầy đủ: biểu đồ loss, CER, bảng so sánh, ảnh mẫu, pred vs GT.

Chạy sau train:
  python data/eval_receipt_ocr.py --data-dir /content/receipt_ocr --models-dir /content/receipt_models

Hoặc từ notebook Colab (CELL 5 — Đánh giá).
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from app.ocr_eval import char_errors_to_dataframe, compare_models_table, evaluate_field_on_df, split_val_df
from app.ocr_infer import load_receipt_ocr_bundles

FIELD_MANIFEST = {
    "amount": ("manifest_amount.csv", "label_text", "amount_vnd"),
    "merchant": ("manifest_merchant.csv", "label_text", None),
    "date": ("manifest_date.csv", "label_text", None),
    "line": ("manifest_line.csv", "label_text", None),
}


def plot_loss_curves(log_dir: Path, out_dir: Path) -> None:
    fig, axes = plt.subplots(2, 2, figsize=(12, 8))
    axes = axes.flatten()
    for ax, field in zip(axes, ["amount", "merchant", "date", "line"]):
        p = log_dir / f"{field}_epoch_log.csv"
        if not p.is_file():
            ax.set_title(f"{field} — no log")
            continue
        df = pd.read_csv(p)
        ax.plot(df["epoch"], df["train_loss"], label="train", marker="o", ms=3)
        ax.plot(df["epoch"], df["val_loss"], label="val", marker="o", ms=3)
        ax.set_title(f"Loss — {field}")
        ax.set_xlabel("epoch")
        ax.set_ylabel("CTC loss")
        ax.legend()
        ax.grid(alpha=0.3)
    plt.tight_layout()
    out = out_dir / "loss_all_fields.png"
    plt.savefig(out, dpi=120)
    plt.show()
    print(f"Saved {out}")


def show_dataset_samples(data_dir: Path, out_dir: Path, n: int = 6) -> None:
    manifest = data_dir / "manifest.csv"
    if not manifest.is_file():
        print("Khong co manifest.csv")
        return
    df = pd.read_csv(manifest).head(n)
    fig, axes = plt.subplots(2, 3, figsize=(14, 8))
    for ax, (_, row) in zip(axes.flatten(), df.iterrows()):
        img = Image.open(data_dir / row["image_path"])
        ax.imshow(img, cmap="gray")
        ax.set_title(
            f"{row.get('merchant', '')[:18]}\n{row.get('amount_vnd', '')} VND",
            fontsize=9,
        )
        ax.axis("off")
    plt.suptitle("Dataset synthetic — bill mau", fontsize=12)
    plt.tight_layout()
    out = out_dir / "dataset_samples.png"
    plt.savefig(out, dpi=120)
    plt.show()
    print(f"Saved {out}")


def show_field_crop_samples(data_dir: Path, out_dir: Path, n: int = 4) -> None:
    """Ảnh crop từng field (amount, merchant, date, line)."""
    fig, axes = plt.subplots(4, n, figsize=(3 * n, 10))
    for row, field in enumerate(["amount", "merchant", "date", "line"]):
        manifest_name, label_col, _ = FIELD_MANIFEST[field]
        manifest = data_dir / manifest_name
        if not manifest.is_file():
            continue
        df = pd.read_csv(manifest).head(n)
        for col, (_, sample) in enumerate(df.iterrows()):
            ax = axes[row, col]
            img = Image.open(data_dir / sample["image_path"])
            ax.imshow(img, cmap="gray")
            lbl = str(sample[label_col])[:28]
            ax.set_title(f"{field}: {lbl}", fontsize=8)
            ax.axis("off")
    plt.suptitle("Dataset — crop mau theo field", fontsize=12)
    plt.tight_layout()
    out = out_dir / "field_crop_samples.png"
    plt.savefig(out, dpi=120)
    plt.show()
    print(f"Saved {out}")


def show_pred_vs_gt(eval_dir: Path, field: str, n: int = 6) -> None:
    p = eval_dir / f"{field}_predictions.csv"
    if not p.is_file():
        return
    df = pd.read_csv(p).head(n)
    fig, axes = plt.subplots(n, 2, figsize=(10, 2.2 * n))
    if n == 1:
        axes = [axes]
    data_root = eval_dir  # image_path relative — need data_dir passed
    for ax_row, (_, row) in zip(axes, df.iterrows()):
        ax_row[0].text(0.05, 0.5, f"GT:   {row['reference']}\nPred: {row['prediction']}\n"
                       f"CER={row['cer']}  exact={row['exact']}",
                       fontsize=10, va="center", family="monospace")
        ax_row[0].axis("off")
        ax_row[1].axis("off")
    plt.suptitle(f"Pred vs GT — {field}", fontsize=12)
    plt.tight_layout()
    plt.savefig(eval_dir / f"{field}_pred_vs_gt.png", dpi=120)
    plt.show()


def show_pred_vs_gt_with_images(
    data_dir: Path,
    eval_dir: Path,
    field: str,
    n: int = 6,
) -> None:
    p = eval_dir / f"{field}_predictions.csv"
    if not p.is_file():
        return
    df = pd.read_csv(p).head(n)
    fig, axes = plt.subplots(n, 1, figsize=(12, 2.4 * n))
    if n == 1:
        axes = [axes]
    for ax, (_, row) in zip(axes, df.iterrows()):
        img = Image.open(data_dir / row["image_path"])
        ax.imshow(img, cmap="gray")
        mark = "OK" if row["exact"] else "SAI"
        ax.set_title(
            f"[{mark}] GT: {row['reference']}  |  Pred: {row['prediction']}  "
            f"(CER={row['cer']:.2f})",
            fontsize=9,
        )
        ax.axis("off")
    plt.tight_layout()
    out = eval_dir / f"{field}_pred_vs_gt_images.png"
    plt.savefig(out, dpi=120)
    plt.show()
    print(f"Saved {out}")


def plot_char_errors(eval_dir: Path, field: str, top_k: int = 15) -> None:
    p = eval_dir / f"{field}_char_errors.csv"
    if not p.is_file() or p.stat().st_size == 0:
        print(f"  [{field}] khong co loi ky tu de ve bieu do")
        return
    df = pd.read_csv(p)
    if df.empty:
        print(f"  [{field}] char_errors.csv rong — model doc dung 100%")
        return
    df = df.head(top_k)
    fig, ax = plt.subplots(figsize=(10, 5))
    ax.barh(df["error"][::-1], df["count"][::-1], color="#0288D1")
    ax.set_xlabel("So lan")
    ax.set_title(f"Loi ky tu thuong gap — {field} (ref→pred)")
    plt.tight_layout()
    plt.savefig(eval_dir / f"{field}_char_errors.png", dpi=120)
    plt.show()


def run_full_eval(
    data_dir: Path,
    models_dir: Path,
    log_dir: Path | None = None,
    device=None,
) -> pd.DataFrame:
    import torch

    log_dir = log_dir or (models_dir / "ocr_logs")
    log_dir.mkdir(parents=True, exist_ok=True)
    dev = device or torch.device("cuda" if torch.cuda.is_available() else "cpu")
    bundles = load_receipt_ocr_bundles(models_dir, device=dev)

    all_metrics: list[dict] = []
    for field, (manifest_name, label_col, amount_col) in FIELD_MANIFEST.items():
        bundle = getattr(bundles, field)
        if bundle is None:
            print(f"Skip {field} — chua co model")
            continue
        manifest = data_dir / manifest_name
        df = pd.read_csv(manifest)
        va_df = split_val_df(df)

        result = evaluate_field_on_df(
            bundle, va_df, data_dir,
            label_col=label_col,
            amount_col=amount_col,
        )
        metrics = result.to_metrics_dict()
        all_metrics.append(metrics)

        pd.DataFrame(result.predictions).to_csv(
            log_dir / f"{field}_predictions.csv", index=False, encoding="utf-8",
        )
        char_errors_to_dataframe(result.char_error_counter).to_csv(
            log_dir / f"{field}_char_errors.csv", index=False, encoding="utf-8",
        )
        print(f"\n=== {field} ===")
        for k, v in metrics.items():
            print(f"  {k}: {v}")

    compare = compare_models_table(all_metrics)
    compare.to_csv(log_dir / "compare_models.csv", encoding="utf-8")
    (log_dir / "eval_summary.json").write_text(
        json.dumps(all_metrics, indent=2, ensure_ascii=False), encoding="utf-8",
    )
    print("\n=== BANG SO SANH 4 MODEL ===")
    print(compare.to_string())
    print(f"\nLogs -> {log_dir}")
    return compare


def eval_real_bill(
    image_path: Path,
    models_dir: Path,
    data_dir: Path,
    log_dir: Path,
    device=None,
) -> None:
    import torch
    from app.receipt_parse import parse_receipt_image

    dev = device or torch.device("cpu")
    bundles = load_receipt_ocr_bundles(models_dir, device=dev)
    img = Image.open(image_path)
    result = parse_receipt_image(img, bundles, classify=None)

    fig, axes = plt.subplots(1, 2, figsize=(12, 6))
    axes[0].imshow(img.convert("L"), cmap="gray")
    axes[0].set_title(f"Bill that: {image_path.name}")
    axes[0].axis("off")
    txt = "\n".join(f"{k}: {v}" for k, v in result.to_dict().items() if k != "raw")
    axes[1].text(0.05, 0.95, txt, va="top", fontsize=10, family="monospace")
    axes[1].axis("off")
    plt.tight_layout()
    out = log_dir / "real_bill_eval.png"
    plt.savefig(out, dpi=120)
    plt.show()
    print(f"Saved {out}")
    print(json.dumps(result.to_dict(), indent=2, ensure_ascii=False))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--data-dir", type=str, default="")
    ap.add_argument("--models-dir", type=str, default="")
    ap.add_argument("--log-dir", type=str, default="")
    ap.add_argument("--real-bill", type=str, default="", help="Duong dan anh bill that")
    ap.add_argument("--no-plots", action="store_true")
    args = ap.parse_args()

    data_dir = Path(args.data_dir) if args.data_dir else ROOT / "data" / "receipt_ocr"
    models_dir = Path(args.models_dir) if args.models_dir else ROOT / "models"
    log_dir = Path(args.log_dir) if args.log_dir else models_dir / "ocr_logs"

    run_full_eval(data_dir, models_dir, log_dir)

    if not args.no_plots:
        show_dataset_samples(data_dir, log_dir)
        show_field_crop_samples(data_dir, log_dir)
        plot_loss_curves(log_dir, log_dir)
        for field in FIELD_MANIFEST:
            show_pred_vs_gt_with_images(data_dir, log_dir, field, n=5)
            plot_char_errors(log_dir, field)

    if args.real_bill:
        eval_real_bill(Path(args.real_bill), models_dir, data_dir, log_dir)


if __name__ == "__main__":
    main()
