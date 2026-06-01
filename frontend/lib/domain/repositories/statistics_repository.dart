import 'package:expense_manager/domain/models/forecast_eligibility.dart';
import 'package:expense_manager/domain/models/spending_forecast.dart';
import 'package:expense_manager/domain/models/statistics.dart';

abstract class StatisticsRepository {
  Future<Statistics> getByDay({DateTime? date, int? walletId});
  Future<Statistics> getByMonth(int year, int month, {String? categoryType, int? walletId});
  Future<Statistics> getByYear(int year, {String? categoryType, int? walletId});
  Future<Statistics> getByDateRange(DateTime startDate, DateTime endDate, {String? categoryType, int? walletId});
  Future<DailyBreakdown> getDailyBreakdown(DateTime startDate, DateTime endDate);

  /// Đủ ngày có chi trong cửa sổ để gọi dự báo AI hay chưa.
  Future<ForecastEligibility> getForecastEligibility({int? walletId, DateTime? lastObservationDate});

  /// Dự báo chi tiêu 7 ngày tới (backend → ai_service). Cần mạng + Python AI chạy.
  Future<SpendingForecast> getSpendingForecast({int? walletId, DateTime? lastObservationDate});
}
