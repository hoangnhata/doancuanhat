# Báo cáo dataset SAU khi xử lý (production-ready)

- **Tổng dòng:** 10,000
- **Số nhãn:** 20
- **Độ dài text TB:** 26.8 ký tự
- **% text unique:** 100.0%
- **Duplicate row (text+label):** 0
- **Text trùng khác label (conflict):** 0
- **Imbalance ratio (max/min):** 1.00
- **Vocabulary size (ký tự):** 147

## Phân bố label

| Label | Count |
|-------|------:|
| Ăn uống | 500 |
| Di chuyển | 500 |
| Mua sắm | 500 |
| Nhà ở | 500 |
| Hóa đơn | 500 |
| Giải trí | 500 |
| Du lịch | 500 |
| Giáo dục | 500 |
| Sức khỏe | 500 |
| Gia đình | 500 |
| Thú cưng | 500 |
| Quà tặng | 500 |
| Từ thiện | 500 |
| Khác | 500 |
| Lương | 500 |
| Thưởng | 500 |
| Freelance | 500 |
| Đầu tư | 500 |
| Bán hàng | 500 |
| Thu nhập khác | 500 |

## Skeleton lặp nhiều (template risk)

- `thuong du an <AMT>|Thưởng` → **8** lần
- `cty thuong tet <AMT>|Thưởng` → **7** lần
- `bonus quy <AMT>|Thưởng` → **7** lần
- `thuong du an xong <AMT>|Thưởng` → **6** lần
- `kpi đat nhan <AMT>|Thưởng` → **6** lần

## Keyword leakage (tỉ lệ mẫu chứa từ “dễ đoán”)

- **Lương:** 26% (500 mẫu)
- **Thưởng:** 52% (500 mẫu)
- **Ăn uống:** 49% (500 mẫu)
- **Di chuyển:** 64% (500 mẫu)
- **Hóa đơn:** 21% (500 mẫu)
- **Quà tặng:** 41% (500 mẫu)
- **Thu nhập khác:** 40% (500 mẫu)