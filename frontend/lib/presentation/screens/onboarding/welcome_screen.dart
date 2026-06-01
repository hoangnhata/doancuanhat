import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/router/app_router.dart';
import 'package:expense_manager/core/utils/haptic_utils.dart';
import 'package:expense_manager/presentation/widgets/robot/robot_avatar.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.gradientStart, AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const SizedBox(height: 48),
                Align(
                  alignment: Alignment.centerRight,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: 'vi',
                      items: const [
                        DropdownMenuItem(value: 'vi', child: Text('Tiếng Việt')),
                        DropdownMenuItem(value: 'en', child: Text('English')),
                      ],
                      onChanged: (_) {},
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms),
                const Spacer(),
                RobotAvatar(size: 100, showGreeting: false)
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1), curve: Curves.elasticOut),
                const SizedBox(height: 32),
                Text(
                  'Xin chào! Tôi tên là Natta và tôi sẽ là trợ lý theo dõi tiền của bạn.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 400.ms)
                    .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),
                const SizedBox(height: 24),
                Text(
                  'Theo dõi thông minh hơn\nvới trợ lý AI',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    height: 1.3,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 400.ms)
                    .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticUtils.medium();
                      Navigator.pushNamed(context, AppRouter.login);
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
                      'Bắt đầu',
                      style: GoogleFonts.nunito(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 500.ms, duration: 400.ms)
                    .slideY(begin: 0.5, end: 0, curve: Curves.easeOutCubic),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
