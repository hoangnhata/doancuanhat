import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_manager/core/providers/app_providers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/router/app_router.dart';
import 'package:expense_manager/presentation/widgets/robot/bot_selector_sheet.dart';
import 'package:expense_manager/presentation/widgets/settings/change_password_sheet.dart';
import 'package:expense_manager/presentation/widgets/robot/natta_avatar.dart';

class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cài đặt',
                  style: GoogleFonts.nunito(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                userAsync.when(
                  data: (user) {
                    final p = (user?.botPersonality ?? 'HAPPY').toUpperCase();
                    final label = p == 'SAD' ? 'SAD' : p == 'ANGRY' ? 'ANGRY' : 'HAPPY';
                    final color = label == 'HAPPY' ? AppColors.primary : AppColors.accent;
                    final desc = label == 'SAD'
                        ? 'Nhẹ nhàng, phân tích và đưa ra lời khuyên hợp lý.'
                        : label == 'ANGRY'
                            ? 'Mạnh mẽ, nhắc nhở để bạn kiểm soát chi tiêu tốt hơn.'
                            : 'Tràn đầy năng lượng, đồng hành cùng bạn trong hành trình tài chính.';
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: AppColors.softShadow,
                        border: Border.all(color: AppColors.surface),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: color.withOpacity(0.18)),
                            ),
                            child: NattaAvatar(size: 56),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.fullName.isNotEmpty == true ? user!.fullName : (user?.email ?? ''),
                                  style: GoogleFonts.nunito(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
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
                                      backgroundColor: color.withOpacity(0.14),
                                      side: BorderSide(color: color.withOpacity(0.35)),
                                      label: Text(
                                        'Trợ lý: $label',
                                        style: GoogleFonts.nunito(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                    if (user?.email != null && user!.email.isNotEmpty)
                                      Chip(
                                        backgroundColor: AppColors.textMuted.withOpacity(0.08),
                                        side: BorderSide(color: AppColors.textMuted.withOpacity(0.18)),
                                        label: Text(
                                          user.email,
                                          style: GoogleFonts.nunito(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  desc,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.nunito(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => Container(
                    width: double.infinity,
                    height: 110,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                const SizedBox(height: 20),
                _SettingsExpander(
                  icon: Icons.smart_toy_rounded,
                  title: 'Trợ lý Natta',
                  initiallyExpanded: false,
                  children: [
                    _SettingsTile(
                      icon: Icons.smart_toy_rounded,
                      title: 'Đổi nhân vật Natta',
                      subtitle: 'Thay đổi tính cách trợ lý AI',
                      onTap: () => showBotSelectorSheet(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsExpander(
                  icon: Icons.account_circle_rounded,
                  title: 'Tài khoản',
                  initiallyExpanded: false,
                  children: [
                    _SettingsTile(
                      icon: Icons.person_rounded,
                      title: 'Trang cá nhân',
                      subtitle: 'Quản lý thông tin tài khoản',
                      onTap: () => Navigator.pushNamed(context, AppRouter.profile),
                    ),
                    _SettingsTile(
                      icon: Icons.lock_rounded,
                      title: 'Đổi mật khẩu',
                      subtitle: 'Thay đổi mật khẩu tài khoản',
                      onTap: () => showChangePasswordSheet(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsExpander(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'Tài chính',
                  initiallyExpanded: false,
                  children: [
                    _SettingsTile(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Hạn mức chi tiêu',
                      subtitle: 'Đặt hạn mức theo danh mục để kiểm soát chi tiêu',
                      onTap: () => Navigator.pushNamed(context, AppRouter.budget),
                    ),
                    _SettingsTile(
                      icon: Icons.category_rounded,
                      title: 'Danh mục',
                      subtitle: 'Quản lý danh mục chi tiêu',
                      onTap: () => Navigator.pushNamed(context, AppRouter.categories),
                    ),
                    _SettingsTile(
                      icon: Icons.wallet_rounded,
                      title: 'Quản lý ví',
                      subtitle: 'Thêm, sửa, xóa ví',
                      onTap: () => Navigator.pushNamed(context, AppRouter.wallets),
                    ),
                    _SettingsTile(
                      icon: Icons.savings_rounded,
                      title: 'Mục tiêu tiết kiệm',
                      subtitle: 'Ví tiết kiệm nội bộ — nạp, rút, theo dõi',
                      onTap: () => Navigator.pushNamed(context, AppRouter.savingGoals),
                    ),
                    _SettingsTile(
                      icon: Icons.repeat_rounded,
                      title: 'Giao dịch định kỳ',
                      subtitle: 'Tạo giao dịch lặp mỗi tháng',
                      onTap: () => Navigator.pushNamed(context, AppRouter.recurring),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsExpander(
                  icon: Icons.notifications_rounded,
                  title: 'Nhắc nhở chi tiêu',
                  initiallyExpanded: false,
                  children: [
                    Consumer(
                      builder: (context, ref, _) {
                        final reminder = ref.watch(dailyReminderProvider);
                        Future<void> toggle(bool v) async {
                          final r = await ref.read(dailyReminderProvider.notifier).setEnabled(v);
                          if (!context.mounted) return;
                          if (!r.ok && v && r.failure != null) {
                            final msg = switch (r.failure!) {
                              DailyReminderEnableFailure.notificationPermission =>
                                'Cần quyền gửi thông báo. Bật trong Cài đặt → Thông báo → expense_manager.',
                              DailyReminderEnableFailure.exactAlarmPermission =>
                                'Để nhắc đúng giờ–phút trên Android 12+: bật quyền báo thức chính xác cho expense_manager trong Cài đặt (Alarms & reminders / Lịch báo thức).',
                              DailyReminderEnableFailure.scheduleFailed =>
                                'Không thể đặt lịch nhắc. Thử tắt bật lại hoặc khởi động lại ứng dụng.',
                            };
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(msg, style: GoogleFonts.nunito())),
                            );
                          }
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              clipBehavior: Clip.antiAlias,
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Icon(Icons.notifications_active_rounded,
                                          color: AppColors.primary, size: 24),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Bật nhắc hàng ngày',
                                            style: GoogleFonts.nunito(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            'Đúng giờ đặt mỗi ngày (theo giờ điện thoại). Android 12+: có thể hỏi thêm quyền báo thức chính xác.',
                                            style: GoogleFonts.nunito(
                                                fontSize: 13, color: AppColors.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    CupertinoSwitch(
                                      value: reminder.enabled,
                                      activeTrackColor: AppColors.primary,
                                      onChanged: (v) => toggle(v),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _SettingsTile(
                              icon: Icons.schedule_rounded,
                              title: 'Đổi giờ nhắc',
                              subtitle: reminder.enabled
                                  ? 'Đang đặt ${reminder.timeLabel} mỗi ngày'
                                  : 'Giờ đặt: ${reminder.timeLabel} — bật công tắc trên để nhận thông báo',
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime:
                                      TimeOfDay(hour: reminder.hour, minute: reminder.minute),
                                );
                                if (picked != null && context.mounted) {
                                  await ref
                                      .read(dailyReminderProvider.notifier)
                                      .setTime(picked.hour, picked.minute);
                                }
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  await ref.read(dailyReminderProvider.notifier).sendTestNow();
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Đã gửi thông báo thử — kiểm tra khay thông báo.',
                                        style: GoogleFonts.nunito(),
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.send_rounded, size: 20),
                                label: Text(
                                  'Thử gửi thông báo ngay',
                                  style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsExpander(
                  icon: Icons.palette_rounded,
                  title: 'Giao diện',
                  initiallyExpanded: false,
                  children: [
                    Consumer(
                      builder: (context, ref, _) {
                        final mode = ref.watch(themeModeProvider);
                        return Material(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(20),
                          clipBehavior: Clip.antiAlias,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.brightness_6_rounded,
                                          color: AppColors.primary, size: 22),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        'Chế độ màu',
                                        style: GoogleFonts.nunito(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(context).textTheme.bodyLarge?.color,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SegmentedButton<ThemeMode>(
                                  showSelectedIcon: false,
                                  segments: [
                                    ButtonSegment(
                                      value: ThemeMode.light,
                                      label: Text('Sáng',
                                          style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                                      icon: const Icon(Icons.light_mode_rounded, size: 18),
                                    ),
                                    ButtonSegment(
                                      value: ThemeMode.dark,
                                      label: Text('Tối',
                                          style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                                      icon: const Icon(Icons.dark_mode_rounded, size: 18),
                                    ),
                                    ButtonSegment(
                                      value: ThemeMode.system,
                                      label: Text('Theo hệ thống',
                                          style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                                      icon: const Icon(Icons.settings_suggest_rounded, size: 18),
                                    ),
                                  ],
                                  selected: <ThemeMode>{mode},
                                  onSelectionChanged: (s) {
                                    if (s.isEmpty) return;
                                    ref.read(themeModeProvider.notifier).setMode(s.first);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsExpander(
                  icon: Icons.logout_rounded,
                  title: 'Khác',
                  initiallyExpanded: false,
                  children: [
                    _SettingsTile(
                      icon: Icons.logout_rounded,
                      title: 'Đăng xuất',
                      subtitle: 'Đăng xuất khỏi tài khoản',
                      onTap: () async {
                        await ref.read(authRepositoryProvider).logout();
                        if (!context.mounted) return;
                        Navigator.of(context)
                            .pushNamedAndRemoveUntil(AppRouter.login, (r) => false);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsExpander extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  const _SettingsExpander({
    required this.icon,
    required this.title,
    required this.children,
    required this.initiallyExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> out = [];
    for (var i = 0; i < children.length; i++) {
      out.add(children[i]);
      if (i < children.length - 1) out.add(const SizedBox(height: 12));
    }

    return Material(
      color: Colors.white.withOpacity(0.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: ExpansionTile(
            maintainState: true,
            initiallyExpanded: initiallyExpanded,
            tilePadding: const EdgeInsets.symmetric(horizontal: 4),
            childrenPadding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            backgroundColor: Colors.white.withOpacity(0.0),
            collapsedBackgroundColor: Colors.white.withOpacity(0.0),
            iconColor: AppColors.primary,
            collapsedIconColor: AppColors.textMuted,
            trailing: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted),
            title: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary.withOpacity(0.18)),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            children: out,
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
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
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
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
