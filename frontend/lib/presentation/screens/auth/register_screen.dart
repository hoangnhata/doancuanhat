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
import 'package:expense_manager/core/providers/app_providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    HapticUtils.medium();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    try {
      // Bước 1: yêu cầu gửi OTP, chưa tạo user thật.
      await ref.read(authRepositoryProvider).requestRegistration(
            fullName: _nameController.text.trim(),
            email: email,
            password: _passwordController.text,
            phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          );
      if (!mounted) return;
      Navigator.pushNamed(context, AppRouter.verifyRegistration, arguments: email);
      if (mounted) setState(() => _isLoading = false);
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
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () {
                    HapticUtils.selection();
                    Navigator.pop(context);
                  },
                ),
              )
                  .animate()
                  .fadeIn(duration: 300.ms),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Bắt đầu',
                          style: GoogleFonts.nunito(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 50.ms, duration: 400.ms)
                            .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
                        const SizedBox(height: 8),
                        Text(
                          'Hãy bắt đầu bằng cách điền vào mẫu dưới đây',
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 100.ms, duration: 400.ms)
                            .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
                        const SizedBox(height: 28),
                        _buildAnimatedField(
                          delay: 150,
                          child: AppTextField(
                            label: 'Họ tên',
                            hint: 'Nguyễn Văn A',
                            controller: _nameController,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Vui lòng nhập họ tên';
                              if (v.length < 2) return 'Họ tên phải có ít nhất 2 ký tự';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildAnimatedField(
                          delay: 200,
                          child: AppTextField(
                            label: 'Email',
                            hint: 'email@example.com',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Vui lòng nhập email';
                              if (!v.contains('@')) return 'Email không hợp lệ';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildAnimatedField(
                          delay: 250,
                          child: AppTextField(
                            label: 'Số điện thoại',
                            hint: '0901234567',
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildAnimatedField(
                          delay: 300,
                          child: AppTextField(
                            label: 'Mật khẩu',
                            hint: 'Tối thiểu 6 ký tự',
                            controller: _passwordController,
                            obscureText: true,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
                              if (v.length < 6) return 'Mật khẩu phải có ít nhất 6 ký tự';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildAnimatedField(
                          delay: 350,
                          child: AppTextField(
                            label: 'Xác nhận mật khẩu',
                            hint: 'Nhập lại mật khẩu',
                            controller: _confirmPasswordController,
                            obscureText: true,
                            validator: (v) {
                              if (v != _passwordController.text) return 'Mật khẩu không khớp';
                              return null;
                            },
                          ),
                        ),
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
                        const SizedBox(height: 32),
                        AppButton(
                          text: 'Tạo tài khoản',
                          onPressed: _register,
                          isLoading: _isLoading,
                        )
                            .animate()
                            .fadeIn(delay: 400.ms, duration: 400.ms)
                            .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            HapticUtils.selection();
                            Navigator.pop(context);
                          },
                          child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.nunito(fontSize: 15, color: AppColors.textSecondary),
                              children: [
                                const TextSpan(text: 'Bạn đã có tài khoản? '),
                                TextSpan(
                                  text: 'Đăng nhập tại đây',
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
                            .fadeIn(delay: 450.ms),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedField({required int delay, required Widget child}) {
    return child
        .animate()
        .fadeIn(delay: Duration(milliseconds: delay), duration: 400.ms)
        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
  }
}
