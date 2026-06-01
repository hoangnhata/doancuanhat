import 'package:equatable/equatable.dart';

/// Kết quả OCR hóa đơn từ backend (proxy lên FastAPI AI service).
class OcrReceiptResult extends Equatable {
  final String transactionType; // EXPENSE | INCOME
  final double? amount;
  final DateTime? transactionDate;
  final String? merchant;
  final String? description;
  final String? categoryName;
  final int? categoryId;
  final double? confidence;
  final bool needsReview;
  final String? ocrEngine;

  const OcrReceiptResult({
    required this.transactionType,
    this.amount,
    this.transactionDate,
    this.merchant,
    this.description,
    this.categoryName,
    this.categoryId,
    this.confidence,
    required this.needsReview,
    this.ocrEngine,
  });

  factory OcrReceiptResult.fromJson(Map<String, dynamic> json) {
    DateTime? date;
    final d = json['transactionDate'];
    if (d is String && d.isNotEmpty) {
      try {
        date = DateTime.parse(d.length > 10 ? d : '${d}T00:00:00');
      } catch (_) {}
    }
    return OcrReceiptResult(
      transactionType: (json['transactionType'] as String?)?.toUpperCase() ?? 'EXPENSE',
      amount: (json['amount'] as num?)?.toDouble(),
      transactionDate: date,
      merchant: json['merchant'] as String?,
      description: json['description'] as String?,
      categoryName: json['categoryName'] as String?,
      categoryId: json['categoryId'] as int?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      needsReview: json['needsReview'] as bool? ?? true,
      ocrEngine: json['ocrEngine'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        transactionType,
        amount,
        transactionDate,
        merchant,
        description,
        categoryName,
        categoryId,
        confidence,
        needsReview,
        ocrEngine,
      ];
}
