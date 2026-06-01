/// Điều kiện dùng dự báo chi tiêu AI (khớp backend `ForecastEligibilityResponse`).
class ForecastEligibility {
  const ForecastEligibility({
    required this.eligible,
    required this.requiredDaysWithExpense,
    required this.daysWithExpenseInWindow,
    required this.windowDays,
    this.messageVi,
  });

  final bool eligible;
  final int requiredDaysWithExpense;
  final int daysWithExpenseInWindow;
  final int windowDays;
  final String? messageVi;

  factory ForecastEligibility.fromJson(Map<String, dynamic> json) {
    return ForecastEligibility(
      eligible: json['eligible'] == true,
      requiredDaysWithExpense: (json['requiredDaysWithExpense'] as num?)?.toInt() ?? 4,
      daysWithExpenseInWindow: (json['daysWithExpenseInWindow'] as num?)?.toInt() ?? 0,
      windowDays: (json['windowDays'] as num?)?.toInt() ?? 30,
      messageVi: json['messageVi'] as String?,
    );
  }
}
