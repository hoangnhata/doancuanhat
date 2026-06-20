import 'package:expense_manager/domain/models/category.dart';

enum SpendingLimitStatus { safe, warning, exceeded }

SpendingLimitStatus parseSpendingLimitStatus(String? raw) {
  switch (raw?.toUpperCase()) {
    case 'WARNING':
      return SpendingLimitStatus.warning;
    case 'EXCEEDED':
      return SpendingLimitStatus.exceeded;
    default:
      return SpendingLimitStatus.safe;
  }
}

class SpendingLimit {
  final int id;
  final double limitAmount;
  final double currentSpent;
  final double remainingAmount;
  final double usagePercent;
  final SpendingLimitStatus status;
  final String? statusMessage;
  final int? warningThresholdPercent;
  final String startDate;
  final String endDate;
  final Category? category;

  const SpendingLimit({
    required this.id,
    required this.limitAmount,
    required this.currentSpent,
    required this.remainingAmount,
    required this.usagePercent,
    required this.status,
    this.statusMessage,
    this.warningThresholdPercent,
    required this.startDate,
    required this.endDate,
    this.category,
  });

  factory SpendingLimit.fromJson(Map<String, dynamic> json) {
    final cat = json['category'] as Map<String, dynamic>?;
    return SpendingLimit(
      id: json['id'] as int,
      limitAmount: (json['limitAmount'] ?? json['amount'] as num?)?.toDouble() ?? 0,
      currentSpent: (json['currentSpent'] ?? json['spentAmount'] as num?)?.toDouble() ?? 0,
      remainingAmount: (json['remainingAmount'] as num?)?.toDouble() ?? 0,
      usagePercent: (json['usagePercent'] as num?)?.toDouble() ?? 0,
      status: parseSpendingLimitStatus(json['status'] as String?),
      statusMessage: json['statusMessage'] as String?,
      warningThresholdPercent: json['warningThresholdPercent'] as int?,
      startDate: json['startDate'] as String? ?? '',
      endDate: json['endDate'] as String? ?? '',
      category: cat != null
          ? Category(
              id: cat['id'] as int,
              name: cat['name'] as String,
              icon: cat['icon'] as String?,
              type: CategoryType.expense,
            )
          : null,
    );
  }
}

class SpendingLimitAlert {
  final int limitId;
  final String categoryName;
  final double limitAmount;
  final double currentSpent;
  final double usagePercent;
  final SpendingLimitStatus status;
  final String message;

  const SpendingLimitAlert({
    required this.limitId,
    required this.categoryName,
    required this.limitAmount,
    required this.currentSpent,
    required this.usagePercent,
    required this.status,
    required this.message,
  });

  factory SpendingLimitAlert.fromJson(Map<String, dynamic> json) {
    return SpendingLimitAlert(
      limitId: json['limitId'] as int,
      categoryName: json['categoryName'] as String? ?? '',
      limitAmount: (json['limitAmount'] as num?)?.toDouble() ?? 0,
      currentSpent: (json['currentSpent'] as num?)?.toDouble() ?? 0,
      usagePercent: (json['usagePercent'] as num?)?.toDouble() ?? 0,
      status: parseSpendingLimitStatus(json['status'] as String?),
      message: json['message'] as String? ?? '',
    );
  }
}
