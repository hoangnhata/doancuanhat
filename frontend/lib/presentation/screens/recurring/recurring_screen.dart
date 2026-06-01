import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/providers/app_providers.dart';
import 'package:expense_manager/domain/models/recurring_transaction.dart';
import 'package:expense_manager/domain/models/category.dart';
import 'package:expense_manager/domain/models/transaction.dart';
import 'package:expense_manager/core/utils/snackbar_utils.dart' show showSuccessSnackBar, showErrorSnackBar;
import 'package:expense_manager/core/utils/haptic_utils.dart';
import 'package:expense_manager/domain/repositories/recurring_transaction_repository.dart';

class RecurringScreen extends ConsumerStatefulWidget {
  const RecurringScreen({super.key});

  @override
  ConsumerState<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends ConsumerState<RecurringScreen> {
  List<RecurringTransaction> _list = [];
  bool _loading = true;
  String? _error;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(recurringTransactionRepositoryProvider);
      _list = await repo.getAll();
      setState(() => _error = null);
    } catch (e) {
      setState(() => _error = e.toString());
    }
    setState(() => _loading = false);
  }

  Future<void> _showAddSheet({RecurringTransaction? edit}) async {
    List<Category> categories = [];
    try {
      categories = await ref.read(categoryRepositoryProvider).getAll();
    } catch (_) {}

    if (!mounted) return;
    if (categories.isEmpty) {
      showErrorSnackBar(context, 'Vui lòng tạo danh mục trước');
      return;
    }

    final amountController = TextEditingController(text: edit?.amount.toString() ?? '');
    final descController = TextEditingController(text: edit?.description ?? '');
    Category? selectedCategory = edit != null
        ? categories.firstWhere((c) => c.id == edit.category.id, orElse: () => categories.first)
        : categories.first;
    int dayOfMonth = edit?.dayOfMonth ?? DateTime.now().day.clamp(1, 28);
    DateTime startDate = edit?.startDate ?? DateTime.now();
    DateTime? endDate = edit?.endDate;
    String type = edit != null
        ? (edit.type == TransactionType.income ? 'INCOME' : 'EXPENSE')
        : 'EXPENSE';

    final categoriesFiltered = type == 'INCOME'
        ? categories.where((c) => c.type == CategoryType.income).toList()
        : categories.where((c) => c.type == CategoryType.expense).toList();
    if (categoriesFiltered.isNotEmpty && !categoriesFiltered.contains(selectedCategory)) {
      selectedCategory = categoriesFiltered.first;
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    edit != null ? 'Sửa giao dịch định kỳ' : 'Thêm giao dịch định kỳ',
                    style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'Loại'),
                    items: const [
                      DropdownMenuItem(value: 'EXPENSE', child: Text('Chi tiêu')),
                      DropdownMenuItem(value: 'INCOME', child: Text('Thu nhập')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setModalState(() {
                          type = v;
                          final filtered = v == 'INCOME'
                              ? categories.where((c) => c.type == CategoryType.income).toList()
                              : categories.where((c) => c.type == CategoryType.expense).toList();
                          selectedCategory = filtered.isNotEmpty ? filtered.first : null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Số tiền (₫)'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Category>(
                    value: selectedCategory,
                    decoration: const InputDecoration(labelText: 'Danh mục'),
                    items: (type == 'INCOME'
                            ? categories.where((c) => c.type == CategoryType.income)
                            : categories.where((c) => c.type == CategoryType.expense))
                        .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                        .toList(),
                    onChanged: (c) => setModalState(() => selectedCategory = c),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'Ghi chú (tùy chọn)'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: dayOfMonth,
                    decoration: const InputDecoration(labelText: 'Ngày chạy mỗi tháng (1-28)'),
                    items: List.generate(28, (i) => i + 1)
                        .map((d) => DropdownMenuItem(value: d, child: Text('Ngày $d')))
                        .toList(),
                    onChanged: (d) => setModalState(() => dayOfMonth = d ?? 1),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: Text('Từ ngày: ${DateFormat('dd/MM/yyyy').format(startDate)}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (d != null) setModalState(() => startDate = d);
                    },
                  ),
                  ListTile(
                    title: Text(
                      endDate != null
                          ? 'Đến ngày: ${DateFormat('dd/MM/yyyy').format(endDate!)}'
                          : 'Đến ngày: Không giới hạn',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: endDate ?? startDate.add(const Duration(days: 365)),
                        firstDate: startDate,
                        lastDate: DateTime(2030),
                      );
                      if (d != null) setModalState(() => endDate = d);
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Hủy'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (amountController.text.trim().isEmpty ||
                                selectedCategory == null ||
                                double.tryParse(amountController.text.replaceAll(',', '')) == null) {
                              return;
                            }
                            Navigator.pop(ctx, true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(edit != null ? 'Cập nhật' : 'Thêm'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (result == true && amountController.text.trim().isNotEmpty && selectedCategory != null) {
      final amount = double.tryParse(amountController.text.replaceAll(',', ''));
      if (amount != null && amount > 0) {
        final data = RecurringTransactionCreateData(
          type: type,
          amount: amount,
          description: descController.text.trim().isEmpty ? null : descController.text.trim(),
          dayOfMonth: dayOfMonth,
          startDate: startDate,
          endDate: endDate,
          categoryId: selectedCategory!.id,
        );
        try {
          if (edit != null) {
            await ref.read(recurringTransactionRepositoryProvider).update(edit.id, data);
            if (mounted) showSuccessSnackBar(context, 'Đã cập nhật');
          } else {
            await ref.read(recurringTransactionRepositoryProvider).create(data);
            if (mounted) showSuccessSnackBar(context, 'Đã thêm giao dịch định kỳ');
          }
          HapticUtils.medium();
          _load();
        } catch (e) {
          if (mounted) showErrorSnackBar(context, e.toString());
        }
      }
    }
  }

  Future<void> _toggle(RecurringTransaction rt) async {
    try {
      await ref.read(recurringTransactionRepositoryProvider).toggleActive(rt.id);
      HapticUtils.medium();
      _load();
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e.toString());
    }
  }

  Future<void> _delete(RecurringTransaction rt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa giao dịch định kỳ?'),
        content: Text(
          'Bạn có chắc muốn xóa "${rt.description ?? rt.category.name}"?',
        ),
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
    if (confirm == true) {
      try {
        await ref.read(recurringTransactionRepositoryProvider).delete(rt.id);
        HapticUtils.medium();
        if (mounted) showSuccessSnackBar(context, 'Đã xóa');
        _load();
      } catch (e) {
        if (mounted) showErrorSnackBar(context, e.toString());
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Giao dịch định kỳ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showAddSheet(),
          ),
        ],
      ),
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
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Giao dịch chạy định kỳ mỗi tháng',
                  style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(_error!, style: GoogleFonts.nunito(color: AppColors.accent)),
                  )
                else if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_list.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppColors.softShadow,
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.repeat_rounded, size: 48, color: AppColors.textMuted),
                          const SizedBox(height: 16),
                          Text(
                            'Chưa có giao dịch định kỳ',
                            style: GoogleFonts.nunito(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => _showAddSheet(),
                            child: const Text('Thêm giao dịch định kỳ'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ..._list.map(
                    (rt) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AppColors.softShadow,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: (rt.type == TransactionType.income
                                    ? Colors.green
                                    : AppColors.primary)
                                .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            rt.type == TransactionType.income
                                ? Icons.trending_up_rounded
                                : Icons.trending_down_rounded,
                            color: rt.type == TransactionType.income ? Colors.green : AppColors.primary,
                          ),
                        ),
                        title: Text(
                          rt.description ?? rt.category.name,
                          style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${rt.category.name} • Ngày ${rt.dayOfMonth} hàng tháng${rt.endDate != null ? " • Đến ${DateFormat('dd/MM/yyyy').format(rt.endDate!)}" : ""}',
                          style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${NumberFormat.compact(locale: 'vi').format(rt.amount)} ₫',
                              style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w700,
                                color: rt.type == TransactionType.income
                                    ? Colors.green
                                    : AppColors.primary,
                              ),
                            ),
                            Switch(
                              value: rt.isActive,
                              onChanged: (_) => _toggle(rt),
                              activeTrackColor: AppColors.primary.withOpacity(0.5),
                              activeThumbColor: AppColors.primary,
                            ),
                            PopupMenuButton<String>(
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(value: 'edit', child: Text('Sửa')),
                                const PopupMenuItem(value: 'delete', child: Text('Xóa')),
                              ],
                              onSelected: (v) {
                                if (v == 'edit') _showAddSheet(edit: rt);
                                if (v == 'delete') _delete(rt);
                              },
                            ),
                          ],
                        ),
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
