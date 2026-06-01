import 'package:flutter/material.dart';

import 'package:expense_manager/presentation/widgets/robot/animated_natta_robot.dart';
import 'package:expense_manager/presentation/widgets/robot/robot_personality.dart';

export 'robot_personality.dart';

/// Avatar Natta theo tính cách — cùng giao diện full-body với web (SVG chibi).
class PersonalityRobotAvatar extends StatelessWidget {
  final PersonalityType type;
  final double size;
  final bool isSelected;
  final bool animated;

  const PersonalityRobotAvatar({
    super.key,
    required this.type,
    this.size = 56,
    this.isSelected = false,
    this.animated = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedNattaRobot(
        size: size,
        personality: type,
        isSelected: isSelected,
        animated: animated,
      ),
    );
  }
}
