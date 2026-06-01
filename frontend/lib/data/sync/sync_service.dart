import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:expense_manager/core/constants/api_constants.dart';
import 'package:expense_manager/data/datasources/api_client.dart';
import 'package:expense_manager/data/datasources/local_storage.dart';
import 'package:expense_manager/data/local/database.dart';

/// Đồng bộ hai chiều: đẩy outbox lên server, sau đó kéo dữ liệu từ server về SQLite.
class SyncService {
  SyncService(this._db, this._api, this._storage);

  final AppDatabase _db;
  final ApiClient _api;
  final LocalStorage _storage;

  bool _running = false;

  static const entityCategory = 'category';
  static const entityWallet = 'wallet';
  static const entityTransaction = 'transaction';
  static const entityBudget = 'budget';
  static const entityRecurring = 'recurring';

  Future<bool> _isOnline() async {
    final r = await Connectivity().checkConnectivity();
    return !r.contains(ConnectivityResult.none);
  }

  bool _isNetworkError(Object e) {
    if (e is DioException) {
      return e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout;
    }
    return false;
  }

  Future<void> syncAllIfOnline() async {
    if (!await _isOnline()) return;
    if (!await _storage.isLoggedIn()) return;
    if (_running) return;
    _running = true;
    try {
      await pushOutbox();
      await pullAll();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      // Nếu token hết hạn / thiếu quyền thì bỏ qua sync để app không crash.
      if (status == 401 || status == 403) return;
      if (!_isNetworkError(e)) rethrow;
    } finally {
      _running = false;
    }
  }

  Future<void> pushOutbox() async {
    while (true) {
      final rows = await (_db.select(_db.syncOutbox)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
      if (rows.isEmpty) break;
      final row = rows.first;
      try {
        await _dispatchOutbox(row);
        await (_db.delete(_db.syncOutbox)..where((o) => o.id.equals(row.id))).go();
      } on DioException catch (e) {
        if (_isNetworkError(e)) return;
        rethrow;
      }
    }
  }

  Future<void> _dispatchOutbox(DbSyncOutbox row) async {
    switch (row.entity) {
      case entityCategory:
        await _pushCategory(row);
        break;
      case entityWallet:
        await _pushWallet(row);
        break;
      case entityTransaction:
        await _pushTransaction(row);
        break;
      case entityBudget:
        await _pushBudget(row);
        break;
      case entityRecurring:
        await _pushRecurring(row);
        break;
      default:
        break;
    }
  }

  Future<void> _pushCategory(DbSyncOutbox row) async {
    final cat = await (_db.select(_db.categories)..where((c) => c.id.equals(row.localId))).getSingleOrNull();
    if (row.op == 'delete') {
      final remote = _remoteIdFromPayload(row.payloadJson) ?? cat?.remoteId;
      if (remote != null) await _api.delete(ApiConstants.categoryById(remote));
      return;
    }
    if (cat == null) return;
    if (cat.remoteId == null) {
      final response = await _api.post(ApiConstants.categories, data: {
        'name': cat.name,
        'description': cat.description,
        'icon': cat.icon,
        'type': cat.type,
      });
      final rid = (response['data'] as Map<String, dynamic>)['id'] as int;
      await (_db.update(_db.categories)..where((c) => c.id.equals(cat.id))).write(
        CategoriesCompanion(remoteId: Value(rid), pendingSync: const Value(false)),
      );
    } else {
      await _api.put(ApiConstants.categoryById(cat.remoteId!), data: {
        'name': cat.name,
        'description': cat.description,
        'icon': cat.icon,
        'type': cat.type,
      });
      await (_db.update(_db.categories)..where((c) => c.id.equals(cat.id))).write(
        const CategoriesCompanion(pendingSync: Value(false)),
      );
    }
  }

  Future<void> _pushWallet(DbSyncOutbox row) async {
    final w = await (_db.select(_db.wallets)..where((x) => x.id.equals(row.localId))).getSingleOrNull();
    if (row.op == 'delete') {
      final remote = _remoteIdFromPayload(row.payloadJson) ?? w?.remoteId;
      if (remote != null) await _api.delete(ApiConstants.walletById(remote));
      return;
    }
    if (w == null) return;
    if (w.remoteId == null) {
      final response = await _api.post(ApiConstants.wallets, data: {
        'name': w.name,
        'currencyCode': w.currencyCode,
        'initialBalance': w.initialBalance,
        'isDefault': w.isDefault,
      });
      final rid = (response['data'] as Map<String, dynamic>)['id'] as int;
      await (_db.update(_db.wallets)..where((x) => x.id.equals(w.id))).write(
        WalletsCompanion(remoteId: Value(rid), pendingSync: const Value(false)),
      );
    } else {
      await _api.put(ApiConstants.walletById(w.remoteId!), data: {
        'name': w.name,
        'currencyCode': w.currencyCode,
        'initialBalance': w.initialBalance,
        'isDefault': w.isDefault,
      });
      await (_db.update(_db.wallets)..where((x) => x.id.equals(w.id))).write(
        const WalletsCompanion(pendingSync: Value(false)),
      );
    }
  }

  Future<void> _pushTransaction(DbSyncOutbox row) async {
    final t = await (_db.select(_db.transactions)..where((x) => x.id.equals(row.localId))).getSingleOrNull();
    if (row.op == 'delete') {
      final remote = _remoteIdFromPayload(row.payloadJson) ?? t?.remoteId;
      if (remote != null) await _api.delete(ApiConstants.transactionById(remote));
      return;
    }
    if (t == null) return;
    final cat = await (_db.select(_db.categories)..where((c) => c.id.equals(t.categoryLocalId))).getSingle();
    final catRemote = cat.remoteId;
    if (catRemote == null) {
      throw StateError('Danh mục chưa đồng bộ');
    }
    int? walletRemote;
    if (t.walletLocalId != null) {
      final wallet = await (_db.select(_db.wallets)..where((w) => w.id.equals(t.walletLocalId!))).getSingleOrNull();
      walletRemote = wallet?.remoteId;
    }
    final body = <String, dynamic>{
      'type': t.type,
      'amount': t.amount,
      'description': t.description,
      'transactionDate': t.transactionDate,
      'categoryId': catRemote,
    };
    if (walletRemote != null) body['walletId'] = walletRemote;

    if (t.remoteId == null) {
      final response = await _api.post(ApiConstants.transactions, data: body);
      final rid = (response['data'] as Map<String, dynamic>)['id'] as int;
      await (_db.update(_db.transactions)..where((x) => x.id.equals(t.id))).write(
        TransactionsCompanion(remoteId: Value(rid), pendingSync: const Value(false)),
      );
    } else {
      await _api.put(ApiConstants.transactionById(t.remoteId!), data: body);
      await (_db.update(_db.transactions)..where((x) => x.id.equals(t.id))).write(
        const TransactionsCompanion(pendingSync: Value(false)),
      );
    }
  }

  Future<void> _pushBudget(DbSyncOutbox row) async {
    final b = await (_db.select(_db.budgets)..where((x) => x.id.equals(row.localId))).getSingleOrNull();
    if (row.op == 'delete') {
      final remote = _remoteIdFromPayload(row.payloadJson) ?? b?.remoteId;
      if (remote != null) await _api.delete(ApiConstants.budgetById(remote));
      return;
    }
    if (b == null) return;
    final cat = await (_db.select(_db.categories)..where((c) => c.id.equals(b.categoryLocalId))).getSingle();
    final catRemote = cat.remoteId;
    if (catRemote == null) throw StateError('Danh mục chưa đồng bộ');
    final body = <String, dynamic>{
      'amount': b.amount,
      'startDate': b.startDate,
      'endDate': b.endDate,
      'categoryId': catRemote,
      'note': b.note,
    };
    if (b.remoteId == null) {
      final response = await _api.post(ApiConstants.budgets, data: body);
      final rid = (response['data'] as Map<String, dynamic>)['id'] as int;
      await (_db.update(_db.budgets)..where((x) => x.id.equals(b.id))).write(
        BudgetsCompanion(remoteId: Value(rid), pendingSync: const Value(false)),
      );
    } else {
      await _api.put(ApiConstants.budgetById(b.remoteId!), data: body);
      await (_db.update(_db.budgets)..where((x) => x.id.equals(b.id))).write(
        const BudgetsCompanion(pendingSync: Value(false)),
      );
    }
  }

  Future<void> _pushRecurring(DbSyncOutbox row) async {
    final r = await (_db.select(_db.recurringTransactions)..where((x) => x.id.equals(row.localId))).getSingleOrNull();
    if (row.op == 'delete') {
      final remote = _remoteIdFromPayload(row.payloadJson) ?? r?.remoteId;
      if (remote != null) await _api.delete(ApiConstants.recurringTransactionById(remote));
      return;
    }
    if (row.op == 'toggle') {
      final remote = _remoteIdFromPayload(row.payloadJson) ?? r?.remoteId;
      if (remote != null) {
        await _api.patch(ApiConstants.recurringTransactionToggle(remote));
      }
      return;
    }
    if (r == null) return;
    final cat = await (_db.select(_db.categories)..where((c) => c.id.equals(r.categoryLocalId))).getSingle();
    final catRemote = cat.remoteId;
    if (catRemote == null) throw StateError('Danh mục chưa đồng bộ');
    final body = <String, dynamic>{
      'type': r.type,
      'amount': r.amount,
      'description': r.description,
      'dayOfMonth': r.dayOfMonth,
      'startDate': r.startDate,
      'categoryId': catRemote,
    };
    if (r.endDate != null) body['endDate'] = r.endDate;
    if (r.remoteId == null) {
      final response = await _api.post(ApiConstants.recurringTransactions, data: body);
      final rid = (response['data'] as Map<String, dynamic>)['id'] as int;
      await (_db.update(_db.recurringTransactions)..where((x) => x.id.equals(r.id))).write(
        RecurringTransactionsCompanion(remoteId: Value(rid), pendingSync: const Value(false)),
      );
    } else {
      await _api.put(ApiConstants.recurringTransactionById(r.remoteId!), data: body);
      await (_db.update(_db.recurringTransactions)..where((x) => x.id.equals(r.id))).write(
        const RecurringTransactionsCompanion(pendingSync: Value(false)),
      );
    }
  }

  int? _remoteIdFromPayload(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final m = jsonDecode(json) as Map<String, dynamic>;
      return m['remoteId'] as int?;
    } catch (_) {
      return null;
    }
  }

  Future<void> pullAll() async {
    await _pullCategories();
    await _pullWallets();
    final transactionIds = await _pullTransactions();
    final budgetIds = await _pullBudgets();
    final recurringIds = await _pullRecurring();
    await _deleteOrphanTransactions(transactionIds);
    await _deleteOrphanBudgets(budgetIds);
    await _deleteOrphanRecurring(recurringIds);
  }

  Future<Set<int>> _pullCategories() async {
    try {
      final response = await _api.get(ApiConstants.categories, params: {'size': 100});
      final data = response['data'] as Map<String, dynamic>;
      final content = data['content'] as List;
      final serverIds = <int>{};
      for (final e in content) {
        final m = e as Map<String, dynamic>;
        final rid = (m['id'] as num).toInt();
        serverIds.add(rid);
        await _upsertCategoryFromServer(m);
      }
      return serverIds;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      // Khi token sai/thiếu quyền (403) hoặc chưa auth (401), bỏ qua sync pull để app không crash.
      if (status == 401 || status == 403) {
        return <int>{};
      }
      rethrow;
    }
  }

  Future<Set<int>> _pullWallets() async {
    try {
      final response = await _api.get(ApiConstants.wallets);
      final list = response['data'] as List;
      final serverIds = <int>{};
      for (final e in list) {
        final m = e as Map<String, dynamic>;
        final rid = (m['id'] as num).toInt();
        serverIds.add(rid);
        await _upsertWalletFromServer(m);
      }

      // Nếu server đã có dữ liệu ví, dọn các ví local "mồ côi" (remoteId = null)
      // đã từng lưu trong máy nhưng không còn/không cần nữa (tránh app hiện 2 ví trong khi web chỉ 1).
      if (serverIds.isNotEmpty) {
        final orphans = await (_db.select(_db.wallets)..where((w) => w.remoteId.isNull())).get();
        for (final w in orphans) {
          // Chỉ xóa nếu không có giao dịch nào đang dùng ví này (an toàn dữ liệu).
          final used = await (_db.select(_db.transactions)..where((t) => t.walletLocalId.equals(w.id))).get();
          if (used.isNotEmpty) continue;

          // Xóa cả outbox liên quan (nếu có) để không bị đồng bộ lại.
          await (_db.delete(_db.syncOutbox)..where((o) => o.entity.equals(entityWallet) & o.localId.equals(w.id))).go();
          await (_db.delete(_db.wallets)..where((x) => x.id.equals(w.id))).go();
        }
      }

      return serverIds;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        return <int>{};
      }
      rethrow;
    }
  }

  Future<Set<int>> _pullTransactions() async {
    final serverIds = <int>{};
    var page = 0;
    const size = 50;
    while (true) {
      final response = await _api.get(ApiConstants.transactions, params: {'page': page, 'size': size});
      final data = response['data'] as Map<String, dynamic>;
      final content = data['content'] as List;
      if (content.isEmpty) break;
      for (final e in content) {
        final m = e as Map<String, dynamic>;
        final rid = (m['id'] as num).toInt();
        serverIds.add(rid);
        await _upsertTransactionFromServer(m);
      }
      final totalPages = data['totalPages'] as int? ?? 1;
      if (page >= totalPages - 1) break;
      page++;
    }
    return serverIds;
  }

  Future<Set<int>> _pullBudgets() async {
    final serverIds = <int>{};
    var page = 0;
    const size = 50;
    while (true) {
      final response = await _api.get(ApiConstants.budgets, params: {'page': page, 'size': size});
      final data = response['data'] as Map<String, dynamic>;
      final content = data['content'] as List;
      if (content.isEmpty) break;
      for (final e in content) {
        final m = e as Map<String, dynamic>;
        final rid = (m['id'] as num).toInt();
        serverIds.add(rid);
        await _upsertBudgetFromServer(m);
      }
      final totalPages = data['totalPages'] as int? ?? 1;
      if (page >= totalPages - 1) break;
      page++;
    }
    return serverIds;
  }

  Future<Set<int>> _pullRecurring() async {
    final response = await _api.get(ApiConstants.recurringTransactions);
    final list = response['data'] as List;
    final serverIds = <int>{};
    for (final e in list) {
      final m = e as Map<String, dynamic>;
      final rid = (m['id'] as num).toInt();
      serverIds.add(rid);
      await _upsertRecurringFromServer(m);
    }
    return serverIds;
  }

  Future<void> _upsertCategoryFromServer(Map<String, dynamic> json) async {
    final rid = (json['id'] as num).toInt();
    final type = (json['type'] as String).toUpperCase();
    final existing = await (_db.select(_db.categories)..where((c) => c.remoteId.equals(rid))).getSingleOrNull();
    if (existing != null) {
      await (_db.update(_db.categories)..where((c) => c.id.equals(existing.id))).write(CategoriesCompanion(
        remoteId: Value(rid),
        name: Value(json['name'] as String),
        description: Value(json['description'] as String?),
        icon: Value(json['icon'] as String?),
        type: Value(type),
        pendingSync: const Value(false),
      ));
    } else {
      await _db.into(_db.categories).insert(CategoriesCompanion.insert(
            remoteId: Value(rid),
            name: json['name'] as String,
            description: Value(json['description'] as String?),
            icon: Value(json['icon'] as String?),
            type: type,
            pendingSync: const Value(false),
          ));
    }
  }

  Future<void> _upsertWalletFromServer(Map<String, dynamic> json) async {
    final rid = (json['id'] as num).toInt();
    final existing = await (_db.select(_db.wallets)..where((w) => w.remoteId.equals(rid))).getSingleOrNull();
    if (existing != null) {
      await (_db.update(_db.wallets)..where((w) => w.id.equals(existing.id))).write(WalletsCompanion(
        remoteId: Value(rid),
        name: Value(json['name'] as String),
        currencyCode: Value(json['currencyCode'] as String? ?? 'VND'),
        initialBalance: Value((json['initialBalance'] as num?)?.toDouble() ?? 0),
        isDefault: Value(json['isDefault'] as bool? ?? false),
        createdAt: Value(json['createdAt'] as String?),
        pendingSync: const Value(false),
      ));
    } else {
      await _db.into(_db.wallets).insert(WalletsCompanion.insert(
            remoteId: Value(rid),
            name: json['name'] as String,
            currencyCode: json['currencyCode'] as String? ?? 'VND',
            initialBalance: (json['initialBalance'] as num?)?.toDouble() ?? 0,
            isDefault: Value(json['isDefault'] as bool? ?? false),
            createdAt: Value(json['createdAt'] as String?),
            pendingSync: const Value(false),
          ));
    }
  }

  Future<void> _upsertTransactionFromServer(Map<String, dynamic> json) async {
    final catJson = json['category'] as Map<String, dynamic>;
    await _upsertCategoryFromServer(catJson);
    final catRid = (catJson['id'] as num).toInt();
    final catRow = await (_db.select(_db.categories)..where((c) => c.remoteId.equals(catRid))).getSingle();

    int? walletLocalId;
    final walletJson = json['wallet'] as Map<String, dynamic>?;
    if (walletJson != null) {
      await _upsertWalletFromServer(walletJson);
      final wid = (walletJson['id'] as num).toInt();
      final wRow = await (_db.select(_db.wallets)..where((w) => w.remoteId.equals(wid))).getSingle();
      walletLocalId = wRow.id;
    }

    final rid = (json['id'] as num).toInt();
    final type = (json['type'] as String).toUpperCase();
    final txDate = (json['transactionDate'] as String).split('T').first;
    final createdAt = json['createdAt'] as String;

    final existing = await (_db.select(_db.transactions)..where((t) => t.remoteId.equals(rid))).getSingleOrNull();
    if (existing != null) {
      await (_db.update(_db.transactions)..where((t) => t.id.equals(existing.id))).write(TransactionsCompanion(
        remoteId: Value(rid),
        type: Value(type),
        amount: Value((json['amount'] as num).toDouble()),
        description: Value(json['description'] as String?),
        transactionDate: Value(txDate),
        categoryLocalId: Value(catRow.id),
        walletLocalId: Value(walletLocalId),
        createdAt: Value(createdAt),
        pendingSync: const Value(false),
      ));
    } else {
      await _db.into(_db.transactions).insert(TransactionsCompanion.insert(
            remoteId: Value(rid),
            type: type,
            amount: (json['amount'] as num).toDouble(),
            description: Value(json['description'] as String?),
            transactionDate: txDate,
            categoryLocalId: catRow.id,
            walletLocalId: walletLocalId != null ? Value(walletLocalId) : const Value.absent(),
            createdAt: createdAt,
            pendingSync: const Value(false),
          ));
    }
  }

  Future<void> _upsertBudgetFromServer(Map<String, dynamic> json) async {
    final catJson = json['category'] as Map<String, dynamic>;
    await _upsertCategoryFromServer(catJson);
    final catRid = (catJson['id'] as num).toInt();
    final catRow = await (_db.select(_db.categories)..where((c) => c.remoteId.equals(catRid))).getSingle();

    final rid = (json['id'] as num).toInt();
    final amount = (json['amount'] as num).toDouble();
    final spent = (json['spentAmount'] as num?)?.toDouble() ?? 0;
    final remaining = (json['remainingAmount'] as num?)?.toDouble() ?? (amount - spent);
    final start = (json['startDate'] as String).split('T').first;
    final end = (json['endDate'] as String).split('T').first;

    final existing = await (_db.select(_db.budgets)..where((b) => b.remoteId.equals(rid))).getSingleOrNull();
    if (existing != null) {
      await (_db.update(_db.budgets)..where((b) => b.id.equals(existing.id))).write(BudgetsCompanion(
        remoteId: Value(rid),
        amount: Value(amount),
        spentAmount: Value(spent),
        remainingAmount: Value(remaining),
        startDate: Value(start),
        endDate: Value(end),
        categoryLocalId: Value(catRow.id),
        note: Value(json['note'] as String?),
        pendingSync: const Value(false),
      ));
    } else {
      await _db.into(_db.budgets).insert(BudgetsCompanion.insert(
            remoteId: Value(rid),
            amount: amount,
            spentAmount: spent,
            remainingAmount: remaining,
            startDate: start,
            endDate: end,
            categoryLocalId: catRow.id,
            note: Value(json['note'] as String?),
            pendingSync: const Value(false),
          ));
    }
  }

  Future<void> _upsertRecurringFromServer(Map<String, dynamic> json) async {
    final catJson = json['category'] as Map<String, dynamic>;
    await _upsertCategoryFromServer(catJson);
    final catRid = (catJson['id'] as num).toInt();
    final catRow = await (_db.select(_db.categories)..where((c) => c.remoteId.equals(catRid))).getSingle();

    final rid = (json['id'] as num).toInt();
    final type = (json['type'] as String).toUpperCase();
    final start = (json['startDate'] as String).split('T').first;
    final endRaw = json['endDate'];
    final end = endRaw != null ? (endRaw as String).split('T').first : null;

    final existing = await (_db.select(_db.recurringTransactions)..where((r) => r.remoteId.equals(rid))).getSingleOrNull();
    if (existing != null) {
      await (_db.update(_db.recurringTransactions)..where((r) => r.id.equals(existing.id))).write(RecurringTransactionsCompanion(
        remoteId: Value(rid),
        type: Value(type),
        amount: Value((json['amount'] as num).toDouble()),
        description: Value(json['description'] as String?),
        dayOfMonth: Value(json['dayOfMonth'] as int),
        startDate: Value(start),
        endDate: Value(end),
        isActive: Value(json['isActive'] as bool? ?? true),
        categoryLocalId: Value(catRow.id),
        pendingSync: const Value(false),
      ));
    } else {
      await _db.into(_db.recurringTransactions).insert(RecurringTransactionsCompanion.insert(
            remoteId: Value(rid),
            type: type,
            amount: (json['amount'] as num).toDouble(),
            description: Value(json['description'] as String?),
            dayOfMonth: json['dayOfMonth'] as int,
            startDate: start,
            endDate: end != null ? Value(end) : const Value.absent(),
            isActive: Value(json['isActive'] as bool? ?? true),
            categoryLocalId: catRow.id,
            pendingSync: const Value(false),
          ));
    }
  }

  Future<void> _deleteOrphanTransactions(Set<int> serverIds) async {
    final rows = await _db.select(_db.transactions).get();
    for (final row in rows) {
      final rid = row.remoteId;
      if (rid != null && !serverIds.contains(rid)) {
        await (_db.delete(_db.transactions)..where((t) => t.id.equals(row.id))).go();
      }
    }
  }

  Future<void> _deleteOrphanBudgets(Set<int> serverIds) async {
    final rows = await _db.select(_db.budgets).get();
    for (final row in rows) {
      final rid = row.remoteId;
      if (rid != null && !serverIds.contains(rid)) {
        await (_db.delete(_db.budgets)..where((b) => b.id.equals(row.id))).go();
      }
    }
  }

  Future<void> _deleteOrphanRecurring(Set<int> serverIds) async {
    final rows = await _db.select(_db.recurringTransactions).get();
    for (final row in rows) {
      final rid = row.remoteId;
      if (rid != null && !serverIds.contains(rid)) {
        await (_db.delete(_db.recurringTransactions)..where((r) => r.id.equals(row.id))).go();
      }
    }
  }
}
