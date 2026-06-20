import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/providers/app_providers.dart';
import 'package:expense_manager/core/utils/api_error.dart';
import 'package:expense_manager/domain/models/statistics.dart';
import 'package:expense_manager/presentation/widgets/common/period_filter_bar.dart';
import 'package:expense_manager/presentation/widgets/dashboard/section_label.dart';
import 'package:expense_manager/presentation/widgets/analytics/analytics_chart_card.dart';
import 'package:expense_manager/presentation/widgets/analytics/analytics_summary_row.dart';
import 'package:expense_manager/presentation/widgets/analytics/category_breakdown_card.dart';
import 'package:expense_manager/presentation/widgets/analytics/daily_flow_line_chart.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String _period = 'month'; // month | year
  int _selectedYear = 0;
  int _selectedMonth = 0;
  bool _isLoading = true;
  double _totalIncome = 0;
  double _totalExpense = 0;
  double _balance = 0;
  double _prevMonthIncome = 0;
  double _prevMonthExpense = 0;
  List<Map<String, dynamic>> _chartData = [];
  bool _showExpense = true;
  List<DaySummary> _dailyBreakdown = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(statisticsRepositoryProvider);
      final categoryType = _showExpense ? 'EXPENSE' : 'INCOME';
      final stats = _period == 'month'
          ? await repo.getByMonth(_selectedYear, _selectedMonth, categoryType: categoryType)
          : await repo.getByYear(_selectedYear, categoryType: categoryType);

      double prevIncome = 0, prevExpense = 0;
      List<DaySummary> daily = [];
      if (_period == 'month') {
        final prevMonth = _selectedMonth == 1 ? 12 : _selectedMonth - 1;
        final prevYear = _selectedMonth == 1 ? _selectedYear - 1 : _selectedYear;
        try {
          final prevStats = await repo.getByMonth(prevYear, prevMonth);
          prevIncome = prevStats.totalIncome;
          prevExpense = prevStats.totalExpense;
        } catch (_) {}
        try {
          final start = DateTime(_selectedYear, _selectedMonth, 1);
          final end = DateTime(_selectedYear, _selectedMonth + 1, 0);
          final breakdown = await repo.getDailyBreakdown(start, end);
          daily = breakdown.days;
        } catch (_) {}
      }

      setState(() {
        _totalIncome = stats.totalIncome;
        _totalExpense = stats.totalExpense;
        _balance = stats.totalIncome - stats.totalExpense;
        _prevMonthIncome = prevIncome;
        _prevMonthExpense = prevExpense;
        _chartData = stats.byCategory.map((c) => {'name': c.categoryName, 'amount': c.amount}).toList();
        _dailyBreakdown = daily;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _showExportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Xuất báo cáo', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Báo cáo chuyên nghiệp gồm KPI, phân tích danh mục và chi tiết giao dịch',
                style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              _ExportOption(
                icon: Icons.table_chart_rounded,
                label: 'Excel (.xlsx)',
                subtitle: '2 sheet: báo cáo chi tiết + phân tích danh mục',
                onTap: () async {
                  Navigator.pop(ctx);
                  final start = _period == 'month'
                      ? DateTime(_selectedYear, _selectedMonth, 1)
                      : DateTime(_selectedYear, 1, 1);
                  final end = _period == 'month'
                      ? DateTime(_selectedYear, _selectedMonth + 1, 0)
                      : DateTime(_selectedYear, 12, 31);
                  try {
                    await ref.read(exportRepositoryProvider).exportTransactions(
                      format: 'excel',
                      startDate: start,
                      endDate: end,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đã xuất Excel', style: GoogleFonts.nunito())),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Xuất thất bại: ${extractErrorMessage(e)}', style: GoogleFonts.nunito())),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 12),
              _ExportOption(
                icon: Icons.picture_as_pdf_rounded,
                label: 'PDF (báo cáo chi tiết)',
                subtitle: 'Định dạng in ấn, KPI và bảng có viền rõ ràng',
                onTap: () async {
                  Navigator.pop(ctx);
                  final start = _period == 'month'
                      ? DateTime(_selectedYear, _selectedMonth, 1)
                      : DateTime(_selectedYear, 1, 1);
                  final end = _period == 'month'
                      ? DateTime(_selectedYear, _selectedMonth + 1, 0)
                      : DateTime(_selectedYear, 12, 31);
                  try {
                    await ref.read(exportRepositoryProvider).exportTransactions(
                      format: 'pdf',
                      startDate: start,
                      endDate: end,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đã xuất PDF', style: GoogleFonts.nunito())),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Xuất thất bại: ${extractErrorMessage(e)}', style: GoogleFonts.nunito())),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final periodLabel =
        _period == 'month' ? 'Tháng $_selectedMonth/$_selectedYear' : 'Năm $_selectedYear';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Phân tích', style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 18)),
            Text(
              'Thống kê theo kỳ & danh mục',
              style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: () => _showExportSheet(context),
            tooltip: 'Xuất báo cáo',
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                      const SizedBox(height: 20),
                      AnalyticsSummaryRow(
                        periodLabel: periodLabel,
                        balance: _balance,
                        totalIncome: _totalIncome,
                        totalExpense: _totalExpense,
                      ),
                      const SizedBox(height: 24),
                      const SectionLabel('Phân bổ theo loại'),
                      Row(
                        children: [
                          Expanded(child: _TypeToggle(
                            label: 'Chi phí',
                            selected: _showExpense,
                            color: AppColors.expense,
                            onTap: () {
                              setState(() => _showExpense = true);
                              _loadData();
                            },
                          )),
                          const SizedBox(width: 10),
                          Expanded(child: _TypeToggle(
                            label: 'Thu nhập',
                            selected: !_showExpense,
                            color: AppColors.income,
                            onTap: () {
                              setState(() => _showExpense = false);
                              _loadData();
                            },
                          )),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_chartData.isNotEmpty)
                        CategoryBreakdownCard(
                          chartData: _chartData,
                          isExpense: _showExpense,
                          title: _showExpense ? 'Chi tiêu theo danh mục' : 'Thu nhập theo danh mục',
                        )
                      else
                        AnalyticsChartCard(
                          subtitle: 'Danh mục',
                          title: _showExpense ? 'Chi tiêu theo danh mục' : 'Thu nhập theo danh mục',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Column(
                              children: [
                                Icon(Icons.pie_chart_rounded, size: 48, color: AppColors.textMuted),
                                const SizedBox(height: 12),
                                Text(
                                  'Chưa có dữ liệu',
                                  style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Thêm giao dịch để xem phân tích theo danh mục',
                                  style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textSecondary),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_period == 'month' && _dailyBreakdown.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        AnalyticsChartCard(
                          subtitle: 'Xu hướng',
                          title: 'Thu / chi theo ngày trong tháng',
                          child: DailyFlowLineChart(days: _dailyBreakdown),
                        ),
                      ],
                      if (_period == 'month' && (_prevMonthIncome > 0 || _prevMonthExpense > 0)) ...[
                        const SizedBox(height: 20),
                        AnalyticsChartCard(
                          subtitle: 'So sánh',
                          title: 'Tháng này vs tháng trước',
                          child: _MonthCompareChart(
                            thisMonthIncome: _totalIncome,
                            thisMonthExpense: _totalExpense,
                            prevMonthIncome: _prevMonthIncome,
                            prevMonthExpense: _prevMonthExpense,
                          ),
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

class _TypeToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TypeToggle({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.15) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: selected ? 0 : 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.4) : AppColors.textMuted.withValues(alpha: 0.2),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: selected ? color : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthCompareChart extends StatelessWidget {
  final double thisMonthIncome;
  final double thisMonthExpense;
  final double prevMonthIncome;
  final double prevMonthExpense;

  const _MonthCompareChart({
    required this.thisMonthIncome,
    required this.thisMonthExpense,
    required this.prevMonthIncome,
    required this.prevMonthExpense,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal = [thisMonthIncome, thisMonthExpense, prevMonthIncome, prevMonthExpense]
        .reduce((a, b) => a > b ? a : b);
    final maxHeight = maxVal > 0 ? maxVal : 1.0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _CompareBar(label: 'Thu\nT.trước', value: prevMonthIncome, max: maxHeight, color: AppColors.income.withValues(alpha: 0.55)),
            _CompareBar(label: 'Chi\nT.trước', value: prevMonthExpense, max: maxHeight, color: AppColors.expense.withValues(alpha: 0.55)),
            _CompareBar(label: 'Thu\nT.này', value: thisMonthIncome, max: maxHeight, color: AppColors.income),
            _CompareBar(label: 'Chi\nT.này', value: thisMonthExpense, max: maxHeight, color: AppColors.expense),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'T.trước = Tháng trước · T.này = Tháng đang chọn',
          style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _CompareBar extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final Color color;

  const _CompareBar({required this.label, required this.value, required this.max, required this.color});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.compact(locale: 'vi');
    final height = max > 0 ? (value / max * 100).clamp(6.0, 100.0) : 6.0;
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: height,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color, color.withValues(alpha: 0.65)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            fmt.format(value),
            style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ExportOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _ExportOption({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 15)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}
