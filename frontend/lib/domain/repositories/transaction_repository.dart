import 'package:expense_manager/domain/models/transaction.dart';
import 'package:expense_manager/domain/models/ai_categorize.dart';
import 'package:expense_manager/domain/models/ai_suggestion.dart';
import 'package:expense_manager/domain/models/ocr_receipt.dart';

class TransactionFilters {
  final String? type;
  final int? categoryId;
  final int? walletId;
  final DateTime? startDate;
  final DateTime? endDate;

  TransactionFilters({this.type, this.categoryId, this.walletId, this.startDate, this.endDate});
}

class PagedTransactions {
  final List<Transaction> items;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;

  PagedTransactions({
    required this.items,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });
}

abstract class TransactionRepository {
  Future<Transaction> create(TransactionCreateData data);
  Future<Transaction> getById(int id);
  Future<PagedTransactions> getAll({int page = 0, int size = 20, TransactionFilters? filters});
  Future<Transaction> update(int id, TransactionCreateData data);
  Future<void> delete(int id);
  Future<AICategorizeResult> aiCategorize(String text, {String? personality});
  Future<List<AICategorizeResult>> aiCategorizeBatch(String text, {String? personality});
  Future<List<AISuggestionItem>> getSuggestions();
  Future<OcrReceiptResult> ocrReceipt({required List<int> bytes, required String filename});
  Future<({String reply, String engine})> askAssistant(String message);
}

class TransactionCreateData {
  final String type;
  final double amount;
  final String? description;
  final DateTime transactionDate;
  final int categoryId;
  final int? walletId;

  TransactionCreateData({
    required this.type,
    required this.amount,
    this.description,
    required this.transactionDate,
    required this.categoryId,
    this.walletId,
  });
}
