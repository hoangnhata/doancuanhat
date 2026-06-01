# Thư mục `models/` — KHÔNG xóa toàn bộ

Chỉ **thay / xóa** các file **classify** khi train lại phân loại.
**Giữ nguyên** OCR, forecast và mọi file khác.

## Classify (có thể xóa khi train lại)

- `classify_model.pt`
- `classify_vocab.json`
- `classify_preprocess.json`
- `classify_meta.json`
- `classify_metrics.json`
- `classify_best.pt`
- `classify_checkpoint.pt`
- `IMPROVEMENT_REPORT.md`
- `MODEL_IMPROVEMENT_REPORT.md`
- `grid_search_results.json`
- `grid_runs/` (thư mục grid search)

## OCR — giữ lại

- `ocr_amount_model.pt`, `ocr_amount_meta.json`
- `ocr_merchant_model.pt`, `ocr_merchant_meta.json`
- `ocr_date_model.pt`, `ocr_date_meta.json`
- `ocr_line_model.pt`, `ocr_line_meta.json`
- `ocr_meta.json`

## Forecast — giữ lại

- `forecast_model.pt`
- `forecast_meta.json`

## Khôi phục nếu mất file

Copy lại từ Google Drive / backup (`MyDrive/thesis/ai_service/models/`) hoặc train lại notebook:

- `train_receipt_ocr.ipynb` → OCR
- `train_forecast (1).ipynb` → forecast
