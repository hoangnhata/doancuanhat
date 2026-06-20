import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_manager/data/datasources/api_client.dart';
import 'package:expense_manager/data/datasources/local_storage.dart';
import 'package:expense_manager/data/local/database.dart';
import 'package:expense_manager/data/repositories/auth_repository_impl.dart';
import 'package:expense_manager/data/repositories/user_repository_impl.dart';
import 'package:expense_manager/data/repositories/transaction_repository_impl.dart';
import 'package:expense_manager/data/repositories/category_repository_impl.dart';
import 'package:expense_manager/data/repositories/budget_repository_impl.dart';
import 'package:expense_manager/data/repositories/statistics_repository_impl.dart';
import 'package:expense_manager/data/repositories/export_repository_impl.dart';
import 'package:expense_manager/data/repositories/recurring_transaction_repository_impl.dart';
import 'package:expense_manager/data/repositories/wallet_repository_impl.dart';
import 'package:expense_manager/data/repositories/saving_goal_repository_impl.dart';
import 'package:expense_manager/data/repositories/spending_limit_repository_impl.dart';
import 'package:expense_manager/domain/repositories/saving_goal_repository.dart';
import 'package:expense_manager/domain/repositories/spending_limit_repository.dart';
import 'package:expense_manager/data/sync/sync_service.dart';
import 'package:expense_manager/domain/repositories/auth_repository.dart';
import 'package:expense_manager/domain/repositories/user_repository.dart';
import 'package:expense_manager/domain/repositories/transaction_repository.dart';
import 'package:expense_manager/domain/repositories/category_repository.dart';
import 'package:expense_manager/domain/repositories/budget_repository.dart';
import 'package:expense_manager/domain/repositories/statistics_repository.dart';
import 'package:expense_manager/domain/repositories/recurring_transaction_repository.dart';
import 'package:expense_manager/domain/repositories/wallet_repository.dart';
import 'package:expense_manager/core/constants/api_constants.dart';

ApiClient? _apiClient;
LocalStorage? _localStorage;
AppDatabase? _appDatabase;
SyncService? _syncService;

Future<void> initDependencies() async {
  final prefs = await SharedPreferences.getInstance();
  _localStorage = LocalStorage(prefs);

  _apiClient = ApiClient(
    Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      // Fail-fast để app không "đơ" lâu khi API không reachable.
      connectTimeout: const Duration(seconds: 8),
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    )),
    _localStorage!,
  );

  _appDatabase = AppDatabase();
  _syncService = SyncService(_appDatabase!, _apiClient!, _localStorage!);
}

ApiClient get apiClient => _apiClient!;
LocalStorage get localStorage => _localStorage!;
AppDatabase get appDatabase => _appDatabase!;
SyncService get syncService => _syncService!;

AuthRepository get authRepository => AuthRepositoryImpl(apiClient, localStorage, appDatabase);
UserRepository get userRepository => UserRepositoryImpl(apiClient, localStorage);
TransactionRepository get transactionRepository => TransactionRepositoryImpl(appDatabase, apiClient, syncService);
CategoryRepository get categoryRepository => CategoryRepositoryImpl(appDatabase, apiClient, syncService);
BudgetRepository get budgetRepository => BudgetRepositoryImpl(appDatabase, apiClient, syncService);
StatisticsRepository get statisticsRepository => StatisticsRepositoryImpl(apiClient, appDatabase);
ExportRepository get exportRepository => ExportRepository(apiClient);
RecurringTransactionRepository get recurringTransactionRepository =>
    RecurringTransactionRepositoryImpl(appDatabase, apiClient, syncService);
WalletRepository get walletRepository => WalletRepositoryImpl(appDatabase, apiClient, syncService);
SavingGoalRepository get savingGoalRepository => SavingGoalRepositoryImpl(apiClient);
SpendingLimitRepository get spendingLimitRepository => SpendingLimitRepositoryImpl(apiClient);
