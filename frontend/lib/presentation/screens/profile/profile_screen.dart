import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:expense_manager/core/providers/app_providers.dart';
import 'package:expense_manager/core/router/app_router.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/utils/api_error.dart' show extractErrorMessage;
import 'package:expense_manager/domain/models/user.dart';
import 'package:expense_manager/presentation/widgets/robot/bot_selector_sheet.dart';
import 'package:expense_manager/presentation/widgets/settings/change_password_sheet.dart';
import 'package:expense_manager/presentation/widgets/robot/personality_robot_avatar.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _controllersInitialized = false;
  bool _saving = false;
  String? _error;

  User? _serverUser;

  @override
  void initState() {
    super.initState();
    _refreshFromServer();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _refreshFromServer() async {
    try {
      final user = await ref.read(userRepositoryProvider).getCurrentUser();
      if (!mounted) return;
      setState(() => _serverUser = user);
    } catch (_) {
      // Fallback: vẫn hiển thị user từ local storage nếu fetch server thất bại.
    }
  }

  void _maybeInitControllers(User user) {
    if (_controllersInitialized) return;
    _fullNameController.text = user.fullName;
    _phoneController.text = user.phone ?? '';
    _controllersInitialized = true;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = await ref.read(userRepositoryProvider).updateProfile(
            fullName: _fullNameController.text.trim(),
            phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          );

      if (!mounted) return;
      setState(() {
        _serverUser = updated;
        _saving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu thông tin cá nhân')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final msg = extractErrorMessage(e);
      setState(() {
        _error = msg;
        _saving = false;
      });

      if (e is DioException) {
        final status = e.response?.statusCode;
        if (status == 401 || status == 403) {
          await ref.read(authRepositoryProvider).logout();
          if (!mounted) return;
          Navigator.of(context).pushNamedAndRemoveUntil(AppRouter.login, (r) => false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localUser = ref.watch(currentUserProvider).valueOrNull;
    final user = _serverUser ?? localUser;

    if (user == null) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    _maybeInitControllers(user);

    final personality = user.botPersonality?.toUpperCase();
    final personalityLabel = personality == 'SAD'
        ? 'SAD'
        : personality == 'ANGRY'
            ? 'ANGRY'
            : 'HAPPY';

    final personalityColor = personality == 'SAD'
        ? AppColors.accent
        : personality == 'ANGRY'
            ? AppColors.accent
            : AppColors.primary;

    final personalityDesc = personality == 'SAD'
        ? 'Nhẹ nhàng, phân tích và đưa ra lời khuyên tài chính hợp lý.'
        : personality == 'ANGRY'
            ? 'Mạnh mẽ, nhắc nhở để bạn kiểm soát chi tiêu tốt hơn.'
            : 'Tràn đầy năng lượng, đồng hành cùng bạn trong hành trình tài chính.';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Trang cá nhân',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
        ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: personalityColor.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: personalityColor.withOpacity(0.20)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: AppColors.softShadow,
                                  border: Border.all(color: personalityColor.withOpacity(0.15)),
                                ),
                                child: PersonalityRobotAvatar(
                                  type: personality == 'SAD'
                                      ? PersonalityType.sad
                                      : personality == 'ANGRY'
                                          ? PersonalityType.angry
                                          : PersonalityType.happy,
                                  size: 84,
                                  isSelected: true,
                                  animated: false,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.fullName,
                                      style: GoogleFonts.nunito(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        Chip(
                                          label: Text(
                                            'Trợ lý Natta: $personalityLabel',
                                            style: GoogleFonts.nunito(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          backgroundColor:
                                              personalityColor.withOpacity(0.14),
                                          side: BorderSide(
                                            color: personalityColor.withOpacity(0.35),
                                          ),
                                          labelStyle:
                                              TextStyle(color: personalityColor),
                                        ),
                                        Chip(
                                          label: Text(
                                            user.email,
                                            style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                                          ),
                                          backgroundColor:
                                              AppColors.textMuted.withOpacity(0.08),
                                          side: BorderSide(
                                            color: AppColors.textMuted.withOpacity(0.18),
                                          ),
                                          labelStyle:
                                              TextStyle(color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      personalityDesc,
                                      style: GoogleFonts.nunito(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                Text(
                  'Chỉnh sửa thông tin',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                _Field(
                  label: 'Họ tên',
                  child: TextField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _Field(
                  label: 'Email',
                  child: Text(
                    user.email,
                    style: GoogleFonts.nunito(fontSize: 15, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 12),
                _Field(
                  label: 'Số điện thoại',
                  child: TextField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ),
                const SizedBox(height: 12),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.accent.withOpacity(0.20)),
                    ),
                    child: Text(
                      _error!,
                      style: GoogleFonts.nunito(fontSize: 13, color: AppColors.accent),
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
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
                      _saving ? 'Đang lưu…' : 'Lưu thay đổi',
                      style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                Text(
                  'Lưu ý: ví/currency & danh mục vẫn quản lý trong các mục tương ứng.',
                  style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary),
                ),

                const SizedBox(height: 24),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _QuickActionTile(
                          icon: Icons.smart_toy_rounded,
                          iconBg: AppColors.primary.withOpacity(0.12),
                          iconColor: AppColors.primary,
                          title: 'Đổi nhân vật Natta',
                          subtitle: 'Thay đổi tính cách trợ lý AI',
                          onTap: () => showBotSelectorSheet(context),
                        ),
                        const SizedBox(height: 8),
                        _QuickActionTile(
                          icon: Icons.lock_rounded,
                          iconBg: AppColors.accent.withOpacity(0.10),
                          iconColor: AppColors.accent,
                          title: 'Đổi mật khẩu',
                          subtitle: 'Thay đổi mật khẩu tài khoản',
                          onTap: () => showChangePasswordSheet(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String? hint;
  final Widget child;

  const _Field({
    required this.label,
    required this.child,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surface),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint!,
              style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
          if (hint == null) const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

