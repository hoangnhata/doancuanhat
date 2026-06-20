import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/domain/models/transaction.dart';

class TransactionSummaryBar extends StatelessWidget {
  final double totalIncome;
  final double totalExpense;
  final double balance;
  final int count;

  const TransactionSummaryBar({
    super.key,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.compact(locale: 'vi');
    final positive = balance >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            Colors.white,
            AppColors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Tóm tắt danh sách · $count giao dịch',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${fmt.format(balance)}₫',
            style: GoogleFonts.nunito(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: positive ? AppColors.income : AppColors.expense,
            ),
          ),
          Text(
            'Chênh lệch thu − chi (theo bộ lọc hiện tại)',
            style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniBox(
                  label: 'Thu',
                  value: totalIncome,
                  color: AppColors.income,
                  icon: Icons.south_west_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniBox(
                  label: 'Chi',
                  value: totalExpense,
                  color: AppColors.expense,
                  icon: Icons.north_east_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniBox extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final IconData icon;

  const _MiniBox({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.compact(locale: 'vi');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
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
          const SizedBox(height: 4),
          Text(
            '${fmt.format(value)}₫',
            style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}

class TransactionTypeChips extends StatelessWidget {
  final String? selectedType;
  final ValueChanged<String?> onChanged;

  const TransactionTypeChips({
    super.key,
    required this.selectedType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip(context, null, 'Tất cả'),
        _chip(context, 'EXPENSE', 'Chi tiêu'),
        _chip(context, 'INCOME', 'Thu nhập'),
      ],
    );
  }

  Widget _chip(BuildContext context, String? value, String label) {
    final selected = selectedType == value;
    return FilterChip(
      label: Text(label, style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 13)),
      selected: selected,
      onSelected: (_) => onChanged(value),
      selectedColor: AppColors.primary.withValues(alpha: 0.18),
      checkmarkColor: AppColors.primary,
      side: BorderSide(
        color: selected ? AppColors.primary : AppColors.textMuted.withValues(alpha: 0.25),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class TransactionDateHeader extends StatelessWidget {
  final String label;
  final int count;
  final double dayTotal;

  const TransactionDateHeader({
    super.key,
    required this.label,
    required this.count,
    required this.dayTotal,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.compact(locale: 'vi');
    final sign = dayTotal >= 0 ? '+' : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '$count giao dịch',
                  style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Text(
            '$sign${fmt.format(dayTotal)}₫',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

List<TransactionDateGroup> groupTransactionsByDate(List<Transaction> items) {
  final map = <String, List<Transaction>>{};
  for (final t in items) {
    final key = DateFormat('yyyy-MM-dd').format(t.transactionDate);
    map.putIfAbsent(key, () => []).add(t);
  }
  final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));
  return keys.map((key) {
    final date = DateTime.parse(key);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);

    String label;
    if (d == today) {
      label = 'Hôm nay';
    } else if (d == yesterday) {
      label = 'Hôm qua';
    } else {
      label = DateFormat('dd/MM/yyyy').format(date);
    }

    return TransactionDateGroup(dateKey: key, label: label, items: map[key]!);
  }).toList();
}

class TransactionDateGroup {
  final String dateKey;
  final String label;
  final List<Transaction> items;

  TransactionDateGroup({
    required this.dateKey,
    required this.label,
    required this.items,
  });
}

TransactionSummary computeTransactionSummary(List<Transaction> items) {
  var income = 0.0;
  var expense = 0.0;
  for (final t in items) {
    if (t.type == TransactionType.income) {
      income += t.amount;
    } else {
      expense += t.amount;
    }
  }
  return TransactionSummary(
    totalIncome: income,
    totalExpense: expense,
    balance: income - expense,
    count: items.length,
  );
}

class TransactionSummary {
  final double totalIncome;
  final double totalExpense;
  final double balance;
  final int count;

  TransactionSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    required this.count,
  });
}

double dayNetTotal(List<Transaction> items) {
  var total = 0.0;
  for (final t in items) {
    total += t.type == TransactionType.income ? t.amount : -t.amount;
  }
  return total;
}
