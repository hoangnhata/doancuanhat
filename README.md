# Expense Manager - Quản lý Chi tiêu Cá nhân (Natta AI)

**Repository GitHub:** https://github.com/hoangnhata/doancuanhat  
**Clone + chạy máy mới:** [docs/HUONG_DAN_GIT.md](docs/HUONG_DAN_GIT.md)

Ứng dụng quản lý chi tiêu cá nhân đa nền tảng với AI categorize, OCR hóa đơn,
dự báo chi tiêu và **chatbot tài chính cá nhân**.

📖 **Hướng dẫn chạy chi tiết:** [docs/HUONG_DAN_CHAY.md](docs/HUONG_DAN_CHAY.md)
📊 **Phân tích thiết kế hệ thống:** [docs/PHAN_TICH_THIET_KE_HE_THONG.md](docs/PHAN_TICH_THIET_KE_HE_THONG.md)

## Cấu trúc dự án

```
Doantotnghiep2/
├── backend/      # Spring Boot 3.2 + MySQL + JWT
├── frontend/     # Flutter (Android/iOS/Web) - offline-first
├── ai_service/   # FastAPI + PyTorch (Classify / Forecast / OCR / Chatbot)
├── web/          # React + Vite + MUI (mirror của mobile)
└── docs/         # Báo cáo & tài liệu
```

## Các tính năng chính

### Cơ bản
- **Đăng ký 2 bước với OTP email (mới)** — verify email trước khi tạo tài khoản
- Đăng nhập / Refresh token (JWT)
- **Quên mật khẩu qua OTP email (mới)**
- Quản lý ví, danh mục, giao dịch (offline-first với SQLite + đồng bộ outbox)
- Ngân sách theo danh mục + cảnh báo
- Giao dịch định kỳ tự động
- Xuất báo cáo Excel & PDF (font Việt)

### AI tích hợp
- **Phân loại tự động** câu nhập tự nhiên: "ăn trưa 50k, grab 30k" → tách + ghi 2 giao dịch.
- **OCR hóa đơn (mới)**: chụp ảnh / chọn ảnh → backend proxy lên FastAPI (EasyOCR + CRNN) → tự đọc số tiền, ngày, cửa hàng, đề xuất danh mục.
- **Dự báo chi tiêu** 7 ngày (LSTM + seq2seq).
- **Chatbot tài chính Natta (mới)**: hỏi đáp về chi tiêu cá nhân — gọi Google Gemini (free tier) với context giao dịch 45 ngày + ngân sách. Fallback rule-based khi không có API key.

### UX
- **Dark / Light / System Theme (mới)** — chọn trong Settings (cả mobile + web).
- Mascot Natta với 3 personality: HAPPY / SAD / ANGRY (đổi giọng phản hồi).
- FAB kéo thả như AssistiveTouch (mobile).
- Onboarding chọn bot + ví + currency.
- Local notification + daily reminder (mobile).
- Đa nền tảng: Android / iOS / Web / Windows.
- **Tất cả tính năng AI (OCR, Chatbot, Forecast) có sẵn cả mobile + web (mới).**

## Khởi động nhanh (3 service)

### 1. MySQL
```sh
docker run -d --name mysql-expense -p 3307:3306 \
  -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=expense_manager \
  mysql:8
```

### 2. AI Service (FastAPI)
```powershell
cd ai_service
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
# (tuỳ chọn) bật Gemini chatbot:
$env:GEMINI_API_KEY = "YOUR_KEY"
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### 3. Backend (Spring Boot)
```sh
cd backend
mvn spring-boot:run
```
Swagger UI: <http://localhost:8080/api/swagger-ui.html>

### 4. Frontend (Flutter)
```sh
cd frontend
flutter pub get
flutter run
```

### 5. Web (React)
```sh
cd web
npm install
npm run dev
```

## Tính năng mới chi tiết

### Đăng ký 2 bước OTP (mới)
- Trên màn hình **Đăng ký** → nhập họ tên / email / mật khẩu / SĐT → backend tạo OTP 6 số (BCrypt-hash, TTL 10 phút) và lưu vào bảng `pending_registrations` — **chưa tạo user thật**.
- App chuyển sang màn **Xác minh email** → user nhập OTP → backend verify → tạo user thật + auto-login.
- Tối đa 5 lần verify sai → xóa pending, yêu cầu đăng ký lại.
- Endpoints: `POST /auth/register/request`, `POST /auth/register/verify`, `POST /auth/register/resend-otp`.
- Endpoint legacy `POST /auth/register` vẫn còn để tương thích.

### Dark Mode
- **Mobile**: tab **Cài đặt** → mục **Giao diện** → chọn `Sáng / Tối / Theo hệ thống`.
- **Web**: trang **Cài đặt** → mục **Giao diện & nhắc nhở** → chọn 3 chế độ (theo dõi `prefers-color-scheme` tự động khi ở mode System).
- Lưu vào `localStorage` (web) / `SharedPreferences` (mobile), áp dụng ngay không cần reload.

### Quên mật khẩu (OTP)
- Trên màn hình **Đăng nhập** → nhấn "Quên mật khẩu?" → nhập email → backend sinh OTP 6 số (BCrypt-hashed, TTL 10 phút), gửi qua Gmail SMTP.
- Backend: `POST /auth/forgot-password`, `POST /auth/reset-password` (xem [API_DOCUMENTATION.md](backend/API_DOCUMENTATION.md)).
- Cấu hình SMTP qua env:
  ```sh
  export MAIL_USERNAME=your@gmail.com
  export MAIL_PASSWORD=app_password_16ky_tu   # App password Gmail
  ```
- Nếu chưa cấu hình mail, OTP sẽ được log ra console (dev mode) — tắt bằng `PASSWORD_RESET_DEV_LOG_OTP=false`.

### OCR hóa đơn
- **Mobile**: màn **Thêm giao dịch** → nhấn **"Quét hóa đơn bằng camera"** → chọn camera/gallery.
- **Web**: màn **Thêm giao dịch** → nhấn **"Quét hóa đơn"** → upload ảnh (mobile browser sẽ tự mở camera nhờ `capture="environment"`).
- Backend: `POST /transactions/ai/ocr/receipt` (multipart, field `file`) → proxy lên FastAPI `/api/ocr/receipt/parse`.
- Hỗ trợ tối đa 10MB ảnh JPG/PNG.
- Engine: EasyOCR (mặc định) hoặc CRNN nếu có model.

### Chatbot tài chính
- **Mobile + Web** trên tab/trang **Trợ lý AI** → chuyển sang chế độ **"Hỏi Natta"** → hỏi câu hỏi tự nhiên.
- Ví dụ:
  - "Tháng này tôi tiêu nhiều nhất vào đâu?"
  - "Tôi nên cắt giảm khoản nào?"
  - "Ngân sách của tôi còn lại bao nhiêu?"
- Backend: `POST /ai/chat` → tự đính kèm 45 ngày giao dịch + ngân sách → proxy sang FastAPI `/api/chat`.
- AI: Google Gemini 1.5 Flash (cấu hình `GEMINI_API_KEY`). Không có key → rule-based summarizer.
- Lấy free key: <https://aistudio.google.com/apikey>

## Tài khoản demo

Backend tự seed user demo khi `SEED_DEMO_USER=true` (mặc định ở dev):
- Email: `ai.demo@local.test`
- Password: `Demo@123456`
- Có sẵn 45 ngày dữ liệu để demo dự báo + chatbot.

## Biến môi trường quan trọng

| Biến | Module | Mặc định | Mô tả |
|------|--------|----------|-------|
| `JWT_SECRET` | backend | — (có giá trị dev) | Đổi ở production |
| `PYTHON_AI_API_URL` | backend | `http://localhost:8000` | URL của FastAPI |
| `MAIL_USERNAME` | backend | — | Gmail gửi OTP |
| `MAIL_PASSWORD` | backend | — | App password Gmail |
| `PASSWORD_RESET_DEV_LOG_OTP` | backend | `true` | Log OTP ra console (dev only) |
| `SEED_DEMO_USER` | backend | `true` | Seed user demo |
| `GEMINI_API_KEY` | ai_service | — | Google Gemini chatbot |
| `GEMINI_MODEL` | ai_service | `gemini-1.5-flash` | Model Gemini |

## Bảng API chính

| Endpoint | Mô tả |
|----------|-------|
| `POST /auth/login` | Đăng nhập |
| `POST /auth/register/request` | **Bước 1 đăng ký OTP — gửi mã 6 số đến email** |
| `POST /auth/register/verify` | **Bước 2 — verify OTP + tạo user thật + auto-login** |
| `POST /auth/register/resend-otp` | **Gửi lại OTP đăng ký** |
| `POST /auth/forgot-password` | **Yêu cầu OTP đặt lại mật khẩu** |
| `POST /auth/reset-password` | **Đổi mật khẩu bằng OTP** |
| `POST /transactions/ai/categorize` | AI phân loại 1 câu |
| `POST /transactions/ai/categorize/batch` | AI phân loại nhiều khoản |
| `POST /transactions/ai/ocr/receipt` | **OCR hóa đơn (multipart)** |
| `POST /ai/chat` | **Chatbot hỏi đáp tài chính** |
| `GET /ai/suggestions` | Gợi ý tiết kiệm |
| `GET /statistics/spending-forecast` | Dự báo 7 ngày |
| `GET /export/transactions?format=excel\|pdf` | Xuất báo cáo |

Đầy đủ: [backend/API_DOCUMENTATION.md](backend/API_DOCUMENTATION.md)

## Công nghệ

| Lớp | Stack |
|-----|-------|
| Backend | Spring Boot 3.2, Java 17, Spring Security, JPA, MySQL, Apache POI, OpenPDF, Spring Mail |
| AI | FastAPI, PyTorch, EasyOCR, Google Gemini API, httpx |
| Mobile | Flutter 3, Riverpod, Dio, Drift (SQLite), fl_chart, image_picker |
| Web | React 18, Vite, MUI 5, React Query, Recharts |

## Kiến trúc tổng quan

```
┌──────────────┐         ┌──────────────┐         ┌──────────────┐
│  Flutter App │ ──REST──▶  Spring Boot │ ──REST──▶  FastAPI AI  │
│  (offline)   │ ◀────────  Backend     │ ◀────────  (PyTorch +  │
│  SQLite      │         │   MySQL      │         │   Gemini)    │
└──────────────┘         └──────────────┘         └──────────────┘
       ▲                        ▲
       │                        │
       │                  ┌─────┴──────┐
       └──── REST ────────│  React Web │
                          └────────────┘
```

## Tiếp theo cần làm

- [ ] Docker compose toàn stack (1 lệnh chạy đủ 4 service)
- [ ] CI/CD GitHub Actions
- [ ] Unit/Integration test backend
- [ ] Biometric login (Face ID / vân tay)
- [ ] Shared wallet / chia hóa đơn

---

**Đồ án tốt nghiệp** — Natta AI Expense Manager.
