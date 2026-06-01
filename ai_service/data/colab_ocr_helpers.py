"""Helper cho Colab: backup/restore dataset + model, tranh timeout."""

from __future__ import annotations

import json
import shutil
import zipfile
from pathlib import Path

FIELD_PREFIXES = {
    "amount": "ocr_amount",
    "merchant": "ocr_merchant",
    "date": "ocr_date",
    "line": "ocr_line",
}


def restore_models_from_drive(drive_dir: Path, models_dir: Path) -> list[str]:
    """Copy model da backup tu Drive ve /content/receipt_models."""
    models_dir.mkdir(parents=True, exist_ok=True)
    restored: list[str] = []
    for field, prefix in FIELD_PREFIXES.items():
        pt = drive_dir / f"{prefix}_model.pt"
        meta = drive_dir / f"{prefix}_meta.json"
        if pt.is_file() and meta.is_file():
            shutil.copy2(pt, models_dir / f"{prefix}_model.pt")
            shutil.copy2(meta, models_dir / f"{prefix}_meta.json")
            if field == "amount":
                shutil.copy2(pt, models_dir / "ocr_model.pt")
                shutil.copy2(meta, models_dir / "ocr_meta.json")
            restored.append(field)
    return restored


def backup_field_to_drive(field: str, models_dir: Path, drive_dir: Path) -> None:
    """Backup 1 model len Drive ngay sau khi train xong."""
    drive_dir.mkdir(parents=True, exist_ok=True)
    prefix = FIELD_PREFIXES[field]
    for suffix in ("_model.pt", "_meta.json"):
        src = models_dir / f"{prefix}{suffix}"
        if src.is_file():
            shutil.copy2(src, drive_dir / f"{prefix}{suffix}")
    if field == "amount":
        for name in ("ocr_model.pt", "ocr_meta.json"):
            src = models_dir / name
            if src.is_file():
                shutil.copy2(src, drive_dir / name)
    meta_path = models_dir / f"{prefix}_meta.json"
    if meta_path.is_file():
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        print(
            f"  Backup [{field}] -> Drive  "
            f"val_loss={meta.get('val_ctc_loss', '?')}  "
            f"CER={meta.get('mean_cer', '?')}  acc={meta.get('exact_acc', '?')}"
        )


def backup_logs_to_drive(log_dir: Path, drive_dir: Path) -> None:
    dst = drive_dir / "ocr_logs"
    if not log_dir.is_dir():
        return
    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(log_dir, dst)
    print(f"  Backup ocr_logs/ -> {dst}")


def field_done_on_drive(field: str, drive_dir: Path) -> bool:
    prefix = FIELD_PREFIXES[field]
    return (
        (drive_dir / f"{prefix}_model.pt").is_file()
        and (drive_dir / f"{prefix}_meta.json").is_file()
    )


def list_training_status(drive_dir: Path, models_dir: Path) -> dict[str, str]:
    status: dict[str, str] = {}
    for field in FIELD_PREFIXES:
        local = (
            (models_dir / f"{FIELD_PREFIXES[field]}_model.pt").is_file()
            and (models_dir / f"{FIELD_PREFIXES[field]}_meta.json").is_file()
        )
        remote = field_done_on_drive(field, drive_dir)
        if local:
            status[field] = "local OK"
        elif remote:
            status[field] = "Drive only (can restore)"
        else:
            status[field] = "CHUA TRAIN"
    return status


def restore_dataset_from_drive(drive_dir: Path, data_dir: Path, zip_name: str = "receipt_ocr.zip") -> bool:
    """Giai nen dataset tu Drive neu co. Tra ve True neu restore thanh cong."""
    zip_path = drive_dir / zip_name
    if not zip_path.is_file():
        return False
    if data_dir.is_dir():
        shutil.rmtree(data_dir)
    data_dir.parent.mkdir(parents=True, exist_ok=True)
    print(f"Giai nen dataset tu {zip_path} (~2-3 phut)...")
    with zipfile.ZipFile(zip_path, "r") as zf:
        zf.extractall(data_dir.parent)
    ok = (data_dir / "manifest.csv").is_file()
    print(f"Restore dataset: {'OK' if ok else 'LOI'} -> {data_dir}")
    return ok


def save_dataset_to_drive(data_dir: Path, drive_dir: Path, zip_name: str = "receipt_ocr.zip") -> None:
    """Nen dataset len Drive de lan sau khong phai sinh lai."""
    if not (data_dir / "manifest.csv").is_file():
        print("Khong co dataset de nen")
        return
    drive_dir.mkdir(parents=True, exist_ok=True)
    zip_path = drive_dir / zip_name
    tmp = zip_path.with_suffix("")
    if tmp.exists():
        shutil.rmtree(tmp, ignore_errors=True)
    print(f"Nen dataset -> {zip_path} (~3-5 phut, chi lam 1 lan)...")
    shutil.make_archive(str(tmp), "zip", data_dir.parent, data_dir.name)
    final = Path(str(tmp) + ".zip")
    if final != zip_path and final.is_file():
        if zip_path.is_file():
            zip_path.unlink()
        final.rename(zip_path)
    print(f"Da luu dataset zip -> {zip_path}")
