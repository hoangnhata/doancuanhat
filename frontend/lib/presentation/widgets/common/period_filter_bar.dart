import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/utils/haptic_utils.dart';
import 'package:expense_manager/presentation/widgets/common/card_container.dart';
import 'package:expense_manager/presentation/widgets/common/month_year_picker_sheet.dart';
import 'package:expense_manager/presentation/widgets/common/year_picker_sheet.dart';

/// Thanh lọc kỳ xem dữ liệu — khớp web PeriodFilterBar.
class PeriodFilterBar extends StatelessWidget {
  final String period;
  final ValueChanged<String> onPeriodChanged;
  final int year;
  final int month;
  final void Function(int year, int month) onMonthYearChanged;
  final ValueChanged<int> onYearChanged;
  final int minYear;
  final int? maxYear;

  const PeriodFilterBar({
    super.key,
    required this.period,
    required this.onPeriodChanged,
    required this.year,
    required this.month,
    required this.onMonthYearChanged,
    required this.onYearChanged,
    this.minYear = 2020,
    this.maxYear,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveMaxYear = maxYear ?? DateTime.now().year + 1;

    return CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'KỲ XEM DỮ LIỆU',
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.textMuted.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _PeriodSegment(
                    label: 'Theo tháng',
                    icon: Icons.calendar_month_rounded,
                    isSelected: period == 'month',
                    onTap: () {
                      HapticUtils.selection();
                      onPeriodChanged('month');
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _PeriodSegment(
                    label: 'Theo năm',
                    icon: Icons.date_range_rounded,
                    isSelected: period == 'year',
                    onTap: () {
                      HapticUtils.selection();
                      onPeriodChanged('year');
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (period == 'month')
            MonthYearPickerField(
              year: year,
              month: month,
              minYear: minYear,
              maxYear: effectiveMaxYear,
              onChanged: (v) => onMonthYearChanged(v.year, v.month),
            )
          else
            YearPickerField(
              year: year,
              minYear: minYear,
              maxYear: effectiveMaxYear,
              onChanged: onYearChanged,
            ),
        ],
      ),
    );
  }
}

class _PeriodSegment extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodSegment({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
