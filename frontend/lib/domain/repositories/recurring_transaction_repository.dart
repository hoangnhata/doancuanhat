import 'package:expense_manager/domain/models/recurring_transaction.dart';

abstract class RecurringTransactionRepository {
  Future<List<RecurringTransaction>> getAll();
  Future<RecurringTransaction> create(RecurringTransactionCreateData data);
  Future<RecurringTransaction> update(int id, RecurringTransactionCreateData data);
  Future<void> delete(int id);
  Future<RecurringTransaction> toggleActive(int id);
}

class RecurringTransactionCreateData {
  final String type;
  final double amount;
  final String? description;
  final int dayOfMonth;
  final DateTime startDate;
  final DateTime? endDate;
  final int categoryId;

  RecurringTransactionCreateData({
    required this.type,
    required this.amount,
    this.description,
    required this.dayOfMonth,
    required this.startDate,
    this.endDate,
    required this.categoryId,
  });
}
