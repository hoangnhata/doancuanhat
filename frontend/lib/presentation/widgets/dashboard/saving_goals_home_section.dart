import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:expense_manager/core/providers/app_providers.dart';
import 'package:expense_manager/core/router/app_router.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/domain/models/saving_goal.dart';
import 'package:expense_manager/presentation/widgets/common/card_container.dart';
import 'package:expense_manager/presentation/widgets/dashboard/section_label.dart';

class SavingGoalsHomeSection extends ConsumerStatefulWidget {
  const SavingGoalsHomeSection({super.key});

  @override
  ConsumerState<SavingGoalsHomeSection> createState() => _SavingGoalsHomeSectionState();
}

class _SavingGoalsHomeSectionState extends ConsumerState<SavingGoalsHomeSection> {
  List<SavingGoal> _goals = [];
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
      final list = await ref.read(savingGoalRepositoryProvider).getAll();
      if (!mounted) return;
      setState(() {
        _goals = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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

    final preview = _goals.take(3).toList();
    final totalSaved = _goals.fold<double>(0, (s, g) => s + g.currentAmount);
    final completedCount = _goals.where((g) => g.isCompleted).length;
    final showExpandToggle = preview.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: SectionLabel('Mục tiêu tiết kiệm')),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, AppRouter.savingGoals).then((_) => _load()),
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
                          color: const Color(0xFF2E7D32).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.savings_rounded, color: Color(0xFF2E7D32)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _goals.isEmpty
                                  ? 'Chưa có mục tiêu'
                                  : '${_goals.length} mục tiêu · ${_moneyFmt.format(totalSaved)} ₫ đã tiết kiệm',
                              style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                            Text(
                              _goals.isEmpty
                                  ? 'Tạo ví tiết kiệm nội bộ cho kế hoạch lớn'
                                  : _expanded
                                      ? completedCount > 0
                                          ? '$completedCount mục tiêu đã hoàn thành'
                                          : 'Theo dõi tiến độ nạp/rút từng mục tiêu'
                                      : 'Nhấn để xem chi tiết mục tiêu',
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
                              color: const Color(0xFF2E7D32).withOpacity(0.08),
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
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: preview.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: FilledButton(
                          onPressed: () => Navigator.pushNamed(context, AppRouter.savingGoals).then((_) => _load()),
                          child: const Text('Tạo mục tiêu'),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ...preview.asMap().entries.map((entry) {
                              final g = entry.value;
                              final i = entry.key;
                              final color = g.isCompleted ? const Color(0xFF2E7D32) : AppColors.primary;
                              return Padding(
                                padding: EdgeInsets.only(bottom: i < preview.length - 1 ? 14 : 0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            g.isCompleted ? Icons.trending_up_rounded : Icons.savings_outlined,
                                            size: 18,
                                            color: color,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            g.name,
                                            style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          '${g.progressPercent.toStringAsFixed(0)}%',
                                          style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 13, color: color),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(99),
                                      child: LinearProgressIndicator(
                                        value: (g.progressPercent / 100).clamp(0.0, 1.0),
                                        minHeight: 6,
                                        backgroundColor: color.withOpacity(0.12),
                                        valueColor: AlwaysStoppedAnimation(color),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_moneyFmt.format(g.currentAmount)} / ${_moneyFmt.format(g.targetAmount)} ₫',
                                      style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () => Navigator.pushNamed(context, AppRouter.savingGoals).then((_) => _load()),
                              child: Text(_goals.isEmpty ? 'Tạo mục tiêu' : 'Quản lý tiết kiệm'),
                            ),
                          ],
                        ),
                      ),
                crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 220),
              ),
              if (!_expanded && _goals.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: FilledButton(
                    onPressed: () => Navigator.pushNamed(context, AppRouter.savingGoals).then((_) => _load()),
                    child: const Text('Tạo mục tiêu'),
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
