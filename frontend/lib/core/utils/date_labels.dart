const _viMonthNames = [
  '',
  'Tháng Một',
  'Tháng Hai',
  'Tháng Ba',
  'Tháng Tư',
  'Tháng Năm',
  'Tháng Sáu',
  'Tháng Bảy',
  'Tháng Tám',
  'Tháng Chín',
  'Tháng Mười',
  'Tháng Mười một',
  'Tháng Mười hai',
];

/// Hiển thị: "Tháng Sáu 2026"
String formatMonthYearLabel(int year, int month) {
  final name = _viMonthNames[month.clamp(1, 12)];
  return '$name $year';
}

/// Nhãn trong lưới chọn tháng
String formatMonthGridLabel(int month) => _viMonthNames[month.clamp(1, 12)];

int currentYear() => DateTime.now().year;

int currentMonth() => DateTime.now().month;
