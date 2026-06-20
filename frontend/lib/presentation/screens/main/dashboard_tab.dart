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
import 'package:expense_manager/presentation/widgets/common/period_filter_bar.dart';
import 'package:expense_manager/presentation/widgets/common/skeleton_card.dart';
import 'package:expense_manager/presentation/widgets/robot/natta_avatar.dart';
import 'package:expense_manager/presentation/widgets/charts/category_donut_chart.dart';
import 'package:expense_manager/presentation/widgets/dashboard/forecast_promo_card.dart';
import 'package:expense_manager/presentation/widgets/dashboard/net_change_summary_card.dart';
import 'package:expense_manager/presentation/widgets/dashboard/spending_limit_home_section.dart';
import 'package:expense_manager/presentation/widgets/dashboard/saving_goals_home_section.dart';
import 'package:expense_manager/presentation/widgets/dashboard/section_label.dart';

class DashboardTab extends ConsumerStatefulWidget {
  const DashboardTab({super.key});

  @override
  ConsumerState<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends ConsumerState<DashboardTab> {
  String _period = 'month';
  late int _selectedYear;
  late int _selectedMonth;
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
  double _totalSaved = 0;
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _bootstrap();
  }

  String get _periodLabel =>
      _period == 'month' ? 'Tháng $_selectedMonth/$_selectedYear' : 'Năm $_selectedYear';

  Future<void> _bootstrap() async {
    await ref.read(syncServiceProvider).syncAllIfOnline();
    if (!mounted) return;
    await _loadWallets();
    await _loadTotalSaved();
    if (mounted) await _loadData();
  }

  Future<void> _loadTotalSaved() async {
    try {
      final goals = await ref.read(savingGoalRepositoryProvider).getAll();
      _totalSaved = goals.fold(0.0, (sum, g) => sum + g.currentAmount);
    } catch (_) {
      _totalSaved = 0;
    }
    if (mounted) setState(() {});
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
          final d = DateTime(_selectedYear, _selectedMonth, 1);
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
          final y = _selectedYear;
          final m = _selectedMonth;
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
        final y = _selectedYear;
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
    ref.listen(transactionListRefreshTriggerProvider, (prev, next) async {
      if (prev != null && prev != next) {
        await ref.read(syncServiceProvider).syncAllIfOnline();
        if (!mounted) return;
        await _loadWallets();
        await _loadTotalSaved();
        await _loadData();
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
              await ref.read(syncServiceProvider).syncAllIfOnline();
              await _loadWallets();
              await _loadTotalSaved();
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
                              label: 'Mục tiêu tiết kiệm',
                              icon: Icons.savings_rounded,
                              gradient: [const Color(0xFF66BB6A), const Color(0xFFA5D6A7)],
                              onTap: () => Navigator.pushNamed(context, AppRouter.savingGoals),
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
                        const SectionLabel('Ví của bạn'),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_wallets.isNotEmpty)
                                  ..._wallets.map((w) => Padding(
                                        padding: const EdgeInsets.only(right: 12),
                                        child: _WalletCard(
                                        name: w.name,
                                        walletBalance: w.currentBalance ?? w.initialBalance,
                                        totalSaved: _totalSaved,
                                        periodBalance: _selectedWalletId == w.id ? _balance : null,
                                        periodLabel: _periodLabel,
                                        isSelected: _selectedWalletId == w.id,
                                        onTap: () {
                                          HapticUtils.selection();
                                          ref.read(selectedWalletIdProvider.notifier).state = w.id;
                                          _loadData();
                                        },
                                        onEdit: () => Navigator.pushNamed(context, AppRouter.wallets).then((_) => _loadWallets()),
                                      ),
                                    )),
                              _AddWalletCard(
                                onTap: () => Navigator.pushNamed(context, AppRouter.wallets).then((_) {
                                  _loadWallets();
                                  _loadData();
                                }),
                              ),
                            ],
                          ),
                        ),
                        ),
                        const SizedBox(height: 20),
                        const SpendingLimitHomeSection(),
                        const SizedBox(height: 4),
                        const SavingGoalsHomeSection(),
                        const SizedBox(height: 4),
                        PeriodFilterBar(
                          period: _period,
                          onPeriodChanged: (p) {
                            setState(() => _period = p);
                            _loadData();
                          },
                          year: _selectedYear,
                          month: _selectedMonth,
                          onMonthYearChanged: (y, m) {
                            setState(() {
                              _selectedYear = y;
                              _selectedMonth = m;
                            });
                            _loadData();
                          },
                          onYearChanged: (y) {
                            setState(() => _selectedYear = y);
                            _loadData();
                          },
                        ),
                        const SizedBox(height: 16),
                        if (_isLoading)
                          _buildSkeletonLoading()
                        else if (_error != null)
                          CardContainer(
                            child: Text(_error!, style: GoogleFonts.nunito(color: AppColors.accent)),
                          )
                        else if (_totalIncome == 0 && _totalExpense == 0)
                          EmptyState(
                            icon: Icons.account_balance_wallet_rounded,
                            title: 'Chưa có giao dịch trong ${_periodLabel.toLowerCase()}',
                            subtitle: _period == 'month'
                                ? 'Thử chọn tháng khác hoặc chuyển sang xem theo năm để thấy dữ liệu tổng hợp.'
                                : 'Thử chọn năm khác hoặc thêm giao dịch mới.',
                            actionLabel: _period == 'month' ? 'Xem theo năm $_selectedYear' : 'Thêm giao dịch',
                            onAction: () {
                              if (_period == 'month') {
                                setState(() => _period = 'year');
                                _loadData();
                              } else {
                                Navigator.pushNamed(context, AppRouter.addTransaction).then((_) {
                                  ref.read(transactionListRefreshTriggerProvider.notifier).state++;
                                });
                              }
                            },
                          )
                        else ...[
                          NetChangeSummaryCard(
                            periodLabel: _periodLabel,
                            balance: _balance,
                            totalIncome: _totalIncome,
                            totalExpense: _totalExpense,
                          ),
                          const SizedBox(height: 16),
                          ForecastPromoCard(onTap: _openSpendingForecast),
                          const SizedBox(height: 20),
                          const SectionLabel('Phân bổ theo danh mục'),
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
            style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 24),
          CategoryDonutChart(
            chartData: chartData,
            isExpense: _showExpense,
            height: 180,
          ),
          const SizedBox(height: 16),
          ...chartData.asMap().entries.map((e) {
            final color = AppColors.chartCategoryColor(e.key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        e.value['name'] as String,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${NumberFormat.compact(locale: 'vi').format(e.value['amount'])} ₫',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
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
              color: gradient.first.withValues(alpha: 0.3),
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
  final double walletBalance;
  final double totalSaved;
  final double? periodBalance;
  final String periodLabel;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  const _WalletCard({
    required this.name,
    required this.walletBalance,
    required this.totalSaved,
    this.periodBalance,
    required this.periodLabel,
    this.isSelected = false,
    this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.compact(locale: 'vi');
    final total = walletBalance + totalSaved;
    final savedPct = total > 0 ? (totalSaved / total).clamp(0.0, 1.0) : 0.0;
    final screenW = MediaQuery.sizeOf(context).width;
    final cardWidth = isSelected ? (screenW - 40 - 96 - 12).clamp(300.0, 420.0) : 200.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: cardWidth,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? null : Colors.white,
          gradient: isSelected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0x1A0288D1), Colors.white, Color(0xFFF8FAFC)],
                  stops: [0, 0.45, 1],
                )
              : null,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.22),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? AppColors.cardShadow : AppColors.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [AppColors.primary, Color(0xFF4FC3F7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isSelected ? null : AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: isSelected ? Colors.white : AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onEdit != null)
                  GestureDetector(
                    onTap: onEdit,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit_rounded, size: 14, color: AppColors.textMuted),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '${fmt.format(total)}₫',
              style: GoogleFonts.nunito(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'TỔNG TÀI SẢN',
              style: GoogleFonts.nunito(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
            if (isSelected) ...[
              if (total > 0) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Phân bổ',
                      style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                    Text(
                      'Tiết kiệm ${(savedPct * 100).round()}%',
                      style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF22C55E)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: savedPct,
                    minHeight: 5,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF66BB6A)),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _WalletSplitChip(
                        label: 'Ví chính',
                        amount: '${fmt.format(walletBalance)}₫',
                        icon: Icons.account_balance_wallet_rounded,
                        accent: AppColors.primary,
                        bg: AppColors.primary.withValues(alpha: 0.06),
                        border: AppColors.primary.withValues(alpha: 0.18),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _WalletSplitChip(
                        label: 'Tiết kiệm',
                        amount: '${fmt.format(totalSaved)}₫',
                        icon: Icons.savings_rounded,
                        accent: const Color(0xFF2E7D32),
                        bg: const Color(0xFFE8F5E9).withValues(alpha: 0.55),
                        border: const Color(0xFFA5D6A7).withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 6),
              Text(
                'Ví chính · ${fmt.format(walletBalance)}₫',
                style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
            ],
            if (periodBalance != null) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: AppColors.textMuted.withValues(alpha: 0.25)),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.trending_flat_rounded, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: RichText(
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary, height: 1.35),
                        children: [
                          TextSpan(text: 'Chênh lệch · $periodLabel: '),
                          TextSpan(
                            text: '${fmt.format(periodBalance!)}₫',
                            style: GoogleFonts.nunito(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: periodBalance! >= 0 ? AppColors.primary : AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WalletSplitChip extends StatelessWidget {
  final String label;
  final String amount;
  final IconData icon;
  final Color accent;
  final Color bg;
  final Color border;

  const _WalletSplitChip({
    required this.label,
    required this.amount,
    required this.icon,
    required this.accent,
    required this.bg,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: accent),
            ),
          ),
        ],
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
        width: 96,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.35)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              'Ví mới',
              style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted),
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
