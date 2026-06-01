import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:expense_manager/core/constants/api_constants.dart';
import 'package:expense_manager/data/datasources/api_client.dart';
import 'package:expense_manager/data/local/database.dart';
import 'package:expense_manager/data/local/database_extensions.dart';
import 'package:expense_manager/data/sync/sync_service.dart';
import 'package:expense_manager/domain/models/category.dart';
import 'package:expense_manager/domain/repositories/category_repository.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  CategoryRepositoryImpl(this._db, this._api, this._sync);

  final AppDatabase _db;
  final ApiClient _api;
  final SyncService _sync;

  Category _map(DbCategory c) {
    return Category(
      id: c.remoteId ?? -c.id,
      name: c.name,
      description: c.description,
      icon: c.icon,
      type: c.type.toUpperCase() == 'INCOME' ? CategoryType.income : CategoryType.expense,
    );
  }

  Future<DbCategory?> _rowByDomainId(int id) async {
    if (id < 0) {
      return (_db.select(_db.categories)..where((c) => c.id.equals(-id))).getSingleOrNull();
    }
    return (_db.select(_db.categories)..where((c) => c.remoteId.equals(id))).getSingleOrNull();
  }

  @override
  Future<Category> create(CategoryCreateData data) async {
    final localId = await _db.into(_db.categories).insert(CategoriesCompanion.insert(
          name: data.name,
          description: Value(data.description),
          icon: Value(data.icon),
          type: data.type,
          pendingSync: const Value(true),
        ));
    await _db.enqueueSync(SyncService.entityCategory, 'create', localId);
    await _sync.syncAllIfOnline();
    final row = await (_db.select(_db.categories)..where((c) => c.id.equals(localId))).getSingle();
    return _map(row);
  }

  @override
  Future<Category> getById(int id) async {
    final row = await _rowByDomainId(id);
    if (row == null) throw StateError('Không tìm thấy danh mục');
    return _map(row);
  }

  @override
  Future<List<Category>> getAll({String? type}) async {
    var q = _db.select(_db.categories);
    if (type != null) {
      q = q..where((c) => c.type.equals(type));
    }
    final rows = await (q..orderBy([(c) => OrderingTerm.asc(c.name)])).get();
    return rows.map(_map).toList();
  }

  @override
  Future<Category> update(int id, CategoryCreateData data) async {
    final row = await _rowByDomainId(id);
    if (row == null) {
      final response = await _api.put(ApiConstants.categoryById(id), data: {
        'name': data.name,
        'description': data.description,
        'icon': data.icon,
        'type': data.type,
      });
      final m = response['data'] as Map<String, dynamic>;
      return Category(
        id: m['id'] as int,
        name: m['name'] as String,
        description: m['description'] as String?,
        icon: m['icon'] as String?,
        type: (m['type'] as String).toLowerCase() == 'income' ? CategoryType.income : CategoryType.expense,
      );
    }
    await (_db.update(_db.categories)..where((c) => c.id.equals(row.id))).write(CategoriesCompanion(
      name: Value(data.name),
      description: Value(data.description),
      icon: Value(data.icon),
      type: Value(data.type),
      pendingSync: const Value(true),
    ));
    await _db.enqueueSync(SyncService.entityCategory, row.remoteId == null ? 'create' : 'update', row.id);
    await _sync.syncAllIfOnline();
    final updated = await (_db.select(_db.categories)..where((c) => c.id.equals(row.id))).getSingle();
    return _map(updated);
  }

  @override
  Future<void> delete(int id) async {
    final row = await _rowByDomainId(id);
    if (row == null) {
      await _api.delete(ApiConstants.categoryById(id));
      return;
    }
    if (row.remoteId == null) {
      await (_db.delete(_db.categories)..where((c) => c.id.equals(row.id))).go();
      await (_db.delete(_db.syncOutbox)..where((o) => o.entity.equals(SyncService.entityCategory) & o.localId.equals(row.id))).go();
      return;
    }
    await _db.enqueueSync(
      SyncService.entityCategory,
      'delete',
      row.id,
      payloadJson: jsonEncode({'remoteId': row.remoteId}),
    );
    await (_db.delete(_db.categories)..where((c) => c.id.equals(row.id))).go();
    await _sync.syncAllIfOnline();
  }
}
