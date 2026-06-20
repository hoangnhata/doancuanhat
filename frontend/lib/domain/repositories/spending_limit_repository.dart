import 'package:expense_manager/domain/models/spending_limit.dart';

abstract class SpendingLimitRepository {
  Future<List<SpendingLimit>> getAll();
  Future<List<SpendingLimitAlert>> getAlerts();
  Future<SpendingLimit> create({
    required double amount,
    required int categoryId,
    int warningThresholdPercent,
  });
  Future<SpendingLimit> update({
    required int id,
    required double amount,
    required int categoryId,
    int warningThresholdPercent,
  });
  Future<void> delete(int id);
}
