# Expense Manager API - Tài liệu tích hợp Frontend

Base URL: `http://localhost:8080/api`

## Authentication

Tất cả API (trừ auth) yêu cầu header:
```
Authorization: Bearer <access_token>
```

---

## 1. Authentication APIs

### 1.1 Đăng ký

**POST** `/auth/register`

**Request:**
```json
{
  "fullName": "Nguyễn Văn A",
  "email": "user@example.com",
  "password": "password123",
  "phone": "0901234567"
}
```

**Response (200):**
```json
{
  "success": true,
  "message": "Registration successful",
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "tokenType": "Bearer",
    "expiresIn": 86400,
    "user": {
      "id": 1,
      "fullName": "Nguyễn Văn A",
      "email": "user@example.com",
      "phone": "0901234567"
    }
  },
  "timestamp": "2025-03-20T10:00:00"
}
```

### 1.2 Đăng nhập

**POST** `/auth/login`

**Request:**
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response (200):** Tương tự đăng ký

### 1.3 Refresh Token

**POST** `/auth/refresh`

**Headers:** `Authorization: Bearer <refresh_token>`

**Response (200):** Tương tự đăng nhập

---

## 2. User APIs

### 2.1 Lấy thông tin user hiện tại

**GET** `/users/me`

**Response (200):**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "fullName": "Nguyễn Văn A",
    "email": "user@example.com",
    "phone": "0901234567",
    "createdAt": "2025-03-20T10:00:00"
  },
  "timestamp": "2025-03-20T10:00:00"
}
```

### 2.2 Cập nhật profile

**PUT** `/users/me`

**Request:**
```json
{
  "fullName": "Nguyễn Văn B",
  "phone": "0912345678"
}
```

### 2.3 Đổi mật khẩu

**PATCH** `/users/me/password`

**Request:**
```json
{
  "currentPassword": "password123",
  "newPassword": "newpassword456"
}
```

**Response (200):**
```json
{
  "success": true,
  "message": "Mật khẩu đã được thay đổi",
  "data": null,
  "timestamp": "2025-03-20T10:00:00"
}
```

**Error (400):** Mật khẩu hiện tại không đúng

---

## 3. Category APIs

### 3.1 Tạo danh mục

**POST** `/categories`

**Request:**
```json
{
  "name": "Ăn uống",
  "description": "Chi phí ăn uống hàng ngày",
  "icon": "restaurant",
  "type": "EXPENSE"
}
```

**Type:** `EXPENSE` | `INCOME`

**Response (200):**
```json
{
  "success": true,
  "message": "Category created",
  "data": {
    "id": 1,
    "name": "Ăn uống",
    "description": "Chi phí ăn uống hàng ngày",
    "icon": "restaurant",
    "type": "EXPENSE",
    "createdAt": "2025-03-20T10:00:00"
  }
}
```

### 3.2 Lấy danh sách (có phân trang)

**GET** `/categories?page=0&size=20&type=EXPENSE`

**Response (200):**
```json
{
  "success": true,
  "data": {
    "content": [
      {
        "id": 1,
        "name": "Ăn uống",
        "description": "Chi phí ăn uống",
        "icon": "restaurant",
        "type": "EXPENSE",
        "createdAt": "2025-03-20T10:00:00"
      }
    ],
    "page": 0,
    "size": 20,
    "totalElements": 5,
    "totalPages": 1,
    "first": true,
    "last": true
  }
}
```

### 3.3 Lấy theo loại (không phân trang)

**GET** `/categories/by-type/EXPENSE`

### 3.4 Cập nhật / Xóa

**PUT** `/categories/{id}` - Cập nhật  
**DELETE** `/categories/{id}` - Xóa

---

## 4. Transaction APIs

### 4.1 Tạo giao dịch

**POST** `/transactions`

**Request:**
```json
{
  "type": "EXPENSE",
  "amount": 50000,
  "description": "Ăn trưa",
  "transactionDate": "2025-03-20",
  "categoryId": 1
}
```

**Response (200):**
```json
{
  "success": true,
  "message": "Transaction created",
  "data": {
    "id": 1,
    "type": "EXPENSE",
    "amount": 50000,
    "description": "Ăn trưa",
    "transactionDate": "2025-03-20",
    "category": {
      "id": 1,
      "name": "Ăn uống",
      "type": "EXPENSE",
      "icon": "restaurant"
    },
    "createdAt": "2025-03-20T10:00:00"
  }
}
```

### 4.2 Lấy danh sách (filter, pagination)

**GET** `/transactions?page=0&size=20&type=EXPENSE&categoryId=1&startDate=2025-03-01&endDate=2025-03-31`

**Query params:**
- `page`, `size` - Phân trang
- `type` - EXPENSE | INCOME
- `categoryId` - Lọc theo danh mục
- `startDate`, `endDate` - Lọc theo khoảng ngày (ISO: yyyy-MM-dd)

### 4.3 AI Phân loại chi tiêu tự động

**POST** `/transactions/ai/categorize`

**Request:**
```json
{
  "text": "ăn trưa 50k"
}
```

**Response (200):**
```json
{
  "success": true,
  "data": {
    "categoryName": "Ăn uống",
    "categoryId": 1,
    "amount": 50000,
    "description": "ăn trưa 50k",
    "suggestedCategoryName": "Ăn uống"
  }
}
```

Frontend có thể dùng response này để pre-fill form tạo giao dịch mới.

---

## 5. Budget APIs

### 5.1 Tạo ngân sách

**POST** `/budgets`

**Request:**
```json
{
  "amount": 5000000,
  "startDate": "2025-03-01",
  "endDate": "2025-03-31",
  "categoryId": 1,
  "note": "Ngân sách ăn uống tháng 3"
}
```

### 5.2 Lấy ngân sách đang hoạt động

**GET** `/budgets/active?date=2025-03-20`

### 5.3 Lấy tất cả (phân trang)

**GET** `/budgets?page=0&size=20`

---

## 6. Statistics APIs

### 6.1 Thống kê theo ngày

**GET** `/statistics/day?date=2025-03-20`

**Response (200):**
```json
{
  "success": true,
  "data": {
    "totalIncome": 10000000,
    "totalExpense": 500000,
    "balance": 9500000,
    "byCategory": [
      {
        "categoryId": 1,
        "categoryName": "Ăn uống",
        "amount": 200000
      },
      {
        "categoryId": 2,
        "categoryName": "Di chuyển",
        "amount": 300000
      }
    ]
  }
}
```

### 6.2 Thống kê theo tháng

**GET** `/statistics/month?year=2025&month=3`

### 6.3 Thống kê theo năm

**GET** `/statistics/year?year=2025`

### 6.4 Thống kê theo khoảng ngày

**GET** `/statistics/range?startDate=2025-03-01&endDate=2025-03-31`

---

## 7. Error Response Format

```json
{
  "success": false,
  "message": "Error description",
  "data": null,
  "timestamp": "2025-03-20T10:00:00"
}
```

**Validation errors (400):**
```json
{
  "success": false,
  "message": "Validation failed",
  "data": {
    "email": "Invalid email format",
    "password": "Password must be at least 6 characters"
  },
  "timestamp": "2025-03-20T10:00:00"
}
```

**HTTP Status Codes:**
- 200 - Success
- 400 - Bad Request / Validation Error
- 401 - Unauthorized (thiếu hoặc token không hợp lệ)
- 404 - Not Found
- 500 - Internal Server Error

---

## 8. Swagger UI

Truy cập: `http://localhost:8080/api/swagger-ui.html` để xem và test API trực tiếp.
