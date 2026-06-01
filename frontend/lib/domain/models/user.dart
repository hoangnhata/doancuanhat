import 'package:equatable/equatable.dart';

enum BotPersonality { happy, sad, angry }

class User extends Equatable {
  final int id;
  final String fullName;
  final String email;
  final String? phone;
  final String? botPersonality;
  final bool onboardingCompleted;
  final String? walletName;
  final String? currencyCode;
  final double? initialBalance;
  final double? savingsGoalMonthly;

  const User({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.botPersonality,
    this.onboardingCompleted = false,
    this.walletName,
    this.currencyCode,
    this.initialBalance,
    this.savingsGoalMonthly,
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
