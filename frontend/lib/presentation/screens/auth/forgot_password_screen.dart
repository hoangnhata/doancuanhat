import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:expense_manager/core/providers/app_providers.dart';
import 'package:expense_manager/core/router/app_router.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/utils/api_error.dart';
import 'package:expense_manager/core/utils/haptic_utils.dart';
import 'package:expense_manager/presentation/widgets/common/app_button.dart';
import 'package:expense_manager/presentation/widgets/common/app_text_field.dart';

/// Bước 1: User nhập email → backend gửi OTP qua mail (hoặc log dev console).
/// Bước 2: tự push sang [ResetPasswordScreen] với email đã nhập.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  final String? initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController =
      TextEditingController(text: widget.initialEmail);
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    HapticUtils.medium();
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final email = _emailController.text.trim();
      await ref.read(authRepositoryProvider).requestPasswordReset(email);
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        AppRouter.resetPassword,
        arguments: email,
      );
    } catch (e) {
      setState(() {
        _error = extractErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quên mật khẩu', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
      ),
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
                  Icon(Icons.mark_email_unread_rounded,
                      size: 64, color: AppColors.primary)
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1)),
                  const SizedBox(height: 16),
                  Text(
                    'Nhập email của bạn',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Chúng tôi sẽ gửi mã OTP 6 chữ số đến email để xác minh và đặt lại mật khẩu.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  AppTextField(
                    label: 'Email',
                    hint: 'email@example.com',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Vui lòng nhập email';
                      if (!v.contains('@')) return 'Email không hợp lệ';
                      return null;
                    },
                  ),
                  if (_error != null) ...[
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
                              _error!,
                              style: GoogleFonts.nunito(color: AppColors.accent, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  AppButton(
                    text: 'Gửi mã OTP',
                    onPressed: _submit,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      HapticUtils.selection();
                      Navigator.pushNamed(
                        context,
                        AppRouter.resetPassword,
                        arguments: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
                      );
                    },
                    child: Text(
                      'Tôi đã có mã OTP →',
                      style: GoogleFonts.nunito(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
