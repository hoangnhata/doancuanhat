import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/router/app_router.dart';
import 'package:expense_manager/core/utils/api_error.dart';
import 'package:expense_manager/core/utils/haptic_utils.dart';
import 'package:expense_manager/presentation/widgets/common/app_text_field.dart';
import 'package:expense_manager/presentation/widgets/common/app_button.dart';
import 'package:expense_manager/presentation/widgets/robot/robot_avatar.dart';
import 'package:expense_manager/core/providers/app_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    HapticUtils.medium();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ref.read(authRepositoryProvider).login(
            _emailController.text.trim(),
            _passwordController.text,
          );
      if (!mounted) return;
      final needsOnboarding = !result.user.onboardingCompleted;
      Navigator.of(context).pushNamedAndRemoveUntil(
        needsOnboarding ? AppRouter.onboardingBot : AppRouter.main,
        (r) => false,
      );
    } catch (e) {
      setState(() {
        _errorMessage = extractErrorMessage(e);
        _isLoading = false;
      });
    }
  }

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  Center(
                    child: RobotAvatar(size: 72, showGreeting: false),
                  )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), curve: Curves.easeOutCubic),
                  const SizedBox(height: 32),
                  Text(
                    'Đăng nhập',
                    style: GoogleFonts.nunito(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 100.ms, duration: 400.ms)
                      .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
                  const SizedBox(height: 8),
                  Text(
                    'Chào mừng trở lại!',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 150.ms, duration: 400.ms)
                      .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
                  const SizedBox(height: 12),
                  Text(
                    'Test AI: ai.demo@local.test / Demo@123456',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppTextField(
                    label: 'Email',
                    hint: 'email@example.com',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Vui lòng nhập email';
                      if (!v.contains('@')) return 'Email không hợp lệ';
                      return null;
                    },
                  )
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 400.ms)
                      .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
                  const SizedBox(height: 20),
                  AppTextField(
                    label: 'Mật khẩu',
                    hint: '••••••••',
                    controller: _passwordController,
                    obscureText: true,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
                      return null;
                    },
                  )
                      .animate()
                      .fadeIn(delay: 250.ms, duration: 400.ms)
                      .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.accent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: GoogleFonts.nunito(color: AppColors.accent, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        HapticUtils.selection();
                        Navigator.pushNamed(
                          context,
                          AppRouter.forgotPassword,
                          arguments: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
                        );
                      },
                      child: Text(
                        'Quên mật khẩu?',
                        style: GoogleFonts.nunito(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    text: 'Đăng nhập',
                    onPressed: _login,
                    isLoading: _isLoading,
                  )
                      .animate()
                      .fadeIn(delay: 300.ms, duration: 400.ms)
                      .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      HapticUtils.selection();
                      Navigator.pushNamed(context, AppRouter.register);
                    },
                    child: RichText(
                      text: TextSpan(
                        style: GoogleFonts.nunito(fontSize: 15, color: AppColors.textSecondary),
                        children: [
                          const TextSpan(text: 'Bạn chưa có tài khoản? '),
                          TextSpan(
                            text: 'Đăng ký tại đây',
                            style: GoogleFonts.nunito(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 350.ms, duration: 400.ms),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
