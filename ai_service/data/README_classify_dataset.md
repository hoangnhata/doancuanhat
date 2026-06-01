# Dataset phân loại giao dịch

## File

| File | Mô tả |
|------|--------|
| `classify_edge_cases.csv` | Mẫu hóc búa (input cho build script) |
| `classify_edge_cases.csv` | Câu hóc búa (comment `#` được bỏ khi build) |
| **`classify_train_cleaned.csv`** | **Dùng để train** — đã làm sạch + cân bằng |
| `classify_dataset_report_before.md` | Báo cáo trước xử lý |
| `classify_dataset_report_after.md` | Báo cáo sau xử lý |
| `classify_dataset_stats.json` | Thống kê JSON |

## Tạo lại dataset production

```powershell
cd ai_service
python data/build_classify_dataset.py
```

## Train (Colab / local)

Trong `train_classify.ipynb` CELL 2, trỏ CSV tới:

```python
PRIMARY_CSV_OVERRIDE = Path("data/classify_train_cleaned.csv")
```

Hoặc copy `classify_train_cleaned.csv` lên Drive thay `classify_train.csv`.

Sau train → copy artifacts vào `ai_service/models/` (xem `TRAIN_AUDIT.md`).

## Rà soát train

Xem **`data/TRAIN_AUDIT.md`** — checklist lỗi phổ biến (câu ngắn, Freelance, Đầu tư, confidence).
