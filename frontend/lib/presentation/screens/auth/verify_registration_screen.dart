import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:expense_manager/core/providers/app_providers.dart';
import 'package:expense_manager/core/router/onboarding_route.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/utils/api_error.dart';
import 'package:expense_manager/core/utils/haptic_utils.dart';
import 'package:expense_manager/core/utils/snackbar_utils.dart';
import 'package:expense_manager/presentation/widgets/common/app_button.dart';
import 'package:expense_manager/presentation/widgets/common/app_text_field.dart';

/// Hiện sau khi user submit form đăng ký. Yêu cầu nhập 6 chữ số OTP đã gửi qua email.
/// Verify thành công → backend tạo user thật + trả AuthResponse → auto-login.
class VerifyRegistrationScreen extends ConsumerStatefulWidget {
  final String email;
  const VerifyRegistrationScreen({super.key, required this.email});

  @override
  ConsumerState<VerifyRegistrationScreen> createState() => _VerifyRegistrationScreenState();
}

class _VerifyRegistrationScreenState extends ConsumerState<VerifyRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  String? _error;

  @override
  void dispose() {
    _otpController.dispose();
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
      final result = await ref.read(authRepositoryProvider).verifyRegistration(
            email: widget.email,
            otp: _otpController.text.trim(),
          );
      if (!mounted) return;
      showSuccessSnackBar(context, 'Đăng ký thành công!');
      Navigator.of(context).pushNamedAndRemoveUntil(
        resolveOnboardingRoute(result.user),
        (r) => false,
      );
    } catch (e) {
      setState(() {
        _error = extractErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _resend() async {
    HapticUtils.selection();
    setState(() {
      _isResending = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).resendRegistrationOtp(widget.email);
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
        title: Text('Xác minh email', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
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
                  Icon(Icons.mark_email_read_rounded, size: 64, color: AppColors.primary)
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1)),
                  const SizedBox(height: 16),
                  Text(
                    'Kiểm tra hộp thư của bạn',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Chúng tôi đã gửi mã OTP 6 chữ số đến:',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.email,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 28),
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
                    text: 'Xác minh & Tạo tài khoản',
                    onPressed: _submit,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _isResending ? null : _resend,
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
                  TextButton(
                    onPressed: () {
                      HapticUtils.selection();
                      Navigator.pop(context);
                    },
                    child: Text(
                      '← Quay lại form đăng ký',
                      style: GoogleFonts.nunito(color: AppColors.textSecondary),
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
