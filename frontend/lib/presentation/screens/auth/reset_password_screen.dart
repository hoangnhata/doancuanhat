import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:expense_manager/core/providers/app_providers.dart';
import 'package:expense_manager/core/router/app_router.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/utils/api_error.dart';
import 'package:expense_manager/core/utils/haptic_utils.dart';
import 'package:expense_manager/core/utils/snackbar_utils.dart';
import 'package:expense_manager/presentation/widgets/common/app_button.dart';
import 'package:expense_manager/presentation/widgets/common/app_text_field.dart';

/// Nhập email (đã pre-fill) + OTP 6 số + mật khẩu mới.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String? initialEmail;
  const ResetPasswordScreen({super.key, this.initialEmail});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController =
      TextEditingController(text: widget.initialEmail);
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmController.text) {
      setState(() => _error = 'Mật khẩu xác nhận không khớp');
      return;
    }
    HapticUtils.medium();
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).resetPassword(
            email: _emailController.text.trim(),
            otp: _otpController.text.trim(),
            newPassword: _passwordController.text,
          );
      if (!mounted) return;
      showSuccessSnackBar(context, 'Đặt lại mật khẩu thành công. Hãy đăng nhập với mật khẩu mới.');
      Navigator.of(context).pushNamedAndRemoveUntil(AppRouter.login, (r) => false);
    } catch (e) {
      setState(() {
        _error = extractErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _resendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Vui lòng nhập email hợp lệ trước khi gửi lại OTP');
      return;
    }
    HapticUtils.selection();
    setState(() {
      _isResending = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).requestPasswordReset(email);
      if (!mounted) return;
      showInfoSnackBar(context, 'Đã gửi lại OTP. Vui lòng kiểm tra email.');
    } catch (e) {
      setState(() => _error = extractErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Đặt lại mật khẩu',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
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
                  const SizedBox(height: 16),
                  Icon(Icons.lock_reset_rounded, size: 64, color: AppColors.primary)
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1)),
                  const SizedBox(height: 16),
                  Text(
                    'Nhập mã OTP và mật khẩu mới',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),
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
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Mã OTP (6 chữ số)',
                    hint: '------',
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    validator: (v) {
                      if (v == null || v.trim().length != 6) return 'OTP gồm 6 chữ số';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Mật khẩu mới',
                    hint: '••••••••',
                    controller: _passwordController,
                    obscureText: true,
                    validator: (v) {
                      if (v == null || v.length < 6) return 'Tối thiểu 6 ký tự';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Nhập lại mật khẩu',
                    hint: '••••••••',
                    controller: _confirmController,
                    obscureText: true,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Vui lòng xác nhận';
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
                  const SizedBox(height: 24),
                  AppButton(
                    text: 'Đặt lại mật khẩu',
                    onPressed: _submit,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _isResending ? null : _resendOtp,
                    icon: _isResending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: Text(
                      'Gửi lại mã OTP',
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
