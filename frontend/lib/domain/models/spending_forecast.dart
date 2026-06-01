class ForecastBudgetAlert {
  const ForecastBudgetAlert({
    required this.categoryName,
    required this.budgetAmountVnd,
    required this.spentVnd,
    required this.remainingVnd,
    required this.percentUsed,
    required this.severity,
  });

  final String categoryName;
  final int budgetAmountVnd;
  final int spentVnd;
  final int remainingVnd;
  final int percentUsed;
  final String severity;

  factory ForecastBudgetAlert.fromJson(Map<String, dynamic> json) {
    return ForecastBudgetAlert(
      categoryName: json['categoryName'] as String? ?? '',
      budgetAmountVnd: (json['budgetAmountVnd'] as num?)?.round() ?? 0,
      spentVnd: (json['spentVnd'] as num?)?.round() ?? 0,
      remainingVnd: (json['remainingVnd'] as num?)?.round() ?? 0,
      percentUsed: (json['percentUsed'] as num?)?.round() ?? 0,
      severity: json['severity'] as String? ?? 'OK',
    );
  }
}

class ForecastInsight {
  const ForecastInsight({
    required this.totalNext7DaysVnd,
    required this.avgPerDayVnd,
    required this.baseline7DaysVnd,
    this.paceVsBaselinePercent,
    required this.level,
    required this.headlineVi,
    required this.tipsVi,
    this.expenseMonthToDateVnd,
    this.forecastOverlapSameMonthVnd,
    this.projectedMonthFloorVnd,
    required this.budgetAlerts,
  });

  final int totalNext7DaysVnd;
  final int avgPerDayVnd;
  final int baseline7DaysVnd;
  final int? paceVsBaselinePercent;
  final String level;
  final String headlineVi;
  final List<String> tipsVi;
  final int? expenseMonthToDateVnd;
  final int? forecastOverlapSameMonthVnd;
  final int? projectedMonthFloorVnd;
  final List<ForecastBudgetAlert> budgetAlerts;

  factory ForecastInsight.fromJson(Map<String, dynamic> json) {
    final tipsRaw = json['tipsVi'] as List<dynamic>? ?? [];
    final alertsRaw = json['budgetAlerts'] as List<dynamic>? ?? [];
    return ForecastInsight(
      totalNext7DaysVnd: (json['totalNext7DaysVnd'] as num?)?.round() ?? 0,
      avgPerDayVnd: (json['avgPerDayVnd'] as num?)?.round() ?? 0,
      baseline7DaysVnd: (json['baseline7DaysVnd'] as num?)?.round() ?? 0,
      paceVsBaselinePercent: (json['paceVsBaselinePercent'] as num?)?.round(),
      level: json['level'] as String? ?? 'OK',
      headlineVi: json['headlineVi'] as String? ?? '',
      tipsVi: tipsRaw.map((e) => e.toString()).toList(),
      expenseMonthToDateVnd: (json['expenseMonthToDateVnd'] as num?)?.round(),
      forecastOverlapSameMonthVnd: (json['forecastOverlapSameMonthVnd'] as num?)?.round(),
      projectedMonthFloorVnd: (json['projectedMonthFloorVnd'] as num?)?.round(),
      budgetAlerts: alertsRaw
          .map((e) => ForecastBudgetAlert.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SpendingForecast {
  const SpendingForecast({
    required this.predictedNextDaysVnd,
    required this.horizon,
    required this.window,
    required this.lastObservationDate,
    this.insight,
  });

  final List<int> predictedNextDaysVnd;
  final int horizon;
  final int window;
  final String lastObservationDate;
  final ForecastInsight? insight;

  factory SpendingForecast.fromJson(Map<String, dynamic> json) {
    final raw = json['predictedNextDaysVnd'] as List<dynamic>? ?? [];
    final preds = raw.map((e) => (e as num).round()).toList();
    final insightRaw = json['insight'];
    return SpendingForecast(
      predictedNextDaysVnd: preds,
      horizon: (json['horizon'] as num?)?.toInt() ?? preds.length,
      window: (json['window'] as num?)?.toInt() ?? 30,
      lastObservationDate: json['lastObservationDate'] as String? ?? '',
      insight: insightRaw is Map<String, dynamic> ? ForecastInsight.fromJson(insightRaw) : null,
    );
  }
}
