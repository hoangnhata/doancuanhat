import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:expense_manager/core/providers/app_providers.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/utils/api_error.dart';
import 'package:expense_manager/domain/models/saving_goal.dart';
import 'package:expense_manager/domain/models/wallet.dart';
import 'package:expense_manager/core/utils/haptic_utils.dart';
import 'package:expense_manager/core/utils/snackbar_utils.dart';
import 'package:expense_manager/presentation/widgets/onboarding/onboarding_form_widgets.dart';

class SavingGoalsScreen extends ConsumerStatefulWidget {
  const SavingGoalsScreen({super.key});

  @override
  ConsumerState<SavingGoalsScreen> createState() => _SavingGoalsScreenState();
}

class _SavingGoalsScreenState extends ConsumerState<SavingGoalsScreen> {
  List<SavingGoal> _goals = [];
  bool _loading = true;
  String? _error;

  static final _moneyFmt = NumberFormat('#,###', 'vi');
  static const _green = Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ref.read(savingGoalRepositoryProvider).getAll();
      setState(() {
        _goals = list;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = extractErrorMessage(e));
    }
    setState(() => _loading = false);
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'COMPLETED':
        return 'Hoàn thành';
      case 'PAUSED':
        return 'Tạm dừng';
      case 'CANCELLED':
        return 'Đã hủy';
      default:
        return 'Đang tiết kiệm';
    }
  }

  double? _parseAmount(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return double.tryParse(digits);
  }

  Color _progressColor(SavingGoal g) {
    if (g.isCompleted) return _green;
    if (g.progressPercent >= 75) return AppColors.primary;
    return const Color(0xFF0288D1);
  }

  String _formatTargetDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  Future<void> _showCreateDialog() async {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final initialCtrl = TextEditingController();
    DateTime? targetDate;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Tạo mục tiêu tiết kiệm', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Tên mục tiêu',
                    hintText: 'Ví dụ: Du lịch Đà Lạt',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Số tiền mục tiêu',
                    hintText: '10.000.000',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onChanged: (v) {
                    final formatted = formatOnboardingAmount(v);
                    if (formatted != v) {
                      targetCtrl.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(offset: formatted.length),
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: initialCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Số tiền ban đầu (tùy chọn)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    helperText: 'Không trừ từ ví — chỉ ghi nhận số dư ban đầu',
                  ),
                  onChanged: (v) {
                    final formatted = formatOnboardingAmount(v);
                    if (formatted != v) {
                      initialCtrl.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(offset: formatted.length),
                      );
                    }
                  },
                ),
                const SizedBox(height: 8),
                OnboardingDateField(
                  label: 'Ngày dự kiến hoàn thành',
                  value: targetDate,
                  onChanged: (d) => setLocal(() => targetDate = d),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Tạo mục tiêu'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;
    final target = _parseAmount(targetCtrl.text);
    if (nameCtrl.text.trim().isEmpty || target == null || target <= 0) return;

    try {
      await ref.read(savingGoalRepositoryProvider).create(
            name: nameCtrl.text.trim(),
            targetAmount: target,
            initialAmount: _parseAmount(initialCtrl.text),
            targetDate: targetDate?.toIso8601String().split('T').first,
          );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(extractErrorMessage(e))));
    }
  }

  Future<void> _showTransferDialog(SavingGoal goal, {required bool deposit}) async {
    HapticUtils.selection();
    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    List<Wallet> wallets = [];
    try {
      wallets = await ref.read(walletRepositoryProvider).getAll();
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        showErrorSnackBar(context, extractErrorMessage(e));
      }
      return;
    }

    if (!mounted) return;
    Navigator.pop(context);

    if (wallets.isEmpty) {
      showErrorSnackBar(context, 'Chưa có ví. Hãy tạo ví trước khi nạp/rút.');
      return;
    }

    final result = await showModalBottomSheet<_TransferSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TransferBottomSheet(
        goal: goal,
        deposit: deposit,
        wallets: wallets,
        moneyFmt: _moneyFmt,
      ),
    );

    if (result == null || !mounted) return;

    try {
      final repo = ref.read(savingGoalRepositoryProvider);
      if (deposit) {
        await repo.deposit(
          goalId: goal.id,
          walletId: result.walletId,
          amount: result.amount,
          note: result.note,
        );
      } else {
        await repo.withdraw(
          goalId: goal.id,
          walletId: result.walletId,
          amount: result.amount,
          note: result.note,
        );
      }
      await ref.read(syncServiceProvider).syncAllIfOnline();
      ref.read(transactionListRefreshTriggerProvider.notifier).state++;
      if (mounted) showSuccessSnackBar(context, deposit ? 'Đã nạp tiền vào mục tiêu' : 'Đã rút tiền từ mục tiêu');
      await _load();
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, extractErrorMessage(e));
    }
  }

  Future<void> _showHistory(SavingGoal goal) async {
    try {
      final txs = await ref.read(savingGoalRepositoryProvider).getTransactions(goal.id);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: txs.isEmpty ? 0.38 : 0.62,
          minChildSize: 0.32,
          maxChildSize: 0.9,
          builder: (ctx, scrollController) => Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, Color(0xFF01579B)],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.history_rounded, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Lịch sử nạp/rút',
                                style: GoogleFonts.nunito(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                goal.name,
                                style: GoogleFonts.nunito(color: Colors.white.withOpacity(0.92), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        _HistoryChip(
                          label: 'Đã tiết kiệm: ${_moneyFmt.format(goal.currentAmount)} ₫',
                        ),
                        _HistoryChip(label: '${txs.length} giao dịch'),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: txs.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.history_rounded, size: 48, color: AppColors.textMuted),
                              const SizedBox(height: 12),
                              Text(
                                'Chưa có giao dịch nạp/rút',
                                style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Các lần nạp hoặc rút tiền sẽ hiển thị tại đây',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        itemCount: txs.length,
                        itemBuilder: (_, i) {
                          final tx = txs[i];
                          final isDeposit = tx.type == 'DEPOSIT';
                          final accent = isDeposit ? AppColors.income : const Color(0xFFF57C00);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: accent.withOpacity(0.2)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: accent.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isDeposit ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
                                    color: accent,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              isDeposit ? 'Nạp tiền' : 'Rút tiền',
                                              style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                                            ),
                                          ),
                                          Text(
                                            '${isDeposit ? '+' : '-'}${_moneyFmt.format(tx.amount)} ₫',
                                            style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: accent),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '${tx.walletName ?? 'Ví'} · ${tx.createdAt.split('T').first}',
                                        style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                      if (tx.note != null && tx.note!.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          tx.note!,
                                          style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(extractErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalSaved = _goals.fold<double>(0, (s, g) => s + g.currentAmount);
    final completedCount = _goals.where((g) => g.isCompleted).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.gradientStart, AppColors.background],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: Text('Mục tiêu tiết kiệm', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
                actions: [
                  IconButton(onPressed: _showCreateDialog, icon: const Icon(Icons.add_rounded)),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mỗi mục tiêu là ví tiết kiệm nội bộ. Nạp/rút không tính vào thu/chi.',
                        style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      if (_goals.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _SummaryStatCard(
                              icon: Icons.savings_rounded,
                              iconColor: _green,
                              bgColor: const Color(0xFFE8F5E9),
                              borderColor: const Color(0xFFA5D6A7),
                              label: 'Tổng đã tiết kiệm',
                              value: '${_moneyFmt.format(totalSaved)} ₫',
                              valueColor: _green,
                            )),
                            const SizedBox(width: 12),
                            Expanded(child: _SummaryStatCard(
                              icon: Icons.trending_up_rounded,
                              iconColor: AppColors.primary,
                              bgColor: Colors.white,
                              borderColor: const Color(0xFFE0E0E0),
                              label: 'Mục tiêu',
                              value: '${_goals.length} · $completedCount hoàn thành',
                            )),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (_loading)
                        const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                      else if (_error != null)
                        Center(child: Text(_error!, style: GoogleFonts.nunito(color: AppColors.accent)))
                      else if (_goals.isEmpty)
                        _buildEmptyState()
                      else
                        ..._goals.map(_buildGoalCard),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.textMuted.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _green.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.savings_rounded, size: 36, color: _green),
          ),
          const SizedBox(height: 16),
          Text('Chưa có mục tiêu tiết kiệm',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 8),
          Text(
            'Tạo mục tiêu để theo dõi tiến độ tiết kiệm cho kế hoạch lớn của bạn.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _showCreateDialog,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Tạo mục tiêu đầu tiên'),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(SavingGoal g) {
    final color = _progressColor(g);
    final progress = (g.progressPercent / 100).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: g.isCompleted ? Border.all(color: _green.withOpacity(0.35)) : null,
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  g.isCompleted ? Icons.trending_up_rounded : Icons.savings_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.name, style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_statusLabel(g.status),
                    style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tiến độ', style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
              Text('${g.progressPercent.toStringAsFixed(1)}%',
                  style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: color.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _GoalInfoChip(
                  label: 'Đã tiết kiệm',
                  value: '${_moneyFmt.format(g.currentAmount)} ₫',
                  accentColor: color,
                  filled: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _GoalInfoChip(
                  label: 'Mục tiêu',
                  value: '${_moneyFmt.format(g.targetAmount)} ₫',
                ),
              ),
            ],
          ),
          if (g.targetDate != null) ...[
            const SizedBox(height: 8),
            _GoalInfoChip(
              label: 'Dự kiến hoàn thành',
              value: _formatTargetDate(g.targetDate!),
              icon: Icons.calendar_month_outlined,
              fullWidth: true,
            ),
          ],
          const SizedBox(height: 6),
          Text(
            g.isCompleted
                ? 'Chúc mừng! Bạn đã đạt mục tiêu.'
                : 'Còn thiếu ${_moneyFmt.format(g.remainingAmount)} ₫',
            style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: g.status == 'CANCELLED' || g.status == 'PAUSED'
                    ? null
                    : () => _showTransferDialog(g, deposit: true),
                child: const Text('Nạp tiền'),
              ),
              OutlinedButton(
                onPressed: g.currentAmount <= 0 || g.status == 'CANCELLED'
                    ? null
                    : () => _showTransferDialog(g, deposit: false),
                child: const Text('Rút tiền'),
              ),
              TextButton.icon(
                onPressed: () => _showHistory(g),
                icon: const Icon(Icons.history, size: 18),
                label: const Text('Lịch sử'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalInfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? accentColor;
  final bool filled;
  final IconData? icon;
  final bool fullWidth;

  const _GoalInfoChip({
    required this.label,
    required this.value,
    this.accentColor,
    this.filled = false,
    this.icon,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppColors.textPrimary;
    final child = Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: filled ? accent.withOpacity(0.08) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: filled ? accent.withOpacity(0.25) : const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: filled ? accent : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return child;
  }
}

class _SummaryStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color borderColor;
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryStatCard({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: valueColor ?? AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryChip extends StatelessWidget {
  final String label;

  const _HistoryChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }
}

class _TransferSheetResult {
  final int walletId;
  final double amount;
  final String? note;

  const _TransferSheetResult({
    required this.walletId,
    required this.amount,
    this.note,
  });
}

class _TransferBottomSheet extends StatefulWidget {
  final SavingGoal goal;
  final bool deposit;
  final List<Wallet> wallets;
  final NumberFormat moneyFmt;

  const _TransferBottomSheet({
    required this.goal,
    required this.deposit,
    required this.wallets,
    required this.moneyFmt,
  });

  @override
  State<_TransferBottomSheet> createState() => _TransferBottomSheetState();
}

class _TransferBottomSheetState extends State<_TransferBottomSheet> {
  late int _selectedWalletId;
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  Color get _headerColor => widget.deposit ? const Color(0xFF2E7D32) : const Color(0xFFF57C00);
  Color get _headerDark => widget.deposit ? const Color(0xFF1B5E20) : const Color(0xFFE65100);

  @override
  void initState() {
    super.initState();
    final defaultWallet = widget.wallets.where((w) => w.isDefault).firstOrNull ?? widget.wallets.first;
    _selectedWalletId = defaultWallet.id;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  double? _parseAmount(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  void _submit() {
    final amount = _parseAmount(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      showErrorSnackBar(context, 'Nhập số tiền hợp lệ');
      return;
    }
    final note = _noteCtrl.text.trim();
    Navigator.pop(
      context,
      _TransferSheetResult(
        walletId: _selectedWalletId,
        amount: amount,
        note: note.isEmpty ? null : note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_headerColor, _headerDark],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          widget.deposit ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.deposit ? 'Nạp tiền vào mục tiêu' : 'Rút tiền từ mục tiêu',
                              style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 17, color: Colors.white),
                            ),
                            Text(
                              widget.goal.name,
                              style: GoogleFonts.nunito(color: Colors.white.withValues(alpha: 0.92), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Số dư mục tiêu hiện tại',
                          style: GoogleFonts.nunito(fontSize: 12, color: Colors.white.withValues(alpha: 0.9)),
                        ),
                        Text(
                          '${widget.moneyFmt.format(widget.goal.currentAmount)} ₫',
                          style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 20, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<int>(
                      value: _selectedWalletId,
                      decoration: InputDecoration(
                        labelText: widget.deposit ? 'Ví nguồn' : 'Ví nhận',
                        prefixIcon: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      items: widget.wallets
                          .map(
                            (w) => DropdownMenuItem(
                              value: w.id,
                              child: Text(
                                '${w.name} · ${widget.moneyFmt.format(w.currentBalance ?? w.initialBalance)} ₫',
                                style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedWalletId = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Số tiền',
                        hintText: 'VD: 500.000',
                        suffixText: '₫',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onChanged: (v) {
                        final formatted = formatOnboardingAmount(v);
                        if (formatted != v) {
                          _amountCtrl.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(offset: formatted.length),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _noteCtrl,
                      decoration: InputDecoration(
                        labelText: 'Ghi chú (tùy chọn)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Giao dịch nạp/rút không tính vào chi tiêu hàng ngày.',
                        style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Hủy'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: _headerColor),
                        onPressed: _submit,
                        child: Text(widget.deposit ? 'Nạp tiền' : 'Rút tiền'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
