# Hướng dẫn Git — clone và chạy trên máy mới

Repository: **https://github.com/hoangnhata/doancuanhat**

---

## Phần A — Lấy code từ GitHub (máy chưa có gì)

### Bước 1: Cài Git

**Windows:** tải [Git for Windows](https://git-scm.com/download/win), cài mặc định, mở **Git Bash** hoặc **PowerShell**.

Kiểm tra:

```powershell
git --version
```

### Bước 2: Clone dự án

Chọn thư mục lưu code (ví dụ `C:\Projects`):

```powershell
cd C:\Projects
git clone https://github.com/hoangnhata/doancuanhat.git
cd doancuanhat
```

Nếu repo **private**, GitHub sẽ hỏi đăng nhập. Dùng **Personal Access Token** thay mật khẩu: GitHub → Settings → Developer settings → Personal access tokens.

### Bước 3: Cập nhật code sau này

```powershell
cd C:\Projects\doancuanhat
git pull
```

---

## Phần B — Cài phần mềm trên máy trắng (Windows)

Cài lần lượt (có thể dùng [winget](https://learn.microsoft.com/en-us/windows/package-manager/winget/) hoặc link chính thức):

| Thứ tự | Phần mềm | Link / lệnh | Kiểm tra |
|--------|----------|-------------|----------|
| 1 | **Git** | https://git-scm.com/download/win | `git --version` |
| 2 | **Docker Desktop** (khuyến nghị cho MySQL) | https://www.docker.com/products/docker-desktop | `docker --version` |
| 3 | **Java JDK 17** | https://adoptium.net/ | `java -version` |
| 4 | **Maven** | https://maven.apache.org/download.cgi | `mvn -v` |
| 5 | **Python 3.10+** | https://www.python.org/downloads/ (tick *Add to PATH*) | `python --version` |
| 6 | **Node.js 18+** (cho web) | https://nodejs.org/ | `node -v` |
| 7 | **Flutter 3** | https://docs.flutter.dev/get-started/install/windows | `flutter doctor` |

**Android app:** cài thêm **Android Studio** → SDK + tạo emulator (theo `flutter doctor`).

**Chỉ chạy Web:** có thể bỏ Flutter/Android, chỉ cần Node + Java + MySQL + Python.

---

## Phần C — Model AI (quan trọng)

Thư mục `ai_service/models/` trên Git **không chứa** file `.pt` (file nặng, train riêng).

Sau khi clone, bạn cần **một trong hai**:

1. **Copy từ máy cũ / Google Drive** vào `ai_service/models/`:
   - Classify: `classify_model.pt`, `classify_vocab.json`, `classify_meta.json`, …
   - OCR: `ocr_*.pt`, `ocr_*_meta.json`
   - Forecast: `forecast_model.pt`, `forecast_meta.json`
   - Xem danh sách đầy đủ: `ai_service/models/README.md`

2. **Train lại** trên máy mới (mất thời gian):
   ```powershell
   cd ai_service
   python -m venv .venv
   .\.venv\Scripts\Activate.ps1
   pip install -r requirements.txt
   python scripts/train_classify_pipeline.py
   python data/train_receipt_models.py --gen-n 4000 --epochs 40
   ```

Không có model → AI classify/OCR/forecast sẽ lỗi hoặc fallback; backend vẫn chạy được phần CRUD cơ bản.

**Chatbot Gemini (tuỳ chọn):**

```powershell
$env:GEMINI_API_KEY = "your-key-from-aistudio"
```

Lấy key miễn phí: https://aistudio.google.com/apikey

---

## Phần D — Chạy toàn bộ hệ thống (4 terminal)

Giả sử project nằm tại `C:\Projects\doancuanhat`.

### Terminal 1 — MySQL (Docker)

```powershell
docker run -d --name mysql-expense -p 3307:3306 `
  -e MYSQL_ROOT_PASSWORD=root `
  -e MYSQL_DATABASE=expense_manager `
  mysql:8
```

Tạo DB (nếu cần):

```powershell
docker exec -it mysql-expense mysql -uroot -proot -e "CREATE DATABASE IF NOT EXISTS expense_manager CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
```

### Terminal 2 — AI Service (port 8000)

```powershell
cd C:\Projects\doancuanhat\ai_service
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Kiểm tra: http://localhost:8000/health

### Terminal 3 — Backend (port 8080)

```powershell
cd C:\Projects\doancuanhat\backend
mvn spring-boot:run
```

- Swagger: http://localhost:8080/api/swagger-ui.html  
- MySQL mặc định trong `application.yml`: `localhost:3307`, user `root`, password `root`.

**Tài khoản demo** (seed tự động ở dev):

- Email: `ai.demo@local.test`
- Password: `Demo@123456`

### Terminal 4a — Flutter (mobile / web app)

```powershell
cd C:\Projects\doancuanhat\frontend
flutter pub get
flutter doctor
flutter run -d chrome
```

App tự chọn `baseUrl` theo nền tảng (`api_constants.dart`). Thiết bị thật: máy và phone cùng WiFi, backend bind `0.0.0.0`.

### Terminal 4b — React Web (tuỳ chọn)

```powershell
cd C:\Projects\doancuanhat\web
copy .env.example .env.local
npm install
npm run dev
```

Mở URL do Vite in ra (thường http://localhost:5173).

---

## Phần E — Đẩy code lên GitHub (cho người maintain)

Trên máy đã có thay đổi:

```powershell
cd C:\Nam4\Doantotnghiep2
git status
git add .
git commit -m "Mô tả thay đổi"
git push origin main
```

Lần đầu trên máy mới:

```powershell
git remote add origin https://github.com/hoangnhata/doancuanhat.git
git branch -M main
git push -u origin main
```

---

## Phần F — Lỗi thường gặp khi clone

| Triệu chứng | Cách xử lý |
|-------------|------------|
| `git clone` bị từ chối | Đăng nhập GitHub / dùng token |
| Backend: Cannot connect MySQL | Bật Docker container MySQL, đúng port **3307** |
| `mvn` không nhận lệnh | Cài Maven, thêm vào PATH |
| `flutter` không nhận lệnh | Cài Flutter, chạy `flutter doctor` |
| AI `/health` báo thiếu model | Copy hoặc train file `.pt` vào `ai_service/models/` |
| App không gọi được API | Backend đang chạy; firewall; thiết bị thật dùng IP LAN |

Chi tiết thêm: [HUONG_DAN_CHAY.md](HUONG_DAN_CHAY.md), [README.md](../README.md).
