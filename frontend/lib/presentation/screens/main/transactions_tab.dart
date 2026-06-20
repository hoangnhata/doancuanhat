import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/router/app_router.dart';
import 'package:expense_manager/core/utils/haptic_utils.dart';
import 'package:expense_manager/core/utils/snackbar_utils.dart';
import 'package:expense_manager/domain/models/category.dart';
import 'package:expense_manager/domain/models/transaction.dart';
import 'package:expense_manager/domain/repositories/transaction_repository.dart';
import 'package:expense_manager/core/providers/app_providers.dart';
import 'package:expense_manager/core/utils/api_error.dart';
import 'package:expense_manager/presentation/widgets/transactions/transaction_list_item.dart';
import 'package:expense_manager/presentation/widgets/transactions/transaction_widgets.dart';

class TransactionsTab extends ConsumerStatefulWidget {
  const TransactionsTab({super.key});

  @override
  ConsumerState<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends ConsumerState<TransactionsTab> {
  bool _isLoading = false;
  String? _error;
  List<Transaction> _transactions = [];
  int _page = 0;
  bool _hasMore = true;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  TransactionFilters? _filters;
  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadCategories();
      if (!mounted) return;
      _loadTransactions(reset: true);
    });
    _scrollController.addListener(_onScroll);
  }


  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_isLoading) _loadTransactions();
    }
  }

  Future<void> _loadCategories() async {
    try {
      await ref.read(syncServiceProvider).syncAllIfOnline();
      final cats = await ref.read(categoryRepositoryProvider).getAll();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {}
  }

  List<Category> _categoriesForFilterSheet() {
    final type = _filters?.type;
    if (type == null) return _categories;
    if (type == 'EXPENSE') {
      return _categories.where((c) => c.type == CategoryType.expense).toList();
    }
    if (type == 'INCOME') {
      return _categories.where((c) => c.type == CategoryType.income).toList();
    }
    return _categories;
  }

  Future<void> _loadTransactions({bool reset = false}) async {
    if (_isLoading) return;
    if (reset) {
      _page = 0;
      _hasMore = true;
    }
    setState(() => _isLoading = true);

    try {
      final repo = ref.read(transactionRepositoryProvider);
      final walletId = ref.read(selectedWalletIdProvider);
      final filters = TransactionFilters(
        type: _filters?.type,
        categoryId: _filters?.categoryId,
        walletId: walletId,
        startDate: _filters?.startDate,
        endDate: _filters?.endDate,
      );
      final pageToLoad = reset ? 0 : _page;
      final result = await repo.getAll(
        page: pageToLoad,
        size: 20,
        filters: filters,
      );

      setState(() {
        if (reset) {
          _transactions = result.items;
          _page = 1;
        } else {
          _transactions.addAll(result.items);
          _page++;
        }
        _hasMore = result.totalPages > 1 && _page < result.totalPages;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = extractErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  void _applyFilters(String? type, int? categoryId, DateTime? startDate, DateTime? endDate) {
    setState(() {
      _filters = TransactionFilters(
        type: type,
        categoryId: categoryId,
        startDate: startDate,
        endDate: endDate,
      );
      _loadTransactions(reset: true);
    });
  }

  void _clearFilters() {
    setState(() {
      _filters = null;
      _loadTransactions(reset: true);
    });
  }

  void _setTypeFilter(String? type) {
    setState(() {
      _filters = TransactionFilters(
        type: type,
        categoryId: _filters?.categoryId,
        startDate: _filters?.startDate,
        endDate: _filters?.endDate,
      );
    });
    _loadTransactions(reset: true);
  }

  int _categoryIndex(int categoryId) {
    final i = _categories.indexWhere((c) => c.id == categoryId);
    return i >= 0 ? i : 0;
  }

  Widget? _flatListItem(
    BuildContext context,
    List<TransactionDateGroup> groups,
    int index,
    List<Transaction> displayList,
  ) {
    var cursor = 0;
    for (final group in groups) {
      if (index == cursor) {
        return TransactionDateHeader(
          label: group.label,
          count: group.items.length,
          dayTotal: dayNetTotal(group.items),
        );
      }
      cursor++;
      for (final t in group.items) {
        if (index == cursor) {
          return TransactionListItem(
            transaction: t,
            categoryIndex: _categoryIndex(t.category.id),
            onTap: () => Navigator.pushNamed(
              context,
              AppRouter.addTransaction,
              arguments: t,
            ).then((_) {
              if (mounted) {
                ref.read(transactionListRefreshTriggerProvider.notifier).state++;
              }
            }),
            onLongPress: () {
              HapticUtils.medium();
              _showActionSheet(context, t);
            },
          );
        }
        cursor++;
      }
    }
    return null;
  }

  List<Transaction> get _filteredBySearch {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _transactions;
    return _transactions.where((t) {
      final desc = (t.description ?? '').toLowerCase();
      final cat = t.category.name.toLowerCase();
      return desc.contains(q) || cat.contains(q);
    }).toList();
  }

  void _showActionSheet(BuildContext context, Transaction t) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Sửa'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, AppRouter.addTransaction, arguments: t)
                    .then((_) {
                  if (mounted) {
                    ref.read(transactionListRefreshTriggerProvider.notifier).state++;
                  }
                });
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_rounded, color: AppColors.accent),
              title: Text('Xóa', style: TextStyle(color: AppColors.accent)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, t);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(selectedWalletIdProvider, (prev, next) {
      if (prev != next) _loadTransactions(reset: true);
    });
    ref.listen(transactionListRefreshTriggerProvider, (prev, next) {
      if (prev != null && prev != next) _loadTransactions(reset: true);
    });
    final displayList = _filteredBySearch;
    final groups = groupTransactionsByDate(displayList);
    final summary = computeTransactionSummary(displayList);
    final hasAdvancedFilter = _filters?.categoryId != null ||
        _filters?.startDate != null ||
        _filters?.endDate != null;
    final contentLen = groups.fold<int>(0, (sum, g) => sum + 1 + g.items.length);
    final showLoader = _hasMore && _isLoading;
    final flatLen = contentLen + (showLoader ? 1 : 0);

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
          child: RefreshIndicator(
            onRefresh: () async {
              await _loadCategories();
              await _loadTransactions(reset: true);
            },
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppColors.primary, AppColors.primaryDark],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Giao dịch',
                                    style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                  ),
                                  Text(
                                    'Lịch sử thu chi · nhóm theo ngày',
                                    style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (displayList.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          TransactionSummaryBar(
                            totalIncome: summary.totalIncome,
                            totalExpense: summary.totalExpense,
                            balance: summary.balance,
                            count: summary.count,
                          ),
                        ],
                        const SizedBox(height: 16),
                        TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Tìm theo mô tả, danh mục...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: AppColors.textMuted.withValues(alpha: 0.15)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: AppColors.textMuted.withValues(alpha: 0.15)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TransactionTypeChips(
                          selectedType: _filters?.type,
                          onChanged: _setTypeFilter,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => _showFilterSheet(context),
                              icon: Icon(
                                Icons.filter_list_rounded,
                                color: hasAdvancedFilter ? AppColors.primary : AppColors.textMuted,
                              ),
                              style: IconButton.styleFrom(
                                side: BorderSide(
                                  color: hasAdvancedFilter
                                      ? AppColors.primary
                                      : AppColors.textMuted.withValues(alpha: 0.25),
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            if (_filters != null)
                              TextButton(
                                onPressed: _clearFilters,
                                child: Text('Xóa lọc', style: GoogleFonts.nunito(color: AppColors.primary)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (_error != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(_error!, style: GoogleFonts.nunito(color: AppColors.accent)),
                      ),
                    ),
                  )
                else if (displayList.isEmpty && !_isLoading)
                  SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_rounded, size: 64, color: AppColors.textMuted),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isNotEmpty || _filters != null
                                  ? 'Không tìm thấy kết quả'
                                  : 'Chưa có giao dịch',
                              style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'Thử từ khóa khác hoặc xóa bộ lọc'
                                  : 'Bắt đầu ghi chép thu chi của bạn',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () {
                                if (_searchController.text.isNotEmpty || _filters != null) {
                                  _searchController.clear();
                                  _clearFilters();
                                } else {
                                  Navigator.pushNamed(context, AppRouter.addTransaction)
                                      .then((_) {
                                    if (mounted) {
                                      ref.read(transactionListRefreshTriggerProvider.notifier).state++;
                                    }
                                  });
                                }
                              },
                              child: Text(
                                _searchController.text.isNotEmpty || _filters != null
                                    ? 'Xóa bộ lọc'
                                    : 'Thêm giao dịch đầu tiên',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (showLoader && index == contentLen) {
                            return const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return _flatListItem(context, groups, index, displayList) ??
                              const SizedBox.shrink();
                        },
                        childCount: flatLen,
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

  Future<void> _showFilterSheet(BuildContext context) async {
    HapticUtils.selection();
    await _loadCategories();
    if (!context.mounted) return;

    int? categoryId = _filters?.categoryId;
    DateTime? startDate = _filters?.startDate;
    DateTime? endDate = _filters?.endDate;
    final sheetCategories = _categoriesForFilterSheet();
    if (categoryId != null && !sheetCategories.any((c) => c.id == categoryId)) {
      categoryId = null;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Lọc nâng cao', style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w700)),
                  TextButton(
                    onPressed: () {
                      categoryId = null;
                      startDate = null;
                      endDate = null;
                      setModalState(() {});
                    },
                    child: const Text('Đặt lại'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Danh mục và khoảng thời gian. Loại thu/chi chọn ở trên danh sách.',
                style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Text('Danh mục', style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (sheetCategories.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Chưa có danh mục. Kéo xuống để làm mới danh sách giao dịch.',
                    style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
                  ),
                )
              else
                SizedBox(
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChip(label: 'Tất cả', selected: categoryId == null, onTap: () => setModalState(() => categoryId = null)),
                      ...sheetCategories.map((c) => _FilterChip(
                            label: c.name,
                            selected: categoryId == c.id,
                            onTap: () => setModalState(() => categoryId = c.id),
                          )),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final d = await showDatePicker(context: ctx, initialDate: startDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                        if (d != null) setModalState(() => startDate = d);
                      },
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(startDate != null ? DateFormat('dd/MM').format(startDate!) : 'Từ ngày'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final d = await showDatePicker(context: ctx, initialDate: endDate ?? DateTime.now(), firstDate: startDate ?? DateTime(2020), lastDate: DateTime.now());
                        if (d != null) setModalState(() => endDate = d);
                      },
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(endDate != null ? DateFormat('dd/MM').format(endDate!) : 'Đến ngày'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _applyFilters(_filters?.type, categoryId, startDate, endDate);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text('Áp dụng', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Transaction t) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa giao dịch?'),
        content: Text('Bạn có chắc muốn xóa "${t.description ?? t.category.name}" - ${NumberFormat.compact(locale: 'vi').format(t.amount)}₫?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Xóa', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ref.read(transactionRepositoryProvider).delete(t.id);
        if (!mounted) return;
        showSuccessSnackBar(context, 'Đã xóa giao dịch');
        _loadTransactions(reset: true);
      } catch (e) {
        if (!mounted) return;
        showErrorSnackBar(context, 'Không thể xóa');
      }
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
    );
  }
}
