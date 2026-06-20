import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:expense_manager/core/constants/api_constants.dart';
import 'package:expense_manager/data/datasources/api_client.dart';
import 'package:expense_manager/data/local/database.dart';
import 'package:expense_manager/data/local/database_extensions.dart';
import 'package:expense_manager/data/sync/sync_service.dart';
import 'package:expense_manager/domain/models/wallet.dart';
import 'package:expense_manager/domain/repositories/wallet_repository.dart';

class WalletRepositoryImpl implements WalletRepository {
  WalletRepositoryImpl(this._db, this._api, this._sync);

  final AppDatabase _db;
  final ApiClient _api;
  final SyncService _sync;

  Wallet _map(DbWallet w, {double? currentBalance}) {
    return Wallet(
      id: w.remoteId ?? -w.id,
      name: w.name,
      currencyCode: w.currencyCode,
      initialBalance: w.initialBalance,
      currentBalance: currentBalance,
      isDefault: w.isDefault,
      createdAt: w.createdAt != null ? DateTime.tryParse(w.createdAt!) : null,
    );
  }

  Future<Map<int, double>> _fetchRemoteBalances() async {
    try {
      final response = await _api.get(ApiConstants.wallets);
      final list = response['data'] as List;
      final balances = <int, double>{};
      for (final item in list) {
        final m = item as Map<String, dynamic>;
        final id = (m['id'] as num).toInt();
        if (m['currentBalance'] != null) {
          balances[id] = (m['currentBalance'] as num).toDouble();
        }
      }
      return balances;
    } catch (_) {
      return {};
    }
  }

  Future<double> _computeLocalBalance(DbWallet wallet) async {
    final defaultWallet = await (_db.select(_db.wallets)..where((w) => w.isDefault.equals(true))).getSingleOrNull();
    final includeLegacy = defaultWallet?.id == wallet.id;

    final q = _db.select(_db.transactions);
    if (includeLegacy) {
      q.where((t) => t.walletLocalId.equals(wallet.id) | t.walletLocalId.isNull());
    } else {
      q.where((t) => t.walletLocalId.equals(wallet.id));
    }
    final rows = await q.get();

    var income = 0.0;
    var expense = 0.0;
    for (final t in rows) {
      if (t.type.toUpperCase() == 'INCOME') {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    return wallet.initialBalance + income - expense;
  }

  Future<double> _pendingNetChange(DbWallet wallet) async {
    final defaultWallet = await (_db.select(_db.wallets)..where((w) => w.isDefault.equals(true))).getSingleOrNull();
    final includeLegacy = defaultWallet?.id == wallet.id;

    final q = _db.select(_db.transactions)..where((t) => t.pendingSync.equals(true));
    if (includeLegacy) {
      q.where((t) => t.walletLocalId.equals(wallet.id) | t.walletLocalId.isNull());
    } else {
      q.where((t) => t.walletLocalId.equals(wallet.id));
    }
    final rows = await q.get();

    var income = 0.0;
    var expense = 0.0;
    for (final t in rows) {
      if (t.type.toUpperCase() == 'INCOME') {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    return income - expense;
  }

  Future<double?> _resolveBalance(DbWallet wallet, Map<int, double> remoteBalances) async {
    if (wallet.remoteId == null) {
      return _computeLocalBalance(wallet);
    }

    final remote = remoteBalances[wallet.remoteId];
    if (remote == null) {
      return _computeLocalBalance(wallet);
    }

    // Cùng nguồn với web: số dư server + giao dịch chưa đồng bộ (offline).
    final pendingDelta = await _pendingNetChange(wallet);
    return remote + pendingDelta;
  }

  Future<List<Wallet>> _mapWallets(List<DbWallet> rows, Map<int, double> remoteBalances) async {
    final wallets = <Wallet>[];
    for (final w in rows) {
      final balance = await _resolveBalance(w, remoteBalances);
      wallets.add(_map(w, currentBalance: balance));
    }
    return wallets;
  }

  Future<DbWallet?> _rowByDomainId(int id) async {
    if (id < 0) {
      return (_db.select(_db.wallets)..where((w) => w.id.equals(-id))).getSingleOrNull();
    }
    return (_db.select(_db.wallets)..where((w) => w.remoteId.equals(id))).getSingleOrNull();
  }

  @override
  Future<List<Wallet>> getAll() async {
    final rows = await (_db.select(_db.wallets)..orderBy([(w) => OrderingTerm.asc(w.name)])).get();
    final remoteBalances = await _fetchRemoteBalances();
    return _mapWallets(rows, remoteBalances);
  }

  @override
  Future<Wallet> getById(int id) async {
    final row = await _rowByDomainId(id);
    if (row == null) throw StateError('Không tìm thấy ví');
    final remoteBalances = await _fetchRemoteBalances();
    return _map(row, currentBalance: await _resolveBalance(row, remoteBalances));
  }

  @override
  Future<Wallet> create({
    required String name,
    required String currencyCode,
    required double initialBalance,
    bool isDefault = false,
  }) async {
    final localId = await _db.into(_db.wallets).insert(WalletsCompanion.insert(
          name: name,
          currencyCode: currencyCode,
          initialBalance: initialBalance,
          isDefault: Value(isDefault),
          pendingSync: const Value(true),
        ));
    await _db.enqueueSync(SyncService.entityWallet, 'create', localId);
    await _sync.syncAllIfOnline();
    final row = await (_db.select(_db.wallets)..where((w) => w.id.equals(localId))).getSingle();
    final remoteBalances = await _fetchRemoteBalances();
    return _map(row, currentBalance: await _resolveBalance(row, remoteBalances));
  }

  @override
  Future<Wallet> update(int id, {
    required String name,
    required String currencyCode,
    required double initialBalance,
    bool? isDefault,
  }) async {
    final row = await _rowByDomainId(id);
    if (row == null) {
      final data = <String, dynamic>{
        'name': name,
        'currencyCode': currencyCode,
        'initialBalance': initialBalance,
      };
      if (isDefault != null) data['isDefault'] = isDefault;
      final response = await _api.put(ApiConstants.walletById(id), data: data);
      return Wallet.fromJson(response['data'] as Map<String, dynamic>);
    }
    await (_db.update(_db.wallets)..where((w) => w.id.equals(row.id))).write(WalletsCompanion(
      name: Value(name),
      currencyCode: Value(currencyCode),
      initialBalance: Value(initialBalance),
      isDefault: isDefault != null ? Value(isDefault) : const Value.absent(),
      pendingSync: const Value(true),
    ));
    await _db.enqueueSync(SyncService.entityWallet, row.remoteId == null ? 'create' : 'update', row.id);
    await _sync.syncAllIfOnline();
    final updated = await (_db.select(_db.wallets)..where((w) => w.id.equals(row.id))).getSingle();
    final remoteBalances = await _fetchRemoteBalances();
    return _map(updated, currentBalance: await _resolveBalance(updated, remoteBalances));
  }

  @override
  Future<void> delete(int id) async {
    final row = await _rowByDomainId(id);
    if (row == null) {
      await _api.delete(ApiConstants.walletById(id));
      return;
    }
    if (row.remoteId == null) {
      await (_db.delete(_db.wallets)..where((w) => w.id.equals(row.id))).go();
      await (_db.delete(_db.syncOutbox)..where((o) => o.entity.equals(SyncService.entityWallet) & o.localId.equals(row.id))).go();
      return;
    }
    await _db.enqueueSync(
      SyncService.entityWallet,
      'delete',
      row.id,
      payloadJson: jsonEncode({'remoteId': row.remoteId}),
    );
    await (_db.delete(_db.wallets)..where((w) => w.id.equals(row.id))).go();
    await _sync.syncAllIfOnline();
  }
}
