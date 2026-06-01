import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:expense_manager/core/constants/api_constants.dart';
import 'package:expense_manager/data/datasources/api_client.dart';
import 'package:expense_manager/data/local/database.dart';
import 'package:expense_manager/data/local/database_extensions.dart';
import 'package:expense_manager/data/sync/sync_service.dart';
import 'package:expense_manager/domain/models/category.dart';
import 'package:expense_manager/domain/models/recurring_transaction.dart';
import 'package:expense_manager/domain/models/transaction.dart';
import 'package:expense_manager/domain/repositories/recurring_transaction_repository.dart';

class RecurringTransactionRepositoryImpl implements RecurringTransactionRepository {
  RecurringTransactionRepositoryImpl(this._db, this._api, this._sync);

  final AppDatabase _db;
  final ApiClient _api;
  final SyncService _sync;

  Future<int> _categoryLocalId(int domainId) async {
    if (domainId < 0) return -domainId;
    final row = await (_db.select(_db.categories)..where((c) => c.remoteId.equals(domainId))).getSingleOrNull();
    if (row == null) throw StateError('Danh mục không tồn tại');
    return row.id;
  }

  Future<DbRecurringTransaction?> _rowByDomainId(int id) async {
    if (id < 0) {
      return (_db.select(_db.recurringTransactions)..where((r) => r.id.equals(-id))).getSingleOrNull();
    }
    return (_db.select(_db.recurringTransactions)..where((r) => r.remoteId.equals(id))).getSingleOrNull();
  }

  Future<RecurringTransaction> _toDomain(DbRecurringTransaction r) async {
    final cat = await (_db.select(_db.categories)..where((c) => c.id.equals(r.categoryLocalId))).getSingle();
    return RecurringTransaction(
      id: r.remoteId ?? -r.id,
      type: r.type.toUpperCase() == 'INCOME' ? TransactionType.income : TransactionType.expense,
      amount: r.amount,
      description: r.description,
      dayOfMonth: r.dayOfMonth,
      startDate: DateTime.parse(r.startDate),
      endDate: r.endDate != null ? DateTime.parse(r.endDate!) : null,
      isActive: r.isActive,
      category: Category(
        id: cat.remoteId ?? -cat.id,
        name: cat.name,
        description: cat.description,
        icon: cat.icon,
        type: cat.type.toUpperCase() == 'INCOME' ? CategoryType.income : CategoryType.expense,
      ),
    );
  }

  @override
  Future<List<RecurringTransaction>> getAll() async {
    final rows = await (_db.select(_db.recurringTransactions)
          ..orderBy([(r) => OrderingTerm.desc(r.id)]))
        .get();
    final out = <RecurringTransaction>[];
    for (final r in rows) {
      out.add(await _toDomain(r));
    }
    return out;
  }

  @override
  Future<RecurringTransaction> create(RecurringTransactionCreateData data) async {
    final catLocal = await _categoryLocalId(data.categoryId);
    final sd = data.startDate.toIso8601String().split('T').first;
    final ed = data.endDate?.toIso8601String().split('T').first;
    final localId = await _db.into(_db.recurringTransactions).insert(RecurringTransactionsCompanion.insert(
          type: data.type,
          amount: data.amount,
          description: Value(data.description),
          dayOfMonth: data.dayOfMonth,
          startDate: sd,
          endDate: ed != null ? Value(ed) : const Value.absent(),
          isActive: const Value(true),
          categoryLocalId: catLocal,
          pendingSync: const Value(true),
        ));
    await _db.enqueueSync(SyncService.entityRecurring, 'create', localId);
    await _sync.syncAllIfOnline();
    final row = await (_db.select(_db.recurringTransactions)..where((r) => r.id.equals(localId))).getSingle();
    return _toDomain(row);
  }

  @override
  Future<RecurringTransaction> update(int id, RecurringTransactionCreateData data) async {
    final row = await _rowByDomainId(id);
    if (row == null) {
      final body = <String, dynamic>{
        'type': data.type,
        'amount': data.amount,
        'description': data.description,
        'dayOfMonth': data.dayOfMonth,
        'startDate': data.startDate.toIso8601String().split('T')[0],
        'categoryId': data.categoryId,
      };
      if (data.endDate != null) body['endDate'] = data.endDate!.toIso8601String().split('T')[0];
      final response = await _api.put(ApiConstants.recurringTransactionById(id), data: body);
      return _parse(response['data'] as Map<String, dynamic>);
    }
    final catLocal = await _categoryLocalId(data.categoryId);
    final sd = data.startDate.toIso8601String().split('T').first;
    final ed = data.endDate?.toIso8601String().split('T').first;
    await (_db.update(_db.recurringTransactions)..where((r) => r.id.equals(row.id))).write(RecurringTransactionsCompanion(
      type: Value(data.type),
      amount: Value(data.amount),
      description: Value(data.description),
      dayOfMonth: Value(data.dayOfMonth),
      startDate: Value(sd),
      endDate: ed != null ? Value(ed) : const Value.absent(),
      categoryLocalId: Value(catLocal),
      pendingSync: const Value(true),
    ));
    await _db.enqueueSync(SyncService.entityRecurring, row.remoteId == null ? 'create' : 'update', row.id);
    await _sync.syncAllIfOnline();
    final updated = await (_db.select(_db.recurringTransactions)..where((r) => r.id.equals(row.id))).getSingle();
    return _toDomain(updated);
  }

  @override
  Future<void> delete(int id) async {
    final row = await _rowByDomainId(id);
    if (row == null) {
      await _api.delete(ApiConstants.recurringTransactionById(id));
      return;
    }
    if (row.remoteId == null) {
      await (_db.delete(_db.recurringTransactions)..where((r) => r.id.equals(row.id))).go();
      await (_db.delete(_db.syncOutbox)..where((o) => o.entity.equals(SyncService.entityRecurring) & o.localId.equals(row.id))).go();
      return;
    }
    await _db.enqueueSync(
      SyncService.entityRecurring,
      'delete',
      row.id,
      payloadJson: jsonEncode({'remoteId': row.remoteId}),
    );
    await (_db.delete(_db.recurringTransactions)..where((r) => r.id.equals(row.id))).go();
    await _sync.syncAllIfOnline();
  }

  @override
  Future<RecurringTransaction> toggleActive(int id) async {
    final row = await _rowByDomainId(id);
    if (row == null) {
      final response = await _api.patch(ApiConstants.recurringTransactionToggle(id));
      return _parse(response['data'] as Map<String, dynamic>);
    }
    if (row.remoteId == null) {
      await (_db.update(_db.recurringTransactions)..where((r) => r.id.equals(row.id))).write(
        RecurringTransactionsCompanion(isActive: Value(!row.isActive)),
      );
      return _toDomain(await (_db.select(_db.recurringTransactions)..where((r) => r.id.equals(row.id))).getSingle());
    }
    await (_db.update(_db.recurringTransactions)..where((r) => r.id.equals(row.id))).write(
      RecurringTransactionsCompanion(
        isActive: Value(!row.isActive),
        pendingSync: const Value(true),
      ),
    );
    await _db.enqueueSync(
      SyncService.entityRecurring,
      'toggle',
      row.id,
      payloadJson: jsonEncode({'remoteId': row.remoteId}),
    );
    await _sync.syncAllIfOnline();
    return _toDomain(await (_db.select(_db.recurringTransactions)..where((r) => r.id.equals(row.id))).getSingle());
  }

  RecurringTransaction _parse(Map<String, dynamic> json) {
    final categoryJson = json['category'] as Map<String, dynamic>;
    return RecurringTransaction(
      id: json['id'] as int,
      type: (json['type'] as String).toLowerCase() == 'income' ? TransactionType.income : TransactionType.expense,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String?,
      dayOfMonth: json['dayOfMonth'] as int,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate'] as String) : null,
      isActive: json['isActive'] as bool? ?? true,
      category: Category(
        id: categoryJson['id'] as int,
        name: categoryJson['name'] as String,
        description: categoryJson['description'] as String?,
        icon: categoryJson['icon'] as String?,
        type: (categoryJson['type'] as String).toLowerCase() == 'income' ? CategoryType.income : CategoryType.expense,
      ),
    );
  }
}
