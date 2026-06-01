# Báo cáo dataset TRƯỚC khi xử lý

- **Tổng dòng:** 10,232
- **Số nhãn:** 20
- **Độ dài text TB:** 26.3 ký tự
- **% text unique:** 98.0%
- **Duplicate row (text+label):** 203
- **Text trùng khác label (conflict):** 1
- **Imbalance ratio (max/min):** 1.08
- **Vocabulary size (ký tự):** 146

## Phân bố label

| Label | Count |
|-------|------:|
| Ăn uống | 522 |
| Di chuyển | 518 |
| Mua sắm | 516 |
| Nhà ở | 511 |
| Hóa đơn | 515 |
| Giải trí | 509 |
| Du lịch | 506 |
| Giáo dục | 508 |
| Sức khỏe | 509 |
| Gia đình | 506 |
| Thú cưng | 502 |
| Quà tặng | 520 |
| Từ thiện | 502 |
| Khác | 509 |
| Lương | 510 |
| Thưởng | 505 |
| Freelance | 509 |
| Đầu tư | 508 |
| Bán hàng | 505 |
| Thu nhập khác | 542 |

## Skeleton lặp nhiều (template risk)

- `thuong du an <AMT>|Thưởng` → **8** lần
- `bonus quy <AMT>|Thưởng` → **7** lần
- `thuong du an xong <AMT>|Thưởng` → **7** lần
- `cty thuong tet <AMT>|Thưởng` → **7** lần
- `xem phim <AMT>|Giải trí` → **7** lần
- `ung ho lu lut <AMT>|Từ thiện` → **6** lần
- `nhan sinh nhat <AMT>|Thu nhập khác` → **6** lần
- `cho ban qua sn <AMT>|Quà tặng` → **6** lần
- `mua cat meo <AMT>|Thú cưng` → **6** lần
- `kpi đat nhan <AMT>|Thưởng` → **6** lần

## Keyword leakage (tỉ lệ mẫu chứa từ “dễ đoán”)

- **Lương:** 27% (510 mẫu)
- **Thưởng:** 52% (505 mẫu)
- **Ăn uống:** 50% (522 mẫu)
- **Di chuyển:** 64% (518 mẫu)
- **Hóa đơn:** 22% (515 mẫu)
- **Quà tặng:** 42% (520 mẫu)
- **Thu nhập khác:** 38% (542 mẫu)