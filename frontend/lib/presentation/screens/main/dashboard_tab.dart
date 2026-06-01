import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/providers/app_providers.dart';
import 'package:expense_manager/core/router/app_router.dart';
import 'package:expense_manager/domain/models/wallet.dart';
import 'package:expense_manager/core/utils/haptic_utils.dart';
import 'package:expense_manager/presentation/widgets/common/card_container.dart';
import 'package:expense_manager/presentation/widgets/common/empty_state.dart';
import 'package:expense_manager/presentation/widgets/common/skeleton_card.dart';
import 'package:expense_manager/presentation/widgets/robot/natta_avatar.dart';
import 'package:expense_manager/presentation/widgets/charts/category_donut_chart.dart';

class DashboardTab extends ConsumerStatefulWidget {
  const DashboardTab({super.key});

  @override
  ConsumerState<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends ConsumerState<DashboardTab> {
  String _period = 'month';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  String? _error;
  double _totalIncome = 0;
  double _totalExpense = 0;
  double _balance = 0;
  /// Theo danh mục — API mặc định chỉ trả EXPENSE nếu không gửi categoryType; cần tách 2 loại để tab Thu nhập hiển thị đúng.
  List<Map<String, dynamic>> _chartDataExpense = [];
  List<Map<String, dynamic>> _chartDataIncome = [];
  bool _showExpense = true;
  List<Wallet> _wallets = [];
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await ref.read(syncServiceProvider).syncAllIfOnline();
    if (!mounted) return;
    await _loadWallets();
    if (mounted) await _loadData();
  }

  Future<void> _loadWallets() async {
    try {
      final repo = ref.read(walletRepositoryProvider);
      _wallets = await repo.getAll();
      final sel = ref.read(selectedWalletIdProvider);
      if (sel != null && !_wallets.any((w) => w.id == sel)) {
        ref.read(selectedWalletIdProvider.notifier).state = null;
      }
      if (_wallets.isNotEmpty && ref.read(selectedWalletIdProvider) == null) {
        final defaultWallet = _wallets.where((w) => w.isDefault).firstOrNull ?? _wallets.first;
        ref.read(selectedWalletIdProvider.notifier).state = defaultWallet.id;
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  int? get _selectedWalletId => ref.read(selectedWalletIdProvider);

  Future<void> _openSpendingForecast() async {
    await Navigator.pushNamed(context, AppRouter.spendingForecast);
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(statisticsRepositoryProvider);
      final walletId = _selectedWalletId;

      Future<
          ({
            List<Map<String, dynamic>> expenseChart,
            List<Map<String, dynamic>> incomeChart,
            double totalIncome,
            double totalExpense,
            double balance,
          })> loadPair() async {
        if (_period == 'day') {
          final d = _selectedDate;
          final start = DateTime(d.year, d.month, d.day);
          final end = start;
          final expenseStats = await repo.getByDateRange(start, end, categoryType: 'EXPENSE', walletId: walletId);
          final incomeStats = await repo.getByDateRange(start, end, categoryType: 'INCOME', walletId: walletId);
          return (
            expenseChart: expenseStats.byCategory.map((c) => {'name': c.categoryName, 'amount': c.amount}).toList(),
            incomeChart: incomeStats.byCategory.map((c) => {'name': c.categoryName, 'amount': c.amount}).toList(),
            // Offline: mỗi lần gọi chỉ gộp theo loại danh mục → phải lấy thu từ incomeStats, chi từ expenseStats.
            // Online: API vẫn trả đủ tổng ở cả hai; kết quả tương đương.
            totalIncome: incomeStats.totalIncome,
            totalExpense: expenseStats.totalExpense,
            balance: incomeStats.totalIncome - expenseStats.totalExpense,
          );
        }
        if (_period == 'month') {
          final y = _selectedDate.year;
          final m = _selectedDate.month;
          final expenseStats = await repo.getByMonth(y, m, categoryType: 'EXPENSE', walletId: walletId);
          final incomeStats = await repo.getByMonth(y, m, categoryType: 'INCOME', walletId: walletId);
          return (
            expenseChart: expenseStats.byCategory.map((c) => {'name': c.categoryName, 'amount': c.amount}).toList(),
            incomeChart: incomeStats.byCategory.map((c) => {'name': c.categoryName, 'amount': c.amount}).toList(),
            totalIncome: incomeStats.totalIncome,
            totalExpense: expenseStats.totalExpense,
            balance: incomeStats.totalIncome - expenseStats.totalExpense,
          );
        }
        final y = _selectedDate.year;
        final expenseStats = await repo.getByYear(y, categoryType: 'EXPENSE', walletId: walletId);
        final incomeStats = await repo.getByYear(y, categoryType: 'INCOME', walletId: walletId);
        return (
          expenseChart: expenseStats.byCategory.map((c) => {'name': c.categoryName, 'amount': c.amount}).toList(),
          incomeChart: incomeStats.byCategory.map((c) => {'name': c.categoryName, 'amount': c.amount}).toList(),
          totalIncome: incomeStats.totalIncome,
          totalExpense: expenseStats.totalExpense,
          balance: incomeStats.totalIncome - expenseStats.totalExpense,
        );
      }

      final pair = await loadPair();

      setState(() {
        _totalIncome = pair.totalIncome;
        _totalExpense = pair.totalExpense;
        _balance = pair.balance;
        _chartDataExpense = pair.expenseChart;
        _chartDataIncome = pair.incomeChart;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(transactionListRefreshTriggerProvider, (prev, next) {
      if (prev != null && prev != next) {
        _loadData();
        _loadWallets();
      }
    });

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
              await _loadWallets();
              await _loadData();
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _HeaderPill(
                              label: 'Những cột mốc',
                              icon: Icons.emoji_events_rounded,
                              gradient: [const Color(0xFFFFB347), const Color(0xFFFFCC70)],
                              onTap: () => Navigator.pushNamed(context, AppRouter.milestones).then((_) {
                                ref.invalidate(currentUserProvider);
                                _loadData();
                              }),
                            ),
                            _HeaderPill(
                              label: 'Phân tích thêm',
                              icon: Icons.bar_chart_rounded,
                              gradient: [const Color(0xFF4FC3F7), const Color(0xFF81D4FA)],
                              onTap: () => Navigator.pushNamed(context, AppRouter.analytics),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: AppColors.softShadow,
                                ),
                                child: const NattaAvatar(size: 56),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: AppColors.softShadow,
                                ),
                                child: Text(
                                  'Chào bạn! 👋',
                                  style: GoogleFonts.nunito(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 100,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              if (_wallets.isNotEmpty)
                                ..._wallets.map((w) => Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: _WalletCard(
                                  name: w.name,
                                  balance: _selectedWalletId == w.id ? _balance : 0,
                                  isSelected: _selectedWalletId == w.id,
                                  onTap: () {
                                    HapticUtils.selection();
                                    ref.read(selectedWalletIdProvider.notifier).state = w.id;
                                    _loadData();
                                  },
                                  onEdit: () => Navigator.pushNamed(context, AppRouter.wallets).then((_) => _loadWallets()),
                                ),
                              )),
                              if (_wallets.isNotEmpty) const SizedBox(width: 12),
                              _AddWalletCard(
                                onTap: () => Navigator.pushNamed(context, AppRouter.wallets).then((_) {
                                  _loadWallets();
                                  _loadData();
                                }),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _DateFilterChip(
                                icon: Icons.calendar_month_rounded,
                                label: 'Tháng',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _DateFilterChip(
                                label: 'Tháng ${_selectedDate.month}/${_selectedDate.year}',
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now(),
                                  );
                                  if (date != null) {
                                    setState(() => _selectedDate = date);
                                    _loadData();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (!_isLoading) _buildMilestoneHomeCard(),
                        const SizedBox(height: 24),
                        if (_isLoading)
                          _buildSkeletonLoading()
                        else if (_error != null)
                          CardContainer(
                            child: Text(_error!, style: GoogleFonts.nunito(color: AppColors.accent)),
                          )
                        else if (_totalIncome == 0 && _totalExpense == 0)
                          EmptyState(
                            icon: Icons.account_balance_wallet_rounded,
                            title: 'Chưa có giao dịch nào',
                            subtitle: 'Thêm giao dịch đầu tiên để bắt đầu theo dõi chi tiêu của bạn.',
                            actionLabel: 'Thêm giao dịch',
                            onAction: () => Navigator.pushNamed(context, AppRouter.addTransaction).then((_) {
                              ref.read(transactionListRefreshTriggerProvider.notifier).state++;
                            }),
                          )
                        else ...[
                          _buildNetChangeCard(),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: _openSpendingForecast,
                            child: CardContainer(
                              child: Row(
                                children: [
                                  Icon(Icons.auto_graph_rounded, color: AppColors.primary, size: 26),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Dự báo chi tiêu 7 ngày tới',
                                          style: GoogleFonts.nunito(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Chạm để mở trang dự báo — nút “Xem dự báo” chỉ hoạt động khi đã đủ ngày có chi',
                                          style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _FilterToggle(
                                  label: 'Chi phí',
                                  isSelected: _showExpense,
                                  onTap: () {
                                    HapticUtils.selection();
                                    setState(() => _showExpense = true);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _FilterToggle(
                                  label: 'Thu nhập',
                                  isSelected: !_showExpense,
                                  onTap: () {
                                    HapticUtils.selection();
                                    setState(() => _showExpense = false);
                                  },
                                ),
                              ),
                            ],
                          ),
                          if (_chartDataExpense.isNotEmpty || _chartDataIncome.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            _buildChartCard(),
                          ] else ...[
                            const SizedBox(height: 24),
                            EmptyState(
                              icon: Icons.pie_chart_rounded,
                              title: 'Chưa có dữ liệu biểu đồ',
                              subtitle: 'Thêm giao dịch theo danh mục để xem thống kê.',
                              actionLabel: 'Thêm giao dịch',
                              onAction: () => Navigator.pushNamed(context, AppRouter.addTransaction).then((_) {
                                ref.read(transactionListRefreshTriggerProvider.notifier).state++;
                              }),
                            ),
                          ],
                        ],
                      ],
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

  /// Thanh mục tiêu tiết kiệm + tiến độ (theo tháng đang chọn trên trang chủ).
  Widget _buildMilestoneHomeCard() {
    final userAsync = ref.watch(currentUserProvider);
    final goal = userAsync.valueOrNull?.savingsGoalMonthly;
    final fmt = NumberFormat.compact(locale: 'vi');

    Future<void> openMilestones() async {
      await Navigator.pushNamed(context, AppRouter.milestones);
      if (!mounted) return;
      ref.invalidate(currentUserProvider);
      await _loadData();
    }

    if (goal != null && goal > 0) {
      final current = (_balance > 0 ? _balance : 0).toDouble();
      final pct = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
      return GestureDetector(
        onTap: openMilestones,
        child: CardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.flag_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mục tiêu tiết kiệm · Tháng ${_selectedDate.month}/${_selectedDate.year}',
                      style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ),
                  Text(
                    '${(pct * 100).clamp(0, 999).toStringAsFixed(0)}%',
                    style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 10,
                  backgroundColor: AppColors.textMuted.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(pct >= 1 ? AppColors.income : AppColors.primary),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${fmt.format(current)}₫ / ${fmt.format(goal)}₫  ·  Chạm để xem cột mốc',
                style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: openMilestones,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.textMuted.withOpacity(0.25)),
          boxShadow: AppColors.softShadow,
        ),
        child: Row(
          children: [
            Icon(Icons.flag_outlined, color: AppColors.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Đặt mục tiêu tiết kiệm tháng để theo dõi ngay trên trang chủ',
                style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return Column(
      children: [
        SkeletonCard(height: 140),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: SkeletonCard(height: 60)),
            const SizedBox(width: 12),
            Expanded(child: SkeletonCard(height: 60)),
          ],
        ),
        const SizedBox(height: 24),
        SkeletonCard(height: 200),
      ],
    );
  }

  Widget _buildNetChangeCard() {
    final fmt = NumberFormat.compact(locale: 'vi');
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.15),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.softShadow,
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thay đổi ròng',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${fmt.format(_balance)}₫',
            style: GoogleFonts.nunito(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: _balance >= 0 ? AppColors.primary : AppColors.accent,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppColors.softShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.arrow_upward_rounded, color: AppColors.expense, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Chi phí',
                            style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${fmt.format(_totalExpense)}₫',
                        style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.expense),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppColors.softShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.arrow_downward_rounded, color: AppColors.income, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Thu nhập',
                            style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${fmt.format(_totalIncome)}₫',
                        style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.income),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard() {
    final chartData = _showExpense ? _chartDataExpense : _chartDataIncome;
    if (chartData.isEmpty) {
      return CardContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _showExpense ? 'Chi tiêu theo danh mục' : 'Thu nhập theo danh mục',
              style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            Text(
              _showExpense ? 'Chưa có chi tiêu theo danh mục trong kỳ này.' : 'Chưa có thu nhập theo danh mục trong kỳ này.',
              style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }
    return CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _showExpense ? 'Chi tiêu theo danh mục' : 'Thu nhập theo danh mục',
            style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 24),
          CategoryDonutChart(
            chartData: chartData,
            isExpense: _showExpense,
            height: 180,
          ),
          const SizedBox(height: 16),
          ...chartData.asMap().entries.map((e) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.chartCategoryColor(e.key),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      e.value['name'] as String,
                      style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textPrimary),
                    ),
                  ),
                  Text(
                    '${NumberFormat.compact(locale: 'vi').format(e.value['amount'])} ₫',
                    style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _HeaderPill({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  final String name;
  final double balance;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  const _WalletCard({
    required this.name,
    required this.balance,
    this.isSelected = false,
    this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.compact(locale: 'vi');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.primary.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: AppColors.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onEdit != null)
                  GestureDetector(
                    onTap: onEdit,
                    child: Icon(Icons.edit_rounded, size: 18, color: AppColors.textMuted),
                  ),
              ],
            ),
            Text(
              '${fmt.format(balance)}₫',
              style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddWalletCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AddWalletCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.textMuted.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, color: AppColors.textMuted, size: 28),
            const SizedBox(height: 6),
            Text(
              'Ví mới',
              style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateFilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  const _DateFilterChip({required this.label, this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.softShadow,
          border: Border.all(color: AppColors.surface),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterToggle extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterToggle({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
