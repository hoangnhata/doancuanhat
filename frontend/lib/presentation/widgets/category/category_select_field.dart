import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/utils/category_icons.dart';
import 'package:expense_manager/domain/models/category.dart';

class CategoryIconBadge extends StatelessWidget {
  final String name;
  final String? icon;
  final int colorIndex;
  final double size;

  const CategoryIconBadge({
    super.key,
    required this.name,
    this.icon,
    this.colorIndex = 0,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(colorIndex);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(categoryIconData(name: name, icon: icon), color: color, size: size * 0.52),
    );
  }
}

class CategorySelectField extends StatelessWidget {
  final List<Category> categories;
  final Category? value;
  final ValueChanged<Category?> onChanged;
  final String label;
  final Set<int> disabledCategoryIds;
  final String disabledHint;

  const CategorySelectField({
    super.key,
    required this.categories,
    required this.value,
    required this.onChanged,
    this.label = 'Danh mục chi tiêu',
    this.disabledCategoryIds = const {},
    this.disabledHint = 'Đã có hạn mức',
  });

  Future<void> _openPicker(BuildContext context) async {
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có danh mục chi tiêu. Vui lòng thử lại sau vài giây.')),
      );
      return;
    }
    final picked = await showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.65),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(
                    label,
                    style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: categories.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                      child: Text(
                        'Chưa có danh mục chi tiêu.',
                        style: GoogleFonts.nunito(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, i) {
                  final c = categories[i];
                  final selected = value?.id == c.id;
                  final isUsed = disabledCategoryIds.contains(c.id);
                  return Material(
                    color: selected ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: isUsed ? null : () => Navigator.pop(ctx, c),
                      borderRadius: BorderRadius.circular(16),
                      child: Opacity(
                        opacity: isUsed ? 0.55 : 1,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          child: Row(
                            children: [
                              CategoryIconBadge(name: c.name, icon: c.icon, colorIndex: i),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  c.name,
                                  style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: selected ? AppColors.primary : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (isUsed) ...[
                                const Icon(Icons.check_circle_rounded, color: AppColors.income, size: 20),
                                const SizedBox(width: 4),
                                Text(
                                  disabledHint,
                                  style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textMuted),
                                ),
                              ] else if (selected)
                                const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final idx = value != null ? categories.indexWhere((c) => c.id == value!.id) : -1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => _openPicker(context),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.surface),
              ),
              child: Row(
                children: [
                  if (value != null)
                    CategoryIconBadge(name: value!.name, icon: value!.icon, colorIndex: idx >= 0 ? idx : 0)
                  else
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.category_outlined, color: AppColors.primary, size: 20),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      value?.name ?? 'Chọn danh mục',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: value != null ? AppColors.textPrimary : AppColors.textMuted,
                      ),
                    ),
                  ),
                  const Icon(Icons.expand_more_rounded, color: AppColors.primary),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
