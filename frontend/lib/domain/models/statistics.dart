import 'package:equatable/equatable.dart';

class CategorySummary extends Equatable {
  final int categoryId;
  final String categoryName;
  final double amount;

  const CategorySummary({
    required this.categoryId,
    required this.categoryName,
    required this.amount,
  });

  @override
  List<Object?> get props => [categoryId, categoryName, amount];
}

class Statistics extends Equatable {
  final double totalIncome;
  final double totalExpense;
  final double balance;
  final List<CategorySummary> byCategory;

  const Statistics({
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    required this.byCategory,
  });

  @override
  List<Object?> get props => [totalIncome, totalExpense, balance];
}

class DailyBreakdown extends Equatable {
  final List<DaySummary> days;

  const DailyBreakdown({required this.days});

  @override
  List<Object?> get props => [days];
}

class DaySummary extends Equatable {
  final DateTime date;
  final double income;
  final double expense;

  const DaySummary({
    required this.date,
    required this.income,
    required this.expense,
  });

  @override
  List<Object?> get props => [date, income, expense];
}
