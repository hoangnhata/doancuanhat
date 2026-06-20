# Deploy Oracle Cloud — Phương án A (FREE)

Chạy **MySQL + Backend (Spring Boot) + AI Service (FastAPI)** trên **một VM Oracle Always Free**.

## Model AI trên máy bạn

Đã có trong `ai_service/models/`:

| File | Dung lượng ~ |
|------|----------------|
| `classify_model.pt` | 2.6 MB |
| `forecast_model.pt` | 1.1 MB |
| `ocr_reco_model.pt` | 52 MB |

> `classify_model.pt` bị `.gitignore` — **không lên GitHub**, phải upload bằng script (bước 6).

---

## Bước 1 — Tạo VM Oracle Cloud

1. Đăng ký: https://www.oracle.com/cloud/free/
2. **Compute → Instances → Create Instance**
3. Cấu hình:
   - Image: **Ubuntu 22.04**
   - Shape: **VM.Standard.A1.Flex** (ARM, free 4 OCPU / 24 GB RAM)
   - OCPU: **2**, Memory: **12 GB**
   - Tick **Assign a public IPv4**
   - Tạo **SSH key** → tải file `.pem`
4. **VCN → Security List → Ingress Rules** — mở port **22, 80, 443** từ `0.0.0.0/0`

Ghi lại **Public IP** (ví dụ `123.45.67.89`).

---

## Bước 2 — Push code lên GitHub

```powershell
cd c:\Nam4\Doantotnghiep2
git add .
git commit -m "Add Oracle Cloud deploy scripts"
git push origin main
```

Sửa `GIT_REPO` trong `deploy/oracle/env.example` thành URL repo thật của bạn.

---

## Bước 3 — SSH vào VM

```powershell
ssh -i "C:\path\to\oracle-key.pem" ubuntu@<PUBLIC_IP>
```

---

## Bước 4 — Chạy setup (trên VM)

```bash
# Clone repo (lần đầu)
git clone https://github.com/<username>/Doantotnghiep2.git
cd Doantotnghiep2

# Cấu hình production
sudo mkdir -p /etc/expense-manager
sudo cp deploy/oracle/env.example /etc/expense-manager/production.env
sudo nano /etc/expense-manager/production.env
```

**Bắt buộc sửa trong `production.env`:**

| Biến | Ví dụ |
|------|-------|
| `MYSQL_PASSWORD` | mật khẩu mạnh |
| `SPRING_DATASOURCE_PASSWORD` | cùng mật khẩu MySQL |
| `JWT_SECRET` | chạy `openssl rand -hex 32` |
| `GIT_REPO` | URL GitHub repo |
| `GEMINI_API_KEY` | lấy tại https://aistudio.google.com/apikey |
| `MAIL_USERNAME` / `MAIL_PASSWORD` | Gmail App Password |
| `CORS_ALLOWED_ORIGINS` | URL web deploy (thêm sau cũng được) |

Chạy setup:

```bash
chmod +x deploy/oracle/setup.sh deploy/oracle/deploy-app.sh
bash deploy/oracle/setup.sh
```

---

## Bước 5 — Upload model `.pt` (từ Windows)

Vì `classify_model.pt` không có trên Git, chạy trên **PowerShell Windows**:

```powershell
cd c:\Nam4\Doantotnghiep2
.\deploy\oracle\upload-models.ps1 -SshKey "C:\path\to\oracle-key.pem" -VmIp "<PUBLIC_IP>"
```

Trên VM, restart AI:

```bash
sudo systemctl restart expense-ai
curl http://127.0.0.1:8000/health
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

---

## Bước 6 — Kiểm tra API

| URL | Mô tả |
|-----|-------|
| `http://<IP>/api/swagger-ui.html` | Swagger Backend |
| `http://<IP>/health` | Health AI Service |
| `http://<IP>/api/auth/login` | Đăng nhập |

```bash
sudo systemctl status expense-ai expense-backend nginx
sudo journalctl -u expense-backend -f   # xem log backend
sudo journalctl -u expense-ai -f          # xem log AI
```

---

## Bước 7 — Trỏ Web / Flutter

### Web (`web/.env.local`)

```env
VITE_API_BASE_URL=http://<PUBLIC_IP>/api
```

### Flutter APK

```powershell
flutter build apk --dart-define=API_BASE_URL=http://<PUBLIC_IP>/api
```

Thêm URL web vào `CORS_ALLOWED_ORIGINS` trong `/etc/expense-manager/production.env`, rồi:

```bash
sudo systemctl restart expense-backend
```

---

## Cập nhật code sau này

```bash
cd ~/Doantotnghiep2
bash deploy/oracle/deploy-app.sh
```

---

## HTTPS miễn phí (tuỳ chọn)

**Cloudflare Tunnel** (không cần mở thêm port):

```bash
# ARM VM
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb -o cloudflared.deb
sudo dpkg -i cloudflared.deb
cloudflared tunnel login
```

Hoặc **Let's Encrypt** nếu có domain trỏ về IP VM:

```bash
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d api.yourdomain.com
```

---

## Xử lý lỗi

| Triệu chứng | Cách sửa |
|-------------|----------|
| `classify_loaded: false` | Chạy lại `upload-models.ps1` |
| Backend `Connection refused` MySQL | `sudo systemctl status mysql` |
| `502 Bad Gateway` | `sudo systemctl restart expense-backend` |
| CORS trên web | Thêm origin vào `CORS_ALLOWED_ORIGINS` |
| AI OOM | Tăng RAM VM (ARM 12GB) hoặc giảm `-Xmx` backend |
