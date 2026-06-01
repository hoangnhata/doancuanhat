import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:expense_manager/core/theme/app_theme.dart';

/// Donut theo danh mục: mỗi mục một màu, giữa hiển thị tổng/chi tiết, hover/chạm đổi nội dung giữa.
class CategoryDonutChart extends StatefulWidget {
  final List<Map<String, dynamic>> chartData;
  final bool isExpense;
  final double height;

  const CategoryDonutChart({
    super.key,
    required this.chartData,
    required this.isExpense,
    this.height = 180,
  });

  @override
  State<CategoryDonutChart> createState() => _CategoryDonutChartState();
}

class _CategoryDonutChartState extends State<CategoryDonutChart> {
  int? _touchedIndex;

  String _dataSignature(List<Map<String, dynamic>> d) =>
      d.map((e) => '${e['name']}_${e['amount']}').join('|');

  @override
  void didUpdateWidget(CategoryDonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isExpense != widget.isExpense ||
        _dataSignature(oldWidget.chartData) != _dataSignature(widget.chartData)) {
      _touchedIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chartData = widget.chartData;
    if (chartData.isEmpty) return SizedBox(height: widget.height);

    final fmt = NumberFormat.compact(locale: 'vi');
    final total = chartData.fold<double>(
      0,
      (s, e) => s + (e['amount'] as num).toDouble(),
    );
    final idx = _touchedIndex;
    final slice = (idx != null && idx >= 0 && idx < chartData.length) ? chartData[idx] : null;
    final amount = slice != null ? (slice['amount'] as num).toDouble() : total;
    final single = chartData.length == 1;
    final defaultTitle = single
        ? (chartData.first['name'] as String)
        : (widget.isExpense ? 'Tổng chi' : 'Tổng thu');
    final title = slice != null ? (slice['name'] as String) : defaultTitle;
    final pct = slice != null && total > 0 && chartData.length > 1
        ? '${((amount / total) * 100).round()}%'
        : null;

    return SizedBox(
      height: widget.height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 52,
              sections: chartData.asMap().entries.map((e) {
                return PieChartSectionData(
                  value: (e.value['amount'] as num).toDouble(),
                  title: '',
                  showTitle: false,
                  color: AppColors.chartCategoryColor(e.key),
                  radius: 28,
                );
              }).toList(),
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    final touched = pieTouchResponse?.touchedSection;
                    if (!event.isInterestedForInteractions || touched == null) {
                      _touchedIndex = null;
                      return;
                    }
                    _touchedIndex = touched.touchedSectionIndex;
                  });
                },
              ),
            ),
          ),
          Center(
            child: IgnorePointer(
              child: SizedBox(
                width: 118,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${fmt.format(amount)} ₫',
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (pct != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        pct,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
