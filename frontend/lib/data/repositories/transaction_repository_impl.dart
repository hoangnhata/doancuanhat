import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:expense_manager/core/constants/api_constants.dart';
import 'package:expense_manager/data/datasources/api_client.dart';
import 'package:expense_manager/data/local/database.dart';
import 'package:expense_manager/data/local/database_extensions.dart';
import 'package:expense_manager/data/sync/sync_service.dart';
import 'package:expense_manager/domain/models/category.dart';
import 'package:expense_manager/core/utils/transaction_text_parse.dart';
import 'package:expense_manager/domain/models/transaction.dart';
import 'package:expense_manager/domain/models/ai_categorize.dart';
import 'package:expense_manager/domain/models/ai_suggestion.dart';
import 'package:expense_manager/domain/models/ocr_receipt.dart';
import 'package:expense_manager/domain/repositories/transaction_repository.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  TransactionRepositoryImpl(this._db, this._api, this._sync);

  final AppDatabase _db;
  final ApiClient _api;
  final SyncService _sync;

  Future<int> _categoryLocalId(int domainId) async {
    if (domainId < 0) return -domainId;
    final row = await (_db.select(_db.categories)..where((c) => c.remoteId.equals(domainId))).getSingleOrNull();
    if (row == null) throw StateError('Danh mục không tồn tại');
    return row.id;
  }

  Future<int?> _walletLocalId(int? domainId) async {
    if (domainId == null) return null;
    if (domainId < 0) return -domainId;
    final row = await (_db.select(_db.wallets)..where((w) => w.remoteId.equals(domainId))).getSingleOrNull();
    return row?.id;
  }

  Future<DbTransaction?> _rowByDomainId(int id) async {
    if (id < 0) {
      return (_db.select(_db.transactions)..where((t) => t.id.equals(-id))).getSingleOrNull();
    }
    return (_db.select(_db.transactions)..where((t) => t.remoteId.equals(id))).getSingleOrNull();
  }

  Future<Transaction> _toDomain(DbTransaction t) async {
    final cat = await (_db.select(_db.categories)..where((c) => c.id.equals(t.categoryLocalId))).getSingle();
    final catDomain = Category(
      id: cat.remoteId ?? -cat.id,
      name: cat.name,
      description: cat.description,
      icon: cat.icon,
      type: cat.type.toUpperCase() == 'INCOME' ? CategoryType.income : CategoryType.expense,
    );
    int? walletDomain;
    if (t.walletLocalId != null) {
      final w = await (_db.select(_db.wallets)..where((x) => x.id.equals(t.walletLocalId!))).getSingleOrNull();
      if (w != null) walletDomain = w.remoteId ?? -w.id;
    }
    return Transaction(
      id: t.remoteId ?? -t.id,
      type: t.type.toUpperCase() == 'INCOME' ? TransactionType.income : TransactionType.expense,
      amount: t.amount,
      description: t.description,
      transactionDate: DateTime.parse(t.transactionDate.length > 10 ? t.transactionDate : '${t.transactionDate}T00:00:00'),
      category: catDomain,
      walletId: walletDomain,
      createdAt: DateTime.parse(t.createdAt),
    );
  }

  @override
  Future<Transaction> create(TransactionCreateData data) async {
    final catLocal = await _categoryLocalId(data.categoryId);
    final walletLocal = await _walletLocalId(data.walletId);
    if (data.walletId != null && walletLocal == null) {
      throw StateError('Ví không tồn tại');
    }
    final txDate = data.transactionDate.toIso8601String().split('T')[0];
    final now = DateTime.now().toUtc().toIso8601String();
    final localId = await _db.into(_db.transactions).insert(TransactionsCompanion.insert(
          type: data.type,
          amount: data.amount,
          description: Value(data.description),
          transactionDate: txDate,
          categoryLocalId: catLocal,
          walletLocalId: walletLocal != null ? Value(walletLocal) : const Value.absent(),
          createdAt: now,
          pendingSync: const Value(true),
        ));
    await _db.enqueueSync(SyncService.entityTransaction, 'create', localId);
    await _sync.syncAllIfOnline();
    final row = await (_db.select(_db.transactions)..where((t) => t.id.equals(localId))).getSingle();
    return _toDomain(row);
  }

  @override
  Future<Transaction> getById(int id) async {
    final row = await _rowByDomainId(id);
    if (row == null) throw StateError('Không tìm thấy giao dịch');
    return _toDomain(row);
  }

  @override
  Future<PagedTransactions> getAll({int page = 0, int size = 20, TransactionFilters? filters}) async {
    final q = _db.select(_db.transactions);
    if (filters?.type != null) {
      q.where((t) => t.type.equals(filters!.type!));
    }
    if (filters?.categoryId != null) {
      final cl = await _categoryLocalId(filters!.categoryId!);
      q.where((t) => t.categoryLocalId.equals(cl));
    }
    if (filters?.walletId != null) {
      final wl = await _walletLocalId(filters!.walletId);
      if (wl == null) {
        return PagedTransactions(items: [], page: page, size: size, totalElements: 0, totalPages: 0);
      }
      q.where((t) => t.walletLocalId.equals(wl));
    }
    var rows = await (q
          ..orderBy([
            (t) => OrderingTerm.desc(t.transactionDate),
            (t) => OrderingTerm.desc(t.id),
          ]))
        .get();

    if (filters?.startDate != null) {
      final s = filters!.startDate!.toIso8601String().split('T').first;
      rows = rows.where((t) => t.transactionDate.compareTo(s) >= 0).toList();
    }
    if (filters?.endDate != null) {
      final e = filters!.endDate!.toIso8601String().split('T').first;
      rows = rows.where((t) => t.transactionDate.compareTo(e) <= 0).toList();
    }

    final total = rows.length;
    final totalPages = total == 0 ? 0 : (total / size).ceil();
    final start = page * size;
    final end = (start + size) > total ? total : start + size;
    final slice = start < total ? rows.sublist(start, end) : <DbTransaction>[];
    final items = <Transaction>[];
    for (final r in slice) {
      items.add(await _toDomain(r));
    }
    return PagedTransactions(
      items: items,
      page: page,
      size: size,
      totalElements: total,
      totalPages: totalPages == 0 ? 1 : totalPages,
    );
  }

  @override
  Future<Transaction> update(int id, TransactionCreateData data) async {
    final row = await _rowByDomainId(id);
    if (row == null) {
      final body = <String, dynamic>{
        'type': data.type,
        'amount': data.amount,
        'description': data.description,
        'transactionDate': data.transactionDate.toIso8601String().split('T')[0],
        'categoryId': data.categoryId,
      };
      if (data.walletId != null) body['walletId'] = data.walletId;
      final response = await _api.put(ApiConstants.transactionById(id), data: body);
      return _parseTransaction(response['data'] as Map<String, dynamic>);
    }
    final catLocal = await _categoryLocalId(data.categoryId);
    final walletLocal = await _walletLocalId(data.walletId);
    if (data.walletId != null && walletLocal == null) {
      throw StateError('Ví không tồn tại');
    }
    final txDate = data.transactionDate.toIso8601String().split('T')[0];
    await (_db.update(_db.transactions)..where((t) => t.id.equals(row.id))).write(TransactionsCompanion(
      type: Value(data.type),
      amount: Value(data.amount),
      description: Value(data.description),
      transactionDate: Value(txDate),
      categoryLocalId: Value(catLocal),
      walletLocalId: walletLocal != null ? Value(walletLocal) : const Value.absent(),
      pendingSync: const Value(true),
    ));
    await _db.enqueueSync(SyncService.entityTransaction, row.remoteId == null ? 'create' : 'update', row.id);
    await _sync.syncAllIfOnline();
    final updated = await (_db.select(_db.transactions)..where((t) => t.id.equals(row.id))).getSingle();
    return _toDomain(updated);
  }

  @override
  Future<void> delete(int id) async {
    final row = await _rowByDomainId(id);
    if (row == null) {
      await _api.delete(ApiConstants.transactionById(id));
      return;
    }
    if (row.remoteId == null) {
      await (_db.delete(_db.transactions)..where((t) => t.id.equals(row.id))).go();
      await (_db.delete(_db.syncOutbox)..where((o) => o.entity.equals(SyncService.entityTransaction) & o.localId.equals(row.id))).go();
      return;
    }
    await _db.enqueueSync(
      SyncService.entityTransaction,
      'delete',
      row.id,
      payloadJson: jsonEncode({'remoteId': row.remoteId}),
    );
    await (_db.delete(_db.transactions)..where((t) => t.id.equals(row.id))).go();
    await _sync.syncAllIfOnline();
  }

  @override
  Future<AICategorizeResult> aiCategorize(String text, {String? personality}) async {
    final body = <String, dynamic>{'text': text};
    if (personality != null) body['personality'] = personality;
    final response = await _api.post(ApiConstants.transactionsAiCategorize, data: body);
    final data = response['data'] as Map<String, dynamic>;

    final txType = _inferTxType(
      serverTransactionType: data['transactionType'] as String?,
      categoryName: data['categoryName'] as String?,
    );
    final txDate = _parseAiTransactionDate(data['transactionDate']) ??
        extractDateFromNaturalText(text);

    return AICategorizeResult(
      transactionType: txType,
      categoryName: data['categoryName'] as String,
      categoryId: data['categoryId'] as int?,
      amount: (data['amount'] as num?)?.toDouble(),
      description: data['description'] as String? ?? text,
      transactionDate: txDate,
      suggestedCategoryName: data['suggestedCategoryName'] as String? ?? data['categoryName'] as String,
      rollyResponse: data['rollyResponse'] as String?,
    );
  }

  @override
  Future<List<AICategorizeResult>> aiCategorizeBatch(String text, {String? personality}) async {
    final body = <String, dynamic>{'text': text};
    if (personality != null) body['personality'] = personality;
    final response = await _api.post(ApiConstants.transactionsAiCategorizeBatch, data: body);
    final list = response['data'] as List;
    return list.map((x) {
      final data = x as Map<String, dynamic>;

      final txType = _inferTxType(
        serverTransactionType: data['transactionType'] as String?,
        categoryName: data['categoryName'] as String?,
      );
      return AICategorizeResult(
        transactionType: txType,
        categoryName: data['categoryName'] as String,
        categoryId: data['categoryId'] as int?,
        amount: (data['amount'] as num?)?.toDouble(),
        description: data['description'] as String? ?? text,
        transactionDate: _parseAiTransactionDate(data['transactionDate']) ??
            extractDateFromNaturalText(text),
        suggestedCategoryName: data['suggestedCategoryName'] as String? ?? data['categoryName'] as String,
        rollyResponse: data['rollyResponse'] as String?,
      );
    }).toList();
  }

  static DateTime? _parseAiTransactionDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is List && raw.length >= 3) {
      final y = (raw[0] as num).toInt();
      final m = (raw[1] as num).toInt();
      final d = (raw[2] as num).toInt();
      return DateTime(y, m, d);
    }
    if (raw is Map) {
      final y = raw['year'] ?? raw['Year'];
      final m = raw['month'] ?? raw['Month'] ?? raw['monthValue'];
      final d = raw['day'] ?? raw['Day'] ?? raw['dayOfMonth'];
      if (y != null && m != null && d != null) {
        return DateTime((y as num).toInt(), (m as num).toInt(), (d as num).toInt());
      }
    }
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    final head = s.length >= 10 ? s.substring(0, 10) : s;
    // yyyy-MM-dd — tạo DateTime local, tránh lệch ngày do timezone UTC
    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(head);
    if (iso != null) {
      final y = int.parse(iso.group(1)!);
      final m = int.parse(iso.group(2)!);
      final d = int.parse(iso.group(3)!);
      return DateTime(y, m, d);
    }
    // dd/MM/yyyy fallback
    final vn = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(head);
    if (vn != null) {
      final d = int.parse(vn.group(1)!);
      final m = int.parse(vn.group(2)!);
      final y = int.parse(vn.group(3)!);
      return DateTime(y, m, d);
    }
    try {
      return DateTime.parse(head.contains('T') ? head : '${head}T00:00:00');
    } catch (_) {
      return null;
    }
  }

  static String _inferTxType({required String? serverTransactionType, required String? categoryName}) {
    final server = serverTransactionType?.toUpperCase();
    if (server == 'INCOME' || server == 'EXPENSE') return server!;

    const incomeCats = {
      'LƯƠNG',
      'THƯỞNG',
      'FREELANCE',
      'ĐẦU TƯ',
      'BÁN HÀNG',
      'HOÀN TIỀN',
      'TIỀN LÃI',
      'THU NHẬP KHÁC',
    };

    final cat = (categoryName ?? '').trim().toUpperCase();
    return incomeCats.contains(cat) ? 'INCOME' : 'EXPENSE';
  }

  @override
  Future<OcrReceiptResult> ocrReceipt({required List<int> bytes, required String filename}) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await _api.postMultipart(ApiConstants.transactionsAiOcrReceipt, formData: form);
    return OcrReceiptResult.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<List<AISuggestionItem>> getSuggestions() async {
    final response = await _api.get(ApiConstants.aiSuggestions);
    final data = response['data'] as List;
    return data.map((e) => AISuggestionItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<({String reply, String engine})> askAssistant(String message) async {
    final response = await _api.post(ApiConstants.aiChat, data: {'message': message});
    final data = response['data'] as Map<String, dynamic>;
    return (
      reply: (data['reply'] as String?) ?? 'Không có phản hồi.',
      engine: (data['engine'] as String?) ?? 'unknown',
    );
  }

  Transaction _parseTransaction(Map<String, dynamic> json) {
    final categoryJson = json['category'] as Map<String, dynamic>;
    final walletJson = json['wallet'] as Map<String, dynamic>?;
    return Transaction(
      id: json['id'] as int,
      type: (json['type'] as String).toLowerCase() == 'income' ? TransactionType.income : TransactionType.expense,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String?,
      transactionDate: DateTime.parse(json['transactionDate'] as String),
      category: Category(
        id: categoryJson['id'] as int,
        name: categoryJson['name'] as String,
        icon: categoryJson['icon'] as String?,
        type: (categoryJson['type'] as String).toLowerCase() == 'income' ? CategoryType.income : CategoryType.expense,
      ),
      walletId: walletJson != null ? walletJson['id'] as int? : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
