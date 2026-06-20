import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:expense_manager/core/providers/app_providers.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/utils/api_error.dart';
import 'package:expense_manager/domain/models/category.dart';
import 'package:expense_manager/domain/models/spending_limit.dart';
import 'package:expense_manager/presentation/widgets/category/category_select_field.dart';
import 'package:expense_manager/presentation/widgets/common/card_container.dart';
import 'package:expense_manager/presentation/widgets/onboarding/onboarding_form_widgets.dart';

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  List<SpendingLimit> _limits = [];
  bool _isLoading = true;
  String? _error;

  static final _moneyFmt = NumberFormat('#,###', 'vi');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final list = await ref.read(spendingLimitRepositoryProvider).getAll();
      setState(() {
        _limits = list;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = extractErrorMessage(e));
    }
    setState(() => _isLoading = false);
  }

  Future<void> _showCreateDialog() async {
    List<Category> categories = [];
    try {
      categories = await ref.read(categoryRepositoryProvider).getAll(type: 'EXPENSE');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(extractErrorMessage(e))));
      return;
    }
    if (categories.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng tạo danh mục chi tiêu trước')),
      );
      return;
    }

    final usedCategoryIds = _limits.map((l) => l.category?.id).whereType<int>().toSet();
    final available = categories.where((c) => !usedCategoryIds.contains(c.id)).toList();
    if (available.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tất cả danh mục đã có hạn mức')),
      );
      return;
    }

    final amountController = TextEditingController();
    var selected = available.first;
    var warning = 80;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Tạo hạn mức chi tiêu', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CategorySelectField(
                  categories: available,
                  value: selected,
                  onChanged: (c) => setLocal(() => selected = c ?? selected),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Số tiền hạn mức',
                    prefixIcon: Icon(Icons.payments_outlined, color: AppColors.primary),
                    suffixText: '₫',
                  ),
                  onChanged: (v) {
                    final f = formatOnboardingAmount(v);
                    if (f != v) {
                      amountController.value = TextEditingValue(
                        text: f,
                        selection: TextSelection.collapsed(offset: f.length),
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
                const OnboardingPeriodField(),
                const SizedBox(height: 12),
                OnboardingWarningSlider(
                  value: warning,
                  onChanged: (v) => setLocal(() => warning = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Tạo')),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;
    final amount = double.tryParse(amountController.text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (amount == null || amount <= 0) return;

    try {
      await ref.read(spendingLimitRepositoryProvider).create(
            amount: amount,
            categoryId: selected.id,
            warningThresholdPercent: warning,
          );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(extractErrorMessage(e))));
    }
  }

  Future<void> _showEditDialog(SpendingLimit limit) async {
    List<Category> categories = [];
    try {
      categories = await ref.read(categoryRepositoryProvider).getAll(type: 'EXPENSE');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(extractErrorMessage(e))));
      return;
    }

    final usedCategoryIds =
        _limits.where((l) => l.id != limit.id).map((l) => l.category?.id).whereType<int>().toSet();
    final available = categories.where((c) => !usedCategoryIds.contains(c.id)).toList();
    if (available.isEmpty) return;

    final amountController = TextEditingController(
      text: formatOnboardingAmount(limit.limitAmount.round().toString()),
    );
    var selected = available.firstWhere(
      (c) => c.id == limit.category?.id,
      orElse: () => available.first,
    );
    var warning = limit.warningThresholdPercent ?? 80;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Sửa hạn mức chi tiêu', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CategorySelectField(
                  categories: available,
                  value: selected,
                  onChanged: (c) => setLocal(() => selected = c ?? selected),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Số tiền hạn mức',
                    prefixIcon: Icon(Icons.payments_outlined, color: AppColors.primary),
                    suffixText: '₫',
                  ),
                  onChanged: (v) {
                    final f = formatOnboardingAmount(v);
                    if (f != v) {
                      amountController.value = TextEditingValue(
                        text: f,
                        selection: TextSelection.collapsed(offset: f.length),
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
                const OnboardingPeriodField(),
                const SizedBox(height: 12),
                OnboardingWarningSlider(
                  value: warning,
                  onChanged: (v) => setLocal(() => warning = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cập nhật')),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;
    final amount = double.tryParse(amountController.text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (amount == null || amount <= 0) return;

    try {
      await ref.read(spendingLimitRepositoryProvider).update(
            id: limit.id,
            amount: amount,
            categoryId: selected.id,
            warningThresholdPercent: warning,
          );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(extractErrorMessage(e))));
    }
  }

  Future<void> _delete(SpendingLimit limit) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vô hiệu hóa hạn mức?'),
        content: Text('Xóa hạn mức "${limit.category?.name ?? ''}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(spendingLimitRepositoryProvider).delete(limit.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(extractErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final warningCount = _limits.where((l) => l.status != SpendingLimitStatus.safe).length;

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
                title: Text('Hạn mức chi tiêu', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
                actions: [
                  IconButton(
                    onPressed: _showCreateDialog,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(
                      'Kiểm soát chi tiêu theo danh mục trong từng tháng.',
                      style: GoogleFonts.nunito(color: AppColors.textSecondary, height: 1.45),
                    ),
                    if (!_isLoading && _limits.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _SummaryChip(
                            label: '${_limits.length} hạn mức',
                            icon: Icons.speed_rounded,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 10),
                          if (warningCount > 0)
                            _SummaryChip(
                              label: '$warningCount cảnh báo',
                              icon: Icons.warning_amber_rounded,
                              color: const Color(0xFFFF9800),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (_error != null)
                      CardContainer(
                        child: Text(_error!, style: GoogleFonts.nunito(color: AppColors.accent)),
                      )
                    else if (_isLoading)
                      const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()))
                    else if (_limits.isEmpty)
                      CardContainer(
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(Icons.speed_rounded, color: AppColors.primary, size: 32),
                            ),
                            const SizedBox(height: 16),
                            Text('Chưa có hạn mức chi tiêu', style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 17)),
                            const SizedBox(height: 8),
                            Text(
                              'Đặt hạn mức theo danh mục để kiểm soát chi tiêu hàng tháng.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.nunito(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: _showCreateDialog,
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Tạo hạn mức đầu tiên'),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._limits.asMap().entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _LimitTile(
                            limit: e.value,
                            colorIndex: e.key,
                            moneyFmt: _moneyFmt,
                            onEdit: () => _showEditDialog(e.value),
                            onDelete: () => _delete(e.value),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _SummaryChip({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
        ],
      ),
    );
  }
}

class _LimitTile extends StatelessWidget {
  final SpendingLimit limit;
  final int colorIndex;
  final NumberFormat moneyFmt;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _LimitTile({
    required this.limit,
    required this.colorIndex,
    required this.moneyFmt,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = limit.category?.name ?? 'Danh mục';
    final status = limit.status;
    Color statusColor;
    String statusLabel;
    switch (status) {
      case SpendingLimitStatus.exceeded:
        statusColor = AppColors.expense;
        statusLabel = 'Vượt hạn mức';
        break;
      case SpendingLimitStatus.warning:
        statusColor = const Color(0xFFFF9800);
        statusLabel = 'Sắp vượt';
        break;
      default:
        statusColor = AppColors.income;
        statusLabel = 'An toàn';
    }

    final barColor = status == SpendingLimitStatus.exceeded
        ? AppColors.expense
        : status == SpendingLimitStatus.warning
            ? const Color(0xFFFF9800)
            : AppColors.primary;
    final progress = (limit.usagePercent / 100).clamp(0.0, 1.0);
    final remaining = limit.remainingAmount.clamp(0, double.infinity);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: status != SpendingLimitStatus.safe
            ? Border.all(color: statusColor.withOpacity(0.35))
            : null,
        boxShadow: status != SpendingLimitStatus.safe
            ? [
                BoxShadow(
                  color: statusColor.withOpacity(0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CategoryIconBadge(
                name: name,
                icon: limit.category?.icon,
                colorIndex: colorIndex,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      'Kỳ: ${limit.startDate} → ${limit.endDate}',
                      style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tiến độ chi tiêu',
                style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted),
              ),
              Text(
                '${limit.usagePercent.toStringAsFixed(1)}%',
                style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800, color: barColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: barColor.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _LimitInfoChip(
                  label: 'Đã chi',
                  value: '${moneyFmt.format(limit.currentSpent)} ₫',
                  accentColor: barColor,
                  filled: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _LimitInfoChip(
                  label: 'Hạn mức',
                  value: '${moneyFmt.format(limit.limitAmount)} ₫',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _LimitInfoChip(
            label: 'Còn lại · Cảnh báo từ ${limit.warningThresholdPercent ?? 80}%',
            value: '${moneyFmt.format(remaining)} ₫',
            icon: Icons.speed_rounded,
            fullWidth: true,
          ),
          if (limit.statusMessage != null && limit.statusMessage!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              limit.statusMessage!,
              style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Sửa'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.accent),
                  label: Text('Xóa', style: GoogleFonts.nunito(color: AppColors.accent)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LimitInfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? accentColor;
  final bool filled;
  final IconData? icon;
  final bool fullWidth;

  const _LimitInfoChip({
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
    return Container(
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
  }
}
