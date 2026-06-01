import 'package:equatable/equatable.dart';
import 'package:expense_manager/domain/models/category.dart';
import 'package:expense_manager/domain/models/transaction.dart';

class RecurringTransaction extends Equatable {
  final int id;
  final TransactionType type; // from transaction.dart
  final double amount;
  final String? description;
  final int dayOfMonth;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final Category category;

  const RecurringTransaction({
    required this.id,
    required this.type,
    required this.amount,
    this.description,
    required this.dayOfMonth,
    required this.startDate,
    this.endDate,
    required this.isActive,
    required this.category,
  });

  @override
  List<Object?> get props => [id, type, amount, dayOfMonth];
}
