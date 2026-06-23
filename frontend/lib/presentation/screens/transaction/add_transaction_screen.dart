import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/utils/category_icons.dart';
import 'package:expense_manager/core/utils/api_error.dart' show extractErrorMessage;
import 'package:expense_manager/core/utils/haptic_utils.dart';
import 'package:expense_manager/core/utils/transaction_text_parse.dart';
import 'package:expense_manager/core/utils/snackbar_utils.dart';
import 'package:expense_manager/domain/models/category.dart';
import 'package:expense_manager/domain/models/ai_categorize.dart';
import 'package:expense_manager/domain/models/ocr_receipt.dart';
import 'package:expense_manager/domain/models/saving_goal.dart';
import 'package:expense_manager/domain/models/transaction.dart';
import 'package:expense_manager/domain/models/wallet.dart';
import 'package:expense_manager/domain/repositories/transaction_repository.dart';
import 'package:expense_manager/core/constants/api_constants.dart';
import 'package:expense_manager/core/di/injection.dart';
import 'package:expense_manager/core/providers/app_providers.dart';
import 'package:expense_manager/core/router/app_router.dart';
import 'package:expense_manager/presentation/widgets/transaction/amount_input_section.dart';
import 'package:expense_manager/presentation/widgets/transaction/receipt_ocr_sheet.dart';
import 'package:expense_manager/presentation/widgets/transaction/transaction_form_widgets.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final Transaction? transactionToEdit;
  final SpendFromSavingGoalArgs? spendFromGoal;

  const AddTransactionScreen({super.key, this.transactionToEdit, this.spendFromGoal});

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
  Transaction? _savedTransaction;
  bool _spendSuccess = false;

  bool get _isEditMode => widget.transactionToEdit != null || _savedTransaction != null;
  bool get _isSpendFromGoal => widget.spendFromGoal != null;

  int? get _transactionId => widget.transactionToEdit?.id ?? _savedTransaction?.id;

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
    } else if (widget.spendFromGoal != null) {
      final goal = widget.spendFromGoal!;
      _isExpense = true;
      _selectedDate = DateTime.now();
      _amountController.text = goal.amount.toStringAsFixed(0);
      _descriptionController.text = 'Chi tiêu cho mục tiêu tiết kiệm: ${goal.name}';
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
        if (_isEditMode) {
          _selectedCategory = widget.transactionToEdit?.category ?? _savedTransaction?.category;
        } else if (!_isSpendFromGoal && _expenseCategories.isNotEmpty) {
          _selectedCategory = _isExpense ? _expenseCategories.first : (_incomeCategories.isNotEmpty ? _incomeCategories.first : null);
        }
      }
      if (_selectedWallet == null && _wallets.isNotEmpty) {
        final walletId = widget.transactionToEdit?.walletId ?? _savedTransaction?.walletId;
        if (_isEditMode && walletId != null) {
          _selectedWallet = _wallets.where((w) => w.id == walletId).firstOrNull;
        }
        _selectedWallet ??= _wallets.firstWhere((w) => w.isDefault, orElse: () => _wallets.first);
      }
    } catch (e) {
      _categoriesLoadError = extractErrorMessage(e);
    }
    if (mounted) setState(() => _isLoadingMeta = false);
    if (_isSpendFromGoal && widget.spendFromGoal != null) {
      await _categorizeSavingGoalByName(
        widget.spendFromGoal!.name,
        amount: widget.spendFromGoal!.amount,
      );
    }
  }

  Category? _guessCategoryFromGoalName(List<Category> cats, String goalName) {
    final t = goalName.toLowerCase();
    final rules = <(RegExp, String)>[
      (RegExp(r'\b(laptop|lap\s*top|mua\s+lap\b|macbook|ipad|iphone|điện thoại|dien thoai|máy tính|may tinh)\b'), 'Mua sắm'),
      (RegExp(r'\b(mua|sắm|sam|shop|shopee|lazada|tiki|quần áo|giày)\b'), 'Mua sắm'),
      (RegExp(r'\b(du lịch|du lich|khách sạn|tour|vé máy bay)\b'), 'Du lịch'),
      (RegExp(r'\b(xe|ô tô|oto|xăng|grab|uber|taxi)\b'), 'Di chuyển'),
      (RegExp(r'\b(ăn|uống|cơm|phở|cafe|trà sữa)\b'), 'Ăn uống'),
    ];
    for (final (re, label) in rules) {
      if (!re.hasMatch(t)) continue;
      for (final c in cats) {
        final n = c.name.toLowerCase();
        if (n == label.toLowerCase() || n.contains(label.toLowerCase())) return c;
      }
    }
    return null;
  }

  Category? _matchCategoryFromAi(List<Category> cats, AICategorizeResult result) {
    if (result.categoryId != null) {
      final byId = cats.where((c) => c.id == result.categoryId).firstOrNull;
      if (byId != null) return byId;
    }
    final raw = result.categoryName.toLowerCase();
    if (raw.isEmpty) return null;
    return cats.where((c) {
      final n = c.name.toLowerCase();
      return n == raw || n.contains(raw) || raw.contains(n);
    }).firstOrNull;
  }

  Future<void> _categorizeSavingGoalByName(String goalName, {double? amount}) async {
    if (!mounted) return;
    setState(() {
      _isAiLoading = true;
      _error = null;
    });
    try {
      final user = ref.read(currentUserProvider).value;
      final local = _guessCategoryFromGoalName(_expenseCategories, goalName);
      if (local != null) {
        setState(() => _selectedCategory = local);
      }

      final aiText = amount != null
          ? '$goalName ${amount.toStringAsFixed(0)}'
          : goalName;
      final result = await ref.read(transactionRepositoryProvider).aiCategorize(
            aiText,
            personality: user?.botPersonality,
          );
      if (!mounted) return;
      final aiMatch = _matchCategoryFromAi(_expenseCategories, result);
      setState(() {
        if (aiMatch != null) {
          _selectedCategory = aiMatch;
        } else if (_selectedCategory == null && _expenseCategories.isNotEmpty) {
          _selectedCategory = _expenseCategories.first;
        }
        _isAiLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _selectedCategory ??= _guessCategoryFromGoalName(_expenseCategories, goalName)
            ?? (_expenseCategories.isNotEmpty ? _expenseCategories.first : null);
        _isAiLoading = false;
      });
    }
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
    final createdIds = <int>[];
    Transaction? lastCreated;
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
        final tx = await repo.create(TransactionCreateData(
          type: isIncome ? 'INCOME' : 'EXPENSE',
          amount: amount,
          description: it.description.trim().isEmpty ? null : it.description.trim(),
          transactionDate: it.transactionDate ?? _selectedDate,
          categoryId: cat.id,
          walletId: _selectedWallet?.id,
        ));
        createdIds.add(tx.id);
        lastCreated = tx;
        created++;
      }
      if (!mounted) return;
      ref.read(transactionListRefreshTriggerProvider.notifier).state++;
      if (skipped > 0) {
        showInfoSnackBar(context, 'Bỏ qua $skipped khoản (thiếu số tiền hoặc không khớp danh mục).');
      }
      if (createdIds.length == 1 && lastCreated != null) {
        setState(() {
          _savedTransaction = lastCreated;
          _isSaving = false;
        });
      } else {
        Navigator.pop(context, createdIds);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = extractErrorMessage(e);
        _isSaving = false;
      });
    }
  }

  Future<void> _undoTransaction() async {
    final id = _transactionId;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thu hồi giao dịch?'),
        content: const Text('Giao dịch sẽ bị xóa khỏi danh sách.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: const Text('Thu hồi'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await ref.read(transactionRepositoryProvider).delete(id);
      ref.read(transactionListRefreshTriggerProvider.notifier).state++;
      if (!mounted) return;
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
      if (_isExpense) {
        try {
          final checkRes = await apiClient.post(ApiConstants.spendingLimitsCheckTransaction, data: {
            'categoryId': _selectedCategory!.id,
            'amount': amount,
            'transactionDate': _selectedDate.toIso8601String().split('T').first,
            'type': 'EXPENSE',
            if (_isEditMode && _transactionId != null) 'excludeTransactionId': _transactionId,
          });
          final checkData = checkRes['data'] as Map<String, dynamic>?;
          if (checkData != null && checkData['hasWarning'] == true) {
            final msg = checkData['message'] as String? ?? 'Giao dịch này có thể vượt hạn mức chi tiêu.';
            if (!mounted) return;
            final proceed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Cảnh báo hạn mức chi tiêu'),
                content: Text(msg),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Tiếp tục tạo')),
                ],
              ),
            );
            if (proceed != true) {
              setState(() => _isSaving = false);
              return;
            }
          }
        } catch (_) {
          // offline hoặc lỗi API — vẫn cho phép lưu local
        }
      }

      final data = TransactionCreateData(
        type: _isExpense ? 'EXPENSE' : 'INCOME',
        amount: amount,
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        transactionDate: _selectedDate,
        categoryId: _selectedCategory!.id,
        walletId: _selectedWallet?.id,
      );
      if (_isSpendFromGoal && widget.spendFromGoal != null && _transactionId == null) {
        if (_selectedWallet == null) {
          setState(() {
            _error = 'Vui lòng chọn ví';
            _isSaving = false;
          });
          return;
        }
        await ref.read(savingGoalRepositoryProvider).spendFromGoal(
          goalId: widget.spendFromGoal!.id,
          categoryId: _selectedCategory!.id,
          walletId: _selectedWallet!.id,
          amount: amount,
          transactionDate: _selectedDate.toIso8601String().split('T').first,
          description: data.description,
        );
        ref.read(transactionListRefreshTriggerProvider.notifier).state++;
        if (!mounted) return;
        setState(() {
          _spendSuccess = true;
          _isSaving = false;
        });
        showSuccessSnackBar(context, 'Chi tiêu từ mục tiêu tiết kiệm thành công!');
        return;
      }
      if (_transactionId != null) {
        final updated = await ref.read(transactionRepositoryProvider).update(_transactionId!, data);
        ref.read(transactionListRefreshTriggerProvider.notifier).state++;
        if (!mounted) return;
        setState(() {
          _savedTransaction = updated;
          _isSaving = false;
        });
        showSuccessSnackBar(context, 'Đã cập nhật giao dịch!');
      } else {
        final created = await ref.read(transactionRepositoryProvider).create(data);
        ref.read(transactionListRefreshTriggerProvider.notifier).state++;
        if (!mounted) return;
        setState(() {
          _savedTransaction = created;
          _isSaving = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = extractErrorMessage(e);
        _isSaving = false;
      });
    }
  }

  Widget _buildCategoryPicker(BuildContext context) {
    if (_isLoadingMeta) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_categoriesLoadError != null) {
      return Column(
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
      );
    }
    final pool = _isExpense ? _expenseCategories : _incomeCategories;
    if (pool.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isExpense
                ? 'Chưa có danh mục chi tiêu. Thêm tại Cài đặt → Danh mục.'
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
      );
    }
    return _CategoryGrid(
      categories: pool,
      selected: _selectedCategory,
      onSelect: (c) {
        HapticUtils.selection();
        setState(() => _selectedCategory = c);
      },
    );
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        HapticUtils.selection();
                        Navigator.pop(context);
                      },
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            _isEditMode ? 'Sửa giao dịch' : 'Thêm giao dịch',
                            style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Ghi chép thu chi nhanh, chính xác',
                            style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDark],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _isEditMode ? Icons.edit_rounded : Icons.add_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
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
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withValues(alpha: 0.12),
                                Colors.white,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                            boxShadow: AppColors.cardShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Nhập nhanh với AI',
                                    style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800),
                                  ),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: _scanReceipt,
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                    ),
                                    icon: const Icon(Icons.document_scanner_rounded, size: 18),
                                    label: Text('Quét', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'VD: ăn trưa 50k, grab 30k + cà phê 45k',
                                style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _naturalInputController,
                                      decoration: InputDecoration(
                                        hintText: 'Mô tả tự nhiên...',
                                        hintStyle: GoogleFonts.nunito(color: AppColors.textMuted),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: BorderSide(color: AppColors.textMuted.withValues(alpha: 0.2)),
                                        ),
                                      ),
                                      onSubmitted: (_) => _aiCategorize(),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.filled(
                                    onPressed: _isAiLoading ? null : _aiCategorize,
                                    style: IconButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: _isAiLoading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(Icons.auto_awesome_rounded),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      TransactionFormSection(
                        title: 'Loại giao dịch',
                        child: TransactionTypeToggle(
                          isExpense: _isExpense,
                          onChanged: (exp) {
                            setState(() {
                              _isExpense = exp;
                              _selectedCategory = exp
                                  ? (_expenseCategories.isNotEmpty ? _expenseCategories.first : null)
                                  : (_incomeCategories.isNotEmpty ? _incomeCategories.first : null);
                            });
                          },
                        ),
                      ),
                      TransactionFormSection(
                        title: 'Số tiền',
                        child: AmountInputSection(
                          controller: _amountController,
                          isExpense: _isExpense,
                          showQuickAmounts: !_isEditMode,
                          onQuickAdd: _quickAmount,
                          onChanged: () => setState(() {}),
                        ),
                      ),
                      if (_wallets.isNotEmpty)
                        TransactionFormSection(
                          title: 'Ví',
                          subtitle: 'Giao dịch sẽ ghi vào ví này',
                          child: _isLoadingMeta
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(12),
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _wallets.map((w) {
                                    final selected = _selectedWallet?.id == w.id;
                                    return GestureDetector(
                                      onTap: () {
                                        HapticUtils.selection();
                                        setState(() => _selectedWallet = w);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: selected ? AppColors.primary : AppColors.surface,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: selected
                                                ? AppColors.primary
                                                : AppColors.textMuted.withValues(alpha: 0.3),
                                            width: selected ? 2 : 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.account_balance_wallet_rounded,
                                              size: 18,
                                              color: selected ? Colors.white : AppColors.textSecondary,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              w.name,
                                              style: GoogleFonts.nunito(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: selected ? Colors.white : AppColors.textPrimary,
                                              ),
                                            ),
                                            if (w.isDefault) ...[
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.star_rounded,
                                                size: 14,
                                                color: selected ? Colors.white : AppColors.primary,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                        ),
                      TransactionFormSection(
                        title: 'Mô tả',
                        subtitle: 'Tùy chọn — giúp bạn nhớ khoản này',
                        child: TextField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            hintText: 'VD: Cơm trưa với team',
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: AppColors.textMuted.withValues(alpha: 0.2)),
                            ),
                          ),
                        ),
                      ),
                      TransactionFormSection(
                        title: 'Ngày giao dịch',
                        subtitle: 'Nhấn để mở lịch chọn ngày',
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              HapticUtils.selection();
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                                helpText: 'Chọn ngày giao dịch',
                                cancelText: 'Hủy',
                                confirmText: 'Chọn',
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: ColorScheme.light(
                                        primary: AppColors.primary,
                                        onPrimary: Colors.white,
                                        surface: Colors.white,
                                        onSurface: AppColors.textPrimary,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (date != null) setState(() => _selectedDate = date);
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.event_rounded, size: 22, color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Ngày giao dịch',
                                          style: GoogleFonts.nunito(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                        Text(
                                          DateFormat('EEEE, dd/MM/yyyy', 'vi').format(_selectedDate),
                                          style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.calendar_month_rounded, size: 20, color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      TransactionFormSection(
                        title: 'Danh mục',
                        subtitle: _isSpendFromGoal && _isAiLoading
                            ? 'AI đang phân loại theo tên mục tiêu…'
                            : _isSpendFromGoal && _selectedCategory != null
                                ? 'AI gợi ý: ${_selectedCategory!.name} — có thể đổi trước khi lưu'
                                : 'Chọn danh mục ${_isExpense ? 'chi tiêu' : 'thu nhập'}',
                        child: _buildCategoryPicker(context),
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
                      if (_savedTransaction != null && widget.transactionToEdit == null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.income.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.income.withOpacity(0.25)),
                          ),
                          child: Text(
                            'Giao dịch đã được lưu. Bạn có thể cập nhật hoặc thu hồi nếu nhập nhầm.',
                            style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                          ),
                        ),
                      ],
                      if (_isEditMode) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isSaving ? null : _undoTransaction,
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('Thu hồi giao dịch'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.accent,
                              side: BorderSide(color: AppColors.accent.withOpacity(0.5)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (_isEditMode)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isSaving ? null : () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: Text('Xong', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                              ),
                            ),
                          if (_isEditMode) const SizedBox(width: 12),
                          Expanded(
                            flex: _isEditMode ? 1 : 1,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isExpense ? AppColors.expense : AppColors.income,
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
                                      _isEditMode ? 'Cập nhật' : 'Lưu giao dịch',
                                      style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                                    ),
                            ),
                          ),
                        ],
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
      children: categories.asMap().entries.map((entry) {
        final i = entry.key;
        final c = entry.value;
        final color = AppColors.chartCategoryPalette[i % AppColors.chartCategoryPalette.length];
        final isSelected = selected?.id == c.id;
        return GestureDetector(
                onTap: () => onSelect(c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? color : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? color : AppColors.textMuted.withValues(alpha: 0.3),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _iconForCategory(c.name),
                        size: 18,
                        color: isSelected ? Colors.white : color,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        c.name,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
      }).toList(),
    );
  }

  IconData _iconForCategory(String name) => categoryIconData(name: name);
}
