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
      await ref.read(syncServiceProvider).syncAllIfOnline();
      if (!mounted) return;
      _loadTransactions(reset: true);
      _loadCategories();
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
      final cats = await ref.read(categoryRepositoryProvider).getAll();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {}
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

  List<Transaction> get _filteredBySearch {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _transactions;
    return _transactions.where((t) {
      final desc = (t.description ?? '').toLowerCase();
      final cat = t.category.name.toLowerCase();
      return desc.contains(q) || cat.contains(q);
    }).toList();
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
            onRefresh: () => _loadTransactions(reset: true),
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
                                    'Lịch sử thu chi',
                                    style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Tìm theo mô tả, danh mục...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => _showFilterSheet(context),
                              icon: Icon(
                                Icons.filter_list_rounded,
                                color: _filters != null ? AppColors.primary : AppColors.textMuted,
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_rounded, size: 64, color: AppColors.textMuted),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isNotEmpty ? 'Không tìm thấy kết quả' : 'Chưa có giao dịch',
                            style: GoogleFonts.nunito(fontSize: 16, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              if (_searchController.text.isNotEmpty) {
                                _searchController.clear();
                                setState(() {});
                              } else {
                                Navigator.pushNamed(context, AppRouter.addTransaction).then((_) => _loadTransactions(reset: true));
                              }
                            },
                            child: Text(_searchController.text.isNotEmpty ? 'Xóa tìm kiếm' : 'Thêm giao dịch đầu tiên'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == displayList.length) {
                          return _isLoading
                              ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
                              : const SizedBox();
                        }
                        return _TransactionItem(
                          transaction: displayList[index],
                          onEdit: () => Navigator.pushNamed(context, AppRouter.addTransaction, arguments: displayList[index]).then((_) => _loadTransactions(reset: true)),
                          onDelete: () => _confirmDelete(context, displayList[index]),
                        );
                      },
                      childCount: displayList.length + (_hasMore && _isLoading ? 1 : 0),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    HapticUtils.selection();
    String? type = _filters?.type;
    int? categoryId = _filters?.categoryId;
    DateTime? startDate = _filters?.startDate;
    DateTime? endDate = _filters?.endDate;

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
                  Text('Lọc giao dịch', style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w700)),
                  TextButton(
                    onPressed: () {
                      type = null;
                      categoryId = null;
                      startDate = null;
                      endDate = null;
                      setModalState(() {});
                    },
                    child: const Text('Đặt lại'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Loại', style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _FilterChip(label: 'Tất cả', selected: type == null, onTap: () => setModalState(() => type = null)),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'Chi tiêu', selected: type == 'EXPENSE', onTap: () => setModalState(() => type = 'EXPENSE')),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'Thu nhập', selected: type == 'INCOME', onTap: () => setModalState(() => type = 'INCOME')),
                ],
              ),
              const SizedBox(height: 16),
              Text('Danh mục', style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FilterChip(label: 'Tất cả', selected: categoryId == null, onTap: () => setModalState(() => categoryId = null)),
                    ..._categories.map((c) => _FilterChip(
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
                    _applyFilters(type, categoryId, startDate, endDate);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text('Áp dụng'),
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
      selectedColor: AppColors.primary.withOpacity(0.2),
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TransactionItem({required this.transaction, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    return GestureDetector(
      onTap: onEdit,
      onLongPress: () {
        HapticUtils.medium();
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
                    onEdit();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_rounded, color: AppColors.accent),
                  title: Text('Xóa', style: TextStyle(color: AppColors.accent)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onDelete();
                  },
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
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
              color: (isIncome ? AppColors.income : AppColors.expense).withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: isIncome ? AppColors.income : AppColors.expense,
              size: 24,
            ),
          ),
          title: Text(
            transaction.description ?? transaction.category.name,
            style: GoogleFonts.nunito(fontWeight: FontWeight.w600, fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${transaction.category.name} • ${DateFormat('dd/MM').format(transaction.transactionDate)}',
            style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary),
          ),
          trailing: Text(
            '${isIncome ? '+' : '-'}${NumberFormat.compact(locale: 'vi').format(transaction.amount)} ₫',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: isIncome ? AppColors.income : AppColors.expense,
            ),
          ),
        ),
      ),
    );
  }
}
