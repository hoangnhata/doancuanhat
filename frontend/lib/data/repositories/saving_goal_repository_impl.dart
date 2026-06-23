import 'package:expense_manager/core/constants/api_constants.dart';
import 'package:expense_manager/data/datasources/api_client.dart';
import 'package:expense_manager/domain/models/saving_goal.dart';
import 'package:expense_manager/domain/repositories/saving_goal_repository.dart';

class SavingGoalRepositoryImpl implements SavingGoalRepository {
  SavingGoalRepositoryImpl(this._api);

  final ApiClient _api;

  List<SavingGoal> _parseList(dynamic data) {
    if (data is! List) return [];
    return data.map((e) => SavingGoal.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<SavingGoal>> getAll() async {
    final response = await _api.get(ApiConstants.savingGoals);
    final data = response['data'];
    return _parseList(data);
  }

  @override
  Future<SavingGoal> create({
    required String name,
    required double targetAmount,
    double? initialAmount,
    String? targetDate,
    String? note,
  }) async {
    final response = await _api.post(ApiConstants.savingGoals, data: {
      'name': name,
      'targetAmount': targetAmount,
      if (initialAmount != null) 'initialAmount': initialAmount,
      if (targetDate != null) 'targetDate': targetDate,
      if (note != null) 'note': note,
    });
    return SavingGoal.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<SavingGoal> update({
    required int id,
    required String name,
    required double targetAmount,
    String? targetDate,
    String? note,
  }) async {
    final response = await _api.put(ApiConstants.savingGoalById(id), data: {
      'name': name,
      'targetAmount': targetAmount,
      if (targetDate != null) 'targetDate': targetDate,
      if (note != null) 'note': note,
    });
    return SavingGoal.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<SavingGoal> deposit({
    required int goalId,
    required int walletId,
    required double amount,
    String? note,
  }) async {
    final response = await _api.post(ApiConstants.savingGoalDeposit(goalId), data: {
      'walletId': walletId,
      'amount': amount,
      if (note != null) 'note': note,
    });
    return SavingGoal.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<SavingGoal> withdraw({
    required int goalId,
    required int walletId,
    required double amount,
    String? note,
  }) async {
    final response = await _api.post(ApiConstants.savingGoalWithdraw(goalId), data: {
      'walletId': walletId,
      'amount': amount,
      if (note != null) 'note': note,
    });
    return SavingGoal.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<List<SavingTransaction>> getTransactions(int goalId) async {
    final response = await _api.get(ApiConstants.savingGoalTransactions(goalId));
    final data = response['data'];
    if (data is! List) return [];
    return data.map((e) => SavingTransaction.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> spendFromGoal({
    required int goalId,
    required int categoryId,
    required int walletId,
    required double amount,
    required String transactionDate,
    String? description,
  }) async {
    await _api.post(ApiConstants.savingGoalSpend(goalId), data: {
      'categoryId': categoryId,
      'walletId': walletId,
      'amount': amount,
      'transactionDate': transactionDate,
      if (description != null) 'description': description,
    });
  }

  @override
  Future<void> delete(int id) async {
    await _api.delete(ApiConstants.savingGoalById(id));
  }
}
