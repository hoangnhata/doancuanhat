# Hướng dẫn chạy Expense Manager

Hướng dẫn từng bước để chạy ứng dụng quản lý chi tiêu cá nhân.

---

## Bước 0: Chuẩn bị

Đảm bảo đã cài:

| Công cụ | Phiên bản | Kiểm tra |
|---------|-----------|----------|
| **Java** | 17+ | `java -version` |
| **Maven** | 3.6+ | `mvn -v` |
| **MySQL** | 8+ | `mysql --version` |
| **Flutter** | 3.x | `flutter doctor` |

---

## Bước 1: Tạo database MySQL

1. Mở MySQL (port 3307 theo cấu hình hiện tại):

```powershell
mysql -u root -p -P 3307
```

2. Tạo database:

```sql
CREATE DATABASE IF NOT EXISTS expense_manager
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
```

3. Thoát: `exit`

**Hoặc chạy file schema:**

```powershell
mysql -u root -p -P 3307 < backend\src\main\resources\schema.sql
```

---

## Bước 2: Chạy Backend (Spring Boot)

1. Mở terminal tại thư mục dự án:

```powershell
cd c:\Nam4\Doantotnghiep2\backend
```

2. Chạy backend:

```powershell
mvn spring-boot:run
```

3. Đợi đến khi thấy dòng:

```
Started ExpenseManagerApplication in X.XXX seconds
```

4. Kiểm tra API:
   - Swagger UI: http://localhost:8080/api/swagger-ui.html
   - Health: http://localhost:8080/api (có thể trả 401 nếu chưa đăng nhập – vẫn là bình thường)

**Lưu ý:** Giữ terminal này mở. Backend phải chạy liên tục khi dùng app.

---

## Bước 3: Cấu hình địa chỉ API (Frontend)

Mở file `frontend\lib\core\constants\api_constants.dart` và chỉnh `baseUrl` theo môi trường:

| Bạn chạy app trên | baseUrl |
|-------------------|---------|
| **Android Emulator** | `http://10.0.2.2:8080/api` |
| **Chrome (web)** | `http://localhost:8080/api` |
| **Thiết bị thật** | `http://IP_MÁY_TÍNH:8080/api` |

**Ví dụ thiết bị thật:** Máy chạy backend có IP `192.168.1.100`:

```dart
static const String baseUrl = 'http://192.168.1.100:8080/api';
```

Để xem IP máy: `ipconfig` (tìm IPv4 Address).

---

## Bước 4: Chạy Frontend (Flutter)

1. Mở terminal mới (không đóng terminal backend):

```powershell
cd c:\Nam4\Doantotnghiep2\frontend
```

2. Cài dependencies (lần đầu):

```powershell
flutter pub get
```

3. Tạo platform (nếu chưa có thư mục android/ios):

```powershell
flutter create .
```

4. Chạy app:

```powershell
flutter run
```

5. Chọn thiết bị khi được hỏi (Chrome, Android emulator, v.v.)

**Chạy trên Chrome (web):**

```powershell
flutter run -d chrome
```

**Chạy trên Android emulator:**

```powershell
flutter run -d emulator-5554
```

(Xem danh sách thiết bị: `flutter devices`)

---

## Bước 5: Sử dụng ứng dụng

1. Mở app → màn hình **Đăng nhập**
2. Bấm **Tạo tài khoản** → Điền form → **Đăng ký**
3. Sau khi đăng nhập → màn hình **Tổng quan**
4. Bấm **Danh mục** (icon trên góc phải) → **Thêm danh mục** (vd: Ăn uống, Di chuyển)
5. Bấm nút **Thêm** (dấu +) → Thêm giao dịch
   - Có thể nhập nhanh: `ăn trưa 50k` rồi bấm icon AI để tự phân loại
6. Xem thống kê trên **Tổng quan** và danh sách **Giao dịch**

---

## Xử lý lỗi thường gặp

### Backend không kết nối được MySQL

- Kiểm tra MySQL đang chạy (port 3307)
- Kiểm tra `backend\src\main\resources\application.yml`: `url`, `username`, `password`

### App không kết nối được API

- Kiểm tra backend đã chạy (`mvn spring-boot:run`)
- Kiểm tra `api_constants.dart`: `baseUrl` đúng với môi trường
- Thiết bị thật: máy và điện thoại phải cùng mạng WiFi

### Flutter: "No devices found"

- Chạy Android emulator từ Android Studio, hoặc
- Dùng Chrome: `flutter run -d chrome`

---

## Tóm tắt lệnh nhanh

```powershell
# Terminal 1 - Backend
cd c:\Nam4\Doantotnghiep2\backend
mvn spring-boot:run

# Terminal 2 - Frontend
cd c:\Nam4\Doantotnghiep2\frontend
flutter pub get
flutter run -d chrome
```
