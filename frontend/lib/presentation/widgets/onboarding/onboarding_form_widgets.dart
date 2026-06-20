import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:expense_manager/core/theme/app_theme.dart';

/// Nút quay lại bước onboarding trước (đổi thiết lập đã nhập).
class OnboardingBackStepButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const OnboardingBackStepButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.arrow_back_rounded, size: 20),
        label: Text(
          'Quay về bước trước',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
        ),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        ),
      ),
    );
  }
}

/// Ô chọn ngày — mở lịch hệ thống thay vì gõ tay.
class OnboardingDateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const OnboardingDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
  });

  static final _displayFmt = DateFormat('EEEE, dd/MM/yyyy', 'vi');

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? now.add(const Duration(days: 90)),
      firstDate: firstDate ?? DateTime(now.year, now.month, now.day),
      lastDate: lastDate ?? now.add(const Duration(days: 3650)),
      helpText: 'Chọn ngày dự kiến',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (picked != null) onChanged(picked);
  }

  String _displayValue() {
    if (value == null) return 'Nhấn để chọn ngày trên lịch';
    final raw = _displayFmt.format(value!);
    return raw[0].toUpperCase() + raw.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => _pick(context),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.surface),
            boxShadow: AppColors.softShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.event_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _displayValue(),
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: hasValue ? AppColors.textPrimary : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _pick(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String formatOnboardingAmount(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return '';
  return NumberFormat('#,###', 'vi').format(int.parse(digits));
}

/// Thanh trượt ngưỡng cảnh báo hạn mức (50–100%).
class OnboardingWarningSlider extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const OnboardingWarningSlider({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surface),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active_outlined, size: 20, color: AppColors.primary.withOpacity(0.9)),
              const SizedBox(width: 8),
              Text(
                'Cảnh báo khi đạt $value%',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.primary.withOpacity(0.15),
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withOpacity(0.12),
              valueIndicatorColor: AppColors.primary,
            ),
            child: Slider(
              value: value.toDouble(),
              min: 50,
              max: 100,
              divisions: 10,
              label: '$value%',
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('50%', style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textMuted)),
                Text('80%', style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textMuted)),
                Text('100%', style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ô hiển thị chu kỳ cố định (Theo tháng).
class OnboardingPeriodField extends StatelessWidget {
  const OnboardingPeriodField({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surface),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_month_outlined, color: AppColors.primary.withOpacity(0.7), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chu kỳ',
                  style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Theo tháng',
                  style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'MONTHLY',
              style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
