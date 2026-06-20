import 'package:equatable/equatable.dart';

enum BotPersonality { happy, sad, angry }

class User extends Equatable {
  final int id;
  final String fullName;
  final String email;
  final String? phone;
  final String? botPersonality;
  final bool botSetupCompleted;
  final bool onboardingCompleted;
  final bool walletSetupCompleted;
  final bool savingGoalSetupCompleted;
  final bool savingGoalSetupSkipped;
  final bool spendingLimitSetupCompleted;
  final bool spendingLimitSetupSkipped;
  final String? onboardingStep;
  final String? walletName;
  final String? currencyCode;
  final double? initialBalance;

  const User({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.botPersonality,
    this.botSetupCompleted = false,
    this.onboardingCompleted = false,
    this.walletSetupCompleted = false,
    this.savingGoalSetupCompleted = false,
    this.savingGoalSetupSkipped = false,
    this.spendingLimitSetupCompleted = false,
    this.spendingLimitSetupSkipped = false,
    this.onboardingStep,
    this.walletName,
    this.currencyCode,
    this.initialBalance,
  });

  BotPersonality get personality {
    switch (botPersonality?.toUpperCase()) {
      case 'SAD': return BotPersonality.sad;
      case 'ANGRY': return BotPersonality.angry;
      default: return BotPersonality.happy;
    }
  }

  @override
  List<Object?> get props => [id, fullName, email, phone];
}
