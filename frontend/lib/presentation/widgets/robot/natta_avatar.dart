import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_manager/core/providers/app_providers.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/domain/models/user.dart';
import 'package:expense_manager/presentation/widgets/robot/personality_robot_avatar.dart';
import 'package:expense_manager/presentation/widgets/robot/robot_avatar.dart';

/// Avatar Natta theo nhân vật user đã chọn
class NattaAvatar extends ConsumerWidget {
  final double size;
  final bool showGreeting;

  const NattaAvatar({
    super.key,
    this.size = 72,
    this.showGreeting = false,
  });

  static PersonalityType _typeFromUser(User? user) {
    switch (user?.botPersonality?.toUpperCase()) {
      case 'SAD':
        return PersonalityType.sad;
      case 'ANGRY':
        return PersonalityType.angry;
      default:
        return PersonalityType.happy;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.when(
      data: (user) {
        final type = _typeFromUser(user);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PersonalityRobotAvatar(
              type: type,
              size: size,
              isSelected: false,
            ),
            if (showGreeting) ...[
              const SizedBox(height: 8),
              Text(
                'Xin chào! Tôi là AI trợ lý tài chính',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        );
      },
      loading: () => RobotAvatar(size: size, showGreeting: showGreeting),
      error: (_, __) => RobotAvatar(size: size, showGreeting: showGreeting),
    );
  }
}
