# Expense AI Service (FastAPI)

Phục vụ **phân loại giao dịch**, **dự báo chi tiêu**, **OCR hóa đơn** và **chatbot tài chính**.

| Endpoint | Mô tả |
|----------|--------|
| `POST /api/categorize` | Phân loại từ text |
| `POST /api/categorize/batch` | Phân loại nhiều khoản trong 1 câu |
| `POST /api/forecast` | Dự báo 7 ngày |
| `POST /api/ocr/receipt/parse` | Ảnh hóa đơn → số tiền, ngày, cửa hàng, mô tả, danh mục |
| `POST /api/ocr/receipt/amount` | Chỉ đọc số tiền |
| `POST /api/chat` | **Chatbot Q&A về chi tiêu (Gemini + fallback rule-based)** |
| `GET /health` | Kiểm tra trạng thái model + Gemini |

## Yêu cầu

- Python 3.10+
- Model trong `models/`:
  - `classify_model.pt`, `classify_meta.json`, `classify_vocab.json`
  - `forecast_model.pt`, `forecast_meta.json` (tuỳ chọn)
  - OCR: `ocr_amount_model.pt`, `ocr_merchant_model.pt`, `ocr_date_model.pt`, `ocr_line_model.pt` (+ file `*_meta.json`)

## Cài đặt và chạy

```powershell
cd c:\Nam4\Doantotnghiep2\ai_service
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

## Train OCR (local hoặc Colab)

```powershell
# Sinh 4000 bill synthetic + train 4 model CRNN (~10-20 phút CPU)
python data/train_receipt_models.py --gen-n 4000 --epochs 40
```

Hoặc mở `train_receipt_ocr.ipynb` trên Google Colab.

## Test OCR parse

```powershell
curl -X POST "http://127.0.0.1:8000/api/ocr/receipt/parse" ^
  -F "file=@data/receipt_ocr/images/full/bill_00000.png"
```

Response mẫu:

```json
{
  "amount_vnd": 125000,
  "transaction_date": "2025-06-15",
  "merchant": "HIGHLANDS COFFEE",
  "description": "Ca phe sua da",
  "category": "Ăn uống",
  "type": "EXPENSE",
  "needs_review": false
}
```

## Chatbot Gemini

Endpoint `/api/chat` nhận:
```json
{
  "message": "Tháng này tôi tiêu nhiều nhất vào đâu?",
  "personality": "HAPPY",
  "context": {
    "currency": "VND",
    "month_total_expense": 5400000,
    "month_total_income": 12000000,
    "by_category": [{"name": "Ăn uống", "amount": 2000000}],
    "recent_transactions": [...],
    "budgets": [...]
  }
}
```

Bật Gemini (free tier):
```powershell
$env:GEMINI_API_KEY = "AIza...your_key..."
```

Lấy API key: <https://aistudio.google.com/apikey>

Nếu không có key → service tự fallback rule-based summarizer dựa trên context.

## Biến môi trường

- `PYTHON_AI_API_URL` (Spring Boot phía backend): mặc định `http://localhost:8000`
- `GEMINI_API_KEY`: bật chatbot LLM
- `GEMINI_MODEL`: mặc định `gemini-1.5-flash`
- `GEMINI_TIMEOUT_S`: mặc định 20s
