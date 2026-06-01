import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:expense_manager/core/router/app_router.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/domain/models/spending_forecast.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Public card widget
// ──────────────────────────────────────────────────────────────────────────────
class SpendingForecastCard extends StatelessWidget {
  const SpendingForecastCard({
    super.key,
    required this.loading,
    required this.onRun,
    this.forecast,
    this.error,
    this.walletName,
  });

  final bool loading;
  final VoidCallback onRun;
  final SpendingForecast? forecast;
  final String? error;
  final String? walletName;

  // ── helpers ──────────────────────────────────────────────────────────────

  static Color _levelColor(String level) {
    switch (level) {
      case 'ALERT':
        return AppColors.expense;
      case 'WATCH':
        return AppColors.accent;
      default:
        return AppColors.primary;
    }
  }

  static String _levelLabel(String level) {
    switch (level) {
      case 'ALERT':
        return 'Cần lưu ý';
      case 'WATCH':
        return 'Nên theo dõi';
      default:
        return 'Bình thường';
    }
  }

  static Color _severityColor(String sev) {
    switch (sev) {
      case 'OVER':
        return AppColors.expense;
      case 'WARN':
        return const Color(0xFFF59E0B);
      default:
        return AppColors.textMuted;
    }
  }

  static String _fmt(int v) =>
      '${NumberFormat('#,###', 'vi_VN').format(v)}₫';

  static String _spendZoneSubtitle(ForecastInsight? insight, int displayAvg) {
    final parts = <String>['~ ${_fmt(displayAvg)}/ngày'];
    if (insight?.paceVsBaselinePercent != null) {
      final p = insight!.paceVsBaselinePercent!;
      parts.add('${p > 0 ? '+' : ''}$p% so với TB 30 ngày');
    }
    if (insight?.projectedMonthFloorVnd != null) {
      parts.add('Tháng ≥ ${_fmt(insight!.projectedMonthFloorVnd!)}');
    }
    return parts.join(' · ');
  }

  static String _weekday(int d) {
    const w = [
      '',
      'Thứ hai',
      'Thứ ba',
      'Thứ tư',
      'Thứ năm',
      'Thứ sáu',
      'Thứ bảy',
      'Chủ nhật'
    ];
    return w[d.clamp(1, 7)];
  }

  static DateTime _parseDate(String ymd) {
    final p = ymd.split('-');
    if (p.length != 3) return DateTime.now();
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasData = forecast != null && forecast!.predictedNextDaysVnd.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.softShadow,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── header row ──────────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.auto_graph_rounded, color: AppColors.primary, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dự báo chi tiêu · 7 ngày tới',
                            style: GoogleFonts.nunito(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (walletName != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Ví: $walletName',
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF546E7A),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: loading ? null : onRun,
                      icon: loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(
                              hasData ? Icons.refresh_rounded : Icons.trending_up_rounded,
                              size: 20,
                            ),
                      label: Text(
                        loading ? 'Đang tính…' : hasData ? 'Cập nhật' : 'Xem dự báo',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),

                // ── empty prompt ─────────────────────────────────────────────
                if (!hasData && !loading && error == null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.textMuted.withValues(alpha: 0.35),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Text(
                      'Bấm “Xem dự báo” hoặc “Cập nhật” để tải gợi ý từ AI.',
                      style: GoogleFonts.nunito(fontSize: 13.5, color: AppColors.textSecondary, height: 1.4),
                    ),
                  ),
                ],

                // ── loading ──────────────────────────────────────────────────
                if (loading && !hasData) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(minHeight: 3),
                  const SizedBox(height: 6),
                  Text(
                    'Đang tính gợi ý…',
                    style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],

                // ── error ────────────────────────────────────────────────────
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      error!,
                      style: GoogleFonts.nunito(fontSize: 13, color: AppColors.accent),
                    ),
                  ),
                ],

                // ── data zones ───────────────────────────────────────────────
                if (hasData && forecast != null) ...[
                  const SizedBox(height: 18),
                  _SpendZone(forecast: forecast!),
                  const SizedBox(height: 14),
                  if (forecast!.insight != null) ...[
                    _BudgetZone(
                      alerts: forecast!.insight!.budgetAlerts,
                      onSetupBudget: () => Navigator.of(context).pushNamed(AppRouter.budget),
                    ),
                    const SizedBox(height: 14),
                  ],
                  _ActionZone(forecast: forecast!, context: context),
                  const Divider(height: 28),
                  _ChartAndDetail(forecast: forecast!),
                ],
              ],
            ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// ZONE 1: How much will I spend?
// ──────────────────────────────────────────────────────────────────────────────
class _SpendZone extends StatelessWidget {
  const _SpendZone({required this.forecast});

  final SpendingForecast forecast;

  @override
  Widget build(BuildContext context) {
    final insight = forecast.insight;
    final amounts = forecast.predictedNextDaysVnd;
    final total = amounts.fold<int>(0, (a, b) => a + b);
    final displayTotal = insight?.totalNext7DaysVnd ?? total;
    final displayAvg = insight?.avgPerDayVnd ?? (amounts.isEmpty ? 0 : (total / amounts.length).round());
    final c = insight != null
        ? SpendingForecastCard._levelColor(insight.level)
        : AppColors.primary;
    final level = insight?.level ?? 'OK';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.withValues(alpha: 0.1), c.withValues(alpha: 0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Ước tính 7 ngày',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF37474F),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.withValues(alpha: 0.45)),
                ),
                child: Text(
                  SpendingForecastCard._levelLabel(level),
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: c,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              SpendingForecastCard._fmt(displayTotal),
              maxLines: 1,
              style: GoogleFonts.nunito(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: c,
                height: 1.05,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            SpendingForecastCard._spendZoneSubtitle(insight, displayAvg),
            style: GoogleFonts.nunito(
              fontSize: 13.5,
              color: const Color(0xFF455A64),
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// ZONE 2: Budget status
// ──────────────────────────────────────────────────────────────────────────────
class _BudgetZone extends StatelessWidget {
  const _BudgetZone({required this.alerts, required this.onSetupBudget});

  final List<ForecastBudgetAlert> alerts;
  final VoidCallback onSetupBudget;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.28)),
          color: AppColors.textMuted.withValues(alpha: 0.05),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.savings_outlined, size: 22, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'So với ngân sách đã đặt',
                    style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Chưa có ngân sách theo danh mục còn hiệu lực trong tháng này. Thêm ngân sách để so sánh mức đã chi với hạn mức.',
                    style: GoogleFonts.nunito(fontSize: 13, height: 1.45, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: onSetupBudget,
                    icon: const Icon(Icons.savings_outlined, size: 18),
                    label: Text('Đặt ngân sách', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final hasIssue = alerts.any((a) => a.severity != 'OK');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.savings_outlined, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              'So với ngân sách đã đặt',
              style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
            ),
            if (hasIssue) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Có mục cần xem',
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        ...alerts.take(6).map((a) {
          final c = SpendingForecastCard._severityColor(a.severity);
          final pct = a.percentUsed.clamp(0, 100).toDouble();
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: a.severity != 'OK' ? c.withValues(alpha: 0.06) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (a.severity == 'OVER')
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(Icons.warning_amber_rounded, size: 14, color: c),
                        ),
                      Expanded(
                        child: Text(
                          a.categoryName,
                          style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '${SpendingForecastCard._fmt(a.spentVnd)} / ${SpendingForecastCard._fmt(a.budgetAmountVnd)}',
                        style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textMuted),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          a.severity == 'OVER'
                              ? 'Vượt ${a.percentUsed}%'
                              : '${a.percentUsed}%',
                          style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w800, color: c),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      minHeight: 5,
                      backgroundColor: c.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(c),
                    ),
                  ),
                  if (a.severity == 'OVER') ...[
                    const SizedBox(height: 4),
                    Text(
                      'Còn lại: -${SpendingForecastCard._fmt(a.remainingVnd.abs())} (đã vượt)',
                      style: GoogleFonts.nunito(fontSize: 11, color: c, fontWeight: FontWeight.w700),
                    ),
                  ] else if (a.severity == 'WARN') ...[
                    const SizedBox(height: 4),
                    Text(
                      'Còn lại: ${SpendingForecastCard._fmt(a.remainingVnd)}',
                      style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// ZONE 3: Actions
// ──────────────────────────────────────────────────────────────────────────────
class _ActionZone extends StatelessWidget {
  const _ActionZone({required this.forecast, required this.context});

  final SpendingForecast forecast;
  final BuildContext context;

  @override
  Widget build(BuildContext ctx) {
    final insight = forecast.insight;
    final level = insight?.level ?? 'OK';
    final tips = insight?.tipsVi ?? [];
    final c = SpendingForecastCard._levelColor(level);
    final isAlert = level == 'ALERT';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gợi ý',
          style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        if (tips.isNotEmpty) ...[
          ...tips.take(2).map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: GoogleFonts.nunito(color: c, fontWeight: FontWeight.w800, fontSize: 14)),
                  Expanded(
                    child: Text(
                      t,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity,
          child: isAlert
              ? FilledButton.icon(
                  onPressed: () => Navigator.of(ctx).pushNamed(AppRouter.budget),
                  icon: const Icon(Icons.savings_outlined),
                  label: Text(
                    'Chỉnh ngân sách',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: c,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                )
              : OutlinedButton.icon(
                  onPressed: () => Navigator.of(ctx).pushNamed(AppRouter.budget),
                  icon: const Icon(Icons.savings_outlined, size: 18),
                  label: Text(
                    'Mở Ngân sách',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Chart + day detail
// ──────────────────────────────────────────────────────────────────────────────
class _ChartAndDetail extends StatefulWidget {
  const _ChartAndDetail({required this.forecast});

  final SpendingForecast forecast;

  @override
  State<_ChartAndDetail> createState() => _ChartAndDetailState();
}

class _ChartAndDetailState extends State<_ChartAndDetail> {
  bool _daysOpen = false;

  @override
  Widget build(BuildContext context) {
    final forecast = widget.forecast;
    final amounts = forecast.predictedNextDaysVnd;
    final base = SpendingForecastCard._parseDate(forecast.lastObservationDate);
    final total = amounts.fold<int>(0, (a, b) => a + b);
    final avg = amounts.isEmpty ? 0 : (total / amounts.length).round();
    final maxV = amounts.reduce((a, b) => a > b ? a : b);
    final minV = amounts.reduce((a, b) => a < b ? a : b);
    final maxIdx = amounts.indexOf(maxV);

    final spots = <FlSpot>[
      for (var i = 0; i < amounts.length; i++) FlSpot(i.toDouble(), amounts[i].toDouble()),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // day rows (collapsible) — trước biểu đồ để luôn thấy
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _daysOpen = !_daysOpen),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Chi tiết từng ngày (dự báo)',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Icon(
                    _daysOpen ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _daysOpen
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    ...List.generate(amounts.length, (i) {
                      final amt = amounts[i];
                      final d = base.add(Duration(days: i + 1));
                      final pct = maxV > 0 ? amt / maxV : 0.0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.15)),
                            color: i == maxIdx ? AppColors.primary.withValues(alpha: 0.04) : Colors.white,
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        SpendingForecastCard._weekday(d.weekday),
                                        style: GoogleFonts.nunito(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF546E7A),
                                        ),
                                      ),
                                      Text(
                                        DateFormat('dd/MM/yyyy').format(d),
                                        style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    SpendingForecastCard._fmt(amt),
                                    style: GoogleFonts.nunito(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: i == maxIdx ? AppColors.expense : AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 4,
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    i == maxIdx ? AppColors.expense : AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),

        // line chart
        SizedBox(
          height: 190,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxV > 0 ? maxV * 1.12 : 1,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxV > 0 ? maxV / 4 : 1,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: AppColors.textMuted.withValues(alpha: 0.2), strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (v, _) {
                      final i = v.round();
                      if (i < 0 || i >= amounts.length) return const SizedBox.shrink();
                      final d = base.add(Duration(days: i + 1));
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          DateFormat('dd/MM').format(d),
                          style: GoogleFonts.nunito(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF546E7A),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots.map((s) {
                    final d = base.add(Duration(days: s.x.round() + 1));
                    final label =
                        '${SpendingForecastCard._weekday(d.weekday)}, ${DateFormat('dd/MM/yyyy').format(d)}\n${SpendingForecastCard._fmt(s.y.round())}';
                    return LineTooltipItem(
                      label,
                      GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: AppColors.primary,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (s, _, __, i) => FlDotCirclePainter(
                      radius: i == maxIdx ? 5 : 3,
                      color: AppColors.primary,
                      strokeWidth: 0,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [AppColors.primary.withValues(alpha: 0.3), AppColors.primary.withValues(alpha: 0.0)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // summary tiles
        LayoutBuilder(builder: (context, c) {
          final isNarrow = c.maxWidth < 400;
          final tiles = [
            _tile('Tổng 7 ngày', SpendingForecastCard._fmt(total), emphasize: true),
            _tile('TB / ngày', SpendingForecastCard._fmt(avg)),
            _tile('Thấp nhất', SpendingForecastCard._fmt(minV)),
            _tile('Cao nhất', SpendingForecastCard._fmt(maxV), hint: 'Ngày ${maxIdx + 1}'),
          ];
          if (isNarrow) {
            return Column(children: [
              Row(children: [Expanded(child: tiles[0]), const SizedBox(width: 8), Expanded(child: tiles[1])]),
              const SizedBox(height: 8),
              Row(children: [Expanded(child: tiles[2]), const SizedBox(width: 8), Expanded(child: tiles[3])]),
            ]);
          }
          return Row(children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: tiles[i]),
            ],
          ]);
        }),
      ],
    );
  }

  static Widget _tile(String label, String value, {bool emphasize = false, String? hint}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: emphasize ? AppColors.primary.withValues(alpha: 0.45) : AppColors.textMuted.withValues(alpha: 0.2),
          width: emphasize ? 2 : 1,
        ),
        color: emphasize ? AppColors.primary.withValues(alpha: 0.06) : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF546E7A))),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          if (hint != null)
            Text(
              hint,
              style: GoogleFonts.nunito(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF607D8B),
              ),
            ),
        ],
      ),
    );
  }
}
