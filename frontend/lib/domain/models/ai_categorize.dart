import 'package:equatable/equatable.dart';

class AICategorizeResult extends Equatable {
  final String transactionType; // EXPENSE | INCOME
  final String categoryName;
  final int? categoryId;
  final double? amount;
  final String description;
  final DateTime? transactionDate;
  final String suggestedCategoryName;
  final String? rollyResponse;

  const AICategorizeResult({
    required this.transactionType,
    required this.categoryName,
    this.categoryId,
    this.amount,
    required this.description,
    this.transactionDate,
    required this.suggestedCategoryName,
    this.rollyResponse,
  });

  @override
  List<Object?> get props => [
        transactionType,
        categoryName,
        categoryId,
        amount,
        description,
        transactionDate,
      ];
}
