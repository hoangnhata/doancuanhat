import 'package:expense_manager/domain/models/budget.dart';

abstract class BudgetRepository {
  Future<Budget> create(BudgetCreateData data);
  Future<Budget> getById(int id);
  Future<List<Budget>> getAll({int page = 0, int size = 20});
  Future<List<Budget>> getActive({DateTime? date});
  Future<Budget> update(int id, BudgetCreateData data);
  Future<void> delete(int id);
}

class BudgetCreateData {
  final double amount;
  final DateTime startDate;
  final DateTime endDate;
  final int categoryId;
  final String? note;

  BudgetCreateData({
    required this.amount,
    required this.startDate,
    required this.endDate,
    required this.categoryId,
    this.note,
  });
}
