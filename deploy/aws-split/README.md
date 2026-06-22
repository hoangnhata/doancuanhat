# Deploy: AWS (Backend + RDS) + Hugging Face (AI)

Kiến trúc:

```
Web/Flutter  →  AWS EC2 (Spring Boot)  →  AWS RDS MySQL
                      ↓
              Hugging Face Space (FastAPI + PyTorch)
```

**Thời gian ước tính:** 2–3 giờ lần đầu.

---

## PHẦN 0 — Chuẩn bị trên máy Windows

### 0.1. Tài khoản cần có

| Dịch vụ | Link | Dùng cho |
|---------|------|----------|
| AWS | https://aws.amazon.com | EC2 + RDS |
| Hugging Face | https://huggingface.co | AI Service |
| GitHub | đã có `hoangnhata/doancuanhat` | Source code |
| Gmail | App Password | OTP email |

### 0.2. Lấy Gemini API key (chatbot)

1. Vào https://aistudio.google.com/apikey
2. Tạo key → lưu lại (dùng cho HF Space Secrets)

### 0.3. Gmail App Password

1. Google Account → Bảo mật → Bật xác minh 2 bước
2. Mật khẩu ứng dụng → tạo cho "Mail"
3. Lưu 16 ký tự (dùng `MAIL_PASSWORD` trên EC2)

---

## PHẦN 1 — Deploy AI lên Hugging Face (làm TRƯỚC)

> Làm trước để có URL `PYTHON_AI_API_URL` cho backend.

### Bước 1.1 — Đăng ký Hugging Face

1. https://huggingface.co/join
2. Xác nhận email

### Bước 1.2 — Tạo Space

1. https://huggingface.co/new-space
2. Điền:
   - **Space name:** `expense-ai`
   - **License:** MIT
   - **SDK:** **Docker** (quan trọng!)
   - **Visibility:** Public
3. **Create Space**

### Bước 1.3 — Cài Git LFS trên Windows

```powershell
# Nếu chưa có Git LFS
git lfs install
```

### Bước 1.4 — Clone Space và copy code AI

Thay `YOUR_HF_USERNAME` bằng username Hugging Face của bạn:

```powershell
cd c:\Nam4
git clone https://huggingface.co/spaces/YOUR_HF_USERNAME/expense-ai
cd expense-ai
```

Copy file deploy + code AI vào Space:

```powershell
# Dockerfile + dockerignore + gitattributes
Copy-Item c:\Nam4\Doantotnghiep2\deploy\huggingface\Dockerfile .
Copy-Item c:\Nam4\Doantotnghiep2\deploy\huggingface\.dockerignore .
Copy-Item c:\Nam4\Doantotnghiep2\deploy\huggingface\.gitattributes .

# requirements + app + models
Copy-Item c:\Nam4\Doantotnghiep2\ai_service\requirements.txt .
xcopy /E /I /Y c:\Nam4\Doantotnghiep2\ai_service\app app
xcopy /E /I /Y c:\Nam4\Doantotnghiep2\ai_service\models models
```

**Kiểm tra models có đủ:**

```powershell
dir models\*.pt
# Cần: classify_model.pt, forecast_model.pt, ocr_reco_model.pt
```

### Bước 1.5 — Push lên Hugging Face

```powershell
cd c:\Nam4\expense-ai
git lfs track "*.pt"
git add .
git commit -m "Deploy expense AI service"
git push
```

> Lần đầu push hỏi login HF — dùng **Access Token** (Settings → Access Tokens → Write).

Space sẽ tự build Docker (~5–15 phút). Theo dõi tab **Logs** trên Hugging Face.

### Bước 1.6 — Thêm Secret Gemini

1. Space → **Settings** → **Repository secrets**
2. Thêm:
   - Name: `GEMINI_API_KEY`
   - Value: `AIza...`

### Bước 1.7 — Test AI

URL Space: `https://YOUR_HF_USERNAME-expense-ai.hf.space`

Mở trình duyệt:

```
https://YOUR_HF_USERNAME-expense-ai.hf.space/health
```

Kết quả mong đợi:

```json
{
  "ok": true,
  "classify_loaded": true,
  "forecast_loaded": true,
  "ocr_transfer_loaded": true,
  "gemini_available": true
}
```

**Ghi lại URL này** → dùng cho `PYTHON_AI_API_URL`.

---

## PHẦN 2 — Tạo RDS MySQL trên AWS

### Bước 2.1 — Đăng nhập AWS

1. https://console.aws.amazon.com
2. Góc trên phải chọn region: **Asia Pacific (Singapore) `ap-southeast-1`**

### Bước 2.2 — Tạo database

1. Tìm **RDS** → **Create database**
2. Cấu hình:

| Mục | Giá trị |
|-----|---------|
| Creation method | **Standard create** |
| Engine | **MySQL** |
| Version | 8.0.x |
| Templates | **Free tier** |
| DB instance identifier | `expense-db` |
| Master username | `admin` |
| Master password | Đặt mật khẩu mạnh → **ghi lại** |
| DB name | `expense_manager` |
| Instance class | **db.t3.micro** |
| Storage | 20 GB (free) |
| Public access | **Yes** |
| VPC security group | Tạo mới `expense-rds-sg` |

3. **Create database** — đợi ~5–10 phút (Status = Available)

### Bước 2.3 — Lấy Endpoint

RDS → Databases → `expense-db` → copy **Endpoint**, ví dụ:

```
expense-db.abc123xyz.ap-southeast-1.rds.amazonaws.com
```

### Bước 2.4 — Mở port 3306 cho EC2 (làm sau khi tạo EC2)

Tạm thời cho phép từ mọi IP (demo — production nên giới hạn SG EC2):

1. **EC2 → Security Groups** → chọn `expense-rds-sg`
2. **Inbound rules → Edit**
3. Thêm rule:
   - Type: **MySQL/Aurora**
   - Port: **3306**
   - Source: Security group của EC2 (bước 3) hoặc tạm `0.0.0.0/0`

---

## PHẦN 3 — Tạo EC2 cho Backend

### Bước 3.1 — Launch Instance

1. **EC2 → Instances → Launch instances**
2. Cấu hình:

| Mục | Giá trị |
|-----|---------|
| Name | `expense-backend` |
| AMI | **Ubuntu Server 22.04 LTS** |
| Instance type | **t3.micro** (free tier) |
| Key pair | **Create new** → tải file `.pem` |
| Security group | Tạo mới `expense-ec2-sg` |

3. **Inbound rules** của `expense-ec2-sg`:

| Type | Port | Source |
|------|------|--------|
| SSH | 22 | My IP |
| HTTP | 80 | 0.0.0.0/0 |
| HTTPS | 443 | 0.0.0.0/0 |

4. Storage: **20 GB** gp3
5. **Launch instance**

### Bước 3.2 — Ghi Public IP

EC2 → Instances → copy **Public IPv4 address**, ví dụ `54.123.45.67`

### Bước 3.3 — Cập nhật RDS Security Group

Quay lại RDS SG → Inbound → MySQL 3306 → Source = **`expense-ec2-sg`** (security group của EC2)

---

## PHẦN 4 — SSH và cài Backend trên EC2

### Bước 4.1 — SSH từ Windows

```powershell
ssh -i "C:\path\to\expense-backend.pem" ubuntu@54.123.45.67
```

> Nếu lỗi permission: `icacls "C:\path\to\expense-backend.pem" /inheritance:r /grant:r "%USERNAME%:R"`

### Bước 4.2 — Clone repo

```bash
git clone https://github.com/hoangnhata/doancuanhat.git
cd doancuanhat
```

### Bước 4.3 — Tạo file cấu hình

```bash
sudo mkdir -p /etc/expense-manager
sudo cp deploy/aws-split/env.example /etc/expense-manager/production.env
sudo nano /etc/expense-manager/production.env
```

**Sửa các dòng sau** (ví dụ):

```bash
SPRING_DATASOURCE_URL=jdbc:mysql://expense-db.abc123xyz.ap-southeast-1.rds.amazonaws.com:3306/expense_manager?useSSL=true&serverTimezone=Asia/Ho_Chi_Minh&allowPublicKeyRetrieval=true&characterEncoding=UTF-8
SPRING_DATASOURCE_USERNAME=admin
SPRING_DATASOURCE_PASSWORD=<rds-password>
JWT_SECRET=<chạy: openssl rand -hex 32>
PYTHON_AI_API_URL=https://YOUR_HF_USERNAME-expense-ai.hf.space
MAIL_USERNAME=<gmail>
MAIL_PASSWORD=<gmail-app-password>
CORS_ALLOWED_ORIGINS=http://localhost:5173
GIT_REPO=https://github.com/hoangnhata/doancuanhat.git
APP_DIR=/home/ubuntu/doancuanhat
```

Lưu: `Ctrl+O` → Enter → `Ctrl+X`

### Bước 4.4 — Chạy setup

```bash
chmod +x deploy/aws-split/*.sh
bash deploy/aws-split/setup-backend.sh
```

### Bước 4.5 — Kiểm tra

```bash
# Log backend
sudo journalctl -u expense-backend -n 80 --no-pager

# Test local
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8080/api/swagger-ui.html
```

Từ trình duyệt máy bạn:

```
http://54.123.45.67/api/swagger-ui.html
```

---

## PHẦN 5 — Cấu hình Web / Flutter

### Web (Vercel — tuỳ chọn)

1. https://vercel.com → Import repo → root `web/`
2. Environment variable:

```
VITE_API_BASE_URL=http://54.123.45.67/api
```

3. Deploy xong → thêm URL Vercel vào EC2:

```bash
sudo nano /etc/expense-manager/production.env
# CORS_ALLOWED_ORIGINS=http://localhost:5173,https://your-app.vercel.app
sudo systemctl restart expense-backend
```

### Flutter APK

```powershell
flutter build apk --dart-define=API_BASE_URL=http://54.123.45.67/api
```

---

## PHẦN 6 — Test end-to-end

| # | Test | Cách |
|---|------|------|
| 1 | AI health | `https://USER-expense-ai.hf.space/health` |
| 2 | Backend | `http://EC2_IP/api/swagger-ui.html` |
| 3 | Đăng ký | Swagger → POST `/auth/register/request` |
| 4 | AI categorize | POST `/transactions/ai/categorize` với JWT |
| 5 | Chatbot | Mở tab Chat trên app |

---

## Xử lý lỗi thường gặp

| Lỗi | Nguyên nhân | Cách sửa |
|-----|-------------|----------|
| Backend không start | Sai RDS URL/password | `journalctl -u expense-backend` |
| `Communications link failure` | RDS SG chặn EC2 | Mở 3306 từ EC2 security group |
| AI 503 / timeout | HF Space đang build/sleep | Đợi build xong, gọi `/health` trước |
| `classify_loaded: false` | Thiếu model trên HF | Push lại `.pt` với Git LFS |
| CORS error | Thiếu origin | Thêm URL vào `CORS_ALLOWED_ORIGINS` |
| Email OTP không gửi | Sai App Password | Kiểm tra `MAIL_*` |

---

## Cập nhật code sau này

**Backend (EC2):**

```bash
cd ~/doancuanhat && bash deploy/aws-split/deploy-app.sh
```

**AI (Hugging Face):**

```powershell
cd c:\Nam4\expense-ai
# copy code mới từ ai_service...
git add . && git commit -m "update" && git push
```

---

## Checklist hoàn thành

- [ ] HF Space `/health` → all `true`
- [ ] RDS Status = Available
- [ ] EC2 Swagger mở được
- [ ] Đăng ký + đăng nhập OK
- [ ] AI categorize hoạt động
- [ ] Chatbot trả lời (có Gemini key)
- [ ] Web/App trỏ đúng `API_BASE_URL`
