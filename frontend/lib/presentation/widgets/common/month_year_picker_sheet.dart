import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/utils/date_labels.dart';
import 'package:expense_manager/core/utils/haptic_utils.dart';

/// Mở bottom sheet chọn tháng/năm — giao diện khớp web.
Future<({int year, int month})?> showMonthYearPickerSheet(
  BuildContext context, {
  required int initialYear,
  required int initialMonth,
  int minYear = 2020,
  int? maxYear,
}) async {
  return showModalBottomSheet<({int year, int month})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _MonthYearPickerSheet(
      initialYear: initialYear,
      initialMonth: initialMonth,
      minYear: minYear,
      maxYear: maxYear ?? DateTime.now().year + 1,
    ),
  );
}

class MonthYearPickerField extends StatelessWidget {
  final int year;
  final int month;
  final ValueChanged<({int year, int month})> onChanged;
  final String label;
  final int minYear;
  final int? maxYear;

  const MonthYearPickerField({
    super.key,
    required this.year,
    required this.month,
    required this.onChanged,
    this.label = 'Chọn tháng',
    this.minYear = 2020,
    this.maxYear,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          HapticUtils.selection();
          final result = await showMonthYearPickerSheet(
            context,
            initialYear: year,
            initialMonth: month,
            minYear: minYear,
            maxYear: maxYear,
          );
          if (result != null) onChanged(result);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            labelStyle: GoogleFonts.nunito(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.textMuted.withOpacity(0.25)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.textMuted.withOpacity(0.25)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            prefixIcon: const Icon(Icons.calendar_month_rounded, color: AppColors.primary),
            suffixIcon: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 20),
            ),
          ),
          child: Text(
            formatMonthYearLabel(year, month),
            style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _MonthYearPickerSheet extends StatefulWidget {
  final int initialYear;
  final int initialMonth;
  final int minYear;
  final int maxYear;

  const _MonthYearPickerSheet({
    required this.initialYear,
    required this.initialMonth,
    required this.minYear,
    required this.maxYear,
  });

  @override
  State<_MonthYearPickerSheet> createState() => _MonthYearPickerSheetState();
}

class _MonthYearPickerSheetState extends State<_MonthYearPickerSheet> {
  late int _draftYear;
  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    _draftYear = widget.initialYear;
    _selectedYear = widget.initialYear;
    _selectedMonth = widget.initialMonth;
  }

  void _pickMonth(int month) {
    HapticUtils.selection();
    Navigator.pop(context, (year: _draftYear, month: month));
  }

  void _goToday() {
    HapticUtils.selection();
    Navigator.pop(context, (year: currentYear(), month: currentMonth()));
  }

  @override
  Widget build(BuildContext context) {
    final todayYear = currentYear();
    final todayMonth = currentMonth();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.cardShadow,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _draftYear > widget.minYear
                        ? () => setState(() => _draftYear--)
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Năm',
                          style: GoogleFonts.nunito(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                        Text(
                          '$_draftYear',
                          style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 26),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _draftYear < widget.maxYear
                        ? () => setState(() => _draftYear++)
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.65,
                ),
                itemCount: 12,
                itemBuilder: (_, i) {
                  final month = i + 1;
                  final selected = _draftYear == _selectedYear && month == _selectedMonth;
                  final isToday = _draftYear == todayYear && month == todayMonth;
                  return Material(
                    color: selected
                        ? AppColors.primary
                        : isToday
                            ? AppColors.primary.withOpacity(0.1)
                            : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _pickMonth(month),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : isToday
                                    ? AppColors.primary.withOpacity(0.45)
                                    : AppColors.textMuted.withOpacity(0.2),
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          formatMonthGridLabel(month),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Đóng', style: GoogleFonts.nunito(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  ),
                  FilledButton(
                    onPressed: _goToday,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Tháng này', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
