import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:expense_manager/core/theme/app_theme.dart';

class AmountInputSection extends StatelessWidget {
  final TextEditingController controller;
  final bool isExpense;
  final bool showQuickAmounts;
  final ValueChanged<double> onQuickAdd;
  final VoidCallback? onChanged;

  const AmountInputSection({
    super.key,
    required this.controller,
    required this.isExpense,
    required this.showQuickAmounts,
    required this.onQuickAdd,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isExpense ? AppColors.expense : AppColors.income;
    final raw = double.tryParse(controller.text.replaceAll(',', '')) ?? 0;
    final fmtFull = NumberFormat('#,##0', 'vi');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          onChanged: (_) => onChanged?.call(),
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: accent,
            letterSpacing: -0.5,
          ),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: GoogleFonts.nunito(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted.withValues(alpha: 0.5),
            ),
            prefixText: '₫ ',
            prefixStyle: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w800, color: accent),
            filled: true,
            fillColor: accent.withValues(alpha: 0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: accent.withValues(alpha: 0.25)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: accent.withValues(alpha: 0.25)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: accent, width: 2),
            ),
          ),
        ),
        if (raw > 0) ...[
          const SizedBox(height: 6),
          Text(
            '${fmtFull.format(raw)} ₫',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (showQuickAmounts) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _QuickChip(label: '+10k', onTap: () => onQuickAdd(10000)),
              _QuickChip(label: '+50k', onTap: () => onQuickAdd(50000)),
              _QuickChip(label: '+100k', onTap: () => onQuickAdd(100000)),
              _QuickChip(label: '+500k', onTap: () => onQuickAdd(500000)),
            ],
          ),
        ],
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
          ),
          child: Text(
            label,
            style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}
