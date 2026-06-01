import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/providers/app_providers.dart';
import 'package:expense_manager/core/utils/snackbar_utils.dart';
import 'package:expense_manager/domain/models/transaction.dart';

class MilestonesScreen extends ConsumerStatefulWidget {
  const MilestonesScreen({super.key});

  @override
  ConsumerState<MilestonesScreen> createState() => _MilestonesScreenState();
}

class _MilestonesScreenState extends ConsumerState<MilestonesScreen> {
  double _totalSavings = 0;
  int _daysNoSpend = 0;
  int _transactionCount = 0;
  double? _savingsGoal;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final statsRepo = ref.read(statisticsRepositoryProvider);
      final txRepo = ref.read(transactionRepositoryProvider);
      final userAsync = ref.read(currentUserProvider);

      final monthStats = await statsRepo.getByMonth(DateTime.now().year, DateTime.now().month);
      final allTx = await txRepo.getAll(page: 0, size: 500);
      final user = userAsync.valueOrNull;

      final savings = monthStats.totalIncome - monthStats.totalExpense;
      setState(() {
        _totalSavings = savings > 0 ? savings : 0;
        _transactionCount = allTx.totalElements;
        _daysNoSpend = _calculateDaysNoSpend(allTx.items);
        _savingsGoal = user?.savingsGoalMonthly;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showSetGoalSheet() async {
    final controller = TextEditingController(
      text: _savingsGoal != null && _savingsGoal! > 0
          ? NumberFormat().format(_savingsGoal!.toInt())
          : '',
    );
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Mục tiêu tiết kiệm tháng', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Số tiền (₫)',
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final raw = controller.text.replaceAll(RegExp(r'[^\d.]'), '');
                  final val = double.tryParse(raw) ?? 0;
                  if (val > 0) {
                    try {
                      final user = await ref.read(userRepositoryProvider).updateProfile(savingsGoalMonthly: val);
                      ref.invalidate(currentUserProvider);
                      if (!mounted) return;
                      setState(() => _savingsGoal = user.savingsGoalMonthly);
                      showSuccessSnackBar(context, 'Đã lưu mục tiêu tiết kiệm');
                      Navigator.pop(ctx, true);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Không lưu được: $e')),
                        );
                      }
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text('Lưu', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == true) _loadData();
  }

  int _calculateDaysNoSpend(List<Transaction> items) {
    if (items.isEmpty) return 0;
    final expenses = items.where((t) => t.type == TransactionType.expense).toList();
    final spendDates = expenses.map((t) => DateTime(t.transactionDate.year, t.transactionDate.month, t.transactionDate.day)).toSet();
    final now = DateTime.now();
    int days = 0;
    for (var d = now.day; d >= 1; d--) {
      final date = DateTime(now.year, now.month, d);
      if (spendDates.contains(date)) break;
      days++;
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.compact(locale: 'vi');
    return Scaffold(
      appBar: AppBar(
        title: Text('Những cột mốc', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.gradientStart, AppColors.background],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MilestoneCard(
                        icon: Icons.savings_rounded,
                        title: 'Tiết kiệm tháng này',
                        value: '${fmt.format(_totalSavings)}₫',
                        color: AppColors.income,
                        subtitle: 'Thu nhập - Chi phí',
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _showSetGoalSheet,
                        child: _savingsGoal != null && _savingsGoal! > 0
                            ? _SavingsGoalCard(
                                current: _totalSavings,
                                goal: _savingsGoal!,
                                onEdit: _showSetGoalSheet,
                              )
                            : Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: AppColors.textMuted.withOpacity(0.3)),
                                  boxShadow: AppColors.softShadow,
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.flag_rounded, size: 32, color: AppColors.primary),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Mục tiêu tiết kiệm', style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textSecondary)),
                                          Text('Chạm để đặt mục tiêu (VD: 10 triệu/tháng)', style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textMuted)),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.edit_rounded, color: AppColors.textMuted),
                                  ],
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),
                      _MilestoneCard(
                        icon: Icons.trending_up_rounded,
                        title: 'Số giao dịch',
                        value: '$_transactionCount',
                        color: AppColors.primary,
                        subtitle: 'Tổng giao dịch đã ghi',
                      ),
                      const SizedBox(height: 16),
                      _MilestoneCard(
                        icon: Icons.calendar_today_rounded,
                        title: 'Ngày không chi tiêu',
                        value: '$_daysNoSpend',
                        color: const Color(0xFFFFB347),
                        subtitle: 'Liên tiếp gần đây',
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Tiếp tục theo dõi để đạt thêm cột mốc!',
                        style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _SavingsGoalCard extends StatelessWidget {
  final double current;
  final double goal;
  final VoidCallback onEdit;

  const _SavingsGoalCard({required this.current, required this.goal, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.compact(locale: 'vi');
    final percent = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(24),
        child: Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_rounded, size: 28, color: AppColors.primary),
              const SizedBox(width: 12),
              Text('Mục tiêu tiết kiệm', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: percent,
            minHeight: 10,
            backgroundColor: AppColors.textMuted.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation(percent >= 1 ? AppColors.income : AppColors.primary),
          ),
          const SizedBox(height: 8),
          Text(
            '${fmt.format(current)}₫ / ${fmt.format(goal)}₫ (${(percent * 100).toStringAsFixed(0)}%)',
            style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text('Chạm để sửa mục tiêu', style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
        ),
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final String subtitle;

  const _MilestoneCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 32, color: color),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(value, style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
                Text(subtitle, style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
