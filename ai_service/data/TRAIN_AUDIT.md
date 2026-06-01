# Train classify v3 — checklist

## Dataset (`classify_train_cleaned.csv`)

- Chạy build: `python data/build_classify_dataset.py`
- Audit: `python data/audit_classify_dataset.py` → `DATASET_AUDIT.md`, `classify_dataset_audit_full.json`
- Hard patterns: `data/classify_hard_patterns.py` (~1500+ biến thể, contrastive, Sức khỏe)
- Inject sau balance: tối đa **45** hard câu/nhãn

## Hard validation

- `app/val_hard_samples.py` + `data/val_hard_samples_catalog.py` → **~265+** câu (mở rộng dần tới 500)

## Train (Colab GPU khuyến nghị)

```powershell
cd ai_service
python scripts/train_classify_pipeline.py --full
# hoặc chỉ train:
python scripts/train_classify_pipeline.py --train
# grid 12 combo:
python scripts/train_classify_pipeline.py --grid --grid-epochs 30
# FocalLoss so sánh:
python scripts/train_classify_pipeline.py --train --focal
```

Notebook: `train_classify.ipynb` CELL 0→2.

## Hyperparameter grid (rút gọn 12 điểm)

| dropout | lr | label_smoothing |
|---------|-----|-----------------|
| 0.25–0.40 | 1e-4–5e-4 | 0–0.08 |

Chọn best theo: **hard_macro_f1** → hard_acc → val_macro_f1 → ít low_conf.

Full 64 combo: `$env:CLASSIFY_FULL_GRID="1"`

## Confidence

- `confidence_threshold` = **0.45** (meta)
- Câu chỉ tiền (`50k`, `20tr`) → **Khác** + OOD `amount_only`
- Rule `category_hints.py` override khi model conf thấp nhưng có từ khóa rõ

## Artifacts (copy vào `ai_service/models/`)

**Chỉ ghi đè file classify** — không xóa `ocr_*`, `forecast_*` (xem `models/README.md`).

1. `classify_model.pt`
2. `classify_vocab.json`
3. `classify_preprocess.json`
4. `classify_meta.json`
5. `classify_metrics.json`
6. `MODEL_IMPROVEMENT_REPORT.md`

Xóa classify cũ trước khi copy: `scripts/remove_classify_only.ps1`

Restart: `uvicorn app.main:app --reload` + Spring Boot.

## Mục tiêu

| Metric | Target |
|--------|--------|
| validation_acc | ≥ 0.98 |
| macro_f1 | ≥ 0.98 |
| hard_val_acc | ≥ 0.92 |
