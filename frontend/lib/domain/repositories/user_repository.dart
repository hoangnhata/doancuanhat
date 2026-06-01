import 'package:expense_manager/domain/models/user.dart';

abstract class UserRepository {
  Future<User> getCurrentUser();
  Future<void> changePassword(String currentPassword, String newPassword);
  Future<User> updateProfile({
    String? fullName,
    String? phone,
    String? botPersonality,
    bool? onboardingCompleted,
    String? walletName,
    String? currencyCode,
    double? initialBalance,
    double? savingsGoalMonthly,
  });
}
