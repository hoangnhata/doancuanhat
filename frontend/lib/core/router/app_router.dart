import 'package:flutter/material.dart';
import 'package:expense_manager/presentation/screens/splash_screen.dart';
import 'package:expense_manager/presentation/screens/onboarding/welcome_screen.dart';
import 'package:expense_manager/presentation/screens/onboarding/onboarding_bot_screen.dart';
import 'package:expense_manager/presentation/screens/onboarding/onboarding_wallet_screen.dart';
import 'package:expense_manager/presentation/screens/onboarding/onboarding_saving_goal_screen.dart';
import 'package:expense_manager/presentation/screens/onboarding/onboarding_spending_limit_screen.dart';
import 'package:expense_manager/presentation/screens/saving_goals/saving_goals_screen.dart';
import 'package:expense_manager/presentation/screens/auth/login_screen.dart';
import 'package:expense_manager/presentation/screens/auth/register_screen.dart';
import 'package:expense_manager/presentation/screens/auth/verify_registration_screen.dart';
import 'package:expense_manager/presentation/screens/auth/forgot_password_screen.dart';
import 'package:expense_manager/presentation/screens/auth/reset_password_screen.dart';
import 'package:expense_manager/presentation/screens/main/main_screen.dart';
import 'package:expense_manager/domain/models/transaction.dart';
import 'package:expense_manager/domain/models/saving_goal.dart';
import 'package:expense_manager/presentation/screens/transaction/add_transaction_screen.dart';
import 'package:expense_manager/presentation/screens/category/category_screen.dart';
import 'package:expense_manager/presentation/screens/budget/budget_screen.dart';
import 'package:expense_manager/presentation/screens/analytics/analytics_screen.dart';
import 'package:expense_manager/presentation/screens/forecast/spending_forecast_screen.dart';
import 'package:expense_manager/presentation/screens/recurring/recurring_screen.dart';
import 'package:expense_manager/presentation/screens/wallet/wallets_screen.dart';
import 'package:expense_manager/presentation/screens/profile/profile_screen.dart';

class AppRouter {
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String onboardingBot = '/onboarding/bot';
  static const String onboardingWallet = '/onboarding/wallet';
  static const String onboardingSavingGoal = '/onboarding/saving-goal';
  static const String onboardingSpendingLimit = '/onboarding/spending-limit';
  static const String login = '/login';
  static const String register = '/register';
  static const String verifyRegistration = '/register/verify';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String main = '/main';
  static const String addTransaction = '/add-transaction';
  static const String categories = '/categories';
  static const String budget = '/budget';
  static const String analytics = '/analytics';
  static const String spendingForecast = '/spending-forecast';
  static const String recurring = '/recurring';
  static const String wallets = '/wallets';
  static const String savingGoals = '/saving-goals';
  static const String profile = '/profile';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        // Không dùng fade: FadeTransition(opacity: animation) bắt đầu từ 0 → màn đen tới khi animation chạy (trên emulator hay bị trễ/skipped frames).
        return _instantRoute(const SplashScreen(), splash);
      case welcome:
        return _slideRoute(const WelcomeScreen(), welcome);
      case onboardingBot:
        return _slideRoute(const OnboardingBotScreen(), onboardingBot);
      case onboardingWallet:
        return _slideRoute(const OnboardingWalletScreen(), onboardingWallet);
      case onboardingSavingGoal:
        return _slideRoute(const OnboardingSavingGoalScreen(), onboardingSavingGoal);
      case onboardingSpendingLimit:
        return _slideRoute(const OnboardingSpendingLimitScreen(), onboardingSpendingLimit);
      case login:
        return _slideRoute(const LoginScreen(), login);
      case register:
        return _slideRoute(const RegisterScreen(), register);
      case verifyRegistration:
        final email = settings.arguments is String ? settings.arguments as String : '';
        return _slideRoute(VerifyRegistrationScreen(email: email), verifyRegistration);
      case forgotPassword:
        final email = settings.arguments is String ? settings.arguments as String : null;
        return _slideRoute(ForgotPasswordScreen(initialEmail: email), forgotPassword);
      case resetPassword:
        final email = settings.arguments is String ? settings.arguments as String : null;
        return _slideRoute(ResetPasswordScreen(initialEmail: email), resetPassword);
      case main:
        return _fadeRoute(const MainScreen(), main);
      case addTransaction:
        final args = settings.arguments;
        return _slideRoute(
          AddTransactionScreen(
            transactionToEdit: args is Transaction ? args : null,
            spendFromGoal: args is SpendFromSavingGoalArgs ? args : null,
          ),
          addTransaction,
        );
      case categories:
        return _slideRoute(const CategoryScreen(), categories);
      case budget:
        return _slideRoute(const BudgetScreen(), budget);
      case analytics:
        return _slideRoute(const AnalyticsScreen(), analytics);
      case spendingForecast:
        return _slideRoute(const SpendingForecastScreen(), spendingForecast);
      case recurring:
        return _slideRoute(const RecurringScreen(), recurring);
      case wallets:
        return _slideRoute(const WalletsScreen(), wallets);
      case savingGoals:
        return _slideRoute(const SavingGoalsScreen(), savingGoals);
      case profile:
        return _slideRoute(const ProfileScreen(), profile);
      default:
        return _instantRoute(const SplashScreen(), splash);
    }
  }

  /// Route đầu không transition — tránh frame đầu opacity = 0 (màn đen).
  static PageRouteBuilder _instantRoute(Widget page, String name) {
    return PageRouteBuilder(
      settings: RouteSettings(name: name),
      pageBuilder: (_, __, ___) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  static MaterialPageRoute<void> _fadeRoute(Widget page, String name) {
    return MaterialPageRoute<void>(
      settings: RouteSettings(name: name),
      builder: (_) => page,
    );
  }

  /// MaterialPageRoute: transition chuẩn Android, không để nội dung bắt đầu ngoài màn (Offset 1,0) —
  /// khi emulator bị lỗi Choreographer/vsync, SlideTransition có thể kẹt ở frame đầu → màn đen.
  static MaterialPageRoute<void> _slideRoute(Widget page, String name) {
    return MaterialPageRoute<void>(
      settings: RouteSettings(name: name),
      builder: (_) => page,
    );
  }
}
