#!/usr/bin/env python3
"""
Pipeline: build dataset → (optional grid) → train final model.

Usage:
  python scripts/train_classify_pipeline.py --build-only
  python scripts/train_classify_pipeline.py --train
  python scripts/train_classify_pipeline.py --grid --grid-epochs 25
  python scripts/train_classify_pipeline.py --full   # build + grid + train best
"""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from app.classify_train_lib import TrainConfig, colab_train_config, run_grid_search, run_training


def build_dataset() -> None:
    script = ROOT / "data" / "build_classify_dataset.py"
    subprocess.check_call([sys.executable, str(script)], cwd=str(ROOT / "data"))


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--build-only", action="store_true")
    p.add_argument("--train", action="store_true")
    p.add_argument("--grid", action="store_true")
    p.add_argument("--full", action="store_true")
    p.add_argument("--grid-epochs", type=int, default=25)
    p.add_argument("--epochs", type=int, default=80)
    p.add_argument("--cpu", action="store_true", help="Allow CPU (slow)")
    p.add_argument("--focal", action="store_true", help="Use FocalLoss gamma=2")
    args = p.parse_args()

    csv_path = ROOT / "data" / "classify_train_cleaned.csv"
    save_dir = ROOT / "models"

    if args.build_only or args.full or args.train or args.grid:
        print("=== Build dataset ===")
        build_dataset()

    if args.build_only:
        return

    require_cuda = not args.cpu

    if args.grid or args.full:
        print("=== Grid search (reduced 12 combos) ===")
        gs = run_grid_search(
            csv_path,
            save_dir / "grid_runs",
            quick_epochs=args.grid_epochs,
            require_cuda=require_cuda,
        )
        best = gs.get("best")
        if not best:
            print("Grid search produced no result.")
            sys.exit(1)
        dropout = best["dropout"]
        lr = best["lr"]
        ls = best["label_smoothing"]
        src = Path(best["save_dir"])
        for name in [
            "classify_model.pt",
            "classify_vocab.json",
            "classify_meta.json",
            "classify_preprocess.json",
            "classify_metrics.json",
            "IMPROVEMENT_REPORT.md",
        ]:
            f = src / name
            if f.is_file():
                shutil.copy2(f, save_dir / name)
        print("Copied best grid artifacts to", save_dir)
        if args.grid and not args.full:
            return

    if args.train or args.full:
        print("=== Final train ===")
        cfg = colab_train_config(csv_path, save_dir)
        cfg.epochs = args.epochs
        cfg.require_cuda = require_cuda
        cfg.use_focal_loss = args.focal
        if args.full and (save_dir / "grid_search_results.json").is_file():
            best = json.loads((save_dir / "grid_search_results.json").read_text())["best"]
            cfg.dropout = best["dropout"]
            cfg.lr = best["lr"]
            cfg.label_smoothing = best["label_smoothing"]
        run_training(cfg)
        print("Done. Artifacts in", save_dir)


if __name__ == "__main__":
    main()
