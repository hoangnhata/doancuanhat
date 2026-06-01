import 'package:equatable/equatable.dart';
import 'package:expense_manager/domain/models/category.dart';

enum TransactionType { expense, income }

class Transaction extends Equatable {
  final int id;
  final TransactionType type;
  final double amount;
  final String? description;
  final DateTime transactionDate;
  final Category category;
  final int? walletId;
  final DateTime createdAt;

  const Transaction({
    required this.id,
    required this.type,
    required this.amount,
    this.description,
    required this.transactionDate,
    required this.category,
    this.walletId,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, type, amount, transactionDate];
}
