import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/providers/app_providers.dart';
import 'package:expense_manager/presentation/screens/onboarding/onboarding_wallet_screen.dart';
import 'package:expense_manager/presentation/widgets/robot/personality_robot_avatar.dart';

class _PersonalityData {
  final String id;
  final String label;
  final String desc;
  final Color color;
  final PersonalityType robotType;

  const _PersonalityData(this.id, this.label, this.desc, this.color, this.robotType);
}

const _personalities = [
  _PersonalityData('HAPPY', 'Cổ Động Viên Ủng Hộ',
      'Chọn Cổ Động Viên Ủng Hộ nếu cần một người đồng hành tràn đầy năng lượng, sẵn sàng ăn mừng mọi bước trong hành trình tài chính.',
      AppColors.primary, PersonalityType.happy),
  _PersonalityData('ANGRY', 'Mẹ Giận Dữ',
      'Chọn Mẹ Giận Dữ khi cần ai đó mạnh mẽ nhắc nhở, giúp bạn kiểm soát chi tiêu và không chi tiêu quá tay.',
      AppColors.accent, PersonalityType.angry),
  _PersonalityData('SAD', 'Người Cố Vấn Thông Thái',
      'Chọn Người Cố Vấn Thông Thái để có trợ lý nhẹ nhàng, phân tích và đưa ra lời khuyên tài chính hợp lý.',
      Colors.indigo, PersonalityType.sad),
];

class OnboardingBotScreen extends ConsumerStatefulWidget {
  const OnboardingBotScreen({super.key});

  @override
  ConsumerState<OnboardingBotScreen> createState() => _OnboardingBotScreenState();
}

class _OnboardingBotScreenState extends ConsumerState<OnboardingBotScreen> {
  String _selected = 'HAPPY';

  String get _selectedDesc {
    final matches = _personalities.where((x) => x.id == _selected).toList();
    return matches.isNotEmpty ? matches.first.desc : _personalities.first.desc;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Text(
                  'Thiết lập trợ lý tài chính của bạn – Natta',
                  style: GoogleFonts.nunito(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bạn muốn Natta có tính cách như thế nào?',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 168,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _personalities.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, i) {
                      final p = _personalities[i];
                      return _PersonalityCard(
                        label: p.label,
                        color: p.color,
                        robotType: p.robotType,
                        isSelected: _selected == p.id,
                        onTap: () => setState(() => _selected = p.id),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(height: 1),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 20, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedDesc,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.textMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Nhiều tính cách khác để mở khóa sau này — thậm chí bạn có thể tự tạo tính cách của riêng mình!',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await ref.read(userRepositoryProvider).updateProfile(botPersonality: _selected);
                      if (!context.mounted) return;
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OnboardingWalletScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Tiếp tục',
                      style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonalityCard extends StatelessWidget {
  final String label;
  final Color color;
  final PersonalityType robotType;
  final bool isSelected;
  final VoidCallback onTap;

  const _PersonalityCard({
    required this.label,
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
        width: 120,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? color : AppColors.surface,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PersonalityRobotAvatar(
              type: robotType,
              size: 52,
              isSelected: isSelected,
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
