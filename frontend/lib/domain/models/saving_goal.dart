class SavingGoal {
  final int id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final String? targetDate;
  final String status;
  final String? note;
  final double remainingAmount;
  final double progressPercent;
  final bool isCompleted;
  final String? completedAt;
  final int? durationDays;
  final double? totalSavedAmount;
  final String? createdAt;
  final String? updatedAt;

  const SavingGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    this.targetDate,
    required this.status,
    this.note,
    required this.remainingAmount,
    required this.progressPercent,
    required this.isCompleted,
    this.completedAt,
    this.durationDays,
    this.totalSavedAmount,
    this.createdAt,
    this.updatedAt,
  });

  factory SavingGoal.fromJson(Map<String, dynamic> json) {
    return SavingGoal(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      targetAmount: (json['targetAmount'] as num?)?.toDouble() ?? 0,
      currentAmount: (json['currentAmount'] as num?)?.toDouble() ?? 0,
      targetDate: json['targetDate'] as String?,
      status: json['status'] as String? ?? 'ACTIVE',
      note: json['note'] as String?,
      remainingAmount: (json['remainingAmount'] as num?)?.toDouble() ?? 0,
      progressPercent: (json['progressPercent'] as num?)?.toDouble() ?? 0,
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedAt: json['completedAt'] as String?,
      durationDays: (json['durationDays'] as num?)?.toInt(),
      totalSavedAmount: (json['totalSavedAmount'] as num?)?.toDouble(),
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }
}

class SpendFromSavingGoalArgs {
  final int id;
  final String name;
  final double amount;

  const SpendFromSavingGoalArgs({
    required this.id,
    required this.name,
    required this.amount,
  });
}

class SavingTransaction {
  final int id;
  final int savingGoalId;
  final double amount;
  final String type;
  final String? note;
  final String createdAt;
  final String? walletName;

  const SavingTransaction({
    required this.id,
    required this.savingGoalId,
    required this.amount,
    required this.type,
    this.note,
    required this.createdAt,
    this.walletName,
  });

  factory SavingTransaction.fromJson(Map<String, dynamic> json) {
    final wallet = json['wallet'] as Map<String, dynamic>?;
    return SavingTransaction(
      id: (json['id'] as num).toInt(),
      savingGoalId: (json['savingGoalId'] as num).toInt(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      type: json['type'] as String? ?? 'DEPOSIT',
      note: json['note'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
      walletName: wallet?['name'] as String?,
    );
  }
}
