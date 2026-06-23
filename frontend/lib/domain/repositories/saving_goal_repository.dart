import 'package:expense_manager/domain/models/saving_goal.dart';

abstract class SavingGoalRepository {
  Future<List<SavingGoal>> getAll();
  Future<SavingGoal> create({
    required String name,
    required double targetAmount,
    double? initialAmount,
    String? targetDate,
    String? note,
  });
  Future<SavingGoal> update({
    required int id,
    required String name,
    required double targetAmount,
    String? targetDate,
    String? note,
  });
  Future<SavingGoal> deposit({
    required int goalId,
    required int walletId,
    required double amount,
    String? note,
  });
  Future<SavingGoal> withdraw({
    required int goalId,
    required int walletId,
    required double amount,
    String? note,
  });
  Future<List<SavingTransaction>> getTransactions(int goalId);
  Future<void> spendFromGoal({
    required int goalId,
    required int categoryId,
    required int walletId,
    required double amount,
    required String transactionDate,
    String? description,
  });
  Future<void> delete(int id);
}
