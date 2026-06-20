import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/router/app_router.dart';
import 'package:expense_manager/core/utils/api_error.dart';
import 'package:expense_manager/core/utils/haptic_utils.dart';
import 'package:expense_manager/presentation/widgets/auth/auth_shell.dart';
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
    return AuthShell(
      title: 'Tạo tài khoản',
      subtitle: 'Điền thông tin cơ bản — chúng tôi gửi mã OTP qua email để xác minh trước khi kích hoạt.',
      showBackButton: true,
      footer: TextButton(
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
                text: 'Đăng nhập',
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
            _field(
              delay: 0,
              child: AppTextField(
                label: 'Họ tên',
                hint: 'Nguyễn Văn A',
                controller: _nameController,
                prefixIcon: const Icon(Icons.person_outline_rounded),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Vui lòng nhập họ tên';
                  if (v.length < 2) return 'Họ tên phải có ít nhất 2 ký tự';
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            _field(
              delay: 50,
              child: AppTextField(
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
              ),
            ),
            const SizedBox(height: 16),
            _field(
              delay: 100,
              child: AppTextField(
                label: 'Số điện thoại (tuỳ chọn)',
                hint: '0901234567',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 16),
            _field(
              delay: 150,
              child: AppTextField(
                label: 'Mật khẩu',
                hint: 'Tối thiểu 6 ký tự',
                controller: _passwordController,
                obscureText: true,
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
                  if (v.length < 6) return 'Mật khẩu phải có ít nhất 6 ký tự';
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            _field(
              delay: 200,
              child: AppTextField(
                label: 'Xác nhận mật khẩu',
                hint: 'Nhập lại mật khẩu',
                controller: _confirmPasswordController,
                obscureText: true,
                prefixIcon: const Icon(Icons.lock_person_outlined),
                validator: (v) {
                  if (v != _passwordController.text) return 'Mật khẩu không khớp';
                  return null;
                },
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              AuthErrorBanner(message: _errorMessage!),
            ],
            const SizedBox(height: 24),
            AppButton(
              text: 'Tiếp tục — Nhận OTP qua email',
              onPressed: _register,
              isLoading: _isLoading,
            ).animate().fadeIn(delay: 250.ms, duration: 350.ms),
          ],
        ),
      ),
    );
  }

  Widget _field({required int delay, required Widget child}) {
    return child
        .animate()
        .fadeIn(delay: Duration(milliseconds: delay), duration: 350.ms)
        .slideY(begin: 0.06, end: 0);
  }
}
