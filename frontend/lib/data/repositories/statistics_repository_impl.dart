import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:expense_manager/core/constants/api_constants.dart';
import 'package:expense_manager/data/datasources/api_client.dart';
import 'package:expense_manager/data/local/database.dart';
import 'package:expense_manager/domain/models/forecast_eligibility.dart';
import 'package:expense_manager/domain/models/spending_forecast.dart';
import 'package:expense_manager/domain/models/statistics.dart';
import 'package:expense_manager/domain/repositories/statistics_repository.dart';

class StatisticsRepositoryImpl implements StatisticsRepository {
  StatisticsRepositoryImpl(this._api, this._db);

  final ApiClient _api;
  final AppDatabase _db;

  Future<bool> _online() async {
    final r = await Connectivity().checkConnectivity();
    return !r.contains(ConnectivityResult.none);
  }

  @override
  Future<Statistics> getByDay({DateTime? date, int? walletId}) async {
    final d = date ?? DateTime.now();
    final dayStr = d.toIso8601String().split('T').first;
    if (await _online()) {
      try {
        final params = <String, dynamic>{'date': dayStr};
        if (walletId != null) params['walletId'] = walletId;
        final response = await _api.get(ApiConstants.statisticsDay, params: params);
        return _parseStatistics(response['data'] as Map<String, dynamic>);
      } on DioException catch (_) {}
    }
    return _localForDay(dayStr, walletId: walletId);
  }

  @override
  Future<Statistics> getByMonth(int year, int month, {String? categoryType, int? walletId}) async {
    if (await _online()) {
      try {
        final params = <String, dynamic>{'year': year, 'month': month};
        if (categoryType != null) params['categoryType'] = categoryType;
        if (walletId != null) params['walletId'] = walletId;
        final response = await _api.get(ApiConstants.statisticsMonth, params: params);
        return _parseStatistics(response['data'] as Map<String, dynamic>);
      } on DioException catch (_) {}
    }
    return _localForMonth(year, month, categoryType: categoryType, walletId: walletId);
  }

  @override
  Future<Statistics> getByYear(int year, {String? categoryType, int? walletId}) async {
    if (await _online()) {
      try {
        final params = <String, dynamic>{'year': year};
        if (categoryType != null) params['categoryType'] = categoryType;
        if (walletId != null) params['walletId'] = walletId;
        final response = await _api.get(ApiConstants.statisticsYear, params: params);
        return _parseStatistics(response['data'] as Map<String, dynamic>);
      } on DioException catch (_) {}
    }
    return _localForYear(year, categoryType: categoryType, walletId: walletId);
  }

  @override
  Future<Statistics> getByDateRange(DateTime startDate, DateTime endDate, {String? categoryType, int? walletId}) async {
    if (await _online()) {
      try {
        final params = <String, dynamic>{
          'startDate': startDate.toIso8601String().split('T')[0],
          'endDate': endDate.toIso8601String().split('T')[0],
        };
        if (categoryType != null) params['categoryType'] = categoryType;
        if (walletId != null) params['walletId'] = walletId;
        final response = await _api.get(ApiConstants.statisticsRange, params: params);
        return _parseStatistics(response['data'] as Map<String, dynamic>);
      } on DioException catch (_) {}
    }
    return _localForRange(
      startDate.toIso8601String().split('T').first,
      endDate.toIso8601String().split('T').first,
      categoryType: categoryType,
      walletId: walletId,
    );
  }

  @override
  Future<ForecastEligibility> getForecastEligibility({int? walletId, DateTime? lastObservationDate}) async {
    if (!await _online()) {
      throw StateError('Cần kết nối mạng để kiểm tra điều kiện dự báo.');
    }
    final params = <String, dynamic>{};
    if (walletId != null) params['walletId'] = walletId;
    if (lastObservationDate != null) {
      params['lastObservationDate'] = lastObservationDate.toIso8601String().split('T').first;
    }
    try {
      final response = await _api.get(ApiConstants.statisticsForecastEligibility, params: params);
      final data = response['data'] as Map<String, dynamic>;
      return ForecastEligibility.fromJson(data);
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response!.data as Map)['message']?.toString()
          : e.message;
      throw StateError(msg ?? 'Kiểm tra điều kiện dự báo thất bại (${e.response?.statusCode}).');
    }
  }

  @override
  Future<SpendingForecast> getSpendingForecast({int? walletId, DateTime? lastObservationDate}) async {
    if (!await _online()) {
      throw StateError('Cần kết nối mạng để dự báo AI.');
    }
    final params = <String, dynamic>{};
    if (walletId != null) params['walletId'] = walletId;
    if (lastObservationDate != null) {
      params['lastObservationDate'] = lastObservationDate.toIso8601String().split('T').first;
    }
    try {
      final response = await _api.get(ApiConstants.statisticsSpendingForecast, params: params);
      final data = response['data'] as Map<String, dynamic>;
      return SpendingForecast.fromJson(data);
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response!.data as Map)['message']?.toString()
          : e.message;
      throw StateError(msg ?? 'Dự báo AI thất bại (${e.response?.statusCode}).');
    }
  }

  @override
  Future<DailyBreakdown> getDailyBreakdown(DateTime startDate, DateTime endDate) async {
    if (await _online()) {
      try {
        final params = <String, dynamic>{
          'startDate': startDate.toIso8601String().split('T')[0],
          'endDate': endDate.toIso8601String().split('T')[0],
        };
        final response = await _api.get(ApiConstants.statisticsDailyBreakdown, params: params);
        final data = response['data'] as Map<String, dynamic>;
        final daysList = data['days'] as List;
        final days = daysList.map((e) => _parseDaySummary(e as Map<String, dynamic>)).toList();
        return DailyBreakdown(days: days);
      } on DioException catch (_) {}
    }
    return _localDailyBreakdown(
      startDate.toIso8601String().split('T').first,
      endDate.toIso8601String().split('T').first,
    );
  }

  DaySummary _parseDaySummary(Map<String, dynamic> json) {
    return DaySummary(
      date: DateTime.parse(json['date'] as String),
      income: (json['income'] as num?)?.toDouble() ?? 0,
      expense: (json['expense'] as num?)?.toDouble() ?? 0,
    );
  }

  Statistics _parseStatistics(Map<String, dynamic> json) {
    final byCategory = (json['byCategory'] as List?)?.map((e) {
      final m = e as Map<String, dynamic>;
      return CategorySummary(
        categoryId: m['categoryId'] as int,
        categoryName: m['categoryName'] as String,
        amount: (m['amount'] as num).toDouble(),
      );
    }).toList() ?? [];

    return Statistics(
      totalIncome: (json['totalIncome'] as num?)?.toDouble() ?? 0,
      totalExpense: (json['totalExpense'] as num?)?.toDouble() ?? 0,
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      byCategory: byCategory,
    );
  }

  Future<int?> _walletLocalId(int? domainId) async {
    if (domainId == null) return null;
    if (domainId < 0) return -domainId;
    final row = await (_db.select(_db.wallets)..where((w) => w.remoteId.equals(domainId))).getSingleOrNull();
    return row?.id;
  }

  Future<List<DbTransaction>> _filteredTransactions({
    String? txType,
    int? walletLocalId,
    String? startDate,
    String? endDate,
  }) async {
    final q = _db.select(_db.transactions);
    if (txType != null) {
      q.where((t) => t.type.equals(txType));
    }
    if (walletLocalId != null) {
      q.where((t) => t.walletLocalId.equals(walletLocalId));
    }
    if (startDate != null) {
      q.where((t) => t.transactionDate.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      q.where((t) => t.transactionDate.isSmallerOrEqualValue(endDate));
    }
    return q.get();
  }

  Future<Statistics> _localForDay(String dayStr, {int? walletId}) async {
    final wl = await _walletLocalId(walletId);
    final rows = await _filteredTransactions(
      startDate: dayStr,
      endDate: dayStr,
      walletLocalId: wl,
    );
    return _aggregate(rows, categoryTypeFilter: null);
  }

  Future<Statistics> _localForMonth(int year, int month, {String? categoryType, int? walletId}) async {
    final start = DateTime(year, month, 1).toIso8601String().split('T').first;
    final end = DateTime(year, month + 1, 0).toIso8601String().split('T').first;
    return _localForRange(start, end, categoryType: categoryType, walletId: walletId);
  }

  Future<Statistics> _localForYear(int year, {String? categoryType, int? walletId}) async {
    final start = DateTime(year, 1, 1).toIso8601String().split('T').first;
    final end = DateTime(year, 12, 31).toIso8601String().split('T').first;
    return _localForRange(start, end, categoryType: categoryType, walletId: walletId);
  }

  Future<Statistics> _localForRange(String start, String end, {String? categoryType, int? walletId}) async {
    final wl = await _walletLocalId(walletId);
    final rows = await _filteredTransactions(
      startDate: start,
      endDate: end,
      walletLocalId: wl,
    );
    return _aggregate(rows, categoryTypeFilter: categoryType);
  }

  Future<Statistics> _aggregate(List<DbTransaction> rows, {String? categoryTypeFilter}) async {
    double income = 0;
    double expense = 0;
    final byCat = <String, Map<String, dynamic>>{};
    for (final t in rows) {
      final cat = await (_db.select(_db.categories)..where((c) => c.id.equals(t.categoryLocalId))).getSingle();
      final catType = cat.type.toUpperCase();
      if (categoryTypeFilter != null && catType != categoryTypeFilter.toUpperCase()) {
        continue;
      }
      final isIncome = t.type.toUpperCase() == 'INCOME';
      if (isIncome) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
      final key = '${cat.id}';
      final domainId = cat.remoteId ?? -cat.id;
      byCat[key] ??= {'id': domainId, 'name': cat.name, 'amount': 0.0};
      final prev = byCat[key]!['amount'] as double;
      byCat[key]!['amount'] = prev + t.amount;
    }
    final summaries = byCat.values
        .map((m) => CategorySummary(
              categoryId: m['id'] as int,
              categoryName: m['name'] as String,
              amount: m['amount'] as double,
            ))
        .toList();
    return Statistics(
      totalIncome: income,
      totalExpense: expense,
      balance: income - expense,
      byCategory: summaries,
    );
  }

  Future<DailyBreakdown> _localDailyBreakdown(String start, String end) async {
    final rows = await _filteredTransactions(startDate: start, endDate: end);
    final byDay = <String, List<DbTransaction>>{};
    for (final t in rows) {
      final d = t.transactionDate;
      byDay.putIfAbsent(d, () => []).add(t);
    }
    final keys = byDay.keys.toList()..sort();
    final days = <DaySummary>[];
    for (final k in keys) {
      double income = 0;
      double expense = 0;
      for (final t in byDay[k]!) {
        if (t.type.toUpperCase() == 'INCOME') {
          income += t.amount;
        } else {
          expense += t.amount;
        }
      }
      days.add(DaySummary(
        date: DateTime.parse(k.length > 10 ? k : '${k}T00:00:00'),
        income: income,
        expense: expense,
      ));
    }
    return DailyBreakdown(days: days);
  }
}
