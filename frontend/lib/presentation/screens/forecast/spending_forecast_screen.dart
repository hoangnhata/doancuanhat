import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:expense_manager/core/providers/app_providers.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/domain/models/forecast_eligibility.dart';
import 'package:expense_manager/domain/models/spending_forecast.dart';
import 'package:expense_manager/domain/models/wallet.dart';
import 'package:expense_manager/presentation/widgets/common/card_container.dart';
import 'package:expense_manager/presentation/widgets/dashboard/spending_forecast_card.dart';

/// Màn hình đầy đủ cho dự báo chi tiêu AI (không nhúng vào trang chủ).
class SpendingForecastScreen extends ConsumerStatefulWidget {
  const SpendingForecastScreen({super.key});

  @override
  ConsumerState<SpendingForecastScreen> createState() => _SpendingForecastScreenState();
}

class _SpendingForecastScreenState extends ConsumerState<SpendingForecastScreen> {
  SpendingForecast? _forecast;
  String? _forecastErr;
  bool _forecastLoading = false;

  ForecastEligibility? _eligibility;
  bool _eligibilityLoading = true;
  String? _eligibilityErr;

  List<Wallet> _wallets = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    await _loadWalletsAndLabel();
    await _loadEligibility();
  }

  Future<void> _loadWalletsAndLabel() async {
    try {
      final list = await ref.read(walletRepositoryProvider).getAll();
      if (mounted) setState(() => _wallets = list);
    } catch (_) {}
  }

  Future<void> _loadEligibility() async {
    final walletId = ref.read(selectedWalletIdProvider);
    if (walletId == null) {
      if (mounted) {
        setState(() {
          _eligibilityLoading = false;
          _eligibility = null;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _eligibilityLoading = true;
        _eligibilityErr = null;
      });
    }
    try {
      final el = await ref.read(statisticsRepositoryProvider).getForecastEligibility(walletId: walletId);
      if (!mounted) return;
      setState(() {
        _eligibility = el;
        _eligibilityLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      var msg = e.toString();
      if (msg.startsWith('Bad state: ')) msg = msg.substring('Bad state: '.length);
      setState(() {
        _eligibilityErr = msg;
        _eligibilityLoading = false;
      });
    }
  }

  Future<void> _onRun() async {
    final walletId = ref.read(selectedWalletIdProvider);
    if (walletId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ví trên Trang chủ trước.')),
      );
      return;
    }

    var el = _eligibility;
    if (el == null || _eligibilityLoading) {
      await _loadEligibility();
      el = _eligibility;
    }

    if (!mounted) return;

    if (el != null && !el.eligible && el.messageVi != null && el.messageVi!.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(el.messageVi!)));
      return;
    }

    setState(() {
      _forecastLoading = true;
      _forecastErr = null;
    });
    try {
      final f = await ref.read(statisticsRepositoryProvider).getSpendingForecast(walletId: walletId);
      if (!mounted) return;
      setState(() {
        _forecast = f;
        _forecastLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      var msg = e.toString();
      if (msg.startsWith('Bad state: ')) msg = msg.substring('Bad state: '.length);
      setState(() {
        _forecastErr = msg;
        _forecastLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletId = ref.watch(selectedWalletIdProvider);
    final walletName = walletId != null ? _wallets.where((w) => w.id == walletId).firstOrNull?.name : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Dự báo chi tiêu',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadWalletsAndLabel();
          await _loadEligibility();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ước lượng chi 7 ngày tới theo ví đang chọn. Cần đủ số ngày có chi trong cửa sổ gần nhất để AI hoạt động ổn định.',
                style: GoogleFonts.nunito(fontSize: 13, height: 1.45, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              if (walletId == null)
                CardContainer(
                  child: Text(
                    'Chọn ví trên Trang chủ để xem dự báo theo ví đó.',
                    style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ),
              if (_eligibilityErr != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CardContainer(
                    child: Text(
                      _eligibilityErr!,
                      style: GoogleFonts.nunito(fontSize: 14, color: AppColors.accent),
                    ),
                  ),
                ),
              if (!_eligibilityLoading &&
                  _eligibility != null &&
                  !_eligibility!.eligible &&
                  _eligibility!.messageVi != null &&
                  _eligibility!.messageVi!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CardContainer(
                    child: Text(
                      _eligibility!.messageVi!,
                      style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textPrimary),
                    ),
                  ),
                ),
              SpendingForecastCard(
                loading: _forecastLoading || (walletId != null && _eligibilityLoading),
                error: _forecastErr,
                forecast: _forecast,
                onRun: _onRun,
                walletName: walletName,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
