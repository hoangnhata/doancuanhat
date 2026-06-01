# Expense Manager - Mobile App

Ứng dụng Flutter quản lý chi tiêu cá nhân - Natta AI.

## Hướng dẫn cài đặt Flutter

### 1. Yêu cầu hệ thống

- **Windows 10/11** (64-bit)
- **Disk:** ~2.5 GB (Flutter SDK + Android toolchain)
- **RAM:** Tối thiểu 8 GB khuyến nghị

### 2. Cài đặt Flutter SDK (Windows)

**Cách 1: Tải trực tiếp**

1. Tải Flutter SDK: https://docs.flutter.dev/get-started/install/windows
2. Giải nén vào thư mục (vd: `C:\flutter`) – **không** đặt trong `Program Files`
3. Thêm Flutter vào PATH:
   - Mở **Cài đặt** → **Hệ thống** → **Giới thiệu** → **Cài đặt nâng cao**
   - Chọn **Biến môi trường**
   - Trong **Biến người dùng**, chọn **Path** → **Chỉnh sửa** → **Mới**
   - Thêm: `C:\flutter\bin` (đường dẫn tới thư mục `bin` của Flutter)

**Cách 2: Dùng winget (Windows 11)**

```powershell
winget install -e --id Google.Flutter
```

### 3. Cài đặt Android Studio (cho Android)

1. Tải: https://developer.android.com/studio
2. Cài đặt và mở Android Studio
3. Vào **More Actions** → **SDK Manager**:
   - Tab **SDK Platforms**: chọn **Android 14.0 (API 34)** trở lên
   - Tab **SDK Tools**: chọn **Android SDK Command-line Tools**, **Android SDK Build-Tools**
4. Chấp nhận license:
   ```powershell
   flutter doctor --android-licenses
   ```

### 4. Kiểm tra cài đặt

```powershell
flutter doctor
```

Kết quả mong muốn: tất cả dấu ✓ (Android toolchain, VS Code/Android Studio, Connected device).

### 5. Cài đặt VS Code (tùy chọn)

1. Tải: https://code.visualstudio.com/
2. Cài extension **Flutter** và **Dart** trong VS Code

---

## Chạy ứng dụng Expense Manager

### Bước 1: Mở terminal tại thư mục frontend

```powershell
cd c:\Nam4\Doantotnghiep2\frontend
```

### Bước 2: Tạo platform files (lần đầu)

Nếu chưa có thư mục `android/` hoặc `ios/`:

```powershell
flutter create .
```

### Bước 3: Cài dependencies

```powershell
flutter pub get
```

### Bước 4: Cấu hình địa chỉ API

Sửa file `lib/core/constants/api_constants.dart`:

| Môi trường        | baseUrl                    |
|-------------------|----------------------------|
| Android Emulator  | `http://10.0.2.2:8080/api` |
| iOS Simulator     | `http://localhost:8080/api` |
| Thiết bị thật     | `http://IP_MÁY:8080/api`   |

Ví dụ thiết bị thật (máy chạy backend có IP 192.168.1.100):

```dart
static const String baseUrl = 'http://192.168.1.100:8080/api';
```

### Bước 5: Chạy ứng dụng

**Chạy trên thiết bị/emulator mặc định:**
```powershell
flutter run
```

**Chọn thiết bị:**
```powershell
flutter devices
flutter run -d <device_id>
```

**Chạy trên Chrome (web):**
```powershell
flutter run -d chrome
```

**Chế độ release (tối ưu):**
```powershell
flutter run --release
```

### Bước 6: Đảm bảo Backend đang chạy

Trước khi chạy app, cần khởi động backend:

```powershell
cd c:\Nam4\Doantotnghiep2\backend
mvn spring-boot:run
```

---

## Công nghệ

- **Flutter** + Dart
- **Riverpod** - State management
- **Dio** - HTTP client
- **SharedPreferences** - Lưu token
- **fl_chart** - Biểu đồ
- **Google Fonts** - Typography

## Cấu trúc (Clean Architecture)

```
lib/
├── core/           # Theme, router, constants, DI
├── data/           # API client, repositories impl
├── domain/         # Models, repository interfaces
└── presentation/   # Screens, widgets
```

## Màn hình

- **Splash** - Kiểm tra đăng nhập
- **Đăng nhập/Đăng ký** - Form validation
- **Dashboard** - Số dư, thu/chi, biểu đồ theo ngày/tháng/năm
- **Giao dịch** - Danh sách scroll, pagination
- **Thêm giao dịch** - Input tự nhiên "ăn trưa 50k" + AI phân loại
- **Danh mục** - CRUD
- **Ngân sách** - Quản lý ngân sách theo danh mục
