# Deploy Web (Vercel) + Flutter APK

API production: `http://13.115.209.124/api`

---

## A. Deploy Web lên Vercel (free)

### A1. Push code GitHub

```powershell
cd c:\Nam4\Doantotnghiep2
git add web/ frontend/ deploy/
git commit -m "Web deploy config and remove demo hint"
git push
```

### A2. Tạo project Vercel

1. https://vercel.com → **Sign up** (GitHub)
2. **Add New → Project** → chọn repo `doancuanhat`
3. Cấu hình:

| Field | Value |
|-------|--------|
| Framework Preset | Vite |
| Root Directory | `web` |
| Build Command | `npm run build` |
| Output Directory | `dist` |

4. **Environment Variables** (Production):

| Name | Value |
|------|--------|
| `VITE_API_BASE_URL` | `http://13.115.209.124/api` |

5. **Deploy**

URL ví dụ: `https://doancuanhat.vercel.app`

### A3. CORS trên EC2 (bắt buộc)

Thay `YOUR_VERCEL_URL` bằng URL thật:

```bash
sudo nano /etc/expense-manager/production.env
```

```env
CORS_ALLOWED_ORIGINS=http://localhost:5173,http://127.0.0.1:5173,https://YOUR_VERCEL_URL
```

```bash
sudo systemctl restart expense-backend
```

### A4. Test Web production

- Mở URL Vercel → Đăng nhập demo hoặc đăng ký
- F12 Console: không có lỗi CORS

---

## B. Build Flutter APK (Android)

### B1. Yêu cầu

- Flutter SDK đã cài (`flutter doctor`)
- Android SDK (Android Studio)

### B2. Build

```powershell
cd c:\Nam4\Doantotnghiep2\frontend
flutter pub get
.\build-prod-apk.ps1
```

APK: `frontend\build\app\outputs\flutter-apk\app-release.apk`

### B3. Cài lên điện thoại

1. Copy APK sang điện thoại (USB / Zalo / Drive)
2. Bật **Cài app không rõ nguồn**
3. Mở file APK → Cài đặt

### B4. Lưu ý

- Điện thoại cần **internet**
- API dùng **HTTP** (không HTTPS) — Android 9+ có thể chặn cleartext

Nếu app không gọi được API, thêm `network_security_config` (xem README hoặc hỏi assistant).

---

## C. Khi EC2 đổi IP

Stop/Start EC2 → IP mới → cập nhật:

1. `web/.env.local`, `.env.production`
2. Vercel env `VITE_API_BASE_URL`
3. `frontend/build-prod-apk.ps1`
4. Rebuild web + APK

Hoặc gắn **Elastic IP** (AWS) để IP cố định.

---

## Checklist

- [ ] Vercel deploy OK
- [ ] CORS có URL Vercel
- [ ] Web production login OK
- [ ] APK build OK
- [ ] APK cài + login trên điện thoại OK
