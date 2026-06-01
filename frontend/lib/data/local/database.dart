import 'package:drift/drift.dart';

import 'database_connection.dart';

part 'database.g.dart';

@DataClassName('DbCategory')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get remoteId => integer().nullable()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get icon => text().nullable()();
  TextColumn get type => text()();
  BoolColumn get pendingSync => boolean().withDefault(const Constant(false))();
}

@DataClassName('DbWallet')
class Wallets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get remoteId => integer().nullable()();
  TextColumn get name => text()();
  TextColumn get currencyCode => text()();
  RealColumn get initialBalance => real()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  TextColumn get createdAt => text().nullable()();
  BoolColumn get pendingSync => boolean().withDefault(const Constant(false))();
}

@DataClassName('DbTransaction')
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get remoteId => integer().nullable()();
  TextColumn get type => text()();
  RealColumn get amount => real()();
  TextColumn get description => text().nullable()();
  TextColumn get transactionDate => text()();
  IntColumn get categoryLocalId => integer().references(Categories, #id)();
  IntColumn get walletLocalId => integer().nullable().references(Wallets, #id)();
  TextColumn get createdAt => text()();
  BoolColumn get pendingSync => boolean().withDefault(const Constant(false))();
}

@DataClassName('DbBudget')
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get remoteId => integer().nullable()();
  RealColumn get amount => real()();
  RealColumn get spentAmount => real()();
  RealColumn get remainingAmount => real()();
  TextColumn get startDate => text()();
  TextColumn get endDate => text()();
  IntColumn get categoryLocalId => integer().references(Categories, #id)();
  TextColumn get note => text().nullable()();
  BoolColumn get pendingSync => boolean().withDefault(const Constant(false))();
}

@DataClassName('DbRecurringTransaction')
class RecurringTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get remoteId => integer().nullable()();
  TextColumn get type => text()();
  RealColumn get amount => real()();
  TextColumn get description => text().nullable()();
  IntColumn get dayOfMonth => integer()();
  TextColumn get startDate => text()();
  TextColumn get endDate => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get categoryLocalId => integer().references(Categories, #id)();
  BoolColumn get pendingSync => boolean().withDefault(const Constant(false))();
}

@DataClassName('DbSyncOutbox')
class SyncOutbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entity => text()();
  TextColumn get op => text()();
  IntColumn get localId => integer()();
  TextColumn get payloadJson => text().nullable()();
}

@DriftDatabase(tables: [Categories, Wallets, Transactions, Budgets, RecurringTransactions, SyncOutbox])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openDatabaseConnection());

  @override
  int get schemaVersion => 1;

  Future<void> clearAllData() async {
    await batch((b) {
      b.deleteAll(transactions);
      b.deleteAll(budgets);
      b.deleteAll(recurringTransactions);
      b.deleteAll(categories);
      b.deleteAll(wallets);
      b.deleteAll(syncOutbox);
    });
  }
}
