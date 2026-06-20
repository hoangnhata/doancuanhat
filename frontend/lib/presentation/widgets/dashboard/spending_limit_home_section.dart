import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:expense_manager/core/providers/app_providers.dart';
import 'package:expense_manager/core/router/app_router.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/domain/models/spending_limit.dart';
import 'package:expense_manager/presentation/widgets/category/category_select_field.dart';
import 'package:expense_manager/presentation/widgets/common/card_container.dart';
import 'package:expense_manager/presentation/widgets/dashboard/section_label.dart';

class SpendingLimitHomeSection extends ConsumerStatefulWidget {
  const SpendingLimitHomeSection({super.key});

  @override
  ConsumerState<SpendingLimitHomeSection> createState() => _SpendingLimitHomeSectionState();
}

class _SpendingLimitHomeSectionState extends ConsumerState<SpendingLimitHomeSection> {
  List<SpendingLimit> _limits = [];
  List<SpendingLimitAlert> _alerts = [];
  bool _loading = true;
  bool _expanded = false;

  static final _moneyFmt = NumberFormat('#,###', 'vi');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(spendingLimitRepositoryProvider);
      final limits = await repo.getAll();
      final alerts = await repo.getAlerts();
      if (!mounted) return;
      setState(() {
        _limits = limits;
        _alerts = alerts;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(SpendingLimitStatus status) {
    switch (status) {
      case SpendingLimitStatus.exceeded:
        return AppColors.expense;
      case SpendingLimitStatus.warning:
        return const Color(0xFFFF9800);
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final preview = _limits.take(3).toList();
    final hasAlerts = _alerts.isNotEmpty;
    final showExpandToggle = preview.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: SectionLabel('Hạn mức chi tiêu')),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, AppRouter.budget).then((_) => _load()),
              child: Text('Xem tất cả', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        CardContainer(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: showExpandToggle ? () => setState(() => _expanded = !_expanded) : null,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: hasAlerts
                              ? const Color(0xFFFFF3E0)
                              : AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          hasAlerts ? Icons.warning_amber_rounded : Icons.speed_rounded,
                          color: hasAlerts ? const Color(0xFFF57C00) : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _limits.isEmpty
                                  ? 'Chưa có hạn mức'
                                  : hasAlerts
                                      ? '${_alerts.length} cảnh báo hạn mức'
                                      : 'Hạn mức chi tiêu',
                              style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                            Text(
                              _limits.isEmpty
                                  ? 'Nhấn để tạo hạn mức theo danh mục'
                                  : _expanded
                                      ? '${_limits.length} hạn mức đang theo dõi'
                                      : hasAlerts
                                          ? 'Nhấn để xem chi tiết cảnh báo'
                                          : '${_limits.length} hạn mức · Nhấn để xem chi tiết',
                              style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (showExpandToggle)
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 250),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.expand_more_rounded, color: AppColors.textMuted),
                          ),
                        )
                      else
                        const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
              if (hasAlerts && !_expanded && preview.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _alerts.take(3).map((a) {
                      final limit = _limits.where((l) => l.id == a.limitId).firstOrNull;
                      final name = limit?.category?.name ?? 'Danh mục';
                      final i = _limits.indexWhere((l) => l.id == a.limitId);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CategoryIconBadge(
                              name: name,
                              icon: limit?.category?.icon,
                              colorIndex: i >= 0 ? i : 0,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              name,
                              style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFE65100)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: preview.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: FilledButton(
                          onPressed: () => Navigator.pushNamed(context, AppRouter.budget).then((_) => _load()),
                          child: const Text('Tạo hạn mức'),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ...preview.asMap().entries.map((entry) {
                              final l = entry.value;
                              final i = entry.key;
                              final name = l.category?.name ?? 'Danh mục';
                              final color = _statusColor(l.status);
                              return Padding(
                                padding: EdgeInsets.only(bottom: i < preview.length - 1 ? 14 : 0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CategoryIconBadge(name: name, icon: l.category?.icon, colorIndex: i, size: 32),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          '${l.usagePercent.toStringAsFixed(0)}%',
                                          style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 13, color: color),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(99),
                                      child: LinearProgressIndicator(
                                        value: (l.usagePercent / 100).clamp(0.0, 1.0),
                                        minHeight: 6,
                                        backgroundColor: color.withOpacity(0.12),
                                        valueColor: AlwaysStoppedAnimation(color),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_moneyFmt.format(l.currentSpent)} / ${_moneyFmt.format(l.limitAmount)} ₫',
                                      style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () => Navigator.pushNamed(context, AppRouter.budget).then((_) => _load()),
                              child: Text(_limits.isEmpty ? 'Tạo hạn mức' : 'Quản lý hạn mức'),
                            ),
                            if (hasAlerts) ...[
                              const SizedBox(height: 8),
                              OutlinedButton(
                                onPressed: () => Navigator.pushNamed(context, AppRouter.budget).then((_) => _load()),
                                child: const Text('Điều chỉnh'),
                              ),
                            ],
                          ],
                        ),
                      ),
                crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 220),
              ),
              if (!_expanded && _limits.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: FilledButton(
                    onPressed: () => Navigator.pushNamed(context, AppRouter.budget).then((_) => _load()),
                    child: const Text('Tạo hạn mức'),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
