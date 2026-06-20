# PROJECT KNOWLEDGE BASE

Tài liệu kỹ thuật mô tả toàn bộ hệ thống **Expense Manager - Quản lý Chi tiêu Cá nhân (Natta AI)**. Mọi nội dung dưới đây được trích xuất từ source code, cấu hình và artifact thực tế trong repository `c:\Nam4\Doantotnghiep2`. Không có thư mục `mobile/` chứa ứng dụng hoàn chỉnh — ứng dụng Flutter nằm trong `frontend/`.

---

# PHẦN 1. TỔNG QUAN DỰ ÁN

## Tên dự án

| Nguồn | Tên |
|-------|-----|
| `README.md` (root) | Expense Manager - Quản lý Chi tiêu Cá nhân (Natta AI) |
| `backend/pom.xml` | Expense Manager API |
| `frontend/pubspec.yaml` | expense_manager — Ứng dụng quản lý chi tiêu cá nhân - Natta AI |
| `web/package.json` | expense-manager-web |
| `ai_service/app/main.py` | Expense AI Service (version 0.2.0) |
| `README.md` | Đồ án tốt nghiệp |

Repository GitHub được ghi trong `README.md`: https://github.com/hoangnhata/doancuanhat

## Mục tiêu

Theo `README.md`:
- Ứng dụng quản lý chi tiêu cá nhân đa nền tảng
- Tích hợp AI: phân loại giao dịch, OCR hóa đơn, dự báo chi tiêu, chatbot tài chính cá nhân
- Đồ án tốt nghiệp

## Bài toán giải quyết

Từ mô tả trong `README.md` và các module source code:
- Người dùng cần ghi nhận, phân loại, theo dõi chi tiêu/thu nhập cá nhân
- Nhập liệu tự nhiên (câu tiếng Việt ngắn, ảnh hóa đơn) thay vì form thủ công
- Dự báo chi tiêu ngắn hạn từ lịch sử
- Hỏi đáp về tình hình tài chính cá nhân qua chatbot
- Hoạt động offline trên mobile (SQLite + đồng bộ khi có mạng)

## Đối tượng sử dụng

Source code không định nghĩa persona người dùng riêng. Hệ thống được thiết kế cho:
- Người dùng cá nhân (mỗi `User` có dữ liệu riêng: categories, wallets, transactions, budgets)
- Xác thực qua email/password (JWT)
- Một role duy nhất trong code: `ROLE_USER` (`UserPrincipal`)

## Các tính năng chính

### Cơ bản (từ `README.md` + controllers/services)

| Tính năng | Mô tả từ source |
|-----------|-----------------|
| Đăng ký 2 bước OTP email | `PendingRegistrationService`, endpoints `/auth/register/request`, `/verify`, `/resend-otp` |
| Đăng nhập JWT + refresh token | `AuthService`, `JwtTokenProvider` |
| Quên mật khẩu OTP email | `PasswordResetService`, `/auth/forgot-password`, `/auth/reset-password` |
| Quản lý ví | `WalletController`, `WalletService`, entity `Wallet` |
| Quản lý danh mục | `CategoryController`, seed 14 expense + 6 income mặc định |
| Quản lý giao dịch | `TransactionController`, CRUD + filter |
| Offline-first (mobile) | Drift SQLite + `SyncService` outbox |
| Ngân sách theo danh mục | `BudgetController`, entity `Budget` |
| Giao dịch định kỳ | `RecurringTransactionController`, scheduler hàng ngày 00:00 |
| Xuất Excel/PDF | `ExportController`, Apache POI + OpenPDF |
| Thống kê | `StatisticsController`: day/month/year/range/daily-breakdown |

### AI (từ `ai_service/` + backend proxy)

| Tính năng | Endpoint backend | Endpoint AI service |
|-----------|------------------|---------------------|
| Phân loại giao dịch | `POST /transactions/ai/categorize`, `/batch` | `POST /api/categorize`, `/batch` |
| OCR hóa đơn | `POST /transactions/ai/ocr/receipt` | `POST /api/ocr/receipt/parse` |
| Dự báo chi tiêu 7 ngày | `GET /statistics/spending-forecast` | `POST /api/forecast` |
| Chatbot tài chính | `POST /ai/chat` | `POST /api/chat` |
| Gợi ý tiết kiệm | `GET /ai/suggestions` | (logic trong `AISuggestionService` backend) |

### UX (từ frontend + web)

| Tính năng | Vị trí source |
|-----------|---------------|
| Dark/Light/System theme | `ThemeModeContext` (web), `themeModeProvider` (Flutter) |
| Mascot Natta HAPPY/SAD/ANGRY | `botPersonality` trên `User`, components robot |
| Onboarding bot + ví | `OnboardingPage` (web), `onboarding_bot_screen.dart`, `onboarding_wallet_screen.dart` |
| FAB thêm giao dịch | `AppShell.tsx`, `MainScreen` |
| Local notification (mobile) | `notification_service_impl.dart`, `dailyReminderProvider` |

## Kiến trúc tổng thể

```
Flutter App (offline, SQLite) ──REST──▶ Spring Boot Backend (MySQL) ──REST──▶ FastAPI AI (PyTorch + Gemini)
                                              ▲
React Web ───────────── REST ─────────────────┘
```

- Backend context path: `/api`, port `8080`
- AI service port `8000` (mặc định trong `application.yml`: `PYTHON_AI_API_URL=http://localhost:8000`)
- MySQL port `3307`, database `expense_manager`

## Stack công nghệ

| Lớp | Công nghệ (từ pom.xml, pubspec.yaml, package.json, requirements.txt) |
|-----|----------------------------------------------------------------------|
| Backend | Spring Boot 3.2.5, Java 17, Spring Security, JPA, MySQL, jjwt 0.12.5, Apache POI 5.2.5, OpenPDF 1.3.39, Spring Mail, WebFlux, SpringDoc OpenAPI 2.3.0 |
| AI | FastAPI, PyTorch, Pydantic, httpx, Pillow, numpy, pandas |
| Mobile | Flutter SDK >=3.2.0, Riverpod, Dio, Drift (SQLite), fl_chart, image_picker, flutter_local_notifications, connectivity_plus |
| Web | React 18, Vite 5, TypeScript, MUI 5, TanStack React Query v5, Recharts, Axios |

---

# PHẦN 2. CẤU TRÚC SOURCE CODE

## Cây thư mục cấp cao

```
Doantotnghiep2/
├── README.md
├── .gitignore
├── PROJECT_KNOWLEDGE_BASE.md          (file này)
├── backend/                           Spring Boot API
├── frontend/                          Flutter app (Android/iOS/Web/Windows/Linux/macOS)
├── ai_service/                        FastAPI AI service
├── web/                               React web app
├── docs/                              Tài liệu hướng dẫn và báo cáo
├── scripts/                           Script tiện ích
├── mobile/                            Thư mục gần như trống (chỉ stub theme)
└── target/                            Maven build output (root)
```

## backend/

**Vai trò:** API trung tâm, xác thực JWT, persistence MySQL, proxy sang AI service, export báo cáo, gửi email OTP.

**Cấu trúc:**

```
backend/
├── pom.xml
├── README.md
├── API_DOCUMENTATION.md
└── src/main/
    ├── java/com/expense/
    │   ├── ExpenseManagerApplication.java
    │   ├── config/          (8 files)
    │   ├── controller/      (10 controllers)
    │   ├── dto/             (35 DTOs, 10 subpackages)
    │   ├── entity/          (8 entities + 2 enums)
    │   ├── exception/       (3 files)
    │   ├── repository/      (8 repositories)
    │   ├── security/        (4 files)
    │   └── service/         (17 services)
    └── resources/
        ├── application.yml
        ├── application-dev.yml
        ├── schema.sql
        └── fonts/             (thư mục tồn tại; NotoSans font được ExportService tham chiếu)
```

**File quan trọng:**

| File | Chức năng |
|------|-----------|
| `ExpenseManagerApplication.java` | Entry point, `@EnableScheduling` |
| `SecurityConfig.java` | JWT stateless security, public URLs |
| `JwtTokenProvider.java` | Sinh/validate access + refresh token |
| `RecurringScheduledJob.java` | Cron `0 0 0 * * *` xử lý giao dịch định kỳ |
| `ExportService.java` | Excel (POI) + PDF (OpenPDF) |
| `AICategorizationService.java` | Proxy categorize sang FastAPI |
| `ReceiptOcrService.java` | Proxy OCR multipart sang FastAPI |
| `SpendingForecastService.java` | Gọi forecast AI + build insight |
| `ChatAssistantService.java` | Build context + proxy chat |
| `PendingRegistrationService.java` | OTP đăng ký 2 bước |
| `PasswordResetService.java` | OTP reset password |
| `DemoUserSeedService.java` | Seed user `ai.demo@local.test` |

**Tests:** `backend/src/test` — không có file test.

## frontend/

**Vai trò:** Ứng dụng Flutter đa nền tảng, offline-first với SQLite (Drift), đồng bộ REST với backend.

**Package:** `expense_manager` v1.0.0+2

**Cấu trúc app code (`lib/`):**

```
frontend/lib/
├── main.dart
├── core/
│   ├── constants/     api_constants, storage_constants, api_host_*
│   ├── di/            injection.dart
│   ├── providers/     app_providers.dart
│   ├── router/        app_router.dart
│   ├── services/      notification_service*
│   ├── theme/         app_theme, app_spacing
│   └── utils/         download_*, api_error, snackbar, transaction_text_parse
├── data/
│   ├── datasources/   api_client, local_storage
│   ├── local/         database.dart (Drift), connection variants
│   ├── repositories/  *_repository_impl.dart
│   └── sync/          sync_service.dart
├── domain/
│   ├── models/
│   └── repositories/  interfaces
└── presentation/
    ├── screens/       auth, main, onboarding, transaction, analytics, budget, ...
    └── widgets/       common, charts, dashboard, robot, settings, transaction, wallet
```

**Platform runners:** `android/`, `ios/`, `linux/`, `macos/`, `windows/`, `web/` (Flutter web bootstrap)

**Assets:** `frontend/assets/images/` (pubspec tham chiếu `assets/images/app_icon.png`)

**Tests:** `test/widget_test.dart`, `ios/RunnerTests/`, `macos/RunnerTests/`

## web/

**Vai trò:** Web app React mirror tính năng mobile, gọi cùng backend REST API.

**Package:** `expense-manager-web` v1.0.0

```
web/
├── package.json, vite.config.ts, tsconfig.json
├── index.html, .env.example
├── public/            favicon, logo, manifest
└── src/
    ├── main.tsx
    ├── app/           AppProviders, router, RootLayout
    ├── contexts/      AuthContext, ThemeModeContext, SelectedWalletContext
    ├── components/    common, dashboard, layout, robot, transaction
    ├── lib/           api, constants, format, transactionTextParse
    ├── pages/         20 page components
    ├── services/      9 service files + mappers
    ├── theme/
    └── types/         models.ts
```

**Dev proxy:** `vite.config.ts` proxy `/api` → `http://localhost:8080`

## ai_service/

**Vai trò:** Microservice AI — phân loại, forecast, OCR, chat.

```
ai_service/
├── README.md
├── requirements.txt
├── train_classify.ipynb
├── train_receipt_ocr.ipynb
├── app/                    (23 Python modules)
├── data/                   (datasets, training scripts, audits)
├── models/                 (artifacts: classify JSON, forecast_model.pt)
├── scripts/                train_classify_pipeline.py, ...
└── tools/
```

**Python modules (`app/`):**

| Module | Chức năng |
|--------|-----------|
| `main.py` | FastAPI routes |
| `classify_net.py` | CharCNNBiLSTMAttn architecture |
| `classify_infer.py` | Load model + predict |
| `classify_train_lib.py` | Training pipeline |
| `classify_ood.py` | OOD detection rules |
| `text_preprocess.py` | Text normalization + vocab |
| `category_hints.py` | Keyword override rules |
| `rules.py` | Rule-based category fallback |
| `parsers.py` | Amount/date extraction |
| `transaction_intent.py` | EXPENSE/INCOME inference |
| `forecast_net.py` | SpendingForecastTransformer |
| `forecast_infer.py` | Forecast inference |
| `forecast_features.py` | Feature engineering |
| `ocr_net.py` | ReceiptLineCRNN v2 |
| `ocr_infer.py` | CRNN inference + CTC decode |
| `ocr_real.py` | EasyOCR wrapper |
| `ocr_charset.py` | CTC charset definitions |
| `ocr_eval.py` | CER/WER evaluation |
| `receipt_parse.py` | Full receipt parsing orchestration |
| `receipt_layout.py` | Receipt region split |
| `chat.py` | Gemini + rule-based chat |
| `val_hard_samples.py` | Hard validation samples |

## docs/

| File | Nội dung (theo tên file) |
|------|--------------------------|
| `HUONG_DAN_CHAY.md` | Hướng dẫn chạy |
| `HUONG_DAN_GIT.md` | Hướng dẫn Git |
| `PHAN_TICH_THIET_KE_HE_THONG.md` | Phân tích thiết kế |
| `BAO_CAO_AI.md` | Báo cáo AI |
| `BAO_CAO_AI_OCR.md` | Báo cáo OCR |
| `SQLITE_VA_DONG_BO_DU_LIEU.md` | SQLite và đồng bộ |

## scripts/

- `generate_natta_icons.py` — script tạo icon

## mobile/

Thư mục tồn tại (`mobile/lib/core/theme/`) nhưng không chứa ứng dụng Flutter hoàn chỉnh. Ứng dụng mobile thực tế nằm trong `frontend/`.

---

# PHẦN 3. CHỨC NĂNG HỆ THỐNG

## 3.1. Đăng ký tài khoản (legacy — 1 bước)

**Mục đích:** Tạo user trực tiếp, không qua OTP.

**Cách hoạt động:** `AuthService.register()` kiểm tra email trùng → BCrypt hash password → lưu `User` → `CategoryService.seedDefaultCategoriesIfEmpty()` → sinh access + refresh JWT.

**API:** `POST /api/auth/register` (public)

**Database:** `users`, `categories` (seed)

**Giao diện:** Endpoint tồn tại; Flutter `AuthRepositoryImpl.register()` có implement nhưng không có screen gọi. Web `authService.ts` có hàm nhưng `RegisterPage` dùng flow OTP.

## 3.2. Đăng ký 2 bước OTP

**Mục đích:** Xác minh email trước khi tạo tài khoản.

**Cách hoạt động:**
1. `POST /auth/register/request`: lưu `PendingRegistration` (email, fullName, passwordHash BCrypt, phone, otpHash BCrypt, expiresAt TTL 10 phút)
2. `EmailService` gửi OTP 6 số (async `@Async` trên `mailExecutor`)
3. `POST /auth/register/verify`: verify OTP, tối đa 5 lần sai → xóa pending
4. Tạo `User` thật + auto-login JWT

**API:** `/auth/register/request`, `/verify`, `/resend-otp`

**Database:** `pending_registrations`

**Giao diện:** `RegisterScreen`/`RegisterPage` → `VerifyRegistrationScreen`/`VerifyRegistrationPage`

## 3.3. Đăng nhập

**Mục đích:** Xác thực email/password, cấp JWT.

**Cách hoạt động:** `AuthenticationManager` + `DaoAuthenticationProvider` + BCrypt → `JwtTokenProvider.generateAccessToken/RefreshToken`.

**API:** `POST /api/auth/login`

**Database:** `users`

**Giao diện:** `LoginScreen`, `LoginPage`

## 3.4. Refresh token

**Mục đích:** Gia hạn access token khi hết hạn.

**Cách hoạt động:** Client gửi `Authorization: Bearer <refreshToken>` → `AuthService.refreshToken()` validate → sinh cặp token mới.

**API:** `POST /api/auth/refresh` (public)

**Giao diện:** Dio interceptor (`api_client.dart`), Axios interceptor (`api.ts`)

## 3.5. Quên mật khẩu

**Mục đích:** Reset password qua OTP email.

**Cách hoạt động:** `PasswordResetService` sinh OTP → lưu `PasswordResetToken` (otpHash BCrypt, expiresAt, attempts, used) → verify → update password.

**API:** `POST /auth/forgot-password`, `POST /auth/reset-password`

**Database:** `password_reset_tokens`, `users`

**Giao diện:** `ForgotPasswordScreen`, `ResetPasswordScreen`, tương ứng web

## 3.6. Quản lý hồ sơ người dùng

**Mục đích:** Đọc/cập nhật profile, đổi mật khẩu, onboarding fields.

**Cách hoạt động:** `UserService` đọc user từ SecurityContext (email JWT).

**API:**
- `GET /users/me`
- `PUT /users/me`
- `PATCH /users/me/profile` (botPersonality, onboardingCompleted, walletName, currencyCode, initialBalance, savingsGoalMonthly)
- `PATCH /users/me/password`

**Database:** `users`

**Giao diện:** `ProfileScreen`, `ProfilePage`, `SettingsTab`, `OnboardingPage`

## 3.7. Quản lý danh mục (Category)

**Mục đích:** CRUD danh mục chi tiêu/thu nhập theo user.

**Cách hoạt động:** Mỗi category thuộc một `User`, type `EXPENSE` hoặc `INCOME`. User mới được seed 14 expense + 6 income mặc định (`CategoryService.DEFAULT_EXPENSE`, `DEFAULT_INCOME`).

**API:** CRUD `/categories`, filter `?type=`, `/categories/by-type/{type}`

**Database:** `categories`

**Giao diện:** `CategoryScreen`, `CategoriesPage`; mobile sync qua `SyncService`

## 3.8. Quản lý ví (Wallet)

**Mục đích:** Nhiều ví, mỗi ví có currency và initial balance.

**Cách hoạt động:** `WalletService` CRUD, `isDefault` flag, sort theo default desc + name.

**API:** CRUD `/wallets`

**Database:** `wallets`

**Giao diện:** `WalletsScreen`, `WalletsPage`, `selectedWalletIdProvider`/`SelectedWalletContext`

## 3.9. Quản lý giao dịch (Transaction)

**Mục đích:** Ghi nhận chi tiêu/thu nhập.

**Cách hoạt động:**
- Backend: CRUD với filter page, type, categoryId, walletId, startDate, endDate
- Mobile: ghi SQLite trước, `SyncService` push outbox lên server
- Web: gọi API trực tiếp qua React Query

**API:** CRUD `/transactions`

**Database:** `transactions` (MySQL), `Transactions` table (SQLite Drift)

**Giao diện:** `TransactionsTab`, `TransactionsPage`, `AddTransactionScreen`, `AddTransactionPage`

## 3.10. AI phân loại giao dịch (single)

**Mục đích:** Từ câu nhập tự nhiên → type, category, amount, description, date, confidence.

**Cách hoạt động:**
1. Backend `AICategorizationService` gọi FastAPI `POST /api/categorize`
2. AI: `normalize_note()` → OOD check → `hint_category()` → model `CharCNNBiLSTMAttn` → rules fallback
3. Backend map category name → `Category` entity của user

**API:** `POST /transactions/ai/categorize`

**Database:** Không ghi trực tiếp; client tạo transaction sau khi nhận kết quả

**Giao diện:** `AddTransactionScreen`, `AddTransactionPage`, `ChatTab`/`ChatPage`

## 3.11. AI phân loại batch

**Mục đích:** Tách nhiều khoản trong một câu ("ăn trưa 50k, grab 30k").

**Cách hoạt động:** FastAPI split theo `,`, `;`, newline, `+`, `&`, ` và ` → categorize từng phần.

**API:** `POST /transactions/ai/categorize/batch`

**Giao diện:** Add transaction screens

## 3.12. OCR hóa đơn

**Mục đích:** Đọc số tiền, ngày, cửa hàng từ ảnh hóa đơn.

**Cách hoạt động:**
1. Client upload multipart `file` (max 10MB JPG/PNG)
2. Backend `ReceiptOcrService` proxy sang FastAPI `/api/ocr/receipt/parse`
3. AI: EasyOCR primary (`prefer_easyocr=True`) hoặc CRNN 4 field models fallback
4. `receipt_parse.py` → classify category trên text OCR

**API:** `POST /transactions/ai/ocr/receipt`

**Giao diện:** `receipt_ocr_sheet.dart`, `ReceiptOcrDialog.tsx`

## 3.13. Ngân sách (Budget)

**Mục đích:** Đặt hạn mức chi theo danh mục trong khoảng thời gian.

**Cách hoạt động:** `BudgetService` CRUD; `GET /budgets/active?date=` trả budgets đang hiệu lực.

**API:** CRUD `/budgets`, `/budgets/active`

**Database:** `budgets`; SQLite `Budgets` (có spentAmount, remainingAmount local)

**Giao diện:** `BudgetScreen`, `BudgetPage`

## 3.14. Giao dịch định kỳ

**Mục đích:** Tự tạo transaction hàng tháng theo `dayOfMonth` (1–28).

**Cách hoạt động:** `RecurringScheduledJob` cron `0 0 0 * * *` → `RecurringTransactionService.processRecurringForDate(today)` → tạo `Transaction` nếu chưa có cho ngày đó.

**API:** CRUD `/recurring-transactions`, `PATCH /{id}/toggle`

**Database:** `recurring_transactions`, `transactions.recurring_transaction_id`

**Giao diện:** `RecurringScreen`, `RecurringPage`

## 3.15. Thống kê

**Mục đích:** Tổng hợp chi/thu theo ngày/tháng/năm/khoảng.

**Cách hoạt động:** `StatisticsService` query `TransactionRepository` aggregates.

**API:**
- `GET /statistics/day?date&walletId`
- `GET /statistics/month?year&month&categoryType&walletId`
- `GET /statistics/year?year&categoryType&walletId`
- `GET /statistics/range?startDate&endDate&categoryType&walletId`
- `GET /statistics/daily-breakdown?startDate&endDate`

**Giao diện:** Dashboard, Analytics, Milestones

## 3.16. Dự báo chi tiêu

**Mục đích:** Dự đoán 7 ngày chi tiêu tiếp theo.

**Cách hoạt động:**
1. `SpendingForecastService` lấy 30 ngày daily expense totals
2. Gọi FastAPI `POST /api/forecast` với `SpendingForecastTransformer`
3. Build `ForecastInsightDto`, budget alerts

**API:** `GET /statistics/spending-forecast/eligibility`, `GET /statistics/spending-forecast`

**Giao diện:** `SpendingForecastScreen`, `SpendingForecastPage`, `SpendingForecastCard`

## 3.17. Chatbot tài chính

**Mục đích:** Hỏi đáp về chi tiêu cá nhân.

**Cách hoạt động:**
1. `ChatAssistantService` build context: 45 ngày transactions + budgets + month totals
2. Proxy `POST /api/chat` → Gemini 1.5 Flash nếu có `GEMINI_API_KEY`, else `rule_reply()`

**API:** `POST /ai/chat`

**Giao diện:** `ChatTab`, `ChatPage`

## 3.18. Gợi ý tiết kiệm

**Mục đích:** Gợi ý dựa trên spending patterns.

**Cách hoạt động:** `AISuggestionService` phân tích statistics backend.

**API:** `GET /ai/suggestions`

**Giao diện:** `ChatTab` (Flutter gọi endpoint này; web không gọi)

## 3.19. Xuất báo cáo

**Mục đích:** Download Excel hoặc PDF giao dịch trong khoảng ngày.

**Cách hoạt động:** `ExportService.exportExcel()` (sheet "Giao dịch", cột Ngày/Loại/Số tiền/Danh mục/Mô tả + tổng kết) hoặc `exportPdf()` (OpenPDF, font NotoSans).

**API:** `GET /export/transactions?format=excel|pdf&startDate&endDate`

**Giao diện:** `AnalyticsScreen` (mobile), `AnalyticsPage` (web)

## 3.20. Đồng bộ offline (mobile only)

**Mục đích:** SQLite ↔ MySQL khi có mạng.

**Cách hoạt động:** `SyncService.syncAllIfOnline()` → `pushOutbox()` (category, wallet, transaction, budget, recurring) → `pullAll()`. Trigger: connectivity change, splash, trước reads.

**Database:** SQLite `SyncOutbox` (entity, op, localId, payloadJson)

**Giao diện:** Transparent — tất cả repository impl dùng local DB + sync

## 3.21. Onboarding

**Mục đích:** Chọn personality bot + thiết lập ví ban đầu.

**Cách hoạt động:** `PATCH /users/me/profile` set `botPersonality`, `walletName`, `currencyCode`, `initialBalance`, `onboardingCompleted=true`.

**Giao diện:** `OnboardingBotScreen` → `OnboardingWalletScreen` (Flutter); `OnboardingPage` 2 steps (web)

## 3.22. Theme mode

**Mục đích:** Light/dark/system.

**Cách hoạt động:** Persist `localStorage` key `em_theme_mode` (web) / SharedPreferences (mobile).

**Giao diện:** Settings

## 3.23. Demo user seed

**Mục đích:** Tài khoản demo với 45 ngày dữ liệu.

**Cách hoạt động:** `DemoUserDataInitializer` (`@ConditionalOnProperty app.seed.demo-user-enabled=true`) → `DemoUserSeedService`.

**Config:** `SEED_DEMO_USER=true`, email `ai.demo@local.test`, password `Demo@123456`

---

# PHẦN 4. DATABASE

## Cơ chế schema

- **MySQL (backend):** Hibernate `ddl-auto: update` (`application.yml`). Không có Flyway/Liquibase.
- **Reference SQL:** `backend/src/main/resources/schema.sql` — ghi chú "auto-generated by Hibernate ddl-auto=update", không đầy đủ so với entities hiện tại.
- **SQLite (mobile):** Drift schema version 1 (`frontend/lib/data/local/database.dart`).

**Connection MySQL:** `jdbc:mysql://localhost:3307/expense_manager`, user `root`, password `root`.

---

## Bảng `users`

**Entity:** `com.expense.entity.User`  
**Mục đích:** Tài khoản người dùng, profile, onboarding, bot personality.

| Cột | Kiểu | Ràng buộc | Mô tả |
|-----|------|-----------|-------|
| id | BIGINT | PK, AUTO_INCREMENT | |
| full_name | VARCHAR(100) | NOT NULL | @Size 2-100 |
| email | VARCHAR(150) | NOT NULL, UNIQUE | |
| password | VARCHAR(255) | NOT NULL | BCrypt hash |
| phone | VARCHAR(20) | nullable | |
| bot_personality | VARCHAR(20) | nullable | HAPPY, SAD, ANGRY |
| onboarding_completed | BOOLEAN | nullable | |
| wallet_name | VARCHAR(100) | nullable | Từ onboarding |
| currency_code | VARCHAR(10) | nullable | |
| initial_balance | DECIMAL(15,2) | nullable | |
| savings_goal_monthly | DECIMAL(15,2) | nullable | Mục tiêu tiết kiệm |
| created_at | DATETIME | NOT NULL | @PrePersist |
| updated_at | DATETIME | nullable | @PreUpdate |

**Quan hệ:**
- `@OneToMany` → `transactions`, `categories`, `budgets`, `wallets` (cascade ALL, orphanRemoval)

---

## Bảng `categories`

**Entity:** `com.expense.entity.Category`

| Cột | Kiểu | Ràng buộc |
|-----|------|-----------|
| id | BIGINT | PK |
| name | VARCHAR(100) | NOT NULL |
| description | VARCHAR(255) | nullable |
| icon | VARCHAR(50) | nullable |
| type | VARCHAR(20) | NOT NULL — enum `CategoryType`: EXPENSE, INCOME |
| user_id | BIGINT | FK → users, NOT NULL |
| created_at | DATETIME | NOT NULL |

**Quan hệ:**
- `@ManyToOne` → `User`
- `@OneToMany` → `Transaction`

**Index (schema.sql):** `idx_categories_user_type (user_id, type)`

**Danh mục mặc định seed (CategoryService):**

Expense (14): Ăn uống, Di chuyển, Nhà ở, Hóa đơn, Mua sắm, Giải trí, Du lịch, Giáo dục, Sức khỏe, Gia đình, Thú cưng, Quà tặng, Từ thiện, Khác

Income (6): Lương, Thưởng, Freelance, Đầu tư, Bán hàng, Thu nhập khác

---

## Bảng `wallets`

**Entity:** `com.expense.entity.Wallet`

| Cột | Kiểu | Ràng buộc |
|-----|------|-----------|
| id | BIGINT | PK |
| name | VARCHAR(100) | NOT NULL |
| currency_code | VARCHAR(10) | NOT NULL |
| initial_balance | DECIMAL(15,2) | NOT NULL, default 0 |
| is_default | BOOLEAN | NOT NULL, default false |
| user_id | BIGINT | FK → users |
| created_at | DATETIME | NOT NULL |
| updated_at | DATETIME | nullable |

**Quan hệ:** `@ManyToOne` → `User`

---

## Bảng `transactions`

**Entity:** `com.expense.entity.Transaction`

| Cột | Kiểu | Ràng buộc |
|-----|------|-----------|
| id | BIGINT | PK |
| type | VARCHAR(20) | NOT NULL — `TransactionType`: EXPENSE, INCOME |
| amount | DECIMAL(15,2) | NOT NULL, min 0.01 |
| description | VARCHAR(500) | nullable |
| transaction_date | DATE | NOT NULL |
| category_id | BIGINT | FK → categories, NOT NULL |
| user_id | BIGINT | FK → users, NOT NULL |
| wallet_id | BIGINT | FK → wallets, nullable |
| recurring_transaction_id | BIGINT | FK → recurring_transactions, nullable |
| created_at | DATETIME | NOT NULL |
| updated_at | DATETIME | nullable |

**Quan hệ:**
- `@ManyToOne` → `Category`, `User`, `Wallet`, `RecurringTransaction`

**Indexes (schema.sql):** `idx_transactions_user_date`, `idx_transactions_user_type`, `idx_transactions_wallet`

---

## Bảng `budgets`

**Entity:** `com.expense.entity.Budget`

| Cột | Kiểu | Ràng buộc |
|-----|------|-----------|
| id | BIGINT | PK |
| amount | DECIMAL(15,2) | NOT NULL |
| start_date | DATE | NOT NULL |
| end_date | DATE | NOT NULL |
| category_id | BIGINT | FK → categories |
| user_id | BIGINT | FK → users |
| note | VARCHAR(255) | nullable |
| created_at | DATETIME | NOT NULL |
| updated_at | DATETIME | nullable |

**Quan hệ:** `@ManyToOne` → `Category`, `User`

---

## Bảng `recurring_transactions`

**Entity:** `com.expense.entity.RecurringTransaction`

| Cột | Kiểu | Ràng buộc |
|-----|------|-----------|
| id | BIGINT | PK |
| type | VARCHAR(20) | TransactionType |
| amount | DECIMAL(15,2) | NOT NULL |
| description | VARCHAR(500) | nullable |
| day_of_month | INT | 1–28 |
| start_date | DATE | NOT NULL |
| end_date | DATE | nullable |
| is_active | BOOLEAN | default true |
| category_id | BIGINT | FK |
| user_id | BIGINT | FK |
| created_at | DATETIME | NOT NULL |

**Quan hệ:** `@ManyToOne` → `Category`, `User`; `@OneToMany` → `Transaction`

**Scheduler:** Bỏ qua ngày > 28 trong tháng.

---

## Bảng `pending_registrations`

**Entity:** `com.expense.entity.PendingRegistration`  
**Mục đích:** Lưu đăng ký chờ OTP, chưa tạo user.

| Cột | Kiểu | Ghi chú |
|-----|------|---------|
| id | BIGINT | PK |
| email | VARCHAR | |
| full_name | VARCHAR | |
| password_hash | VARCHAR | BCrypt |
| phone | VARCHAR | nullable |
| otp_hash | VARCHAR | BCrypt hash OTP 6 số |
| expires_at | DATETIME | TTL 10 phút |
| attempts | INT | default 0, max 5 |
| created_at | DATETIME | |

**Indexes:** `idx_pending_reg_email`, `idx_pending_reg_expires_at`

---

## Bảng `password_reset_tokens`

**Entity:** `com.expense.entity.PasswordResetToken`

| Cột | Kiểu | Ghi chú |
|-----|------|---------|
| id | BIGINT | PK |
| email | VARCHAR | |
| otp_hash | VARCHAR | BCrypt |
| expires_at | DATETIME | TTL 10 phút |
| attempts | INT | default 0 |
| used | BOOLEAN | default false |
| created_at | DATETIME | |

**Indexes:** `idx_prt_email`, `idx_prt_expires_at`

---

## SQLite (Flutter Drift) — schema version 1

**File:** `frontend/lib/data/local/database.dart`

### Bảng `Categories`
- id (auto), remoteId (nullable), name, description, icon, type, pendingSync

### Bảng `Wallets`
- id, remoteId, name, currencyCode, initialBalance, isDefault, createdAt, pendingSync

### Bảng `Transactions`
- id, remoteId, type, amount, description, transactionDate, categoryLocalId (FK), walletLocalId (FK nullable), createdAt, pendingSync

### Bảng `Budgets`
- id, remoteId, amount, spentAmount, remainingAmount, startDate, endDate, categoryLocalId, note, pendingSync

### Bảng `RecurringTransactions`
- id, remoteId, type, amount, description, dayOfMonth, startDate, endDate, isActive, categoryLocalId, pendingSync

### Bảng `SyncOutbox`
- id, entity (category/wallet/transaction/budget/recurring), op (create/update/delete), localId, payloadJson

---

# PHẦN 5. BACKEND SPRING BOOT

## Package structure (96 Java files)

Base: `com.expense`

| Package | Số file | Vai trò |
|---------|---------|---------|
| `com.expense` | 1 | `ExpenseManagerApplication` |
| `config` | 8 | Security, CORS, async, OpenAPI, scheduler, demo seed |
| `controller` | 10 | REST endpoints |
| `dto` | 35 | Request/response objects |
| `entity` | 8 + 2 enums | JPA entities |
| `exception` | 3 | GlobalExceptionHandler |
| `repository` | 8 | Spring Data JPA |
| `security` | 4 | JWT filter, UserPrincipal |
| `service` | 17 | Business logic |

## Controllers (10)

| Controller | Base path | Auth |
|------------|-----------|------|
| AuthController | `/auth` | Public (trừ refresh cần Bearer refresh token) |
| UserController | `/users` | Required |
| CategoryController | `/categories` | Required |
| WalletController | `/wallets` | Required |
| TransactionController | `/transactions` | Required |
| BudgetController | `/budgets` | Required |
| RecurringTransactionController | `/recurring-transactions` | Required |
| StatisticsController | `/statistics` | Required |
| AIController | `/ai` | Required |
| ExportController | `/export` | Required |

## Security

**SecurityConfig:**
- `@EnableWebSecurity`, `@EnableMethodSecurity` (không có `@PreAuthorize` trong codebase)
- CSRF disabled
- Session: `STATELESS`
- `DaoAuthenticationProvider` + `BCryptPasswordEncoder`
- `JwtAuthenticationFilter` trước `UsernamePasswordAuthenticationFilter`

**Public URLs:**
```
/auth/register, /auth/register/request, /auth/register/verify, /auth/register/resend-otp
/auth/login, /auth/refresh, /auth/forgot-password, /auth/reset-password
/v3/api-docs/**, /swagger-ui/**, /swagger-ui.html
```

## JWT

**JwtTokenProvider:**
- Secret: `${jwt.secret}` (default trong yml, override `JWT_SECRET`)
- Access token: `jwt.expiration-ms` = 86400000 (24h)
- Refresh token: `jwt.refresh-expiration-ms` = 604800000 (7d)
- Subject = user email
- Library: `io.jsonwebtoken` (Jwts), HMAC signing

**JwtAuthenticationFilter:**
- Đọc `Authorization: Bearer <token>`
- Validate → load user qua `CustomUserDetailsService` → set SecurityContext

**AuthResponse:** accessToken, refreshToken, tokenType "Bearer", expiresIn (seconds), user (UserInfo)

## Authentication flow

1. Login: `AuthenticationManager.authenticate()` → BCrypt verify
2. Register legacy: encode password → save user → JWT
3. Register OTP: pending → verify OTP → create user → JWT
4. Refresh: validate refresh token → new token pair

## Authorization

- Tất cả endpoint ngoài PUBLIC_URLS yêu cầu `authenticated()`
- `UserPrincipal` có single authority `ROLE_USER`
- Không có role-based endpoint separation trong code

## Service layer (17 services)

| Service | Trách nhiệm chính |
|---------|-------------------|
| AuthService | register, login, refreshToken |
| PendingRegistrationService | OTP registration flow |
| PasswordResetService | forgot/reset password OTP |
| UserService | profile CRUD, change password |
| CategoryService | CRUD, seed default categories |
| WalletService | CRUD, default wallet |
| TransactionService | CRUD + filters |
| BudgetService | CRUD, active budgets |
| RecurringTransactionService | CRUD, toggle, processRecurringForDate |
| StatisticsService | day/month/year/range stats |
| SpendingForecastService | forecast eligibility + AI call |
| ExportService | Excel + PDF |
| AICategorizationService | proxy categorize |
| ReceiptOcrService | proxy OCR multipart |
| AISuggestionService | spending suggestions |
| ChatAssistantService | build context + proxy chat |
| EmailService | async OTP email (@Async mailExecutor) |

**Config services:**
- `DemoUserSeedService` — seed demo user + 45 ngày transactions

## Repository layer (8)

| Repository | Custom queries |
|------------|----------------|
| UserRepository | findByEmail, existsByEmail |
| CategoryRepository | findByUserIdAndType, existsByUserIdAndNameAndType |
| WalletRepository | findByUserIdOrderByIsDefaultDescNameAsc, findByUserIdAndIsDefaultTrue |
| TransactionRepository | 10+ queries: filtered paging, sums, daily aggregation, export list, recurring dedup |
| BudgetRepository | active budget by date range |
| RecurringTransactionRepository | findByIsActiveTrueAndDayOfMonth |
| PendingRegistrationRepository | findFirstByEmailOrderByCreatedAtDesc, deleteExpired |
| PasswordResetTokenRepository | findFirstByEmailAndUsedFalseOrderByCreatedAtDesc |

## Scheduler

**RecurringScheduledJob:**
- `@Scheduled(cron = "0 0 0 * * *")` — hàng ngày 00:00
- Gọi `recurringTransactionService.processRecurringForDate(LocalDate.now())`

**AsyncConfig:**
- `@EnableAsync`, bean `mailExecutor` (core 2, max 4, queue 50)

## Export PDF

**ExportService.exportPdf():**
- Library: OpenPDF (`com.lowagie.text`)
- Font: `/fonts/NotoSans-Regular.ttf` classpath
- Layout: header bar, title, period, user info, KPI (expense/income/balance), transaction table, footer
- Locale: `vi-VN` DecimalFormat
- Filename: `bao-cao-giao-dich-{yyyyMM}.pdf`

## Export Excel

**ExportService.exportExcel():**
- Library: Apache POI `XSSFWorkbook`
- Sheet "Giao dịch": Ngày, Loại, Số tiền, Danh mục, Mô tả
- Summary: Tổng chi phí, Tổng thu nhập, Chênh lệch
- Filename: `bao-cao-giao-dich-{yyyyMM}.xlsx`

## Exception handling

**GlobalExceptionHandler:**
- ResourceNotFoundException → 404
- BadRequestException → 400
- BadCredentialsException → 401
- MethodArgumentNotValidException → 400
- Exception → 500

## AI integration config (application.yml)

```yaml
ai:
  categorization:
    provider: python-api
    python-api:
      base-url: http://localhost:8000
      categorize-endpoint: /api/categorize
  forecast:
    endpoint: /api/forecast
    window-days: 30
  ocr:
    parse-endpoint: /api/ocr/receipt/parse
  chat:
    endpoint: /api/chat
    history-days: 45
```

## Pagination

- default-page-size: 20
- max-page-size: 100

---

# PHẦN 6. FRONTEND WEB (React)

## Tech stack

- React 18, Vite 5, TypeScript 5.6
- MUI 5, Emotion, Recharts
- react-router-dom v6 (`createBrowserRouter`)
- @tanstack/react-query v5
- Axios (`src/lib/api.ts`)
- API base: `VITE_API_BASE_URL` (default `/api`)

## Routing (`web/src/app/router.tsx`)

### Public
| Path | Page |
|------|------|
| `/` | Redirect → `/login` |
| `/login` | LoginPage |
| `/register` | RegisterPage |
| `/register/verify` | VerifyRegistrationPage |
| `/forgot-password` | ForgotPasswordPage |
| `/reset-password` | ResetPasswordPage |

### Protected
| Path | Guards | Page |
|------|--------|------|
| `/onboarding` | ProtectedRoute + OnboardingOnly | OnboardingPage |
| `/app/*` | ProtectedRoute + RequireOnboardingComplete | AppShell nested |

### App routes (under `/app`)
| Path | Page | Nav |
|------|------|-----|
| `/app/dashboard` | DashboardPage | Main tab |
| `/app/transactions` | TransactionsPage | Main tab |
| `/app/spending-forecast` | SpendingForecastPage | Main tab |
| `/app/chat` | ChatPage | Main tab |
| `/app/settings` | SettingsPage | Main tab |
| `/app/categories` | CategoriesPage | Sub-page |
| `/app/budget` | BudgetPage | Sub-page |
| `/app/wallets` | WalletsPage | Sub-page |
| `/app/recurring` | RecurringPage | Sub-page |
| `/app/transactions/add` | AddTransactionPage | Sub-page |
| `/app/transactions/:id/edit` | AddTransactionPage (edit) | Sub-page |
| `/app/analytics` | AnalyticsPage | Sub-page |
| `/app/milestones` | MilestonesPage | Sub-page |
| `/app/profile` | ProfilePage | Sub-page |

### Route guards
- **ProtectedRoute:** redirect `/login` nếu chưa auth
- **RequireOnboardingComplete:** redirect `/onboarding` nếu `onboardingCompleted === false`
- **OnboardingOnly:** redirect `/app/dashboard` nếu đã hoàn thành onboarding

### AppShell navigation
- Desktop: permanent left drawer (5 main tabs)
- Mobile: bottom navigation
- Sub-pages: sticky AppBar + back button
- FAB: `/app/transactions/add` (main tabs only)

## Pages (20)

**Auth:** LoginPage, RegisterPage, VerifyRegistrationPage, ForgotPasswordPage, ResetPasswordPage

**Onboarding:** OnboardingPage (2 steps: bot personality, wallet setup)

**Main:** DashboardPage, TransactionsPage, AddTransactionPage, ChatPage, SettingsPage, CategoriesPage, BudgetPage, WalletsPage, RecurringPage, AnalyticsPage, SpendingForecastPage, MilestonesPage, ProfilePage

## Components chính

### Layout
- `AppShell` — chrome, drawer, bottom nav, FAB
- `ProtectedRoute`, `RequireOnboardingComplete`, `OnboardingOnly`

### Common
- `GradientBackground` — wrapper nền gradient

### Robot/Mascot
- `RobotAvatar`, `NattaAvatar`, `PersonalityRobotAvatar`, `AnimatedNattaRobot`, `NattaMascotImage`
- Type `Personality`: HAPPY | SAD | ANGRY

### Feature
- `SpendingForecastCard` — forecast chart + insight + budget alerts
- `ReceiptOcrDialog` — upload OCR trên add transaction

## State management

### React Context
| Context | Persist | Holds |
|---------|---------|-------|
| AuthContext | localStorage `em_access_token`, `em_refresh_token`, `em_user` | user, login/logout, refreshUser |
| SelectedWalletContext | `em_selected_wallet_id` | active wallet ID, cross-tab sync |
| ThemeModeContext | `em_theme_mode` | light/dark/system |

### TanStack React Query
- staleTime: 20s
- refetchOnWindowFocus: always
- refetchInterval: 12s (tab visible)
- Query keys: wallets, stats, transactions, categories, budgets, recurring, analytics, daily, forecast-eligibility, transaction

### Không dùng
Redux, Zustand, Jotai

## API layer

**Axios (`api.ts`):**
- Request interceptor: Bearer accessToken
- Response interceptor: 401 → POST `/auth/refresh` → retry once
- Envelope: `{ success, message?, data }`

**Services (9 files):**
authService, userService, walletService, categoryService, transactionService, budgetService, recurringService, statisticsService, exportService, mappers

## Types (`types/models.ts`)

User, AuthPayload, Category, Wallet, Transaction, PageResponse, Statistics, SpendingForecast, ForecastEligibility, ForecastInsight, AICategorizeResponse, Budget, RecurringTransaction, DaySummary

---

# PHẦN 7. FLUTTER MOBILE (`frontend/`)

## Identity

- Package: `expense_manager`
- Version: 1.0.0+2
- SDK: >=3.2.0 <4.0.0
- Entry: `lib/main.dart`

## Kiến trúc

Clean Architecture:
- `core/` — constants, DI, providers, router, theme, utils
- `data/` — api_client, local_storage, database, repositories, sync
- `domain/` — models, repository interfaces
- `presentation/` — screens, widgets

## Screens (19 route + 4 tabs)

| Screen | Route | File |
|--------|-------|------|
| SplashScreen | `/` (home) | splash_screen.dart |
| WelcomeScreen | `/welcome` | welcome_screen.dart (không có navigation tới) |
| OnboardingBotScreen | `/onboarding/bot` | onboarding_bot_screen.dart |
| OnboardingWalletScreen | (MaterialPageRoute) | onboarding_wallet_screen.dart |
| LoginScreen | `/login` | login_screen.dart |
| RegisterScreen | `/register` | register_screen.dart |
| VerifyRegistrationScreen | `/register/verify` | verify_registration_screen.dart |
| ForgotPasswordScreen | `/forgot-password` | forgot_password_screen.dart |
| ResetPasswordScreen | `/reset-password` | reset_password_screen.dart |
| MainScreen | `/main` | main_screen.dart |
| AddTransactionScreen | `/add-transaction` | add_transaction_screen.dart |
| CategoryScreen | `/categories` | category_screen.dart |
| BudgetScreen | `/budget` | budget_screen.dart |
| MilestonesScreen | `/milestones` | milestones_screen.dart |
| AnalyticsScreen | `/analytics` | analytics_screen.dart |
| SpendingForecastScreen | `/spending-forecast` | spending_forecast_screen.dart |
| RecurringScreen | `/recurring` | recurring_screen.dart |
| WalletsScreen | `/wallets` | wallets_screen.dart |
| ProfileScreen | `/profile` | profile_screen.dart |

### Main tabs (MainScreen IndexedStack)
| Tab | Label |
|-----|-------|
| DashboardTab | Trang chủ |
| TransactionsTab | Giao dịch |
| ChatTab | Trợ lý AI |
| SettingsTab | Cài đặt |

### Bottom sheets
- `receipt_ocr_sheet.dart`, `change_password_sheet.dart`, `edit_wallet_sheet.dart`, `bot_selector_sheet.dart`

## Navigation

- `MaterialApp` + `onGenerateRoute: AppRouter.generateRoute`
- Không dùng go_router, auto_route

**Startup (SplashScreen):**
1. Wait 1.5s
2. Not logged in → `/login`
3. Logged in + online → GET `/users/me`; fail → `/login`
4. Background sync
5. `onboardingCompleted != true` → `/onboarding/bot`, else → `/main`

## State management

**Riverpod 2.x** (`ProviderScope`):

| Provider | Type | Purpose |
|----------|------|---------|
| currentUserProvider | FutureProvider | User từ SharedPreferences |
| syncServiceProvider | Provider | SyncService |
| *RepositoryProvider | Provider | 8 repository impls |
| selectedWalletIdProvider | StateProvider<int?> | Active wallet |
| themeModeProvider | StateNotifierProvider | Light/dark/system |
| transactionListRefreshTriggerProvider | StateProvider<int> | Refresh list |
| dailyReminderProvider | StateNotifierProvider | Local notifications |

**DI:** Manual singleton `injection.dart` (`initDependencies()`)

**Persistence:**
- SharedPreferences: tokens, user JSON, theme, reminder prefs
- Drift SQLite: offline data + SyncOutbox

## API

**Base URL (`api_constants.dart`):**
- Default: `http://localhost:8080/api`
- Android emulator: `http://10.0.2.2:8080/api`
- Override: `--dart-define=API_BASE_URL=...`

**Auth:** Bearer + auto-refresh on 401

### Endpoints được gọi từ UI/repositories

**Auth:** register/request, verify, resend-otp, login, refresh, forgot-password, reset-password

**Users:** GET /users/me, PATCH /users/me/profile, PATCH /users/me/password

**Categories:** GET/POST/PUT/DELETE /categories (sync)

**Wallets:** GET/POST/PUT/DELETE /wallets

**Transactions:** GET/POST/PUT/DELETE /transactions, AI categorize/batch, OCR receipt

**AI:** GET /ai/suggestions, POST /ai/chat

**Budgets:** GET/POST/PUT/DELETE /budgets

**Recurring:** GET/POST/PUT/DELETE /recurring-transactions, PATCH toggle

**Statistics:** day, month, year, range, daily-breakdown, spending-forecast/eligibility, spending-forecast

**Export:** GET /export/transactions

**Defined nhưng không gọi từ UI:** POST /auth/register, GET /categories/by-type, GET /budgets/active, GET /statistics/day (impl có, presentation không dùng)

## Offline-first

Entities sync qua REST: categories, wallets, transactions, budgets, recurring.

Always-online: auth, profile, AI, forecast, export.

Statistics fallback local SQLite khi offline (trừ forecast).

---

# PHẦN 8. AI SERVICE

**Entry:** `ai_service/app/main.py`  
**Version:** 0.2.0  
**Models dir:** `ai_service/models/`  
**Dependencies (`requirements.txt`):** fastapi, uvicorn, pydantic, numpy, pandas, torch, matplotlib, Pillow, httpx, python-multipart

**Env vars:**
- `GEMINI_API_KEY`, `GEMINI_MODEL` (default `gemini-1.5-flash`), `GEMINI_TIMEOUT_S` (default 20)
- EasyOCR: optional, không trong requirements.txt

---

## 8.1. Module phân loại giao dịch (Transaction Classification)

**Files:** `classify_net.py`, `classify_infer.py`, `classify_train_lib.py`, `classify_ood.py`, `text_preprocess.py`, `category_hints.py`, `rules.py`, `parsers.py`, `transaction_intent.py`

**Chức năng:** Phân loại câu nhập tiếng Việt → category (20 lớp), type EXPENSE/INCOME, trích amount/date.

**Input:** `{ "text": "ăn trưa 50k" }`

**Output:** `{ type, category, amount, description, transaction_date, confidence }`

**Pipeline inference (`/api/categorize`):**
1. `normalize_note()` — extract amount, description, cleaned text, assumed date
2. `is_amount_only_text()` → category "Khác", confidence null
3. `hint_category()` — keyword rules override model
4. Model `predict_top_label()` — CharCNNBiLSTMAttn argmax
5. Nếu conf < 0.45 → `rule_based_category()` (trừ khi rule trả "Khác")
6. `infer_transaction_type()` + `adjust_category_for_type()`

**Deployment state:** `classify_model.pt` **không có** trong `models/` → `classify_loaded=false` → fallback hints + rules only.

---

## 8.2. Module dự báo chi tiêu (Spending Forecast)

**Files:** `forecast_net.py`, `forecast_infer.py`, `forecast_features.py`

**Chức năng:** Dự đoán 7 ngày chi tiêu từ chuỗi daily totals.

**Input:** `{ daily_expenses_vnd: float[], last_observation_date?: "YYYY-MM-DD" }` — cần ≥30 ngày.

**Output:** `{ predicted_next_days_vnd: int[7], horizon: 7, window: 30 }`

**Pipeline:**
1. VND → log1p → z-score (mean_log, std_log từ meta)
2. Build 14-dim encoder features (amount + 8 calendar + 5 category shares)
3. `SpendingForecastTransformer` encoder-decoder
4. Denorm → VND integers

**Deployment state:** `forecast_model.pt` + `forecast_meta.json` **có** trong `models/`.

---

## 8.3. Module OCR hóa đơn (Receipt OCR)

**Files:** `ocr_net.py`, `ocr_infer.py`, `ocr_real.py`, `ocr_charset.py`, `ocr_eval.py`, `receipt_parse.py`, `receipt_layout.py`

**Chức năng:** Đọc ảnh hóa đơn → amount, date, merchant, description, category.

**Hai engine:**
| Engine | File | Điều kiện |
|--------|------|-----------|
| EasyOCR (primary) | `ocr_real.py` | `easyocr` installed, langs vi+en |
| CRNN v2 (fallback) | `ocr_infer.py` | 4 model `.pt` trong models/ |

**4 field models CRNN:**
| Field | Prefix | Charset | img_w |
|-------|--------|---------|-------|
| amount | ocr_amount | digits 0-9., | 224 |
| merchant | ocr_merchant | Latin + Vietnamese + punct | 320 |
| date | ocr_date | digits + /-.: space | 320 |
| line | ocr_line | same as merchant | 320 |

**Input:** multipart image bytes

**Output (`ReceiptParseResult`):** amount_vnd, transaction_date, merchant, description, category, type, field confidences, needs_review (threshold 0.55), ocr_engine

**Deployment state:** Không có `ocr_*_model.pt` trong `models/` → CRNN path unavailable; EasyOCR nếu installed.

**Endpoints:**
- `POST /api/ocr/receipt/parse` — full parse, EasyOCR preferred
- `POST /api/ocr/receipt/parse-easyocr` — EasyOCR only
- `POST /api/ocr/receipt/amount` — amount only

---

## 8.4. Module chatbot tài chính

**File:** `chat.py`

**Chức năng:** Hỏi đáp về chi tiêu cá nhân.

**Input:**
```json
{
  "message": "...",
  "personality": "HAPPY|SAD|ANGRY",
  "context": {
    "currency": "VND",
    "month_total_expense": 0,
    "month_total_income": 0,
    "by_category": [{"name":"...", "amount":0}],
    "recent_transactions": [...],
    "budgets": [{"category":"...", "limit":0, "used":0}]
  }
}
```

**Output:** `{ reply: string, engine: "gemini"|"rule" }`

**Pipeline:**
- Có `GEMINI_API_KEY` → Google Generative Language API, model `gemini-1.5-flash`, temperature 0.7, topP 0.9, max 700 tokens
- Không có key → `rule_reply()` pattern-based theo personality

---

## 8.5. Module phụ trợ (rule-based, không ML)

| Module | Chức năng |
|--------|-----------|
| `parsers.py` | Trích amount (k, tr, VND), date từ free text |
| `category_hints.py` | ~70 regex rules short-circuit trước model |
| `rules.py` | Keyword fallback category |
| `classify_ood.py` | OOD: empty, amount_only, keyboard mashing, non-finance |
| `transaction_intent.py` | EXPENSE vs INCOME, remap mislabeled income |
| `receipt_layout.py` | Chia vùng header/footer/body trên receipt |
| `val_hard_samples.py` | Catalog hard validation samples |

---

## 8.6. Health check

`GET /health` trả:
```json
{
  "ok": true,
  "easyocr_available": bool,
  "gemini_available": bool,
  "forecast_loaded": bool,
  "classify_loaded": bool,
  "ocr_amount_loaded": bool,
  "ocr_merchant_loaded": bool,
  "ocr_date_loaded": bool,
  "ocr_line_loaded": bool
}
```

---

# PHẦN 9. AI PHÂN LOẠI GIAO DỊCH (CHI TIẾT)

## Dataset

**File training:** `ai_service/data/classify_train_cleaned.csv`
- **10.001 dòng** (10.000 samples + 1 header)
- Cột: `text`, `label`
- **20 nhãn**, 500 samples/nhãn sau cleaning

**Build script:** `data/build_classify_dataset.py`
- `TARGET_PER_LABEL = 500`
- Nguồn: `classify_train.csv` hoặc fallback cleaned, `classify_edge_cases.csv`, hard patterns từ `classify_hard_patterns.py`
- Inject tối đa 45 hard câu/nhãn sau balance

**Stats (`classify_dataset_stats.json`):**

| Metric | Before clean | After clean |
|--------|--------------|-------------|
| total_rows | 10.232 | 10.000 |
| exact_dup_rows | 203 | 0 |
| conflict_texts | 1 | 0 |
| avg_text_len | 26.34 | 26.81 |
| vocab_size (char) | 146 | 147 |
| imbalance_ratio | 1.08 | 1.0 |

**Edge cases:** `classify_edge_cases.csv`

**Hard patterns:** `classify_hard_patterns.py` — ~1500+ biến thể, contrastive, Sức khỏe

## Các nhãn (20 classes)

**14 Expense (index 0–13):**
Ăn uống, Di chuyển, Mua sắm, Nhà ở, Hóa đơn, Giải trí, Du lịch, Giáo dục, Sức khỏe, Gia đình, Thú cưng, Quà tặng, Từ thiện, Khác

**6 Income (index 14–19):**
Lương, Thưởng, Freelance, Đầu tư, Bán hàng, Thu nhập khác

Mapping trong `classify_meta.json` → `label2idx`.

## Tiền xử lý

**Config (`classify_preprocess.json`):**
```json
{
  "unicode_form": "NFC",
  "lowercase": true,
  "strip_accents": false,
  "normalize_money": true,
  "expand_abbreviations": true,
  "max_repeat_char": 3
}
```

**Pipeline (`text_preprocess.py`):**
1. NFC normalize, lowercase, collapse whitespace
2. Collapse repeated punctuation; cap char repeats at 3
3. Money normalization → `<money_50k>`, `<money_2tr>`, `<money_2tr5>` (k/tr/nghìn/VND/bare digits)
4. Abbreviation expansion (vcb→vietcombank, cf→cafe, bhx→bach hoa xanh, tro→tien tro, ...)
5. Optional accent stripping (off in production config)

## Augmentation (train only)

**Function:** `augment_train_text()` trong `classify_train_lib.py`

**Kỹ thuật:**
- Accent strip, tone swap (`_TONE_SWAPS`)
- Money variants (`_RE_K_AUG`, `_RE_TR_AUG`, `_RE_M_AUG`)
- Abbrev flip (`ABB_AUG_PAIRS` — cafe↔cf, vcb↔vietcombank, ...)
- Char delete/swap
- Slang prefix/suffix (`_SLANG_PREFIX`, `_SLANG_SUFFIX`, `NOISY_PREFIX`, `NOISY_SUFFIX`)
- Emoji by label (`EMOJI_BY_LABEL`: 🍜🚗🛍️🎬)
- Case noise

**aug_copies:** 3 per train sample → **35.200** augmented rows từ **8.800** original train

## Vocabulary

**File:** `classify_vocab.json` — **121 entries**
- `<PAD>=0`, `<UNK>=1`
- Chars tiếng Việt có dấu, digits, punctuation
- Emoji: 🍜🚗🛍️🎬
- Money token chars: `<`, `>`, `_`

**vocab_size trong meta:** 121

## Embedding

- `nn.Embedding(vocab_size, embed_dim=96, padding_idx=0)`
- Character-level (không word-level)

## Model architecture: CharCNNBiLSTMAttn

**File:** `classify_net.py`

```
Input: (B, L) token indices, max_len=128
  ↓
Char Embedding (96-d)
  ↓
5 parallel Conv1d (kernels 2,3,4,5,6; 64 filters each; padding=k//2)
  ↓ concat → (B, L', 320)
BiLSTM (hidden=128, 1 layer, bidirectional) → (B, L', 256)
  ↓
AttentionPool (linear proj → softmax mask → weighted sum)
  ↓
FC 256 + GELU + Dropout(0.35)
  ↓
FC → 20 classes
```

**from_scratch:** true (`classify_meta.json`)
**pretrained_used:** false

## Attention

**Class:** `AttentionPool` trong `classify_net.py`
- `proj: Linear(hidden_dim, 1)` trên LSTM outputs
- Mask padding positions (-1e4)
- Softmax weights → weighted sum context vector

## Loss Function

**Default:** `CrossEntropyLoss` + label_smoothing=0.05 + optional class weights

**Optional:** `FocalLoss` (gamma=2.0) — flag `--focal` trong training CLI

**Class weights:** từ `original_train_distribution` khi `use_class_weights=true`

## OOD Detection

**File:** `classify_ood.py`

**Rules:**
| Condition | Reason |
|-----------|--------|
| Empty text | empty |
| Amount only (50k, 20tr) | amount_only → category "Khác" |
| too_short (≤2 chars, no financial context) | too_short |
| Non-finance phrases ("hôm nay trời đẹp") | non_finance |
| digits_only (≥4 digits) | digits_only |
| Keyboard mashing (asdf, qwer) | random_chars |
| Low entropy (≤4 unique chars) | low_entropy |

**Financial context keywords:** grab, xang, cafe, momo, vcb, luong, salary, tiền, mua, ...

## Hyperparameters

| Param | Value | Nguồn |
|-------|-------|-------|
| embed_dim | 96 | classify_meta.json |
| num_filters | 64 | classify_meta.json |
| kernel_sizes | [2,3,4,5,6] | classify_meta.json |
| lstm_hidden | 128 | classify_meta.json |
| max_len | 128 | classify_meta.json |
| dropout | 0.35 | classify_meta.json |
| batch_size | 64 | TrainConfig default |
| epochs | 80 | TrainConfig default |
| patience | 12 | TrainConfig default |
| lr | 3e-4 | TrainConfig default |
| weight_decay | 1e-4 | TrainConfig default |
| label_smoothing | 0.05 | TrainConfig default |
| val_ratio | 0.12 (stratified) | TrainConfig default |
| aug_copies | 3 | classify_meta.json |
| confidence_threshold | 0.45 | classify_meta.json |
| early_stop_metric | hard_macro_f1 | classify_meta.json |
| optimizer | AdamW + CosineAnnealingLR | classify_train_lib.py |
| use_amp | true on CUDA | TrainConfig default |

## Metrics (từ `classify_metrics.json`)

**Training date:** 2026-05-30T02:28:01.999277+00:00

### Standard validation (1.200 samples — 60/class)

| Metric | Value |
|--------|-------|
| accuracy | 0.9783 |
| macro_f1 | 0.9783 |
| weighted_f1 | 0.9783 |
| precision_macro | 0.9787 |
| recall_macro | 0.9783 |
| best_val_acc (checkpoint) | 0.9817 |
| best_hard_macro_f1 (checkpoint) | 0.9088 |

**Confidence stats (val):**
- mean max confidence: 0.9445
- median: 0.9629
- min: 0.1584
- 1.0% below threshold 0.45

**Weakest per-class accuracy (val):** Mua sắm 0.917, Di chuyển 0.95, Hóa đơn 0.95, Giải trí 0.95, Ăn uống 0.967

**Top confused pairs (val):**
- Mua sắm → Ăn uống: 3
- Di chuyển → Ăn uống: 3
- (15 cặp khác count 1)

### Hard validation (191 samples)

| Metric | Value |
|--------|-------|
| accuracy | 0.8901 |
| macro_f1 | 0.9088 |
| weighted_f1 | 0.8910 |
| precision_macro | 0.9163 |
| recall_macro | 0.9086 |

**Confidence stats (hard):**
- mean: 0.8902, median: 0.9586, min: 0.1416
- 6.28% below 0.45

**Weakest hard per-class:** Khác 0.60, Ăn uống 0.75, Giải trí 0.75, Đầu tư 0.818

**Hard val catalog:** `val_hard_samples.py` + `data/val_hard_samples_catalog.py` — meta ghi 191 samples tại eval time; TRAIN_AUDIT.md ghi ~265+ catalog, target 500

### Training history

32 epochs logged trong `classify_metrics.json` → `history`:
- Final train_acc ≈ 0.999, val_acc ≈ 0.979
- train_loss 1.54→0.35, val_loss 0.60→0.40

## Training process

**Entry points:**
| Path | Mô tả |
|------|-------|
| `app/classify_train_lib.py` | `run_training()`, `run_grid_search()` |
| `scripts/train_classify_pipeline.py` | CLI: `--build-only`, `--train`, `--grid`, `--full`, `--focal` |
| `train_classify.ipynb` | Notebook |
| `scripts/generate_train_classify_notebook.py` | Generator notebook |

**Grid search:** 12 reduced combos (dropout 0.25–0.40, lr 1e-4–5e-4, label_smoothing 0–0.08); full 64 combos nếu `CLASSIFY_FULL_GRID=1`

**Selection rank:** hard_macro_f1 → hard_acc → val_macro_f1

**Artifacts output:**
- classify_model.pt, classify_best.pt, classify_checkpoint.pt
- classify_vocab.json, classify_preprocess.json, classify_meta.json, classify_metrics.json

## Validation process

1. Stratified split val_ratio=0.12 → 1.200 val samples
2. Hard validation set độc lập: 191 samples từ `VAL_HARD_SAMPLES`
3. Early stopping theo `hard_macro_f1` (patience 12)
4. Metrics: accuracy, macro/weighted F1, confusion matrix, per-class accuracy, top_confused_pairs, confidence_stats, errors list, low_confidence_samples, hardest_mistakes

**Targets (TRAIN_AUDIT.md):**
- validation_acc ≥ 0.98
- macro_f1 ≥ 0.98
- hard_val_acc ≥ 0.92

---

# PHẦN 10. OCR HÓA ĐƠN (CHI TIẾT)

## Dataset

**Generator:** `data/gen_receipt_dataset.py` → `data/receipt_ocr/`

| Param | Value |
|-------|-------|
| Default N | 8000 synthetic bills (`--n` CLI) |
| Merchants | 60 names |
| Items | 50 product types with prices |
| Output structure | images/full/, images/crops/{amount,merchant,date,line}/, manifests |
| Augmentation (full bill) | perspective, rotation, noise, blur |
| Date formats | %d/%m/%Y, %d-%m-%Y, %d.%m.%Y |

**Manifests per field:**
- manifest_amount.csv, manifest_merchant.csv, manifest_date.csv, manifest_line.csv, manifest.csv

**Label cleaning:**
- amount: strip non-numeric
- merchant/date/line: strip

**Lưu ý:** Thư mục `data/receipt_ocr/` **không có** trong workspace listing hiện tại — chỉ có generator script.

## Data format

**Manifest columns (từ `eval_receipt_ocr.py`):**
- amount: manifest_amount.csv, label column `label_text`, optional `amount_vnd`
- merchant: manifest_merchant.csv, `label_text`
- date: manifest_date.csv, `label_text`
- line: manifest_line.csv, `label_text`

**Image:** grayscale crops, IMG_H=48 (v2)

## Preprocessing (inference)

**`ocr_infer.preprocess_line_image()`:**
- Resize to field-specific img_w (amount: 224, others: 320)
- Normalize

**Train augmentation (`train_receipt_models.py`):**
- Rotation ±3°, shear, blur, brightness, Gaussian noise, random erasing

## CNN (CRNN v2)

**Architecture (`ReceiptLineCRNN` v2):**

4 stages, mỗi stage: Conv→BN→ReLU → ResBlock → SE attention → MaxPool

| Stage | Channels | Pool |
|-------|----------|------|
| 1 | 64 | (2,2) |
| 2 | 128 | (2,2) |
| 3 | 256 | (1,2) |
| 4 | 256 | (1,2) |

Sau CNN: `AdaptiveAvgPool2d((1, None))` → height=1

**v1 backward compat:** `ReceiptLineCRNN_v1` — 4 ConvBlock đơn giản, img_h=32, LSTM 128×2

## BiLSTM

- 3 layers, hidden=256, bidirectional
- Input từ CNN feature map flattened theo width

## CRNN (tổng thể)

```
Image (H×W)
  ↓ CNN v2 (ResNet-style + SE)
  ↓ AdaptiveAvgPool height→1
  ↓ BiLSTM 3×256 bidirectional
  ↓ FC → num_classes (CTC)
  ↓ Greedy CTC decode
```

**4 models riêng:** amount, merchant, date, line — mỗi field có charset và img_w riêng.

## CTC Loss

- `nn.CTCLoss`, blank index = 0
- Decode: `greedy_ctc_decode()` trong `ocr_infer.py`
- Charset: `ocr_charset.py` — `CTC_CHARSET`, `CHAR2IDX`, `IDX2CHAR`, `NUM_CTC_CLASSES`

## Training

**Script:** `data/train_receipt_models.py`

| Param | Value |
|-------|-------|
| Default epochs | 60 |
| Patience | 15 |
| VAL_RATIO | 0.12 |
| Batch | 64 (CUDA) / 32 (CPU) |
| Optimizer | AdamW lr=5e-4, wd=1e-4 |
| Scheduler | warmup (epochs/15) + cosine |
| Loss | CTCLoss blank=0 |
| AMP | on CUDA |

**CLI example:** `python data/train_receipt_models.py --gen-n 4000 --epochs 40`

**Notebook:** `train_receipt_ocr.ipynb`

**Logs output:** `{field}_epoch_log.csv`, `{field}_loss.png`, `{field}_predictions.csv`, `{field}_char_errors.csv`, `compare_models.csv`

## Inference

**EasyOCR path (`ocr_real.py`):**
- langs: `vi`, `en`
- `parse_receipt_bytes_easyocr()` — không cần CRNN weights

**CRNN path (`receipt_parse.py`):**
- `prefer_easyocr=True` mặc định
- Fallback CRNN nếu EasyOCR fail hoặc không available
- Field confidence threshold `needs_review`: 0.55
- Category trên OCR text: cùng pipeline classify + hints + rules

## Metrics

**Evaluation code:** `ocr_eval.py`, `data/eval_receipt_ocr.py`

**Metrics được implement:**
| Metric | Function |
|--------|----------|
| CER | `cer()` — edit distance / len(ref) |
| WER | `wer()` — word-level Levenshtein |
| Exact match | `exact_match()` |
| Char substitution analysis | `substitution_errors()` |

**Lưu ý:** Không có file JSON/CSV kết quả CER/WER đã train trong `models/` hoặc `data/` workspace hiện tại. Metrics chỉ được tính khi chạy `eval_receipt_ocr.py` sau training.

---

# PHẦN 11. API

Tất cả backend endpoints có prefix `/api` (context-path). AI service không có context-path.

## 11.1. Backend Spring Boot API

### Auth (`AuthController` — PUBLIC)

| URL | Method | Chức năng |
|-----|--------|-----------|
| `/api/auth/register` | POST | Đăng ký legacy 1 bước |
| `/api/auth/register/request` | POST | Đăng ký bước 1 — gửi OTP email |
| `/api/auth/register/verify` | POST | Đăng ký bước 2 — verify OTP + tạo user + JWT |
| `/api/auth/register/resend-otp` | POST | Gửi lại OTP đăng ký |
| `/api/auth/login` | POST | Đăng nhập → access + refresh token |
| `/api/auth/refresh` | POST | Refresh token (Bearer refresh token trong header) |
| `/api/auth/forgot-password` | POST | Yêu cầu OTP reset password |
| `/api/auth/reset-password` | POST | Đổi mật khẩu bằng OTP |

### Users (`UserController` — AUTH)

| URL | Method | Chức năng |
|-----|--------|-----------|
| `/api/users/me` | GET | Lấy thông tin user hiện tại |
| `/api/users/me` | PUT | Cập nhật user |
| `/api/users/me/profile` | PATCH | Cập nhật profile, onboarding, bot personality |
| `/api/users/me/password` | PATCH | Đổi mật khẩu (cần mật khẩu cũ) |

### Categories (`CategoryController` — AUTH)

| URL | Method | Chức năng |
|-----|--------|-----------|
| `/api/categories` | POST | Tạo category |
| `/api/categories/{id}` | GET | Lấy category theo ID |
| `/api/categories` | GET | Danh sách phân trang (?page, ?size, ?type) |
| `/api/categories/by-type/{type}` | GET | Lấy theo EXPENSE/INCOME |
| `/api/categories/{id}` | PUT | Cập nhật category |
| `/api/categories/{id}` | DELETE | Xóa category |

### Wallets (`WalletController` — AUTH)

| URL | Method | Chức năng |
|-----|--------|-----------|
| `/api/wallets` | GET | Danh sách ví |
| `/api/wallets/{id}` | GET | Chi tiết ví |
| `/api/wallets` | POST | Tạo ví |
| `/api/wallets/{id}` | PUT | Cập nhật ví |
| `/api/wallets/{id}` | DELETE | Xóa ví |

### Transactions (`TransactionController` — AUTH)

| URL | Method | Chức năng |
|-----|--------|-----------|
| `/api/transactions` | POST | Tạo giao dịch |
| `/api/transactions/{id}` | GET | Chi tiết giao dịch |
| `/api/transactions` | GET | Danh sách (?page, ?size, ?type, ?categoryId, ?walletId, ?startDate, ?endDate) |
| `/api/transactions/{id}` | PUT | Cập nhật giao dịch |
| `/api/transactions/{id}` | DELETE | Xóa giao dịch |
| `/api/transactions/ai/categorize` | POST | AI phân loại 1 câu |
| `/api/transactions/ai/categorize/batch` | POST | AI phân loại nhiều khoản |
| `/api/transactions/ai/ocr/receipt` | POST | OCR hóa đơn (multipart, field `file`, max 10MB) |

### Budgets (`BudgetController` — AUTH)

| URL | Method | Chức năng |
|-----|--------|-----------|
| `/api/budgets` | POST | Tạo ngân sách |
| `/api/budgets/{id}` | GET | Chi tiết ngân sách |
| `/api/budgets` | GET | Danh sách (?page, ?size) |
| `/api/budgets/active` | GET | Ngân sách đang hiệu lực (?date) |
| `/api/budgets/{id}` | PUT | Cập nhật ngân sách |
| `/api/budgets/{id}` | DELETE | Xóa ngân sách |

### Recurring Transactions (`RecurringTransactionController` — AUTH)

| URL | Method | Chức năng |
|-----|--------|-----------|
| `/api/recurring-transactions` | GET | Danh sách |
| `/api/recurring-transactions` | POST | Tạo |
| `/api/recurring-transactions/{id}` | PUT | Cập nhật |
| `/api/recurring-transactions/{id}` | DELETE | Xóa |
| `/api/recurring-transactions/{id}/toggle` | PATCH | Bật/tắt active |

### Statistics (`StatisticsController` — AUTH)

| URL | Method | Chức năng |
|-----|--------|-----------|
| `/api/statistics/day` | GET | Thống kê 1 ngày (?date, ?walletId) |
| `/api/statistics/month` | GET | Thống kê tháng (?year, ?month, ?categoryType, ?walletId) |
| `/api/statistics/year` | GET | Thống kê năm (?year, ?categoryType, ?walletId) |
| `/api/statistics/range` | GET | Thống kê khoảng (?startDate, ?endDate, ?categoryType, ?walletId) |
| `/api/statistics/daily-breakdown` | GET | Chi tiết theo ngày (?startDate, ?endDate) |
| `/api/statistics/spending-forecast/eligibility` | GET | Kiểm tra đủ dữ liệu forecast (?walletId, ?lastObservationDate) |
| `/api/statistics/spending-forecast` | GET | Dự báo 7 ngày (?walletId, ?lastObservationDate) |

### AI (`AIController` — AUTH)

| URL | Method | Chức năng |
|-----|--------|-----------|
| `/api/ai/suggestions` | GET | Gợi ý tiết kiệm |
| `/api/ai/chat` | POST | Chatbot tài chính |

### Export (`ExportController` — AUTH)

| URL | Method | Chức năng |
|-----|--------|-----------|
| `/api/export/transactions` | GET | Xuất Excel/PDF (?format=excel\|pdf\|xlsx, ?startDate, ?endDate) |

### Swagger/OpenAPI (PUBLIC)

| URL | Method | Chức năng |
|-----|--------|-----------|
| `/api/v3/api-docs/**` | GET | OpenAPI spec |
| `/api/swagger-ui/**` | GET | Swagger UI |
| `/api/swagger-ui.html` | GET | Swagger UI entry |

**Response wrapper:** Hầu hết endpoints trả `ApiResponse<T> = { success, message?, data }`. Export trả raw `byte[]` với `Content-Disposition: attachment`.

---

## 11.2. AI Service FastAPI

| URL | Method | Chức năng |
|-----|--------|-----------|
| `/health` | GET | Health check + model load status |
| `/api/categorize` | POST | Phân loại 1 câu |
| `/api/categorize/batch` | POST | Phân loại batch (split separators) |
| `/api/forecast` | POST | Dự báo 7 ngày (cần ≥30 daily values) |
| `/api/ocr/receipt/parse` | POST | OCR full receipt (EasyOCR preferred) |
| `/api/ocr/receipt/parse-easyocr` | POST | OCR EasyOCR only |
| `/api/ocr/receipt/amount` | POST | OCR amount only |
| `/api/chat` | POST | Chatbot Gemini hoặc rule-based |

---

# PHẦN 12. BẢO MẬT

## JWT

| Thuộc tính | Giá trị | Nguồn |
|------------|---------|-------|
| Algorithm | HMAC (jjwt Keys.hmacShaKeyFor) | JwtTokenProvider |
| Secret | `${JWT_SECRET}` env, có default dev trong yml | application.yml |
| Access token TTL | 86400000 ms (24 giờ) | jwt.expiration-ms |
| Refresh token TTL | 604800000 ms (7 ngày) | jwt.refresh-expiration-ms |
| Subject | User email | JwtTokenProvider |
| Claims | subject, issuedAt, expiration | Jwts.builder() |

## Refresh Token

- Sinh cùng lúc login/register: `generateRefreshToken(email)`
- Refresh endpoint: `POST /auth/refresh` — đọc Bearer token từ header, validate, sinh cặp mới
- Client (web/mobile): interceptor tự gọi refresh khi 401, retry request 1 lần
- Refresh failure → clear auth → redirect login

## Password Encoding

- `BCryptPasswordEncoder` bean trong SecurityConfig
- User password: encode khi register/reset
- OTP: BCrypt hash trước khi lưu `PendingRegistration.otpHash`, `PasswordResetToken.otpHash`
- Pending registration password: lưu `passwordHash` (BCrypt), không plaintext

## Security Filter Chain

```
Request
  ↓
JwtAuthenticationFilter
  - Extract Bearer token
  - validateToken()
  - loadUserByUsername(email)
  - Set SecurityContext authentication
  ↓
UsernamePasswordAuthenticationFilter (bypassed nếu đã authenticated)
  ↓
Controller
```

**Session:** STATELESS — không server-side session.

**CSRF:** Disabled.

**CORS:**
- `CorsConfig`: origins localhost:5173, 127.0.0.1:5173, localhost:3000; allowCredentials false
- `WebConfig`: allowedOriginPatterns("*"), allowCredentials true
- (Hai config coexist — CorsConfig bean + WebMvcConfigurer)

## Authorization model

- Single role: `ROLE_USER`
- `@EnableMethodSecurity` enabled nhưng không có method-level `@PreAuthorize`/`@Secured` trong codebase
- Data isolation: services lấy current user từ SecurityContext, filter queries theo userId

## OTP Security

| Param | Value |
|-------|-------|
| OTP length | 6 digits |
| TTL | 10 phút |
| Max verify attempts | 5 (registration) |
| Storage | BCrypt hash, không plaintext |
| Dev fallback | Log OTP ra console nếu mail chưa config (`PASSWORD_RESET_DEV_LOG_OTP=true`) |

## Multipart upload limit

- max-file-size: 10MB
- max-request-size: 10MB
- OCR receipt endpoint

## OpenAPI security scheme

- `OpenApiConfig`: HTTP bearer JWT scheme `bearerAuth`

---

# PHẦN 13. TESTING

## Backend (Spring Boot)

- `backend/src/test/` — **không có file test**
- `README.md` TODO list ghi: "Unit/Integration test backend" — chưa implement

## Flutter

| File | Loại |
|------|------|
| `frontend/test/widget_test.dart` | Widget test (default Flutter template) |
| `frontend/ios/RunnerTests/RunnerTests.swift` | iOS platform test stub |
| `frontend/macos/RunnerTests/RunnerTests.swift` | macOS platform test stub |

Không có integration test, không có test cho repositories/sync/AI.

## Web (React)

- Không có thư mục `__tests__`, không có vitest/jest config trong `package.json`

## AI Service

- Không có `tests/` directory
- Evaluation scripts (không phải unit test): `eval_model.py`, `eval_receipt_ocr.py`, `audit_classify_dataset.py`

## Manual Test

- `docs/HUONG_DAN_CHAY.md` — hướng dẫn chạy thủ công 3 service
- Swagger UI: `http://localhost:8080/api/swagger-ui.html`
- Demo user: `ai.demo@local.test` / `Demo@123456` (seed khi `SEED_DEMO_USER=true`)

---

# PHẦN 14. KẾT QUẢ THỰC TẾ

Dữ liệu từ artifact và JSON metrics có trong repository.

## 14.1. Transaction Classification

**Nguồn:** `ai_service/models/classify_metrics.json`, `classify_meta.json`  
**Training date:** 2026-05-30T02:28:01.999277+00:00  
**Model weights:** `classify_model.pt` **không có** trong workspace (chỉ metadata)

| Metric | Validation (1200) | Hard Validation (191) |
|--------|-------------------|----------------------|
| Accuracy | 0.9783 | 0.8901 |
| Macro F1 | 0.9783 | 0.9088 |
| Weighted F1 | 0.9783 | 0.8910 |
| Precision (macro) | 0.9787 | 0.9163 |
| Recall (macro) | 0.9783 | 0.9086 |
| Best val acc (checkpoint) | 0.9817 | — |
| Best hard macro F1 (checkpoint) | — | 0.9088 |

**Confidence (val):** mean 0.9445, median 0.9629, 1.0% below 0.45  
**Confidence (hard):** mean 0.8902, median 0.9586, 6.28% below 0.45

**Per-class weakest (val):** Mua sắm 91.7%, Di chuyển 95%, Hóa đơn 95%, Giải trí 95%, Ăn uống 96.7%

**Per-class weakest (hard):** Khác 60%, Ăn uống 75%, Giải trí 75%, Đầu tư 81.8%

**Training samples:** 35.200 augmented (8.800 original × 4), val 1.200, hard val 191

## 14.2. Spending Forecast

**Nguồn:** `ai_service/models/forecast_meta.json`  
**Model weights:** `forecast_model.pt` **có** trong workspace

| Metric | Value |
|--------|-------|
| val_mae_vnd | 4.692 VND |
| val_mape_pct | 1.76% |

**Dataset:** `daily_spending_train.csv` — 1.552 dòng (1.551 ngày + header), range 2021-01-01 → 2025-03-31

**Global stats:**
- mean_log: 12.3033
- median_log: 12.2926
- std_log: 0.3610
- mean_category shares: [0.3696, 0.1642, 0.1928, 0.1385, 0.1349] (food, transport, shopping, bills, other)

## 14.3. OCR Receipt

**Không có file metric kết quả** (CER, WER, exact accuracy) trong `models/` hoặc `data/` workspace.

Code định nghĩa cách tính:
- CER = Levenshtein char edit distance / len(reference)
- WER = word-level Levenshtein / len(reference words)
- Exact match = string equality after strip

OCR model weights (`ocr_*_model.pt`) **không có** trong workspace.

## 14.4. Các metric khác

**Forecast training script (`eval_model.py`) comments:**
- EPOCHS: 300, PATIENCE: 40, BATCH: 32
- Loss: HuberLoss δ=1.0

**Classify training targets (`TRAIN_AUDIT.md`):**
- validation_acc ≥ 0.98 ✓ (đạt 0.9783 — gần target)
- macro_f1 ≥ 0.98 ✓ (đạt 0.9783)
- hard_val_acc ≥ 0.92 ✗ (đạt 0.8901)

---

# PHẦN 15. NHỮNG ĐIỂM ĐẶC BIỆT CỦA DỰ ÁN

So với ứng dụng quản lý chi tiêu thông thường, các điểm sau **tồn tại trong source code**:

## 15.1. AI end-to-end tích hợp sản phẩm

- Phân loại câu tiếng Việt tự nhiên (CharCNN+BiLSTM+Attention, 20 categories) — không chỉ dropdown
- Batch split ("ăn trưa 50k, grab 30k" → 2 transactions)
- OCR hóa đơn (EasyOCR + CRNN dual engine)
- Dự báo chi tiêu 7 ngày (custom Transformer, non-autoregressive)
- Chatbot Gemini + rule fallback với context 45 ngày giao dịch + budgets

## 15.2. Kiến trúc microservice AI tách biệt

- Spring Boot proxy sang FastAPI — backend không embed ML
- Config-driven endpoints (`ai.categorization`, `ai.forecast`, `ai.ocr`, `ai.chat` trong application.yml)
- Health check báo trạng thái load từng model

## 15.3. Hybrid AI + Rules

- `category_hints.py` ~70 regex override trước model
- `classify_ood.py` OOD detection
- `rules.py` fallback khi confidence < 0.45
- `transaction_intent.py` remap income/expense
- Chat rule-based khi không có Gemini key

## 15.4. Offline-first mobile

- Drift SQLite local database
- SyncOutbox pattern (push local changes, pull server state)
- Statistics fallback local aggregation khi offline
- Connectivity-aware sync (`connectivity_plus`)

## 15.5. Đa nền tảng đồng bộ tính năng

- Flutter: Android, iOS, Web, Windows, Linux, macOS
- React web mirror đầy đủ AI features (OCR, Chat, Forecast)
- Cùng backend API, cùng JWT auth flow

## 15.6. UX mascot Natta

- 3 personality HAPPY/SAD/ANGRY ảnh hưởng chatbot response tone
- Robot avatar components trên cả mobile và web
- Onboarding chọn bot personality

## 15.7. Xác thực nâng cao

- Đăng ký 2 bước OTP email (pending_registrations table)
- Quên mật khẩu OTP email (password_reset_tokens)
- Async email sending (@Async) — không block request
- Refresh token 7 ngày + auto-refresh interceptor client

## 15.8. Giao dịch định kỳ tự động

- Scheduler cron hàng ngày
- dayOfMonth 1–28 (tránh ngày 29-31)
- Dedup check — không tạo trùng transaction cho cùng ngày

## 15.9. Dataset và training pipeline tự xây

- Synthetic classify dataset 10K balanced samples
- Hard validation set 191+ samples
- Synthetic daily spending 1.551 ngày (2021-2025)
- Synthetic receipt OCR 8000 bills generator
- Training notebooks + CLI pipelines + grid search

## 15.10. Export báo cáo tiếng Việt

- PDF OpenPDF với font NotoSans Vietnamese
- Excel Apache POI
- Locale vi-VN number formatting

## 15.11. Demo user seed

- Auto seed `ai.demo@local.test` với 45 ngày transaction history
- Phục vụ demo forecast + chatbot ngay khi chạy dev

## 15.12. Theme system

- Light / Dark / System trên cả mobile và web
- Persist preferences, system mode theo `prefers-color-scheme`

## 15.13. Tài khoản đồ án tốt nghiệp

- README ghi rõ "Đồ án tốt nghiệp — Natta AI Expense Manager"
- docs/ chứa phân tích thiết kế, báo cáo AI, hướng dẫn chạy

---

## Phụ lục A: Artifact models/ hiện có

| File | Có trong workspace |
|------|-------------------|
| classify_meta.json | ✓ |
| classify_metrics.json | ✓ |
| classify_preprocess.json | ✓ |
| classify_vocab.json | ✓ |
| classify_model.pt | ✗ |
| forecast_model.pt | ✓ |
| forecast_meta.json | ✓ |
| ocr_*_model.pt | ✗ |
| ocr_*_meta.json | ✗ |

## Phụ lục B: Biến môi trường

| Biến | Module | Mặc định |
|------|--------|----------|
| JWT_SECRET | backend | có giá trị dev trong yml |
| PYTHON_AI_API_URL | backend | http://localhost:8000 |
| MAIL_USERNAME | backend | — |
| MAIL_PASSWORD | backend | — |
| PASSWORD_RESET_DEV_LOG_OTP | backend | true |
| SEED_DEMO_USER | backend | true |
| GEMINI_API_KEY | ai_service | — |
| GEMINI_MODEL | ai_service | gemini-1.5-flash |
| VITE_API_BASE_URL | web | /api |
| API_BASE_URL | flutter | http://localhost:8080/api |

## Phụ lục C: TODO trong README (chưa implement)

- Docker compose toàn stack
- CI/CD GitHub Actions
- Unit/Integration test backend
- Biometric login
- Shared wallet / chia hóa đơn

---

*Kết thúc PROJECT KNOWLEDGE BASE. Tài liệu được tổng hợp từ source code tại thời điểm tạo file.*
