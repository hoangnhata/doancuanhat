import 'package:flutter/material.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/presentation/widgets/robot/animated_natta_robot.dart';
import 'package:expense_manager/presentation/widgets/robot/robot_personality.dart';

/// Robot mascot mặc định — cùng phong cách với web (`AnimatedNattaRobot`).
class RobotAvatar extends StatelessWidget {
  final double size;
  final bool animated;
  final bool showGreeting;

  const RobotAvatar({
    super.key,
    this.size = 80,
    this.animated = true,
    this.showGreeting = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: AnimatedNattaRobot(
            size: size,
            personality: PersonalityType.happy,
            isSelected: false,
            animated: animated,
          ),
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
  }
}
