import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/utils/date_labels.dart';
import 'package:expense_manager/core/utils/haptic_utils.dart';

Future<int?> showYearPickerSheet(
  BuildContext context, {
  required int initialYear,
  int minYear = 2020,
  int? maxYear,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _YearPickerSheet(
      initialYear: initialYear,
      minYear: minYear,
      maxYear: maxYear ?? DateTime.now().year + 1,
    ),
  );
}

class YearPickerField extends StatelessWidget {
  final int year;
  final ValueChanged<int> onChanged;
  final String label;
  final int minYear;
  final int? maxYear;

  const YearPickerField({
    super.key,
    required this.year,
    required this.onChanged,
    this.label = 'Chọn năm',
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
          final result = await showYearPickerSheet(
            context,
            initialYear: year,
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
            prefixIcon: const Icon(Icons.date_range_rounded, color: AppColors.primary),
            suffixIcon: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.date_range_rounded, color: AppColors.primary, size: 20),
            ),
          ),
          child: Text(
            'Năm $year',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _YearPickerSheet extends StatefulWidget {
  final int initialYear;
  final int minYear;
  final int maxYear;

  const _YearPickerSheet({
    required this.initialYear,
    required this.minYear,
    required this.maxYear,
  });

  @override
  State<_YearPickerSheet> createState() => _YearPickerSheetState();
}

class _YearPickerSheetState extends State<_YearPickerSheet> {
  late int _viewStart;
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear;
    _viewStart = (widget.initialYear - 4).clamp(widget.minYear, widget.maxYear - 8);
  }

  List<int> get _years {
    return List.generate(9, (i) => _viewStart + i).where((y) => y >= widget.minYear && y <= widget.maxYear).toList();
  }

  void _pickYear(int year) {
    HapticUtils.selection();
    Navigator.pop(context, year);
  }

  @override
  Widget build(BuildContext context) {
    final current = currentYear();

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
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
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
                    onPressed: _viewStart > widget.minYear
                        ? () => setState(() => _viewStart = (_viewStart - 9).clamp(widget.minYear, widget.maxYear))
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      'Chọn năm',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                  ),
                  IconButton(
                    onPressed: _viewStart + 8 < widget.maxYear
                        ? () => setState(() => _viewStart = (_viewStart + 9).clamp(widget.minYear, widget.maxYear - 8))
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
                  childAspectRatio: 1.8,
                ),
                itemCount: _years.length,
                itemBuilder: (_, i) {
                  final y = _years[i];
                  final selected = y == _selectedYear;
                  final isCurrent = y == current;
                  return Material(
                    color: selected
                        ? AppColors.primary
                        : isCurrent
                            ? AppColors.primary.withOpacity(0.1)
                            : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _pickYear(y),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : isCurrent
                                    ? AppColors.primary.withOpacity(0.45)
                                    : AppColors.textMuted.withOpacity(0.2),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$y',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w800,
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
                    onPressed: () => _pickYear(current),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Năm nay', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
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
