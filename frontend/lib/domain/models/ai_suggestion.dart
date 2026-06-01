class AISuggestionItem {
  final String categoryName;
  final double amount;
  final String suggestion;
  final int percentPossible;

  AISuggestionItem({
    required this.categoryName,
    required this.amount,
    required this.suggestion,
    required this.percentPossible,
  });

  factory AISuggestionItem.fromJson(Map<String, dynamic> json) {
    return AISuggestionItem(
      categoryName: json['categoryName'] as String,
      amount: (json['amount'] as num).toDouble(),
      suggestion: json['suggestion'] as String,
      percentPossible: json['percentPossible'] as int? ?? 0,
    );
  }
}
