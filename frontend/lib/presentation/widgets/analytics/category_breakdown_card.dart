import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/presentation/widgets/analytics/analytics_chart_card.dart';
import 'package:expense_manager/presentation/widgets/charts/category_donut_chart.dart';

class CategoryBreakdownCard extends StatelessWidget {
  final List<Map<String, dynamic>> chartData;
  final bool isExpense;
  final String title;

  const CategoryBreakdownCard({
    super.key,
    required this.chartData,
    required this.isExpense,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.compact(locale: 'vi');
    final total = chartData.fold<double>(
      0,
      (s, e) => s + ((e['amount'] as num?) ?? 0).toDouble(),
    );

    return AnalyticsChartCard(
      subtitle: 'Danh mục',
      title: title,
      child: Column(
        children: [
          CategoryDonutChart(
            chartData: chartData,
            isExpense: isExpense,
            height: 220,
          ),
          const SizedBox(height: 8),
          ...chartData.asMap().entries.map((e) {
            final amount = ((e.value['amount'] as num?) ?? 0).toDouble();
            final pct = total > 0 ? (amount / total * 100) : 0.0;
            final color = AppColors.chartCategoryColor(e.key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.18)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            e.value['name'] as String? ?? '',
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${fmt.format(amount)}₫',
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${pct.round()}%',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        minHeight: 6,
                        backgroundColor: color.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
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
