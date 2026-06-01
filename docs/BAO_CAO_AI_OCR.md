# Báo cáo phần AI – OCR hóa đơn (Receipt Parse)

**Đề tài:** Expense Manager — Quản lý thu/chi cá nhân + trợ lý AI  
**Phiên bản:** 1.0  
**Ngày:** 20/05/2026  

Tài liệu mô tả **bài toán**, **kiến trúc**, **dữ liệu**, **quy trình huấn luyện**, **suy luận (inference)** và **tích hợp hệ thống** cho module AI thứ ba: **OCR và phân tích hóa đơn từ ảnh**.

> Bổ sung cho `docs/BAO_CAO_AI.md` (phân loại TextCNN + dự báo Transformer).

---

## Mục lục

1. [Tổng quan](#1-tổng-quan)
2. [Bài toán và phạm vi](#2-bài-toán-và-phạm-vi)
3. [Vị trí trong hệ thống](#3-vị-trí-trong-hệ-thống)
4. [Kiến trúc tổng thể](#4-kiến-trúc-tổng-thể)
5. [Kiến trúc model: ReceiptLineCRNN](#5-kiến-trúc-model-receiptlinecrnn)
6. [Dữ liệu huấn luyện](#6-dữ-liệu-huấn-luyện)
7. [Quy trình huấn luyện](#7-quy-trình-huấn-luyện)
8. [Suy luận và pipeline 5 field](#8-suy-luận-và-pipeline-5-field)
9. [API và tích hợp](#9-api-và-tích-hợp)
10. [Cấu trúc mã nguồn](#10-cấu-trúc-mã-nguồn)
11. [So sánh 3 module AI](#11-so-sánh-3-module-ai)
12. [Đánh giá và hạn chế](#12-đánh-giá-và-hạn-chế)
13. [Hướng dẫn triển khai](#13-hướng-dẫn-triển-khai)

---

## 1. Tổng quan

Hệ thống Expense Manager ban đầu có **2 module AI**:

| STT | Module | Input | Output |
|-----|--------|-------|--------|
| 1 | Phân loại (`CharTextCNN`) | Text ghi chú | Danh mục (20 nhãn) |
| 2 | Dự báo (`SpendingForecastTransformer`) | 30 ngày chi tiêu | 7 ngày dự báo (VND) |

Module **AI thứ ba — OCR hóa đơn** bổ sung khả năng:

- Người dùng **chụp ảnh hóa đơn** thay vì gõ tay
- Hệ thống tự trích xuất **5 thông tin** và **điền sẵn form** tạo giao dịch

| Field | Mô tả | Nguồn xử lý |
|-------|--------|-------------|
| Số tiền | Tổng thanh toán (VND) | Model OCR `amount` |
| Ngày | Ngày giao dịch | Model OCR `date` + regex |
| Cửa hàng | Tên merchant | Model OCR `merchant` |
| Mô tả / món | Dòng hàng hóa | Model OCR `line` |
| Danh mục | Phân loại chi tiêu | **`CharTextCNN` có sẵn** (text → category) |

**Nguyên tắc thiết kế:** Không fine-tune model pretrained (Tesseract, PaddleOCR, TrOCR). Toàn bộ kiến trúc CRNN được **tự xây dựng từ đầu** bằng PyTorch, thống nhất với triết lý của TextCNN và Transformer dự báo.

---

## 2. Bài toán và phạm vi

### 2.1 Bài toán

Cho ảnh hóa đơn \( I \), tìm mapping:

\[
I \rightarrow (amount, date, merchant, description, category)
\]

Trong đó `category` suy ra từ text `(merchant + description)` qua model phân loại đã huấn luyện.

### 2.2 Phạm vi (In-scope)

- Ảnh hóa đơn in/nền sáng, chữ đen (bill Việt Nam / siêu thị / F&B)
- Trích xuất 4 field từ ảnh bằng OCR tự xây
- Phân loại danh mục bằng TextCNN
- API REST cho backend Spring Boot và client Flutter/Web

### 2.3 Ngoài phạm vi (Out-of-scope)

- OCR hóa đơn nhiều cột phức tạp (VAT, QR, bảng kê dài)
- Nhận diện layout bằng deep learning (chỉ dùng heuristic cắt vùng)
- Huấn luyện phân loại từ pixel ảnh (tái s dụng TextCNN trên text)

---

## 3. Vị trí trong hệ thống

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────────┐
│ Flutter/Web │────▶│ Spring Boot API  │────▶│ ai_service      │
│ (chụp bill) │     │ (port 8080)      │     │ FastAPI :8000   │
└─────────────┘     └──────────────────┘     └────────┬────────┘
                                                     │
                    ┌────────────────────────────────┼────────────────────┐
                    │                                │                    │
              /api/categorize              /api/forecast      /api/ocr/receipt/parse
              (TextCNN)                    (Transformer)      (4× CRNN + TextCNN)
```

Luồng OCR:

1. Client upload ảnh → Backend → `ai_service`
2. `receipt_parse.py` cắt vùng, chạy 4 model OCR
3. Gộp text → gọi `classify_infer.py` → danh mục
4. Trả JSON 5 field → client hiển thị form xác nhận → lưu giao dịch

---

## 4. Kiến trúc tổng thể

### 4.1 Pipeline đa model (không monolithic)

Thay vì một model đọc toàn bộ hóa đơn, hệ thống dùng **pipeline**:

```
Ảnh full bill
    │
    ▼
┌───────────────────────────────────────┐
│  receipt_layout.py                    │
│  Cắt heuristic: header 18% | body 54% │
│                 | footer 28%          │
└───────────────────────────────────────┘
    │              │              │
    ▼              ▼              ▼
 header         body          footer
    │              │              │
    ├─ merchant    └─ line        └─ amount
    └─ date           (mô tả)         (số tiền)
    │              │              │
    └──────────────┴──────────────┘
                   │
                   ▼
         receipt_parse.py
         merchant + description
                   │
                   ▼
         CharTextCNN (có sẵn)
                   │
                   ▼
              category + type
```

**Lý do thiết kế pipeline:**

- Mỗi field có charset và độ dài khác nhau → model chuyên biệt train dễ hơn
- Lỗi một field không làm hỏng toàn bộ kết quả
- Tái s dụng TextCNN cho danh mục — không train thêm model phân loại ảnh
- Phù hợp phạm vi đồ án và tài nguyên Colab

### 4.2 Bốn model OCR

| Model | File weights | Vùng ảnh | Charset CTC |
|-------|--------------|----------|-------------|
| Amount | `ocr_amount_model.pt` | Footer | `0-9` + `. ,` |
| Merchant | `ocr_merchant_model.pt` | Header | Latin + tiếng Việt + dấu câu |
| Date | `ocr_date_model.pt` | Header | `0-9` + `/-.: ` |
| Line | `ocr_line_model.pt` | Body (3 dải) | Latin + tiếng Việt + dấu câu |

Kiến trúc mạng **giống nhau** (`ReceiptLineCRNN`); khác **charset**, **img_w**, và **dữ liệu train**.

---

## 5. Kiến trúc model: ReceiptLineCRNN

### 5.1 Sơ đồ

```
Input: ảnh xám (1, H=32, W)
    │
    ▼
┌─────────────────────────────────────────┐
│ ENCODER CNN (4 khối, tự viết)           │
│   Conv2d(1→32)  → BN → ReLU → MaxPool   │
│   Conv2d(32→64) → BN → ReLU → MaxPool   │
│   Conv2d(64→128)→ BN → ReLU → MaxPool   │
│   Conv2d(128→256)→ BN → ReLU → MaxPool  │
└─────────────────────────────────────────┘
    │  Feature map (B, 256, H', W')
    ▼
 Gom theo chiều cao → (B, W', 256·H')
    │
    ▼
┌─────────────────────────────────────────┐
│ BiLSTM × 2 tầng (hidden=128)            │
└─────────────────────────────────────────┘
    │
    ▼
 Linear → logits (B, T, num_classes)
    │
    ▼
 CTCLoss (train) / Greedy decode (infer)
```

### 5.2 CTC (Connectionist Temporal Classification)

- **Blank token** (index 0): ký tự đệm, không xuất ra output
- **Greedy decode:** argmax từng timestep → loại blank và ký tự lặp liên tiếp
- Phù hợp chuỗi số tiền và text không cần căn chỉnh ký tự-thời gian thủ công

### 5.3 File định nghĩa

| File | Vai trò |
|------|---------|
| `app/ocr_net.py` | Class `ReceiptLineCRNN` |
| `app/ocr_charset.py` | Bảng ký tự CTC cho amount / date / text |
| `app/ocr_infer.py` | Load model, preprocess, decode, parse VND/ngày |
| `app/receipt_layout.py` | Cắt header / body / footer |
| `app/receipt_parse.py` | Orchestrator 5 field + gọi TextCNN |

---

## 6. Dữ liệu huấn luyện

### 6.1 Sinh synthetic — không cần ảnh thật

Script: `data/gen_receipt_dataset.py`

```powershell
python data/gen_receipt_dataset.py --n 4000
```

**Quy trình sinh mỗi mẫu:**

1. Chọn ngẫu nhiên: cửa hàng, ngày, 1–3 món hàng, tổng tiền
2. Vẽ bill bằng Pillow (font Arial/DejaVu, nền trắng, chữ đen)
3. Thêm augmentation nhẹ: blur, brightness, noise
4. Cắt 4 vùng (amount, merchant, date, line) + lưu bill full
5. Ghi nhãn vào 5 file CSV manifest

### 6.2 Cấu trúc output

```
data/receipt_ocr/
├── images/
│   ├── full/bill_00000.png           # Bill đầy đủ
│   └── crops/
│       ├── amount/bill_00000.png
│       ├── merchant/bill_00000.png
│       ├── date/bill_00000.png
│       └── line/bill_00000.png
├── manifest.csv                      # Metadata tổng
├── manifest_amount.csv               # Train model amount
├── manifest_merchant.csv
├── manifest_date.csv
└── manifest_line.csv
```

### 6.3 Ví dụ nhãn

**manifest.csv** (1 dòng):

| Cột | Ví dụ |
|-----|-------|
| amount_vnd | 125000 |
| merchant | HIGHLANDS COFFEE |
| transaction_date | 20/05/2026 |
| description | Ca phe sua da; Banh mi thit |
| crop_amount | images/crops/amount/bill_00001.png |

**manifest_amount.csv:**

| image_path | label_text | amount_vnd |
|------------|------------|------------|
| images/crops/amount/bill_00001.png | 125.000 | 125000 |

### 6.4 Tham số khuyến nghị

| Tham số | Giá trị | Ghi chú |
|---------|---------|---------|
| Số bill synthetic | 4000–8000 | Đủ cho demo đồ án |
| Tỉ lệ validation | 12% | Cố định trong script train |
| Augmentation train | Brightness ±15% | Chỉ trên tập train |

---

## 7. Quy trình huấn luyện

### 7.1 Script train

File: `data/train_receipt_models.py`

```powershell
# Cách 1: Sinh data + train một lệnh
python data/train_receipt_models.py --gen-n 4000 --epochs 40 --patience 15

# Cách 2: Data đã có, chỉ train
python data/train_receipt_models.py --epochs 40 --patience 15
```

Train **lần lượt 4 field:** `amount` → `merchant` → `date` → `line`

### 7.2 Hyperparameters

| Tham số | Giá trị |
|---------|---------|
| Optimizer | AdamW (lr=3e-4, weight_decay=1e-4) |
| Scheduler | CosineAnnealingLR |
| Loss | CTCLoss (blank=0) |
| Batch size | 64 |
| Epochs | 40 (early stopping patience=15) |
| IMG_H | 32 (cố định) |
| IMG_W | 192 / 224 / 160 / 256 (theo field) |
| Gradient clip | 1.0 |

### 7.3 Google Colab

Notebook: `ai_service/train_receipt_ocr.ipynb`

| Cell | Nội dung |
|------|----------|
| 0 | Mount Drive, cài thư viện |
| 1 | Trỏ tới `MyDrive/thesis/ai_service` |
| 2 | Kiểm tra GPU, set GEN_N/EPOCHS |
| 3 | Gọi `gen_receipt_dataset.py` |
| 4 | Gọi `train_receipt_models.py` |
| 5 | Backup 8 file model lên Drive |
| 6–7 | Demo inference |

**Runtime:** T4 GPU (~10–20 phút với 4000 mẫu).

### 7.4 Artifact sau train

```
models/
├── ocr_amount_model.pt      + ocr_amount_meta.json
├── ocr_merchant_model.pt    + ocr_merchant_meta.json
├── ocr_date_model.pt        + ocr_date_meta.json
├── ocr_line_model.pt        + ocr_line_meta.json
├── ocr_model.pt             (alias amount, tương thích cũ)
└── ocr_meta.json
```

File `*_meta.json` lưu: `img_h`, `img_w`, `num_classes`, `val_ctc_loss`, số mẫu train/val.

---

## 8. Suy luận và pipeline 5 field

### 8.1 Hàm chính

```python
from app.receipt_parse import parse_receipt_image

result = parse_receipt_image(img, ocr_bundles, classify_bundle)
# result.to_dict() → JSON 5 field
```

### 8.2 Response mẫu

```json
{
  "amount_vnd": 125000,
  "transaction_date": "2026-05-20",
  "merchant": "HIGHLANDS COFFEE",
  "description": "Ca phe sua da",
  "category": "Ăn uống",
  "type": "EXPENSE",
  "category_confidence": 0.9123,
  "field_confidence": {
    "amount": 0.96,
    "date": 0.88,
    "merchant": 0.91,
    "description": 0.85,
    "category": 0.91
  },
  "raw": {
    "amount": "125.000",
    "merchant": "HIGHLANDS COFFEE",
    "date": "20/05/2026",
    "description": "Ca phe sua da"
  },
  "needs_review": false
}
```

### 8.3 Cờ `needs_review`

`needs_review = true` khi:

- Confidence OCR thấp (< 0.55)
- Không parse được số tiền

→ UI **bắt buộc user xác nhận/sửa** trước khi lưu (tránh ghi nhầm dữ liệu tài chính).

### 8.4 Xử lý danh mục

Không train OCR riêng cho category. Luồng:

```
text = merchant + " " + description
→ predict_category(CharTextCNN)
→ category, confidence, EXPENSE|INCOME
```

Fallback: `rules.py` khi confidence TextCNN < ngưỡng (0.50).

---

## 9. API và tích hợp

### 9.1 Endpoints mới

| Method | Path | Mô tả |
|--------|------|-------|
| POST | `/api/ocr/receipt/parse` | Parse đủ 5 field từ ảnh |
| POST | `/api/ocr/receipt/amount` | Chỉ đọc số tiền |
| GET | `/health` | Bổ sung `ocr_*_loaded` |

### 9.2 Health check

```json
{
  "ok": true,
  "ocr_amount_loaded": true,
  "ocr_merchant_loaded": true,
  "ocr_date_loaded": true,
  "ocr_line_loaded": true,
  "classify_loaded": true,
  "forecast_loaded": true
}
```

### 9.3 Test curl

```powershell
curl.exe -X POST "http://127.0.0.1:8000/api/ocr/receipt/parse" ^
  -F "file=@data/receipt_ocr/images/full/bill_00000.png"
```

### 9.4 Biến môi trường Backend

```yaml
PYTHON_AI_API_URL: http://localhost:8000
```

Backend Java gọi multipart upload tới `/api/ocr/receipt/parse`.

---

## 10. Cấu trúc mã nguồn

```
ai_service/
├── app/
│   ├── ocr_net.py              # ReceiptLineCRNN
│   ├── ocr_charset.py          # Charset CTC
│   ├── ocr_infer.py            # Load + inference từng field
│   ├── receipt_layout.py       # Cắt vùng bill
│   ├── receipt_parse.py        # Pipeline 5 field
│   ├── classify_infer.py       # TextCNN (danh mục)
│   └── main.py                 # FastAPI endpoints
├── data/
│   ├── gen_receipt_dataset.py  # Sinh dataset synthetic
│   └── train_receipt_models.py # Train 4 model
├── models/                     # Weights (.pt + .json)
├── train_receipt_ocr.ipynb     # Notebook Colab
└── README.md
```

---

## 11. So sánh 3 module AI

| Tiêu chí | Phân loại | Dự báo | **OCR hóa đơn** |
|----------|-----------|--------|-----------------|
| Kiến trúc | CharTextCNN | SpendingForecastTransformer | ReceiptLineCRNN × 4 |
| Input | Text | Chuỗi 30 ngày VND | Ảnh hóa đơn |
| Output | 20 nhãn | 7 ngày VND | 5 field giao dịch |
| Số model | 1 | 1 | 4 (+ tái s dụng TextCNN) |
| Loss | CrossEntropy | Huber | CTCLoss |
| Dữ liệu | classify_train.csv | daily_spending_train.csv | **Synthetic PNG** |
| Train notebook | train_classify.ipynb | train_forecast.ipynb | **train_receipt_ocr.ipynb** |
| Fine-tune pretrained | Không | Không | **Không** |
| Endpoint | /api/categorize | /api/forecast | **/api/ocr/receipt/parse** |

---

## 12. Đánh giá và hạn chế

### 12.1 Metric huấn luyện

- **CTC loss** trên tập validation (càng thấp càng tốt)
- **Exact amount accuracy:** % mẫu OCR đúng hoàn toàn số VND
- **needs_review rate:** tỉ lệ ảnh cần user sửa (đo trên tập test)

### 12.2 Hạn chế hiện tại

| Hạn chế | Mô tả | Hướng cải thiện |
|---------|--------|-----------------|
| Dữ liệu synthetic | Font/layout đơn giản | Thêm 50–100 bill thật label tay |
| Heuristic layout | Giả định header/body/footer cố định | LayoutCNN detect vùng |
| Bill phức tạp | Nhiều cột, chữ nghiêng, ảnh mờ | Augmentation mạnh hơn + data thật |
| Chỉ tiếng Việt/Latin | Không hỗ trợ CJK | Mở rộng charset |

### 12.3 Điểm mạnh cho báo cáo

- Kiến trúc **tự xây from-scratch**, thống nhất với 2 AI trước
- Pipeline **tách nhiệm vụ**, dễ giải thích và demo
- **Tái s dụng TextCNN** — thể hiện thiết kế hệ thống hợp lý
- Không phụ thuộc API OCR bên thứ ba
- Có thể demo end-to-end: chụp bill → form pre-fill → lưu giao dịch

---

## 13. Hướng dẫn triển khai

### 13.1 Train trên máy local

```powershell
cd c:\Nam4\Doantotnghiep2\ai_service
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt

python data/gen_receipt_dataset.py --n 4000
python data/train_receipt_models.py --epochs 40 --patience 15
```

### 13.2 Train trên Google Colab

1. Upload `ai_service/` lên `MyDrive/thesis/ai_service`
2. Mở `train_receipt_ocr.ipynb` → Runtime **T4 GPU**
3. Chạy CELL 0 → 5
4. Tải 8 file từ `MyDrive/expense_receipt_ocr/` về `models/`

### 13.3 Chạy service

```powershell
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Kiểm tra: http://127.0.0.1:8000/docs

### 13.4 Checklist demo cho hội đồng

- [ ] `/health` — 4 model OCR loaded
- [ ] Upload bill synthetic → parse đúng amount + merchant
- [ ] Danh mục tự điền (TextCNN)
- [ ] `needs_review` highlight field nghi ngờ trên UI
- [ ] So sánh: nhập tay vs chụp bill (tiết kiệm thao tác)

---

## Tài liệu liên quan

| File | Nội dung |
|------|----------|
| `docs/BAO_CAO_AI.md` | TextCNN phân loại + Transformer dự báo |
| `docs/PHAN_TICH_THIET_KE_HE_THONG.md` | Thiết kế hệ thống tổng thể |
| `ai_service/README.md` | Hướng dẫn chạy nhanh |
| `ai_service/train_receipt_ocr.ipynb` | Notebook Colab |

---

*Báo cáo này mô tả module AI OCR hóa đơn — phần bổ sung thứ ba của hệ thống Expense Manager, phục vụ báo cáo tiến độ và bảo vệ đồ án tốt nghiệp.*
