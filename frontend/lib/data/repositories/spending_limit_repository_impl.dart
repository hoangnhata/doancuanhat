import 'package:expense_manager/core/constants/api_constants.dart';
import 'package:expense_manager/data/datasources/api_client.dart';
import 'package:expense_manager/domain/models/spending_limit.dart';
import 'package:expense_manager/domain/repositories/spending_limit_repository.dart';

class SpendingLimitRepositoryImpl implements SpendingLimitRepository {
  SpendingLimitRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<List<SpendingLimit>> getAll() async {
    final response = await _api.get(ApiConstants.spendingLimits, params: {'page': 0, 'size': 100});
    final envelope = response['data'] as Map<String, dynamic>? ?? {};
    final content = envelope['content'] as List<dynamic>? ?? [];
    return content.map((e) => SpendingLimit.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<SpendingLimitAlert>> getAlerts() async {
    final response = await _api.get(ApiConstants.spendingLimitsAlerts);
    final list = response['data'] as List<dynamic>? ?? [];
    return list.map((e) => SpendingLimitAlert.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<SpendingLimit> create({
    required double amount,
    required int categoryId,
    int warningThresholdPercent = 80,
  }) async {
    final response = await _api.post(ApiConstants.spendingLimits, data: {
      'amount': amount,
      'categoryId': categoryId,
      'periodType': 'MONTHLY',
      'warningThresholdPercent': warningThresholdPercent,
      'alertsEnabled': true,
    });
    return SpendingLimit.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<SpendingLimit> update({
    required int id,
    required double amount,
    required int categoryId,
    int warningThresholdPercent = 80,
  }) async {
    final response = await _api.put(ApiConstants.spendingLimitById(id), data: {
      'amount': amount,
      'categoryId': categoryId,
      'periodType': 'MONTHLY',
      'warningThresholdPercent': warningThresholdPercent,
      'alertsEnabled': true,
    });
    return SpendingLimit.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<void> delete(int id) async {
    await _api.delete(ApiConstants.spendingLimitById(id));
  }
}
