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

---

## D. Flutter Web trên iPhone (không cần Mac)

PWA: deploy Flutter web lên Vercel → mở Safari → **Thêm vào Màn hình chính**.

### D1. Tạo project Vercel mới (app mobile)

1. https://vercel.com → **Add New → Project** → repo `doancuanhat`
2. **Project Name**: `doancuanhat-app` (hoặc `natta-app`)
3. Cấu hình:

| Field | Value |
|-------|--------|
| Framework | **Other** |
| Root Directory | **`frontend`** |
| Install Command | xem bên dưới |
| Build Command | xem bên dưới |
| Output Directory | **`build/web`** |

**Install Command** (copy một dòng):

```bash
git clone https://github.com/flutter/flutter.git -b stable --depth 1 /tmp/flutter && export PATH="/tmp/flutter/bin:$PATH" && flutter config --enable-web && flutter precache --web && cd web && npm install && cd .. && flutter pub get
```

**Build Command**:

```bash
export PATH="/tmp/flutter/bin:$PATH" && flutter build web --release --dart-define=API_BASE_URL=/api
```

4. **Deploy** (lần đầu ~5–10 phút vì cài Flutter)

URL ví dụ: `https://doancuanhat-app.vercel.app`

### D2. CORS trên EC2

Thêm URL app vào `CORS_ALLOWED_ORIGINS`:

```env
...,https://doancuanhat-app.vercel.app
```

```bash
sudo systemctl restart expense-backend
```

### D3. Thêm vào Màn hình chính (iPhone)

1. Mở **Safari** → vào URL app (vd. `https://doancuanhat-app.vercel.app`)
2. Đăng nhập thử
3. Bấm nút **Chia sẻ** (hình vuông + mũi tên)
4. Cuộn → **Thêm vào Màn hình chính**
5. Đặt tên **Natta** → **Thêm**

Icon xuất hiện như app native.

### D4. Build local (tuỳ chọn, nhanh hơn)

```powershell
cd c:\Nam4\Doantotnghiep2\frontend
.\build-prod-web.ps1
```

### D5. Lưu ý iPhone

- Cần **internet** để đăng nhập / đồng bộ
- Camera OCR có thể hạn chế trên web iOS
- Thông báo push **không** hoạt động trên PWA iOS
- Dùng Safari (Chrome iOS cũng dùng engine Safari)
