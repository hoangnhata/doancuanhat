import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:expense_manager/core/providers/app_providers.dart';
import 'package:expense_manager/core/router/app_router.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/domain/models/category.dart';
import 'package:expense_manager/domain/models/spending_limit.dart';
import 'package:expense_manager/presentation/screens/onboarding/onboarding_saving_goal_screen.dart';
import 'package:expense_manager/presentation/widgets/category/category_select_field.dart';
import 'package:expense_manager/presentation/widgets/common/app_text_field.dart';
import 'package:expense_manager/presentation/widgets/common/card_container.dart';
import 'package:expense_manager/presentation/widgets/onboarding/onboarding_form_widgets.dart';

class OnboardingSpendingLimitScreen extends ConsumerStatefulWidget {
  const OnboardingSpendingLimitScreen({super.key});

  @override
  ConsumerState<OnboardingSpendingLimitScreen> createState() => _OnboardingSpendingLimitScreenState();
}

class _OnboardingSpendingLimitScreenState extends ConsumerState<OnboardingSpendingLimitScreen> {
  final _amountController = TextEditingController();
  Category? _selectedCategory;
  int _warning = 80;
  int? _editingLimitId;
  bool _saving = false;
  bool _loadingCategories = true;
  List<Category> _categories = [];
  List<SpendingLimit> _savedLimits = [];

  static final _moneyFmt = NumberFormat('#,###', 'vi');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _goBack() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingSavingGoalScreen()),
    );
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _loadingCategories = true);
    try {
      await ref.read(syncServiceProvider).syncAllIfOnline();
      final cats = await ref.read(categoryRepositoryProvider).getAll(type: 'EXPENSE');
      final limits = await ref.read(spendingLimitRepositoryProvider).getAll();
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _savedLimits = limits;
        _loadingCategories = false;
      });
      _pickFirstAvailableCategory();
    } catch (_) {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  Set<int> get _usedCategoryIds => _savedLimits
      .where((l) => l.id != _editingLimitId)
      .map((l) => l.category?.id ?? 0)
      .where((id) => id > 0)
      .toSet();

  void _pickFirstAvailableCategory() {
    if (_editingLimitId != null) return;
    final available = _categories.where((c) => !_usedCategoryIds.contains(c.id)).toList();
    setState(() => _selectedCategory = available.isNotEmpty ? available.first : null);
  }

  void _resetForm() {
    setState(() => _editingLimitId = null);
    _amountController.clear();
    _warning = 80;
    _pickFirstAvailableCategory();
  }

  double? _parseAmount(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return double.tryParse(digits);
  }

  bool get _canSaveLimit {
    final amount = _parseAmount(_amountController.text);
    return _selectedCategory != null && amount != null && amount > 0;
  }

  Future<void> _saveLimit() async {
    final amount = _parseAmount(_amountController.text);
    if (_selectedCategory == null || amount == null || amount <= 0) return;
    if (_editingLimitId == null && _usedCategoryIds.contains(_selectedCategory!.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Danh mục này đã có hạn mức')),
      );
      return;
    }

    final repo = ref.read(spendingLimitRepositoryProvider);
    if (_editingLimitId != null) {
      await repo.update(
        id: _editingLimitId!,
        amount: amount,
        categoryId: _selectedCategory!.id,
        warningThresholdPercent: _warning,
      );
    } else {
      await repo.create(
        amount: amount,
        categoryId: _selectedCategory!.id,
        warningThresholdPercent: _warning,
      );
    }
    await _loadData();
    _resetForm();
  }

  void _startEdit(SpendingLimit limit) {
    final cat = limit.category;
    if (cat == null) return;
    setState(() {
      _editingLimitId = limit.id;
      _selectedCategory = _categories.firstWhere((c) => c.id == cat.id, orElse: () => cat);
      _amountController.text = formatOnboardingAmount(limit.limitAmount.toStringAsFixed(0));
      _warning = limit.warningThresholdPercent?.round() ?? 80;
    });
  }

  Future<void> _deleteLimit(SpendingLimit limit) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa hạn mức?'),
        content: Text('Xóa hạn mức "${limit.category?.name ?? ''}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(spendingLimitRepositoryProvider).delete(limit.id);
    if (_editingLimitId == limit.id) _resetForm();
    await _loadData();
  }

  Future<void> _skip() async {
    setState(() => _saving = true);
    try {
      await ref.read(userRepositoryProvider).updateProfile(spendingLimitSetupSkipped: true, onboardingCompleted: true);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, AppRouter.main, (r) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      setState(() => _saving = false);
    }
  }

  Future<void> _complete() async {
    setState(() => _saving = true);
    try {
      if (_canSaveLimit) await _saveLimit();
      await ref.read(userRepositoryProvider).updateProfile(spendingLimitSetupCompleted: true, onboardingCompleted: true);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, AppRouter.main, (r) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      setState(() => _saving = false);
    }
  }

  Future<void> _saveAndContinue() async {
    if (!_canSaveLimit) return;
    setState(() => _saving = true);
    try {
      await _saveLimit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_editingLimitId != null ? 'Đã cập nhật hạn mức' : 'Đã lưu hạn mức')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.gradientStart, AppColors.background],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bước 4/4',
                          style: GoogleFonts.nunito(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Thiết lập hạn mức chi tiêu',
                          style: GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Đặt hạn mức theo danh mục để kiểm soát chi tiêu. Bạn có thể bỏ qua và thiết lập sau.',
                          style: GoogleFonts.nunito(color: AppColors.textSecondary, height: 1.45),
                        ),
                        if (_savedLimits.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                            ),
                            child: Text(
                              'Đã thêm ${_savedLimits.length} hạn mức',
                              style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._savedLimits.asMap().entries.map((entry) {
                            final l = entry.value;
                            final i = entry.key;
                            final name = l.category?.name ?? 'Danh mục';
                            final isEditing = _editingLimitId == l.id;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isEditing ? AppColors.primary : AppColors.surface,
                                  width: isEditing ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CategoryIconBadge(name: name, icon: l.category?.icon, colorIndex: i, size: 36),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                                        Text(
                                          '${_moneyFmt.format(l.limitAmount)} ₫ · Cảnh báo ${l.warningThresholdPercent?.round() ?? 80}%',
                                          style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _saving ? null : () => _startEdit(l),
                                    icon: const Icon(Icons.edit_outlined, size: 20),
                                  ),
                                  IconButton(
                                    onPressed: _saving ? null : () => _deleteLimit(l),
                                    icon: Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.accent),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                        const SizedBox(height: 24),
                        CardContainer(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.speed_rounded, color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _editingLimitId != null ? 'Sửa hạn mức' : 'Hạn mức theo tháng',
                                          style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16),
                                        ),
                                        Text(
                                          _editingLimitId != null
                                              ? 'Chỉnh số tiền hoặc ngưỡng cảnh báo'
                                              : 'Giới hạn chi tiêu theo từng danh mục',
                                          style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              if (_loadingCategories)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                )
                              else
                                CategorySelectField(
                                  categories: _categories,
                                  value: _selectedCategory,
                                  onChanged: (v) => setState(() => _selectedCategory = v),
                                  disabledCategoryIds: _usedCategoryIds,
                                ),
                              const SizedBox(height: 16),
                              AppTextField(
                                label: 'Số tiền hạn mức',
                                hint: 'VD: 2.000.000',
                                controller: _amountController,
                                keyboardType: TextInputType.number,
                                prefixIcon: const Icon(Icons.payments_outlined),
                                onChanged: (v) {
                                  final formatted = formatOnboardingAmount(v);
                                  if (formatted != v) {
                                    _amountController.value = TextEditingValue(
                                      text: formatted,
                                      selection: TextSelection.collapsed(offset: formatted.length),
                                    );
                                  }
                                  setState(() {});
                                },
                              ),
                              const SizedBox(height: 16),
                              const OnboardingPeriodField(),
                              const SizedBox(height: 16),
                              OnboardingWarningSlider(
                                value: _warning,
                                onChanged: (v) => setState(() => _warning = v),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary.withOpacity(0.9)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Hệ thống sẽ cảnh báo khi chi tiêu gần chạm hoặc vượt hạn mức. Bạn có thể thêm nhiều hạn mức cho các danh mục khác nhau.',
                                        style: GoogleFonts.nunito(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                          height: 1.45,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OnboardingBackStepButton(onPressed: _saving ? null : _goBack),
                      if (_editingLimitId != null) ...[
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: _saving ? null : _resetForm,
                          child: Text('Hủy sửa', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                        ),
                      ],
                      if (_canSaveLimit) ...[
                        const SizedBox(height: 4),
                        OutlinedButton(
                          onPressed: _saving ? null : _saveAndContinue,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                            side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                          ),
                          child: Text(
                            _editingLimitId != null ? 'Cập nhật hạn mức' : 'Lưu hạn mức',
                            style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          TextButton(
                            onPressed: _saving ? null : _skip,
                            child: Text('Thiết lập sau', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _saving ? null : _complete,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                                elevation: 0,
                              ),
                              child: Text(
                                _saving ? 'Đang lưu…' : 'Hoàn tất',
                                style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
