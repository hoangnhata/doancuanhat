/// Trích ngày / tiền từ câu nhập tự nhiên (fallback khi API thiếu field).
DateTime? extractDateFromNaturalText(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;

  final vn = RegExp(
    r'(?:ngày\s+)?(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})\b',
    caseSensitive: false,
  ).firstMatch(t);
  if (vn != null) {
    var d = int.parse(vn.group(1)!);
    var m = int.parse(vn.group(2)!);
    var y = int.parse(vn.group(3)!);
    if (y < 100) y += 2000;
    return DateTime(y, m, d);
  }
  return null;
}
