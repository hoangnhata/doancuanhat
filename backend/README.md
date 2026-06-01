# Expense Manager API - Backend

Hệ thống backend cho ứng dụng quản lý chi tiêu cá nhân (tương tự Rolly) sử dụng Spring Boot, Java, MySQL.

## Công nghệ

- **Spring Boot 3.2** + Java 17
- **Spring Data JPA** (Hibernate)
- **MySQL**
- **Spring Security** + JWT
- **Hibernate Validator**
- **SpringDoc OpenAPI** (Swagger)
- **WebFlux** (cho AI API integration)

## Cấu trúc dự án

```
src/main/java/com/expense/
├── config/          # Cấu hình (Security, CORS, OpenAPI)
├── controller/      # REST Controllers
├── dto/             # Data Transfer Objects
├── entity/          # JPA Entities
├── exception/       # Global exception handling
├── repository/      # Spring Data JPA Repositories
├── security/        # JWT, UserPrincipal, Filters
└── service/         # Business logic
```

## Database Schema

- **users** - Người dùng
- **categories** - Danh mục (EXPENSE/INCOME)
- **transactions** - Giao dịch (chi tiêu/thu nhập)
- **budgets** - Ngân sách theo danh mục

Quan hệ: User → Transaction, User → Category, User → Budget, Category → Transaction, Category → Budget

## Chạy ứng dụng

### Yêu cầu

- Java 17+
- MySQL 8+
- Maven

### Cấu hình

1. Tạo database MySQL (hoặc để `createDatabaseIfNotExist=true` trong `application.yml`)
2. Cập nhật `application.yml`:
   - `spring.datasource.url`, `username`, `password`
   - `jwt.secret` (production: dùng biến môi trường `JWT_SECRET`)
   - `ai.categorization.openai.api-key` (nếu dùng OpenAI)

### Chạy

```bash
mvn spring-boot:run
```

API chạy tại: `http://localhost:8080/api`

Swagger UI: `http://localhost:8080/api/swagger-ui.html`

## AI Phân loại chi tiêu

Hỗ trợ 2 provider:

1. **OpenAI** - Cấu hình `OPENAI_API_KEY` hoặc trong `application.yml`
2. **Python API** - Chạy service Python riêng, cấu hình `PYTHON_AI_API_URL`

Format Python API response mong đợi:
```json
{
  "category": "Ăn uống",
  "amount": 50000,
  "description": "ăn trưa"
}
```

Nếu AI tắt hoặc lỗi, hệ thống dùng fallback rule-based (regex + keyword matching).

## Xuất báo cáo

- `GET /export/transactions?format=excel|xlsx|pdf&startDate=&endDate=` — Excel (.xlsx) hoặc PDF.
- PDF dùng font **Noto Sans** tại `src/main/resources/fonts/NotoSans-Regular.ttf` (hỗ trợ tiếng Việt). Không xóa file này khi deploy.

## API Documentation

Xem [API_DOCUMENTATION.md](API_DOCUMENTATION.md) để tích hợp frontend.
