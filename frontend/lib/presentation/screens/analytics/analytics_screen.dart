import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/providers/app_providers.dart';
import 'package:expense_manager/core/utils/api_error.dart';
import 'package:expense_manager/domain/models/statistics.dart';
import 'package:expense_manager/presentation/widgets/charts/category_donut_chart.dart';

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
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Xuất báo cáo', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              _ExportOption(
                icon: Icons.table_chart_rounded,
                label: 'Excel (.xlsx)',
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
    final fmt = NumberFormat.compact(locale: 'vi');
    return Scaffold(
      appBar: AppBar(
        title: Text('Phân tích', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _FilterChip(
                              label: 'Tháng',
                              isSelected: _period == 'month',
                              onTap: () => setState(() {
                                _period = 'month';
                                _loadData();
                              }),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _FilterChip(
                              label: 'Năm',
                              isSelected: _period == 'year',
                              onTap: () => setState(() {
                                _period = 'year';
                                _loadData();
                              }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _period == 'month'
                          ? _MonthYearPicker(
                              month: _selectedMonth,
                              year: _selectedYear,
                              onChanged: (m, y) {
                                setState(() {
                                  _selectedMonth = m;
                                  _selectedYear = y;
                                  _loadData();
                                });
                              },
                            )
                          : _YearPicker(
                              year: _selectedYear,
                              onChanged: (y) {
                                setState(() {
                                  _selectedYear = y;
                                  _loadData();
                                });
                              },
                            ),
                      const SizedBox(height: 24),
                      _SummaryCard(
                        title: 'Tổng thu',
                        value: '${fmt.format(_totalIncome)}₫',
                        color: AppColors.income,
                      ),
                      const SizedBox(height: 12),
                      _SummaryCard(
                        title: 'Tổng chi',
                        value: '${fmt.format(_totalExpense)}₫',
                        color: AppColors.expense,
                      ),
                      const SizedBox(height: 12),
                      _SummaryCard(
                        title: 'Chênh lệch',
                        value: '${fmt.format(_balance)}₫',
                        color: _balance >= 0 ? AppColors.primary : AppColors.accent,
                      ),
                      if (_period == 'month' && (_prevMonthIncome > 0 || _prevMonthExpense > 0)) ...[
                        const SizedBox(height: 24),
                        Text(
                          'So sánh với tháng trước',
                          style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        _MonthCompareChart(
                          thisMonthIncome: _totalIncome,
                          thisMonthExpense: _totalExpense,
                          prevMonthIncome: _prevMonthIncome,
                          prevMonthExpense: _prevMonthExpense,
                        ),
                      ],
                      if (_period == 'month' && _dailyBreakdown.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Biểu đồ theo thời gian',
                          style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        _DailyLineChart(days: _dailyBreakdown),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _showExpense = true;
                                _loadData();
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _showExpense ? AppColors.expense.withOpacity(0.2) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Chi phí',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w600,
                                    color: _showExpense ? AppColors.expense : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _showExpense = false;
                                _loadData();
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: !_showExpense ? AppColors.income.withOpacity(0.2) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Thu nhập',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w600,
                                    color: !_showExpense ? AppColors.income : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_chartData.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: AppColors.softShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Theo danh mục',
                                style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 20),
                              CategoryDonutChart(
                                chartData: _chartData,
                                isExpense: _showExpense,
                                height: 180,
                              ),
                              const SizedBox(height: 16),
                              ...(_chartData.asMap().entries.map((entry) {
                                final i = entry.key;
                                final c = entry.value;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: AppColors.chartCategoryColor(i),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          c['name'] as String? ?? '',
                                          style: GoogleFonts.nunito(fontSize: 14),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        '${fmt.format((c['amount'] as num?) ?? 0)}₫',
                                        style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                );
                              })),
                            ],
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: AppColors.softShadow,
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.pie_chart_rounded, size: 48, color: AppColors.textMuted),
                              const SizedBox(height: 12),
                              Text(
                                'Chưa có dữ liệu',
                                style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'Thêm giao dịch để xem phân tích theo danh mục',
                                style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textSecondary),
                                textAlign: TextAlign.center,
                              ),
                            ],
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

class _DailyLineChart extends StatelessWidget {
  final List<DaySummary> days;

  const _DailyLineChart({required this.days});

  static FlDotPainter _dotPainter(FlSpot spot, LineChartBarData barData) {
    if (spot.y <= 0) {
      return FlDotCirclePainter(
        radius: 0,
        color: Colors.transparent,
        strokeWidth: 0,
      );
    }
    return FlDotCirclePainter(
      radius: 4,
      color: barData.color ?? Colors.grey,
      strokeWidth: 2,
      strokeColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();
    final maxVal = days.fold<double>(
      0,
      (m, d) {
        final x = d.income > d.expense ? d.income : d.expense;
        return x > m ? x : m;
      },
    );
    // Khoảng đệm phía trên để nhãn trục Y và đường line không bị cắt
    final maxY = maxVal > 0 ? maxVal * 1.25 : 1.0;
    final gridInterval = maxVal > 0 ? (maxY / 4).clamp(maxVal * 0.05, double.infinity) : 1.0;
    final spotsIncome = days.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.income)).toList();
    final spotsExpense = days.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.expense)).toList();

    final bottomInterval =
        days.length <= 7 ? 1.0 : (days.length / 6).ceilToDouble().clamp(1.0, days.length.toDouble());

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Row(
                children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: AppColors.income, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(width: 6),
                  Text('Thu', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(width: 16),
              Row(
                children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: AppColors.expense, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(width: 6),
                  Text('Chi', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 228,
            child: Padding(
              padding: const EdgeInsets.only(right: 6, top: 10, left: 2),
              child: LineChart(
                LineChartData(
                  clipData: const FlClipData.all(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: gridInterval,
                    getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 46,
                        interval: gridInterval,
                        getTitlesWidget: (v, m) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              NumberFormat.compact(locale: 'vi').format(v),
                              style: GoogleFonts.nunito(fontSize: 10, color: AppColors.textMuted),
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: bottomInterval,
                        getTitlesWidget: (v, m) {
                          final i = v.round();
                          if (i >= 0 && i < days.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '${days[i].date.day}',
                                style: GoogleFonts.nunito(fontSize: 10, color: AppColors.textMuted),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (days.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spotsIncome,
                      // Nối thẳng từng ngày — tránh spline làm đường "lộn xuống" dưới 0 khi chỉ có một đỉnh
                      isCurved: false,
                      color: AppColors.income,
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) => _dotPainter(spot, barData),
                      ),
                      belowBarData: BarAreaData(show: true, color: AppColors.income.withOpacity(0.14)),
                    ),
                    LineChartBarData(
                      spots: spotsExpense,
                      isCurved: false,
                      color: AppColors.expense,
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) => _dotPainter(spot, barData),
                      ),
                      belowBarData: BarAreaData(show: true, color: AppColors.expense.withOpacity(0.14)),
                    ),
                  ],
                ),
                duration: const Duration(milliseconds: 250),
              ),
            ),
          ),
        ],
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CompareBar(label: 'Thu (Ttr)', value: prevMonthIncome, max: maxHeight, color: AppColors.income),
              _CompareBar(label: 'Chi (Ttr)', value: prevMonthExpense, max: maxHeight, color: AppColors.expense),
              _CompareBar(label: 'Thu (Tn)', value: thisMonthIncome, max: maxHeight, color: AppColors.income),
              _CompareBar(label: 'Chi (Tn)', value: thisMonthExpense, max: maxHeight, color: AppColors.expense),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Ttr = Tháng trước | Tn = Tháng này',
            style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
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
    final height = max > 0 ? (value / max * 80).clamp(4.0, 100.0) : 4.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Container(
          width: 32,
          height: height,
          decoration: BoxDecoration(
            color: color.withOpacity(0.6),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          fmt.format(value),
          style: GoogleFonts.nunito(fontSize: 10, color: AppColors.textSecondary),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ExportOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ExportOption({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label, style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.2) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppColors.softShadow,
        ),
        child: Text(label, textAlign: TextAlign.center, style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _MonthYearPicker extends StatelessWidget {
  final int month;
  final int year;
  final void Function(int month, int year) onChanged;

  const _MonthYearPicker({required this.month, required this.year, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime(year, month, 1),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (date != null) onChanged(date.month, date.year);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppColors.softShadow,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_month_rounded, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text('Tháng $month/$year', style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _YearPicker extends StatelessWidget {
  final int year;
  final void Function(int year) onChanged;

  const _YearPicker({required this.year, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime(year, 1, 1),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (date != null) onChanged(date.year);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppColors.softShadow,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today_rounded, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text('Năm $year', style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _SummaryCard({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textSecondary)),
          Text(value, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}
