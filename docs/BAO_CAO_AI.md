# Báo cáo phần AI – Expense Manager

Tài liệu này mô tả **tổng quan mô hình AI**, **quy trình huấn luyện (train)**, **đánh giá**, và **cách sử dụng (inference/tích hợp hệ thống)** cho đề tài Expense Manager.

---

## 1) Tổng quan: AI làm gì trong hệ thống?

Hệ thống có **2 chức năng AI** chạy trong service Python `ai_service` (FastAPI):

- **Phân loại giao dịch từ ghi chú**: nhận chuỗi text (ví dụ: “ăn phở 50k”) → trả về **danh mục** (20 nhãn) + confidence.  
  Endpoint: `POST /api/categorize`
- **Dự báo tổng chi tiêu 7 ngày tiếp theo**: nhận chuỗi tổng chi tiêu theo ngày (VND) → trả về **7 giá trị dự báo**.  
  Endpoint: `POST /api/forecast`

Backend Spring Boot gọi trực tiếp `ai_service` (mặc định `http://localhost:8000`).

---

## 2) Cấu trúc thư mục AI quan trọng

Trong repo:

- `ai_service/app/`: code chạy FastAPI + infer + kiến trúc model
  - `app/main.py`: API `/api/categorize`, `/api/forecast`, `/health`
  - `app/classify_net.py`: kiến trúc **CharTextCNN**
  - `app/classify_infer.py`: load bundle + preprocess + dự đoán
  - `app/forecast_net.py`: kiến trúc **SpendingForecastTransformer**
  - `app/forecast_infer.py`: build feature + dự đoán + denormalize về VND
  - `app/forecast_features.py`: sinh đặc trưng lịch + share danh mục
- `ai_service/data/`: dữ liệu & script hỗ trợ
  - `data/classify_train.csv`: dataset phân loại (text,label)
  - `expand_classify_data.py`: sinh thêm dữ liệu phân loại (data augmentation dạng “tạo câu mới”)
  - `data/daily_spending_train.csv`: dataset chuỗi chi tiêu theo ngày (date, total_expense_vnd, share_*)
  - `data/gen_dataset.py`: sinh dataset daily spending mô phỏng
  - `data/eval_model.py`: script train/eval forecast (Transformer dự báo)
- `ai_service/models/`: **artifact model** để chạy inference
  - Phân loại: `classify_model.pt`, `classify_meta.json`, `classify_vocab.json`
  - Dự báo: `forecast_model.pt`, `forecast_meta.json`

---

## 3) Bài toán 1 – Phân loại giao dịch (Text → Category)

### 3.1 Mục tiêu & đầu vào/đầu ra

- **Input**: ghi chú giao dịch (thường ngắn, tiếng Việt không chuẩn, có số tiền)
- **Output**: 1 trong **20 nhãn**:
  - **Chi tiêu (14)**: Ăn uống, Di chuyển, Mua sắm, Nhà ở, Hóa đơn, Giải trí, Du lịch, Giáo dục, Sức khỏe, Gia đình, Thú cưng, Quà tặng, Từ thiện, Khác
  - **Thu nhập (6)**: Lương, Thưởng, Freelance, Đầu tư, Bán hàng, Thu nhập khác

### 3.2 Tổng quan model: `CharTextCNN` (TextCNN character-level)

Model được tự xây dựng (from-scratch) bằng PyTorch, theo hướng **character-level**:

- Chuẩn hoá text: lowercase + Unicode NFC + gọn khoảng trắng
- Tokenize theo **ký tự** (character indices)
- Mạng `CharTextCNN` (TextCNN):
  - Embedding ký tự (mặc định 64 chiều)
  - 4 nhánh `Conv1d` kernel size \([2,3,4,5]\) + ReLU + GlobalMaxPool
  - Concat → Dropout → Linear(256) → GELU → Dropout → Linear(num_classes)

**Lý do chọn character-level** (phù hợp ghi chú chi tiêu):

- Không cần tokenizer tiếng Việt phức tạp
- Chịu lỗi chính tả/viết tắt (“an pho 50k”, “k”, “ko”, …)
- Vocabulary nhỏ, model gọn, train nhanh trên CPU

### 3.3 Dữ liệu train

- File: `ai_service/data/classify_train.csv`
- Format bắt buộc:
  - `text`: ghi chú giao dịch
  - `label`: 1 trong 20 nhãn ở trên

Ngoài ra có thể dùng script sinh thêm data để cân bằng/đa dạng câu:

```powershell
cd c:\Nam4\Doantotnghiep2\ai_service
python expand_classify_data.py
```

### 3.4 Cách train (notebook có sẵn)

Notebook: `ai_service/train_classify.ipynb`

Luồng chính:

- Đọc `classify_train.csv`
- Split train/val theo stratified
- **Augmentation chỉ áp dụng trên tập train** (val giữ câu gốc để metric tin cậy)
- Xây vocab ký tự (thêm `<PAD>`, `<UNK>`)
- Train với:
  - Loss: CrossEntropy (có label smoothing)
  - Optimizer: AdamW + weight decay
  - Scheduler: CosineAnnealingLR
  - Early stopping theo val accuracy
- Lưu 3 file artifact:
  - `classify_model.pt`: `state_dict`
  - `classify_vocab.json`: char → id
  - `classify_meta.json`: siêu tham số + danh sách nhãn + `min_conf`

**Chạy notebook local**: mở notebook trong VSCode/Jupyter tại thư mục `ai_service/`.  
**Chạy notebook trên Colab**: notebook có cell mount Drive và tự tìm CSV.

### 3.5 Đưa model vào hệ thống (deploy inference)

1) Copy 3 file sau vào `ai_service/models/`:

- `classify_model.pt`
- `classify_vocab.json`
- `classify_meta.json`

2) Chạy service:

```powershell
cd c:\Nam4\Doantotnghiep2\ai_service
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

3) Kiểm tra load model:

- Mở `http://127.0.0.1:8000/health`  
  `classify_loaded: true` nghĩa là đã nhận đủ file model.

### 3.6 Cơ chế fallback “AI + Rule-based”

Trong `app/main.py`:

- Nếu model phân loại có sẵn:
  - Dự đoán AI + confidence
  - Nếu confidence < `min_conf` (trong `classify_meta.json`) → **fallback** sang luật (`rule_based_category`)
- Nếu model không có → dùng rule-based hoàn toàn

Mục tiêu: đảm bảo hệ thống vẫn chạy ổn khi model thiếu/đầu vào quá lạ.

---

## 4) Bài toán 2 – Dự báo chi tiêu 7 ngày (Time-series Forecasting)

### 4.1 Mục tiêu & đầu vào/đầu ra

- **Input**:
  - Chuỗi `daily_expenses_vnd`: tổng chi tiêu mỗi ngày (VND) theo thời gian
  - Cần tối thiểu `window = 30` ngày gần nhất
  - (Tuỳ chọn) `last_observation_date` (YYYY-MM-DD) để sinh đặc trưng lịch chính xác
- **Output**: danh sách 7 số nguyên VND cho 7 ngày tiếp theo

### 4.2 Đặc trưng (feature engineering)

Trong `app/forecast_features.py`, mỗi ngày được biểu diễn bằng:

- **Amount (chuẩn hoá)**: \( \log(1+x) \) rồi z-score theo thống kê toàn cục (mean/std lúc train)
- **Đặc trưng lịch (8 kênh)**:
  - sin/cos thứ trong tuần, weekend flag
  - sin/cos tháng
  - sin/cos ngày trong tháng
  - “early_month_pulse” (xung đầu tháng) để mô tả spike tiền nhà/hoá đơn
- **Share theo 5 nhóm danh mục** (5 kênh):
  - food, transport, shopping, bills, other  
  Nếu inference không có share theo ngày, model dùng `mean_category` trong `forecast_meta.json` như prior.

Tổng số kênh input encoder: `input_size = 1 + 8 + 5 = 14` (khớp `forecast_meta.json`).

### 4.3 Tổng quan model: `SpendingForecastTransformer` (non-autoregressive Transformer)

Model `SpendingForecastTransformer` (PyTorch) tự xây dựng “from scratch” theo hướng **Transformer phi-hồi quy**:

- Encoder đọc chuỗi quá khứ 30 ngày
- Decoder dự báo **7 ngày song song** (không autoregressive)
- Có self-attention + cross-attention + FFN + LayerNorm
- Có “instance norm” kiểu RevIN trên kênh amount theo 14 ngày gần nhất để ổn định scale từng cửa sổ

**Ý nghĩa**: dự báo 7 ngày đồng thời giúp giảm tích luỹ lỗi theo bước (so với dự báo từng ngày nối tiếp).

### 4.4 Dữ liệu train forecast

Dataset mẫu nằm tại `ai_service/data/daily_spending_train.csv` (có thể là dữ liệu mô phỏng).

Nếu cần sinh lại dataset mô phỏng:

```powershell
cd c:\Nam4\Doantotnghiep2\ai_service\data
python gen_dataset.py
```

### 4.5 Cách train & đánh giá forecast (script hiện có)

Hiện trong repo, phần train/eval forecast được thể hiện trong `ai_service/data/eval_model.py`:

- Chuẩn hoá amount: log1p + z-score toàn cục
- Tạo sliding windows với:
  - `WINDOW = 30`, `HORIZON = 7`
- Augmentation chuỗi (scale + noise) để tăng tính tổng quát
- Train với:
  - Loss: HuberLoss
  - Optimizer: AdamW
  - Scheduler: CosineAnnealingLR
  - Early stopping theo validation loss
- Report các metric (MAE/RMSE/MAPE) sau khi denormalize về VND

Ghi chú:

- Code API `app/main.py` có nhắc `train_forecast.ipynb`, nhưng **repo hiện chưa có notebook đó**; bạn có thể xem `data/eval_model.py` như “train script” thay thế để mô tả trong báo cáo.

### 4.6 Đóng gói model forecast để chạy trong `ai_service`

Để inference chạy, cần có trong `ai_service/models/`:

- `forecast_model.pt`: trọng số model (state_dict)
- `forecast_meta.json`: gồm tối thiểu các trường (tham khảo file đang có):
  - `window`, `horizon`, `input_size`
  - `mean_log`, `std_log` (để denormalize)
  - `mean_category` (5 phần tử)
  - tham số kiến trúc (`d_model`, `n_heads`, `n_enc_layers`, …)

Sau khi có đủ file, `/health` sẽ báo `forecast_loaded: true`.

---

## 5) Cách sử dụng API AI (để demo/báo cáo)

### 5.1 Chạy `ai_service`

```powershell
cd c:\Nam4\Doantotnghiep2\ai_service
.\.venv\Scripts\Activate.ps1
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### 5.2 Test phân loại giao dịch

Request (ví dụ):

```json
{ "text": "ăn trưa 50k" }
```

Response (ví dụ):

- `type`: `EXPENSE` hoặc `INCOME`
- `category`: danh mục dự đoán
- `amount`: số tiền (nếu parse được từ text)
- `description`: phần mô tả đã chuẩn hoá
- `confidence`: có thể `null` nếu fallback rule-based

### 5.3 Test dự báo chi tiêu 7 ngày

Request (ví dụ):

```json
{
  "daily_expenses_vnd": [120000, 90000, 150000, 110000, 180000, "..."],
  "last_observation_date": "2025-03-31"
}
```

Response:

- `predicted_next_days_vnd`: 7 số nguyên VND
- `window`: 30
- `horizon`: 7

---

## 6) Checklist tái lập kết quả (reproducibility)

- Cài Python 3.10+ và các thư viện trong `ai_service/requirements.txt`
- Phân loại:
  - Dataset `data/classify_train.csv` có đủ 2 cột `text,label`
  - Chạy `train_classify.ipynb` → sinh 3 file model → copy vào `ai_service/models/`
- Forecast:
  - Có dataset `data/daily_spending_train.csv` (hoặc chạy `data/gen_dataset.py`)
  - Dùng `data/eval_model.py` để train/eval và xuất model + meta (theo format `forecast_infer.py` yêu cầu)
- Chạy `uvicorn app.main:app` và kiểm tra `/health`

---

## 7) Điểm nhấn để trình bày với thầy cô (ngắn gọn)

- **Không dùng pretrained**: cả 2 model đều được thiết kế và train từ đầu để phù hợp bài toán chi tiêu cá nhân.
- **Phân loại dùng TextCNN char-level**: tối ưu cho ghi chú ngắn, nhiều lỗi/viết tắt.
- **Dự báo dùng Transformer phi-hồi quy**: dự báo 7 ngày song song, giảm tích luỹ lỗi; kết hợp feature lịch (tuần/tháng/đầu tháng) và share danh mục.
- **Có cơ chế fallback**: AI confidence thấp → luật; đảm bảo hệ thống ổn định khi input “lạ”.

