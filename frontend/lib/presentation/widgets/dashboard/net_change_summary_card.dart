import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:expense_manager/core/theme/app_theme.dart';

class NetChangeSummaryCard extends StatelessWidget {
  final String periodLabel;
  final double balance;
  final double totalIncome;
  final double totalExpense;

  const NetChangeSummaryCard({
    super.key,
    required this.periodLabel,
    required this.balance,
    required this.totalIncome,
    required this.totalExpense,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.compact(locale: 'vi');
    final positive = balance >= 0;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.12),
            Colors.white,
            AppColors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.cardShadow,
        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_flat_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 6),
              Text(
                'Thay đổi ròng · $periodLabel',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${fmt.format(balance)}₫',
            style: GoogleFonts.nunito(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: positive ? AppColors.primary : AppColors.accent,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  label: 'Chi phí',
                  amount: totalExpense,
                  icon: Icons.arrow_upward_rounded,
                  tint: AppColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBox(
                  label: 'Thu nhập',
                  amount: totalIncome,
                  icon: Icons.arrow_downward_rounded,
                  tint: AppColors.income,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color tint;

  const _StatBox({
    required this.label,
    required this.amount,
    required this.icon,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.compact(locale: 'vi');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tint.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: tint),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${fmt.format(amount)}₫',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: tint,
            ),
          ),
        ],
      ),
    );
  }
}
