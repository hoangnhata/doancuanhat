import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/di/injection.dart';
import 'package:expense_manager/core/providers/app_providers.dart';
import 'package:expense_manager/presentation/widgets/robot/personality_robot_avatar.dart';

void showBotSelectorSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const _BotSelectorSheet(),
  );
}

class _BotSelectorSheet extends ConsumerStatefulWidget {
  const _BotSelectorSheet();

  @override
  ConsumerState<_BotSelectorSheet> createState() => _BotSelectorSheetState();
}

class _BotSelectorSheetState extends ConsumerState<_BotSelectorSheet> {
  String? _selected;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final user = await localStorage.getUser();
    setState(() => _selected = user?.botPersonality ?? 'HAPPY');
  }

  Future<void> _select(String personality) async {
    if (_isLoading) return;
    setState(() {
      _selected = personality;
      _isLoading = true;
    });
    try {
      await ref.read(userRepositoryProvider).updateProfile(botPersonality: personality);
      ref.invalidate(currentUserProvider);
      if (mounted) Navigator.pop(context);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Đổi nhân vật Natta',
            style: GoogleFonts.nunito(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cảm xúc tin nhắn Natta phản hồi sẽ thay đổi theo nhân vật',
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          _BotOption(
            label: 'Cổ Động Viên Ủng Hộ',
            desc: 'Thân thiện, động viên',
            personality: 'HAPPY',
            color: AppColors.primary,
            robotType: PersonalityType.happy,
            isSelected: _selected == 'HAPPY',
            onTap: () => _select('HAPPY'),
          ),
          const SizedBox(height: 12),
          _BotOption(
            label: 'Người Cố Vấn Thông Thái',
            desc: 'Nhẹ nhàng, đưa lời khuyên',
            personality: 'SAD',
            color: Colors.indigo,
            robotType: PersonalityType.sad,
            isSelected: _selected == 'SAD',
            onTap: () => _select('SAD'),
          ),
          const SizedBox(height: 12),
          _BotOption(
            label: 'Mẹ Giận Dữ',
            desc: 'Mạnh mẽ, nhắc nhở',
            personality: 'ANGRY',
            color: AppColors.accent,
            robotType: PersonalityType.angry,
            isSelected: _selected == 'ANGRY',
            onTap: () => _select('ANGRY'),
          ),
          const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _BotOption extends StatelessWidget {
  final String label;
  final String desc;
  final String personality;
  final Color color;
  final PersonalityType robotType;
  final bool isSelected;
  final VoidCallback onTap;

  const _BotOption({
    required this.label,
    required this.desc,
    required this.personality,
    required this.color,
    required this.robotType,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            PersonalityRobotAvatar(
              type: robotType,
              size: 48,
              isSelected: isSelected,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    desc,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 24),
          ],
        ),
      ),
    );
  }
}
