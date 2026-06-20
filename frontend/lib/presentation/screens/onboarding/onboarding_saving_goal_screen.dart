import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:expense_manager/core/providers/app_providers.dart';
import 'package:expense_manager/core/router/app_router.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/presentation/screens/onboarding/onboarding_wallet_screen.dart';
import 'package:expense_manager/presentation/widgets/common/app_text_field.dart';
import 'package:expense_manager/presentation/widgets/common/card_container.dart';
import 'package:expense_manager/presentation/widgets/onboarding/onboarding_form_widgets.dart';

class OnboardingSavingGoalScreen extends ConsumerStatefulWidget {
  const OnboardingSavingGoalScreen({super.key});

  @override
  ConsumerState<OnboardingSavingGoalScreen> createState() => _OnboardingSavingGoalScreenState();
}

class _OnboardingSavingGoalScreenState extends ConsumerState<OnboardingSavingGoalScreen> {
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _initialController = TextEditingController();
  DateTime? _targetDate;
  int? _linkedGoalId;
  bool _saving = false;
  bool _formSynced = false;

  @override
  void initState() {
    super.initState();
    _loadExistingGoal();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _initialController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingGoal() async {
    try {
      final goals = await ref.read(savingGoalRepositoryProvider).getAll();
      if (!mounted || goals.isEmpty || _formSynced) return;
      goals.sort((a, b) => b.id.compareTo(a.id));
      final g = goals.first;
      setState(() {
        _linkedGoalId = g.id;
        _nameController.text = g.name;
        _targetController.text = formatOnboardingAmount(g.targetAmount.toStringAsFixed(0));
        if (g.targetDate != null && g.targetDate!.isNotEmpty) {
          _targetDate = DateTime.tryParse(g.targetDate!);
        }
        _formSynced = true;
      });
    } catch (_) {}
  }

  double? _parseAmount(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return double.tryParse(digits);
  }

  void _goBack() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingWalletScreen()),
    );
  }

  Future<void> _skip() async {
    setState(() => _saving = true);
    try {
      await ref.read(userRepositoryProvider).updateProfile(savingGoalSetupSkipped: true);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRouter.onboardingSpendingLimit);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      setState(() => _saving = false);
    }
  }

  Future<void> _complete() async {
    final target = _parseAmount(_targetController.text);
    if (_nameController.text.trim().isEmpty || target == null || target <= 0) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(savingGoalRepositoryProvider);
      final targetDateStr =
          _targetDate != null ? DateFormat('yyyy-MM-dd').format(_targetDate!) : null;

      if (_linkedGoalId != null) {
        await repo.update(
          id: _linkedGoalId!,
          name: _nameController.text.trim(),
          targetAmount: target,
          targetDate: targetDateStr,
        );
      } else {
        final created = await repo.create(
          name: _nameController.text.trim(),
          targetAmount: target,
          initialAmount: _parseAmount(_initialController.text),
          targetDate: targetDateStr,
        );
        _linkedGoalId = created.id;
      }

      final user = ref.read(currentUserProvider).valueOrNull;
      if (user?.savingGoalSetupCompleted != true) {
        await ref.read(userRepositoryProvider).updateProfile(savingGoalSetupCompleted: true);
      }
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRouter.onboardingSpendingLimit);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canContinue =
        _nameController.text.trim().isNotEmpty && (_parseAmount(_targetController.text) ?? 0) > 0;

    return WillPopScope(
      onWillPop: () async {
        _goBack();
        return false;
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
                          'Bước 3/4',
                          style: GoogleFonts.nunito(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Thiết lập mục tiêu tiết kiệm',
                          style: GoogleFonts.nunito(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tạo mục tiêu đầu tiên hoặc bỏ qua — bạn có thể thiết lập sau trong mục Mục tiêu tiết kiệm.',
                          style: GoogleFonts.nunito(color: AppColors.textSecondary, height: 1.45),
                        ),
                        if (_linkedGoalId != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                            ),
                            child: Text(
                              'Mục tiêu đã được tạo. Bấm Tiếp tục sẽ cập nhật — không tạo thêm bản sao.',
                              style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                            ),
                          ),
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
                                    child: const Icon(Icons.emoji_events_outlined, color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Mục tiêu mới',
                                          style: GoogleFonts.nunito(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          'Điền thông tin cơ bản để bắt đầu tiết kiệm',
                                          style: GoogleFonts.nunito(
                                            fontSize: 13,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              AppTextField(
                                label: 'Tên mục tiêu',
                                hint: 'VD: Mua laptop, Du lịch Đà Lạt',
                                controller: _nameController,
                                prefixIcon: const Icon(Icons.track_changes_rounded),
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: 16),
                              AppTextField(
                                label: 'Số tiền mục tiêu',
                                hint: 'VD: 15.000.000',
                                controller: _targetController,
                                keyboardType: TextInputType.number,
                                prefixIcon: const Icon(Icons.savings_outlined),
                                onChanged: (v) {
                                  final formatted = formatOnboardingAmount(v);
                                  if (formatted != v) {
                                    _targetController.value = TextEditingValue(
                                      text: formatted,
                                      selection: TextSelection.collapsed(offset: formatted.length),
                                    );
                                  }
                                  setState(() {});
                                },
                              ),
                              const SizedBox(height: 16),
                              AppTextField(
                                label: 'Số tiền đã có (tùy chọn)',
                                hint: 'VD: 2.000.000',
                                controller: _initialController,
                                keyboardType: TextInputType.number,
                                prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                                onChanged: (v) {
                                  final formatted = formatOnboardingAmount(v);
                                  if (formatted != v) {
                                    _initialController.value = TextEditingValue(
                                      text: formatted,
                                      selection: TextSelection.collapsed(offset: formatted.length),
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 16),
                              OnboardingDateField(
                                label: 'Ngày dự kiến hoàn thành',
                                value: _targetDate,
                                onChanged: (d) => setState(() => _targetDate = d),
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
                                        'Ngày dự kiến giúp theo dõi tiến độ. Bạn có thể bỏ trống và cập nhật sau.',
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
                      Row(
                        children: [
                          TextButton(
                            onPressed: _saving ? null : _skip,
                            child: Text(
                              'Thiết lập sau',
                              style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _saving || !canContinue ? null : _complete,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: AppColors.surface,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                _saving
                                    ? 'Đang lưu…'
                                    : _linkedGoalId != null
                                        ? 'Cập nhật & tiếp tục'
                                        : 'Tiếp tục',
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
