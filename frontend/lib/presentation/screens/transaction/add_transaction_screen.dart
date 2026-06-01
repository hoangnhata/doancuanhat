import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/utils/api_error.dart' show extractErrorMessage;
import 'package:expense_manager/core/utils/haptic_utils.dart';
import 'package:expense_manager/core/utils/transaction_text_parse.dart';
import 'package:expense_manager/core/utils/snackbar_utils.dart';
import 'package:expense_manager/domain/models/category.dart';
import 'package:expense_manager/domain/models/ai_categorize.dart';
import 'package:expense_manager/domain/models/ocr_receipt.dart';
import 'package:expense_manager/domain/models/transaction.dart';
import 'package:expense_manager/domain/models/wallet.dart';
import 'package:expense_manager/domain/repositories/transaction_repository.dart';
import 'package:expense_manager/core/providers/app_providers.dart';
import 'package:expense_manager/core/router/app_router.dart';
import 'package:expense_manager/presentation/widgets/common/card_container.dart';
import 'package:expense_manager/presentation/widgets/transaction/receipt_ocr_sheet.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final Transaction? transactionToEdit;

  const AddTransactionScreen({super.key, this.transactionToEdit});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _naturalInputController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  late bool _isExpense;
  late DateTime _selectedDate;
  Category? _selectedCategory;
  Wallet? _selectedWallet;
  List<Category> _expenseCategories = [];
  List<Category> _incomeCategories = [];
  List<Wallet> _wallets = [];
  bool _isLoadingMeta = true;
  bool _isAiLoading = false;
  bool _isSaving = false;
  String? _error;
  String? _categoriesLoadError;

  bool get _isEditMode => widget.transactionToEdit != null;

  @override
  void initState() {
    super.initState();
    _loadCategoriesAndWallets();
    if (widget.transactionToEdit != null) {
      final t = widget.transactionToEdit!;
      _isExpense = t.type == TransactionType.expense;
      _selectedDate = t.transactionDate;
      _amountController.text = t.amount.toStringAsFixed(0);
      _descriptionController.text = t.description ?? '';
    } else {
      _isExpense = true;
      _selectedDate = DateTime.now();
    }
  }

  /// Một lần setState khi xong — tránh rebuild cả màn (và reset IME) hai lần liền khi tải danh mục + ví.
  Future<void> _loadCategoriesAndWallets() async {
    _categoriesLoadError = null;
    try {
      final catRepo = ref.read(categoryRepositoryProvider);
      final walletRepo = ref.read(walletRepositoryProvider);
      final r = await Future.wait([
        catRepo.getAll(type: 'EXPENSE'),
        catRepo.getAll(type: 'INCOME'),
        walletRepo.getAll(),
      ]);
      _expenseCategories = r[0] as List<Category>;
      _incomeCategories = r[1] as List<Category>;
      _wallets = r[2] as List<Wallet>;

      if (_selectedCategory == null) {
        if (_isEditMode && widget.transactionToEdit != null) {
          _selectedCategory = widget.transactionToEdit!.category;
        } else if (_expenseCategories.isNotEmpty) {
          _selectedCategory = _isExpense ? _expenseCategories.first : (_incomeCategories.isNotEmpty ? _incomeCategories.first : null);
        }
      }
      if (_selectedWallet == null && _wallets.isNotEmpty) {
        if (_isEditMode && widget.transactionToEdit?.walletId != null) {
          _selectedWallet = _wallets.where((w) => w.id == widget.transactionToEdit!.walletId).firstOrNull;
        }
        _selectedWallet ??= _wallets.firstWhere((w) => w.isDefault, orElse: () => _wallets.first);
      }
    } catch (e) {
      _categoriesLoadError = extractErrorMessage(e);
    }
    if (mounted) setState(() => _isLoadingMeta = false);
  }

  Future<void> _scanReceipt() async {
    HapticUtils.selection();
    final OcrReceiptResult? r = await showReceiptOcrSheet(context, ref);
    if (r == null || !mounted) return;

    setState(() {
      _isExpense = r.transactionType.toUpperCase() != 'INCOME';
      if (r.amount != null) {
        _amountController.text = r.amount!.toStringAsFixed(0);
      }
      if (r.transactionDate != null) {
        _selectedDate = r.transactionDate!;
      }
      final desc = r.description ?? r.merchant;
      if (desc != null && desc.isNotEmpty) {
        _descriptionController.text = desc;
      }
      final pool = _isExpense ? _expenseCategories : _incomeCategories;
      final matches = pool.where(
        (c) => c.id == r.categoryId || c.name == r.categoryName,
      );
      if (matches.isNotEmpty) {
        _selectedCategory = matches.first;
      } else if (pool.isNotEmpty && _selectedCategory == null) {
        _selectedCategory = pool.first;
      }
      _error = r.needsReview
          ? 'AI chưa chắc chắn — kiểm tra lại số tiền và danh mục trước khi lưu.'
          : null;
    });
  }

  Future<void> _aiCategorize() async {
    final text = _naturalInputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isAiLoading = true;
      _error = null;
    });

    try {
      final user = ref.read(currentUserProvider).value;
      final isBatch = RegExp(
        r'(;|\n|\+|&)|,\s*(?!\d)|\s+và\s+',
        caseSensitive: false,
      ).hasMatch(text);
      if (isBatch) {
        final results = await ref.read(transactionRepositoryProvider).aiCategorizeBatch(text, personality: user?.botPersonality);
        if (!mounted) return;
        setState(() => _isAiLoading = false);
        await _showBatchDialog(results);
      } else {
        final result = await ref.read(transactionRepositoryProvider).aiCategorize(text, personality: user?.botPersonality);
        setState(() {
          _isExpense = result.transactionType.toUpperCase() != 'INCOME';
          if (result.amount != null) _amountController.text = result.amount!.toStringAsFixed(0);
          _descriptionController.text = result.description;
          final txDate = result.transactionDate ?? extractDateFromNaturalText(text);
          if (txDate != null) _selectedDate = txDate;
          final pool = _isExpense ? _expenseCategories : _incomeCategories;
          final matches = pool.where((c) => c.id == result.categoryId || c.name == result.categoryName);
          if (matches.isNotEmpty) _selectedCategory = matches.first;
          _isAiLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Không thể phân loại. Vui lòng nhập thủ công.';
        _isAiLoading = false;
      });
    }
  }

  Future<void> _showBatchDialog(List<AICategorizeResult> items) async {
    if (items.isEmpty) {
      setState(() => _error = 'Không nhận diện được khoản nào. Hãy thử ngăn cách bằng dấu phẩy.');
      return;
    }

    final selected = await showDialog<List<AICategorizeResult>>(
      context: context,
      builder: (ctx) {
        final draft = [...items];
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text(
                'AI phát hiện nhiều giao dịch',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: draft.isEmpty
                    ? Text(
                        'Bạn đã xóa hết giao dịch.',
                        style: GoogleFonts.nunito(color: AppColors.textSecondary),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: draft.length,
                        separatorBuilder: (_, __) => const Divider(height: 12),
                        itemBuilder: (_, i) {
                          final it = draft[i];
                          final amt = (it.amount ?? 0).toStringAsFixed(0);
                          final typeLabel = it.transactionType.toUpperCase() == 'INCOME' ? 'Thu nhập' : 'Chi tiêu';
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      it.description,
                                      style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$typeLabel • ${it.categoryName} • ₫ $amt',
                                      style: GoogleFonts.nunito(color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () {
                                  HapticUtils.selection();
                                  setLocal(() => draft.removeAt(i));
                                },
                                icon: const Icon(Icons.delete_outline_rounded),
                                color: AppColors.accent,
                                tooltip: 'Xóa',
                              ),
                            ],
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: Text('Đóng', style: GoogleFonts.nunito()),
                ),
                ElevatedButton(
                  onPressed: draft.isEmpty ? null : () => Navigator.pop(ctx, draft),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: Text(
                    'Xác nhận tất cả',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected == null || selected.isEmpty) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    int created = 0;
    int skipped = 0;
    try {
      final repo = ref.read(transactionRepositoryProvider);
      for (final it in selected) {
        final amount = it.amount ?? 0;
        if (amount <= 0) {
          skipped++;
          continue;
        }
        final isIncome = it.transactionType.toUpperCase() == 'INCOME';
        final pool = isIncome ? _incomeCategories : _expenseCategories;
        Category? cat = pool.where((c) => c.id == it.categoryId || c.name == it.categoryName).firstOrNull;
        cat ??= pool.where((c) => c.name == it.suggestedCategoryName).firstOrNull;
        if (cat == null) {
          skipped++;
          continue;
        }
        await repo.create(TransactionCreateData(
          type: isIncome ? 'INCOME' : 'EXPENSE',
          amount: amount,
          description: it.description.trim().isEmpty ? null : it.description.trim(),
          transactionDate: it.transactionDate ?? _selectedDate,
          categoryId: cat.id,
          walletId: _selectedWallet?.id,
        ));
        created++;
      }
      if (!mounted) return;
      showSuccessSnackBar(context, created > 0 ? 'Đã tạo $created giao dịch!' : 'Không tạo được giao dịch nào.');
      if (skipped > 0) {
        showInfoSnackBar(context, 'Bỏ qua $skipped khoản (thiếu số tiền hoặc không khớp danh mục).');
      }
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = extractErrorMessage(e);
        _isSaving = false;
      });
    }
  }

  void _quickAmount(double value) {
    HapticUtils.selection();
    final current = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    setState(() => _amountController.text = (current + value).toStringAsFixed(0));
  }

  Future<void> _save() async {
    if (_selectedCategory == null) {
      setState(() => _error = 'Vui lòng chọn danh mục');
      return;
    }
    final amount = double.tryParse(_amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Vui lòng nhập số tiền hợp lệ');
      return;
    }

    HapticUtils.medium();
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final data = TransactionCreateData(
        type: _isExpense ? 'EXPENSE' : 'INCOME',
        amount: amount,
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        transactionDate: _selectedDate,
        categoryId: _selectedCategory!.id,
        walletId: _selectedWallet?.id,
      );
      if (_isEditMode) {
        await ref.read(transactionRepositoryProvider).update(widget.transactionToEdit!.id, data);
        if (!mounted) return;
        showSuccessSnackBar(context, 'Đã cập nhật giao dịch!');
      } else {
        await ref.read(transactionRepositoryProvider).create(data);
        if (!mounted) return;
        showSuccessSnackBar(context, 'Đã thêm giao dịch thành công!');
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = extractErrorMessage(e);
        _isSaving = false;
      });
    }
  }

  @override
  void dispose() {
    _naturalInputController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        HapticUtils.selection();
                        Navigator.pop(context);
                      },
                    ),
                    Text(
                      _isEditMode ? 'Sửa giao dịch' : 'Thêm giao dịch',
                      style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    20 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_isEditMode) ...[
                        CardContainer(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Nhập nhanh (VD: ăn trưa 50k)',
                                      style: GoogleFonts.nunito(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  // Nút quét hóa đơn nhỏ gọn — ở góc phải header.
                                  Tooltip(
                                    message: 'Quét hóa đơn bằng camera',
                                    child: TextButton.icon(
                                      onPressed: _scanReceipt,
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        backgroundColor: AppColors.primary.withOpacity(0.10),
                                      ),
                                      icon: const Icon(Icons.document_scanner_rounded, size: 18),
                                      label: Text(
                                        'Quét',
                                        style: GoogleFonts.nunito(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _naturalInputController,
                                      decoration: InputDecoration(
                                        hintText: 'ăn trưa 50k, grab 30k...',
                                        hintStyle: GoogleFonts.nunito(color: AppColors.textMuted),
                                      ),
                                      onSubmitted: (_) => _aiCategorize(),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Tooltip(
                                    message: 'Phân loại bằng AI',
                                    child: IconButton.filled(
                                      onPressed: _isAiLoading ? null : _aiCategorize,
                                      icon: _isAiLoading
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Icon(Icons.auto_awesome_rounded),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      CardContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Loại giao dịch',
                              style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _TypeChip(
                                    label: 'Chi tiêu',
                                    isSelected: _isExpense,
                                    onTap: () {
                                      setState(() {
                                        _isExpense = true;
                                        _selectedCategory = _expenseCategories.isNotEmpty ? _expenseCategories.first : null;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _TypeChip(
                                    label: 'Thu nhập',
                                    isSelected: !_isExpense,
                                    onTap: () {
                                      setState(() {
                                        _isExpense = false;
                                        _selectedCategory = _incomeCategories.isNotEmpty ? _incomeCategories.first : null;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      CardContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Số tiền (₫)',
                              style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                hintText: '0',
                                prefixText: '₫ ',
                              ),
                            ),
                            if (!_isEditMode) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _QuickAmountChip(label: '+10k', onTap: () => _quickAmount(10000)),
                                  _QuickAmountChip(label: '+50k', onTap: () => _quickAmount(50000)),
                                  _QuickAmountChip(label: '+100k', onTap: () => _quickAmount(100000)),
                                  _QuickAmountChip(label: '+500k', onTap: () => _quickAmount(500000)),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_wallets.isNotEmpty) ...[
                        CardContainer(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ví',
                                style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 12),
                            if (_isLoadingMeta)
                                const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _wallets.map((w) => GestureDetector(
                                    onTap: () {
                                      HapticUtils.selection();
                                      setState(() => _selectedWallet = w);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _selectedWallet?.id == w.id ? AppColors.primary : AppColors.surface,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _selectedWallet?.id == w.id ? AppColors.primary : AppColors.textMuted.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.account_balance_wallet_rounded,
                                            size: 18,
                                            color: _selectedWallet?.id == w.id ? Colors.white : AppColors.textSecondary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            w.name,
                                            style: GoogleFonts.nunito(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: _selectedWallet?.id == w.id ? Colors.white : AppColors.textPrimary,
                                            ),
                                          ),
                                          if (w.isDefault) ...[
                                            const SizedBox(width: 4),
                                            Icon(Icons.star_rounded, size: 14, color: _selectedWallet?.id == w.id ? Colors.white : AppColors.primary),
                                          ],
                                        ],
                                      ),
                                    ),
                                  )).toList(),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      CardContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mô tả',
                              style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(hintText: 'Mô tả (tùy chọn)'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      CardContainer(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) setState(() => _selectedDate = date);
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Ngày',
                              style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                            Text(
                              DateFormat('dd/MM/yyyy').format(_selectedDate),
                              style: GoogleFonts.nunito(fontSize: 16, color: AppColors.textSecondary),
                            ),
                            const Icon(Icons.calendar_today_rounded, size: 20, color: AppColors.textMuted),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      CardContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Danh mục',
                              style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 12),
                            if (_isLoadingMeta)
                              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                            else if (_categoriesLoadError != null)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _categoriesLoadError!,
                                    style: GoogleFonts.nunito(fontSize: 13, color: AppColors.accent),
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton.icon(
                                    onPressed: () {
                                      setState(() => _isLoadingMeta = true);
                                      _loadCategoriesAndWallets();
                                    },
                                    icon: const Icon(Icons.refresh_rounded, size: 20),
                                    label: Text('Thử lại', style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              )
                            else if ((_isExpense ? _expenseCategories : _incomeCategories).isEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isExpense
                                        ? 'Chưa có danh mục chi tiêu. Thêm tại Cài đặt → Danh mục, hoặc đăng nhập lại để tải danh mục mặc định.'
                                        : 'Chưa có danh mục thu nhập. Thêm trong màn hình Danh mục.',
                                    style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton.icon(
                                    onPressed: () => Navigator.pushNamed(context, AppRouter.categories).then((_) {
                                      setState(() => _isLoadingMeta = true);
                                      _loadCategoriesAndWallets();
                                    }),
                                    icon: const Icon(Icons.category_rounded, size: 20),
                                    label: Text('Mở danh mục', style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              )
                            else
                              _CategoryGrid(
                                categories: _isExpense ? _expenseCategories : _incomeCategories,
                                selected: _selectedCategory,
                                onSelect: (c) {
                                  HapticUtils.selection();
                                  setState(() => _selectedCategory = c);
                                },
                              ),
                          ],
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(_error!, style: GoogleFonts.nunito(color: AppColors.accent)),
                        ),
                      ],
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  _isEditMode ? 'Cập nhật' : 'Lưu',
                                  style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                                ),
                        ),
                      ),
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
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAmountChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickAmountChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Text(
            label,
            style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final List<Category> categories;
  final Category? selected;
  final ValueChanged<Category> onSelect;

  const _CategoryGrid({required this.categories, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories
          .map((c) => GestureDetector(
                onTap: () => onSelect(c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected?.id == c.id ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected?.id == c.id ? AppColors.primary : AppColors.textMuted.withOpacity(0.3),
                      width: selected?.id == c.id ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _iconForCategory(c.name),
                        size: 18,
                        color: selected?.id == c.id ? Colors.white : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        c.name,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: selected?.id == c.id ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  IconData _iconForCategory(String name) {
    final n = name.toLowerCase();
    if (n.contains('ăn') || n.contains('food') || n.contains('đồ ăn')) return Icons.restaurant_rounded;
    if (n.contains('di chuyển') || n.contains('grab') || n.contains('xe')) return Icons.directions_car_rounded;
    if (n.contains('mua sắm') || n.contains('shopping')) return Icons.shopping_bag_rounded;
    if (n.contains('giải trí')) return Icons.movie_rounded;
    if (n.contains('sức khỏe') || n.contains('y tế')) return Icons.medical_services_rounded;
    if (n.contains('lương') || n.contains('thu nhập')) return Icons.account_balance_wallet_rounded;
    return Icons.category_rounded;
  }
}
