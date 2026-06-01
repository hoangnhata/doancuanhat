import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:expense_manager/core/constants/api_constants.dart';
import 'package:expense_manager/data/datasources/api_client.dart';
import 'package:expense_manager/data/local/database.dart';
import 'package:expense_manager/data/local/database_extensions.dart';
import 'package:expense_manager/data/sync/sync_service.dart';
import 'package:expense_manager/domain/models/budget.dart';
import 'package:expense_manager/domain/models/category.dart';
import 'package:expense_manager/domain/repositories/budget_repository.dart';

class BudgetRepositoryImpl implements BudgetRepository {
  BudgetRepositoryImpl(this._db, this._api, this._sync);

  final AppDatabase _db;
  final ApiClient _api;
  final SyncService _sync;

  Future<int> _categoryLocalId(int domainId) async {
    if (domainId < 0) return -domainId;
    final row = await (_db.select(_db.categories)..where((c) => c.remoteId.equals(domainId))).getSingleOrNull();
    if (row == null) throw StateError('Danh mục không tồn tại');
    return row.id;
  }

  Future<DbBudget?> _rowByDomainId(int id) async {
    if (id < 0) {
      return (_db.select(_db.budgets)..where((b) => b.id.equals(-id))).getSingleOrNull();
    }
    return (_db.select(_db.budgets)..where((b) => b.remoteId.equals(id))).getSingleOrNull();
  }

  Future<Budget> _toDomain(DbBudget b) async {
    final cat = await (_db.select(_db.categories)..where((c) => c.id.equals(b.categoryLocalId))).getSingle();
    return Budget(
      id: b.remoteId ?? -b.id,
      amount: b.amount,
      spentAmount: b.spentAmount,
      remainingAmount: b.remainingAmount,
      startDate: DateTime.parse(b.startDate),
      endDate: DateTime.parse(b.endDate),
      category: Category(
        id: cat.remoteId ?? -cat.id,
        name: cat.name,
        description: cat.description,
        icon: cat.icon,
        type: cat.type.toUpperCase() == 'INCOME' ? CategoryType.income : CategoryType.expense,
      ),
      note: b.note,
    );
  }

  @override
  Future<Budget> create(BudgetCreateData data) async {
    final catLocal = await _categoryLocalId(data.categoryId);
    final sd = data.startDate.toIso8601String().split('T').first;
    final ed = data.endDate.toIso8601String().split('T').first;
    final localId = await _db.into(_db.budgets).insert(BudgetsCompanion.insert(
          amount: data.amount,
          spentAmount: 0,
          remainingAmount: data.amount,
          startDate: sd,
          endDate: ed,
          categoryLocalId: catLocal,
          note: Value(data.note),
          pendingSync: const Value(true),
        ));
    await _db.enqueueSync(SyncService.entityBudget, 'create', localId);
    await _sync.syncAllIfOnline();
    final row = await (_db.select(_db.budgets)..where((b) => b.id.equals(localId))).getSingle();
    return _toDomain(row);
  }

  @override
  Future<Budget> getById(int id) async {
    final row = await _rowByDomainId(id);
    if (row == null) throw StateError('Không tìm thấy ngân sách');
    return _toDomain(row);
  }

  @override
  Future<List<Budget>> getAll({int page = 0, int size = 20}) async {
    final all = await (_db.select(_db.budgets)
          ..orderBy([(b) => OrderingTerm.desc(b.startDate)]))
        .get();
    final total = all.length;
    final start = page * size;
    final end = (start + size) > total ? total : start + size;
    final slice = start < total ? all.sublist(start, end) : <DbBudget>[];
    final out = <Budget>[];
    for (final b in slice) {
      out.add(await _toDomain(b));
    }
    return out;
  }

  @override
  Future<List<Budget>> getActive({DateTime? date}) async {
    final d = date ?? DateTime.now();
    final ds = d.toIso8601String().split('T').first;
    final all = await _db.select(_db.budgets).get();
    final filtered = all.where((b) {
      final s = b.startDate;
      final e = b.endDate;
      return s.compareTo(ds) <= 0 && e.compareTo(ds) >= 0;
    }).toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    final out = <Budget>[];
    for (final b in filtered) {
      out.add(await _toDomain(b));
    }
    return out;
  }

  @override
  Future<Budget> update(int id, BudgetCreateData data) async {
    final row = await _rowByDomainId(id);
    if (row == null) {
      final response = await _api.put(ApiConstants.budgetById(id), data: {
        'amount': data.amount,
        'startDate': data.startDate.toIso8601String().split('T')[0],
        'endDate': data.endDate.toIso8601String().split('T')[0],
        'categoryId': data.categoryId,
        'note': data.note,
      });
      return _parseBudget(response['data'] as Map<String, dynamic>);
    }
    final catLocal = await _categoryLocalId(data.categoryId);
    final sd = data.startDate.toIso8601String().split('T').first;
    final ed = data.endDate.toIso8601String().split('T').first;
    await (_db.update(_db.budgets)..where((b) => b.id.equals(row.id))).write(BudgetsCompanion(
      amount: Value(data.amount),
      spentAmount: Value(row.spentAmount),
      remainingAmount: Value(data.amount - row.spentAmount),
      startDate: Value(sd),
      endDate: Value(ed),
      categoryLocalId: Value(catLocal),
      note: Value(data.note),
      pendingSync: const Value(true),
    ));
    await _db.enqueueSync(SyncService.entityBudget, row.remoteId == null ? 'create' : 'update', row.id);
    await _sync.syncAllIfOnline();
    final updated = await (_db.select(_db.budgets)..where((b) => b.id.equals(row.id))).getSingle();
    return _toDomain(updated);
  }

  @override
  Future<void> delete(int id) async {
    final row = await _rowByDomainId(id);
    if (row == null) {
      await _api.delete(ApiConstants.budgetById(id));
      return;
    }
    if (row.remoteId == null) {
      await (_db.delete(_db.budgets)..where((b) => b.id.equals(row.id))).go();
      await (_db.delete(_db.syncOutbox)..where((o) => o.entity.equals(SyncService.entityBudget) & o.localId.equals(row.id))).go();
      return;
    }
    await _db.enqueueSync(
      SyncService.entityBudget,
      'delete',
      row.id,
      payloadJson: jsonEncode({'remoteId': row.remoteId}),
    );
    await (_db.delete(_db.budgets)..where((b) => b.id.equals(row.id))).go();
    await _sync.syncAllIfOnline();
  }

  Budget _parseBudget(Map<String, dynamic> json) {
    final categoryJson = json['category'] as Map<String, dynamic>;
    final amount = (json['amount'] as num).toDouble();
    final spent = (json['spentAmount'] as num?)?.toDouble() ?? 0;
    final remaining = (json['remainingAmount'] as num?)?.toDouble() ?? (amount - spent);
    return Budget(
      id: (json['id'] as num).toInt(),
      amount: amount,
      spentAmount: spent,
      remainingAmount: remaining,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      category: Category(
        id: (categoryJson['id'] as num).toInt(),
        name: categoryJson['name'] as String,
        icon: categoryJson['icon'] as String?,
        type: (categoryJson['type'] as String).toLowerCase() == 'income' ? CategoryType.income : CategoryType.expense,
      ),
      note: json['note'] as String?,
    );
  }
}
