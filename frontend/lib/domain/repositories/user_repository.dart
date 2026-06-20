import 'package:expense_manager/domain/models/user.dart';

abstract class UserRepository {
  Future<User> getCurrentUser();
  Future<void> changePassword(String currentPassword, String newPassword);
  Future<User> updateProfile({
    String? fullName,
    String? phone,
    String? botPersonality,
    bool? botSetupCompleted,
    bool? onboardingCompleted,
    bool? walletSetupCompleted,
    bool? savingGoalSetupCompleted,
    bool? savingGoalSetupSkipped,
    bool? spendingLimitSetupCompleted,
    bool? spendingLimitSetupSkipped,
    String? onboardingStep,
    String? walletName,
    String? currencyCode,
    double? initialBalance,
  });
}
