import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/domain/models/statistics.dart';

/// Biểu đồ thu/chi theo ngày — tối ưu mobile: cuộn ngang khi tháng dài.
class DailyFlowLineChart extends StatefulWidget {
  final List<DaySummary> days;

  const DailyFlowLineChart({super.key, required this.days});

  @override
  State<DailyFlowLineChart> createState() => _DailyFlowLineChartState();
}

class _DailyFlowLineChartState extends State<DailyFlowLineChart> {
  static const double _chartHeight = 240;
  static const double _yAxisWidth = 52;
  static const double _daySlotWidth = 36;

  int? _touchedIndex;

  static final _moneyFmt = NumberFormat('#,###', 'vi');

  static FlDotPainter _dotPainter(FlSpot spot, LineChartBarData barData) {
    if (spot.y <= 0) {
      return FlDotCirclePainter(
        radius: 0,
        color: Colors.transparent,
        strokeWidth: 0,
      );
    }
    return FlDotCirclePainter(
      radius: 3.5,
      color: barData.color ?? Colors.grey,
      strokeWidth: 1.5,
      strokeColor: Colors.white,
    );
  }

  String _dayDetailText(DaySummary day) {
    return 'Ngày ${day.date.day} · Thu: ${_moneyFmt.format(day.income)} ₫ · Chi: ${_moneyFmt.format(day.expense)} ₫';
  }

  @override
  Widget build(BuildContext context) {
    final days = widget.days;
    if (days.isEmpty) return const SizedBox.shrink();

    final maxVal = days.fold<double>(0, (m, d) {
      final x = d.income > d.expense ? d.income : d.expense;
      return x > m ? x : m;
    });
    final maxY = maxVal > 0 ? maxVal * 1.22 : 1.0;
    final gridInterval =
        maxVal > 0 ? (maxY / 4).clamp(maxVal * 0.05, double.infinity) : 1.0;

    final spotsIncome =
        days.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.income)).toList();
    final spotsExpense =
        days.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.expense)).toList();

    final viewportWidth = MediaQuery.sizeOf(context).width - 40 - _yAxisWidth;
    final contentWidth = math.max(viewportWidth, days.length * _daySlotWidth);
    final scrollable = contentWidth > viewportWidth + 1;

    final lineData = LineChartData(
      clipData: const FlClipData.all(),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: gridInterval,
        getDrawingHorizontalLine: (v) =>
            FlLine(color: Colors.grey.shade200, strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: scrollable ? 1 : (days.length <= 7 ? 1 : (days.length / 6).ceilToDouble()),
            getTitlesWidget: (v, m) {
              final i = v.round();
              if (i >= 0 && i < days.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${days[i].date.day}',
                    style: GoogleFonts.nunito(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
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
      lineTouchData: LineTouchData(
        enabled: true,
        touchSpotThreshold: 24,
        handleBuiltInTouches: true,
        touchCallback: (event, response) {
          if (!event.isInterestedForInteractions ||
              response?.lineBarSpots == null ||
              response!.lineBarSpots!.isEmpty) {
            setState(() => _touchedIndex = null);
            return;
          }
          final idx = response.lineBarSpots!.first.spotIndex;
          setState(() => _touchedIndex = idx);
        },
        getTouchedSpotIndicator: (barData, spotIndexes) {
          return spotIndexes.map((index) {
            return TouchedSpotIndicatorData(
              FlLine(color: AppColors.primary.withValues(alpha: 0.35), strokeWidth: 1.5),
              FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, i) => FlDotCirclePainter(
                  radius: 5,
                  color: bar.color ?? AppColors.primary,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
              ),
            );
          }).toList();
        },
        touchTooltipData: LineTouchTooltipData(
          tooltipRoundedRadius: 10,
          tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          getTooltipItems: (touchedSpots) {
            if (touchedSpots.isEmpty) return [];
            final idx = touchedSpots.first.spotIndex;
            if (idx < 0 || idx >= days.length) {
              return List.filled(touchedSpots.length, null);
            }
            final day = days[idx];
            final text = 'Ngày ${day.date.day}\nThu: ${_moneyFmt.format(day.income)} ₫\nChi: ${_moneyFmt.format(day.expense)} ₫';
            return touchedSpots.asMap().entries.map((entry) {
              if (entry.key != 0) return null;
              return LineTooltipItem(
                text,
                GoogleFonts.nunito(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  height: 1.35,
                ),
              );
            }).toList();
          },
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spotsIncome,
          isCurved: false,
          color: AppColors.income,
          barWidth: 2.2,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) => _dotPainter(spot, barData),
          ),
          belowBarData: BarAreaData(
            show: true,
            color: AppColors.income.withValues(alpha: 0.12),
          ),
        ),
        LineChartBarData(
          spots: spotsExpense,
          isCurved: false,
          color: AppColors.expense,
          barWidth: 2.2,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) => _dotPainter(spot, barData),
          ),
          belowBarData: BarAreaData(
            show: true,
            color: AppColors.expense.withValues(alpha: 0.12),
          ),
        ),
      ],
    );

    final selectedDay = _touchedIndex != null && _touchedIndex! >= 0 && _touchedIndex! < days.length
        ? days[_touchedIndex!]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _LegendDot(color: AppColors.income, label: 'Thu'),
            const SizedBox(width: 16),
            _LegendDot(color: AppColors.expense, label: 'Chi'),
          ],
        ),
        if (scrollable) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.swipe_rounded, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Vuốt ngang để xem toàn bộ các ngày trong tháng · Chạm vào điểm để xem chi tiết',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (selectedDay != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.touch_app_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _dayDetailText(selectedDay),
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          height: _chartHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: _yAxisWidth,
                child: _FixedYAxis(maxY: maxY, interval: gridInterval),
              ),
              Expanded(
                child: scrollable
                    ? SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        child: SizedBox(
                          width: contentWidth,
                          height: _chartHeight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8, top: 8),
                            child: LineChart(lineData, duration: const Duration(milliseconds: 250)),
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.only(right: 4, top: 8),
                        child: LineChart(lineData, duration: const Duration(milliseconds: 250)),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FixedYAxis extends StatelessWidget {
  final double maxY;
  final double interval;

  const _FixedYAxis({required this.maxY, required this.interval});

  @override
  Widget build(BuildContext context) {
    const steps = 4;
    final fmt = NumberFormat.compact(locale: 'vi');
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 30, right: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(steps + 1, (i) {
          final value = maxY - (maxY / steps) * i;
          return Text(
            fmt.format(value),
            style: GoogleFonts.nunito(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
            textAlign: TextAlign.right,
          );
        }),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
