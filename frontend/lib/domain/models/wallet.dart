class Wallet {
  final int id;
  final String name;
  final String currencyCode;
  final double initialBalance;
  final bool isDefault;
  final DateTime? createdAt;

  Wallet({
    required this.id,
    required this.name,
    required this.currencyCode,
    required this.initialBalance,
    required this.isDefault,
    this.createdAt,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'] as int,
      name: json['name'] as String,
      currencyCode: json['currencyCode'] as String? ?? 'VND',
      initialBalance: (json['initialBalance'] as num?)?.toDouble() ?? 0,
      isDefault: json['isDefault'] as bool? ?? false,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'currencyCode': currencyCode,
      'initialBalance': initialBalance,
      'isDefault': isDefault,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
