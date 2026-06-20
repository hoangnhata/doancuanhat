import 'package:expense_manager/core/router/app_router.dart';
import 'package:expense_manager/domain/models/user.dart';

/// Xác định màn onboarding cần hiển thị khi chưa hoàn tất.
String resolveOnboardingRoute(User? user) {
  if (user == null || user.onboardingCompleted) {
    return AppRouter.main;
  }
  if (!user.walletSetupCompleted) {
    if (user.botSetupCompleted) {
      return AppRouter.onboardingWallet;
    }
    return AppRouter.onboardingBot;
  }
  if (!user.savingGoalSetupCompleted && !user.savingGoalSetupSkipped) {
    return AppRouter.onboardingSavingGoal;
  }
  if (!user.spendingLimitSetupCompleted && !user.spendingLimitSetupSkipped) {
    return AppRouter.onboardingSpendingLimit;
  }
  return AppRouter.main;
}
