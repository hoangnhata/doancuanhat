import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/utils/api_error.dart';
import 'package:expense_manager/domain/models/budget.dart';
import 'package:expense_manager/domain/models/category.dart';
import 'package:expense_manager/domain/repositories/budget_repository.dart';
import 'package:expense_manager/core/providers/app_providers.dart';
import 'package:expense_manager/presentation/widgets/common/card_container.dart';

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  List<Budget> _budgets = [];
  bool _isLoading = true;
  String? _error;

  static final _compactFmt = NumberFormat.compact(locale: 'vi');

  @override
  void initState() {
    super.initState();
    _loadBudgets();
  }

  Future<void> _loadBudgets() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(budgetRepositoryProvider);
      final list = await repo.getAll(page: 0, size: 100);
      list.sort((a, b) => b.endDate.compareTo(a.endDate));
      setState(() {
        _budgets = list;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = extractErrorMessage(e));
    }
    setState(() => _isLoading = false);
  }

  double? _parseAmountInput(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return double.tryParse(digits);
  }

  _BudgetStatus _status(Budget b) {
    final now = DateTime.now();
    final d = DateTime(now.year, now.month, now.day);
    final s = DateTime(b.startDate.year, b.startDate.month, b.startDate.day);
    final e = DateTime(b.endDate.year, b.endDate.month, b.endDate.day);
    if (d.isBefore(s)) return _BudgetStatus.upcoming;
    if (d.isAfter(e)) return _BudgetStatus.ended;
    return _BudgetStatus.active;
  }

  Future<void> _showBudgetDialog({Budget? existing}) async {
    List<Category> categories = [];
    try {
      categories = await ref.read(categoryRepositoryProvider).getAll(type: 'EXPENSE');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tải được danh mục: ${extractErrorMessage(e)}')),
      );
      return;
    }

    if (!mounted) return;
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng tạo danh mục chi tiêu trước')),
      );
      return;
    }

    final amountController = TextEditingController(
      text: existing != null ? existing.amount.round().toString() : '',
    );
    var selectedCategory = categories.first;
    if (existing != null) {
      for (final c in categories) {
        if (c.id == existing.category.id) {
          selectedCategory = c;
          break;
        }
      }
    }
    var startDate = existing != null
        ? DateTime(existing.startDate.year, existing.startDate.month, existing.startDate.day)
        : DateTime(DateTime.now().year, DateTime.now().month, 1);
    var endDate = existing != null
        ? DateTime(existing.endDate.year, existing.endDate.month, existing.endDate.day)
        : DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
    final noteController = TextEditingController(text: existing?.note ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Thêm ngân sách' : 'Sửa ngân sách'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Số tiền (₫)',
                    hintText: existing == null ? 'VD: 2000000' : null,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Category>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Danh mục chi tiêu'),
                  items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                  onChanged: (c) {
                    if (c != null) setLocal(() => selectedCategory = c);
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Từ ngày'),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(startDate)),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: startDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (d != null) setLocal(() => startDate = d);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Đến ngày'),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(endDate)),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: endDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (d != null) setLocal(() => endDate = d);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú (tuỳ chọn)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(existing == null ? 'Thêm' : 'Lưu'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    final amount = _parseAmountInput(amountController.text);
    if (amount == null || amount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nhập số tiền hợp lệ (lớn hơn 0)')),
        );
      }
      return;
    }

    final sd = DateTime(startDate.year, startDate.month, startDate.day);
    final ed = DateTime(endDate.year, endDate.month, endDate.day);
    if (ed.isBefore(sd)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ngày kết thúc phải sau hoặc cùng ngày bắt đầu')),
        );
      }
      return;
    }

    final data = BudgetCreateData(
      amount: amount,
      startDate: sd,
      endDate: ed,
      categoryId: selectedCategory.id,
      note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
    );

    try {
      if (existing == null) {
        await ref.read(budgetRepositoryProvider).create(data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã thêm ngân sách', style: GoogleFonts.nunito())),
          );
        }
      } else {
        await ref.read(budgetRepositoryProvider).update(existing.id, data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã cập nhật ngân sách', style: GoogleFonts.nunito())),
          );
        }
      }
      await _loadBudgets();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(extractErrorMessage(e), style: GoogleFonts.nunito())),
        );
      }
    }
  }

  Future<void> _deleteBudget(Budget b) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa ngân sách?'),
        content: Text('Bạn có chắc muốn xóa ngân sách "${b.category.name}"?'),
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
    if (confirm != true) return;
    try {
      await ref.read(budgetRepositoryProvider).delete(b.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xóa ngân sách', style: GoogleFonts.nunito())),
        );
      }
      await _loadBudgets();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(extractErrorMessage(e), style: GoogleFonts.nunito())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ngân sách'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showBudgetDialog(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadBudgets,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Đặt giới hạn chi theo danh mục và kỳ. Đã chi được tính từ giao dịch chi tiêu cùng danh mục trong kỳ.',
                style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary, height: 1.35),
              ),
              const SizedBox(height: 20),
              if (_error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(_error!, style: GoogleFonts.nunito(color: AppColors.accent)),
                )
              else if (_isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()))
              else if (_budgets.isEmpty)
                CardContainer(
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.account_balance_wallet_rounded, size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 16),
                        Text(
                          'Chưa có ngân sách',
                          style: GoogleFonts.nunito(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => _showBudgetDialog(),
                          child: const Text('Thêm ngân sách'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._budgets.map((b) => _BudgetTile(
                      budget: b,
                      status: _status(b),
                      onEdit: () => _showBudgetDialog(existing: b),
                      onDelete: () => _deleteBudget(b),
                      compactFmt: _compactFmt,
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

enum _BudgetStatus { active, upcoming, ended }

class _BudgetTile extends StatelessWidget {
  final Budget budget;
  final _BudgetStatus status;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final NumberFormat compactFmt;

  const _BudgetTile({
    required this.budget,
    required this.status,
    required this.onEdit,
    required this.onDelete,
    required this.compactFmt,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = budget.usageRatio.clamp(0.0, 2.0);
    final barValue = ratio > 1 ? 1.0 : ratio;
    final over = budget.spentAmount > budget.amount;

    Color barColor;
    if (over) {
      barColor = AppColors.expense;
    } else if (ratio >= 0.85) {
      barColor = const Color(0xFFFF9800);
    } else {
      barColor = AppColors.primary;
    }

    String statusLabel;
    Color statusBg;
    switch (status) {
      case _BudgetStatus.active:
        statusLabel = 'Đang hiệu lực';
        statusBg = AppColors.income.withOpacity(0.2);
        break;
      case _BudgetStatus.upcoming:
        statusLabel = 'Sắp tới';
        statusBg = AppColors.primary.withOpacity(0.15);
        break;
      case _BudgetStatus.ended:
        statusLabel = 'Đã kết thúc';
        statusBg = AppColors.textMuted.withOpacity(0.2);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusLabel,
                        style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      color: AppColors.primary,
                      onPressed: onEdit,
                      tooltip: 'Sửa',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      color: AppColors.accent,
                      onPressed: onDelete,
                      tooltip: 'Xóa',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  budget.category.name,
                  style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${DateFormat('dd/MM/yyyy').format(budget.startDate)} — ${DateFormat('dd/MM/yyyy').format(budget.endDate)}',
                  style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ngân sách',
                      style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    Text(
                      '${compactFmt.format(budget.amount)} ₫',
                      style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Đã chi',
                      style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    Text(
                      '${compactFmt.format(budget.spentAmount)} ₫',
                      style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.expense),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      over ? 'Vượt ngân sách' : 'Còn lại',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: over ? AppColors.expense : AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${compactFmt.format(over ? (budget.spentAmount - budget.amount) : budget.remainingAmount)} ₫',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w700,
                        color: over ? AppColors.expense : AppColors.income,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: barValue,
                    minHeight: 8,
                    backgroundColor: AppColors.surface,
                    color: barColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(ratio * 100).clamp(0, 999).toStringAsFixed(0)}% ngân sách đã dùng',
                  style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textMuted),
                ),
                if (budget.note != null && budget.note!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    budget.note!,
                    style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
