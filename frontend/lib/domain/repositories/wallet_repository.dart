import 'package:expense_manager/domain/models/wallet.dart';

abstract class WalletRepository {
  Future<List<Wallet>> getAll();
  Future<Wallet> getById(int id);
  Future<Wallet> create({
    required String name,
    required String currencyCode,
    required double initialBalance,
    bool isDefault = false,
  });
  Future<Wallet> update(int id, {
    required String name,
    required String currencyCode,
    required double initialBalance,
    bool? isDefault,
  });
  Future<void> delete(int id);
}
