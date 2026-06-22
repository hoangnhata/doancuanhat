import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/router/app_router.dart';
import 'package:expense_manager/core/router/onboarding_route.dart';
import 'package:expense_manager/core/utils/api_error.dart';
import 'package:expense_manager/core/utils/haptic_utils.dart';
import 'package:expense_manager/presentation/widgets/auth/auth_shell.dart';
import 'package:expense_manager/presentation/widgets/common/app_text_field.dart';
import 'package:expense_manager/presentation/widgets/common/app_button.dart';
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
      Navigator.of(context).pushNamedAndRemoveUntil(
        resolveOnboardingRoute(result.user),
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
    return AuthShell(
      title: 'Đăng nhập',
      subtitle: 'Chào mừng trở lại! Tiếp tục theo dõi chi tiêu và trò chuyện với trợ lý AI.',
      footer: TextButton(
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
                text: 'Đăng ký miễn phí',
                style: GoogleFonts.nunito(color: AppColors.primary, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: 'Email',
              hint: 'email@example.com',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: const Icon(Icons.email_outlined),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Vui lòng nhập email';
                if (!v.contains('@')) return 'Email không hợp lệ';
                return null;
              },
            ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08, end: 0),
            const SizedBox(height: 18),
            AppTextField(
              label: 'Mật khẩu',
              hint: '••••••••',
              controller: _passwordController,
              obscureText: true,
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
                return null;
              },
            ).animate().fadeIn(delay: 80.ms, duration: 350.ms).slideY(begin: 0.08, end: 0),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              AuthErrorBanner(message: _errorMessage!),
            ],
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
                  style: GoogleFonts.nunito(color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 8),
            AppButton(text: 'Đăng nhập', onPressed: _login, isLoading: _isLoading)
                .animate()
                .fadeIn(delay: 120.ms, duration: 350.ms),
          ],
        ),
      ),
    );
  }
}
