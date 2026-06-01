import 'package:equatable/equatable.dart';
import 'package:expense_manager/domain/models/category.dart';

class Budget extends Equatable {
  final int id;
  final double amount;
  final double spentAmount;
  final double remainingAmount;
  final DateTime startDate;
  final DateTime endDate;
  final Category category;
  final String? note;

  const Budget({
    required this.id,
    required this.amount,
    this.spentAmount = 0,
    this.remainingAmount = 0,
    required this.startDate,
    required this.endDate,
    required this.category,
    this.note,
  });

  /// Tỷ lệ đã dùng (0–∞), >1 nghĩa là vượt ngân sách.
  double get usageRatio => amount > 0 ? spentAmount / amount : 0;

  @override
  List<Object?> get props => [id, amount, spentAmount, startDate, endDate, category];
}
