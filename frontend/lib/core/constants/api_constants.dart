import 'api_host_stub.dart' if (dart.library.io) 'api_host_io.dart';

class ApiConstants {
  /// Theo nền tảng (web vs Android emulator vs còn lại) — xem [resolveApiBaseUrl].
  static String get baseUrl => resolveApiBaseUrl();

  static const String authRegister = '/auth/register';
  static const String authRegisterRequest = '/auth/register/request';
  static const String authRegisterVerify = '/auth/register/verify';
  static const String authRegisterResendOtp = '/auth/register/resend-otp';
  static const String authLogin = '/auth/login';
  static const String authRefresh = '/auth/refresh';
  static const String authForgotPassword = '/auth/forgot-password';
  static const String authResetPassword = '/auth/reset-password';

  static const String usersMe = '/users/me';
  static const String usersMeProfile = '/users/me/profile';
  static const String usersMePassword = '/users/me/password';

  static const String categories = '/categories';
  static String categoryById(int id) => '/categories/$id';
  static const String categoriesByType = '/categories/by-type';

  static const String transactions = '/transactions';
  static String transactionById(int id) => '/transactions/$id';
  static const String transactionsAiCategorize = '/transactions/ai/categorize';
  static const String transactionsAiCategorizeBatch = '/transactions/ai/categorize/batch';
  static const String transactionsAiOcrReceipt = '/transactions/ai/ocr/receipt';

  static const String aiSuggestions = '/ai/suggestions';
  static const String aiChat = '/ai/chat';

  static const String budgets = '/budgets';
  static String budgetById(int id) => '/budgets/$id';
  static const String budgetsActive = '/budgets/active';

  static const String spendingLimits = '/spending-limits';
  static String spendingLimitById(int id) => '/spending-limits/$id';
  static const String spendingLimitsAlerts = '/spending-limits/alerts';
  static const String spendingLimitsCheckTransaction = '/spending-limits/check-transaction';

  static const String statisticsDay = '/statistics/day';
  static const String statisticsMonth = '/statistics/month';
  static const String statisticsYear = '/statistics/year';
  static const String statisticsRange = '/statistics/range';
  static const String statisticsDailyBreakdown = '/statistics/daily-breakdown';
  static const String statisticsSpendingForecast = '/statistics/spending-forecast';
  static const String statisticsForecastEligibility = '/statistics/spending-forecast/eligibility';

  static const String exportTransactions = '/export/transactions';

  static const String wallets = '/wallets';
  static String walletById(int id) => '/wallets/$id';

  static const String savingGoals = '/saving-goals';
  static String savingGoalById(int id) => '/saving-goals/$id';
  static String savingGoalDeposit(int id) => '/saving-goals/$id/deposit';
  static String savingGoalWithdraw(int id) => '/saving-goals/$id/withdraw';
  static String savingGoalSpend(int id) => '/saving-goals/$id/spend';
  static String savingGoalTransactions(int id) => '/saving-goals/$id/transactions';

  static const String recurringTransactions = '/recurring-transactions';
  static String recurringTransactionById(int id) => '/recurring-transactions/$id';
  static String recurringTransactionToggle(int id) => '/recurring-transactions/$id/toggle';
}
