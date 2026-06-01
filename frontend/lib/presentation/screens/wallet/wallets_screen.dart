import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/utils/haptic_utils.dart';
import 'package:expense_manager/core/utils/snackbar_utils.dart';
import 'package:expense_manager/core/utils/api_error.dart' show extractErrorMessage;
import 'package:expense_manager/domain/models/wallet.dart';
import 'package:expense_manager/core/providers/app_providers.dart';
import 'package:expense_manager/presentation/widgets/common/card_container.dart';

class WalletsScreen extends ConsumerStatefulWidget {
  const WalletsScreen({super.key});

  @override
  ConsumerState<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends ConsumerState<WalletsScreen> {
  List<Wallet> _wallets = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWallets();
  }

  Future<void> _loadWallets() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(syncServiceProvider).syncAllIfOnline();
      if (!mounted) return;
      _wallets = await ref.read(walletRepositoryProvider).getAll();
      setState(() => _error = null);
    } catch (e) {
      setState(() => _error = extractErrorMessage(e));
    }
    setState(() => _isLoading = false);
  }

  Future<void> _showWalletSheet([Wallet? wallet]) async {
    final nameController = TextEditingController(text: wallet?.name ?? '');
    final balanceController = TextEditingController(
      text: wallet != null && wallet.initialBalance > 0
          ? NumberFormat().format(wallet.initialBalance) : '',
    );
    String currency = wallet?.currencyCode ?? 'VND';
    bool isDefault = wallet?.isDefault ?? false;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _WalletFormSheet(
        wallet: wallet,
        nameController: nameController,
        balanceController: balanceController,
        currency: currency,
        isDefault: isDefault,
        onCurrencyChanged: (v) => currency = v,
        onDefaultChanged: (v) => isDefault = v,
      ),
    );
    if (result != null && mounted) {
      try {
        final repo = ref.read(walletRepositoryProvider);
        if (wallet == null) {
          await repo.create(
            name: result['name'] as String,
            currencyCode: result['currencyCode'] as String,
            initialBalance: (result['initialBalance'] as num).toDouble(),
            isDefault: result['isDefault'] as bool,
          );
          if (mounted) showSuccessSnackBar(context, 'Đã thêm ví!');
        } else {
          await repo.update(wallet.id,
            name: result['name'] as String,
            currencyCode: result['currencyCode'] as String,
            initialBalance: (result['initialBalance'] as num).toDouble(),
            isDefault: result['isDefault'],
          );
          if (mounted) showSuccessSnackBar(context, 'Đã cập nhật ví!');
        }
        _loadWallets();
      } catch (e) {
        if (mounted) showErrorSnackBar(context, extractErrorMessage(e));
      }
    }
  }

  Future<void> _deleteWallet(Wallet wallet) async {
    if (wallet.isDefault) {
      showErrorSnackBar(context, 'Không thể xóa ví mặc định');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa ví?'),
        content: Text('Bạn có chắc muốn xóa "${wallet.name}"? Các giao dịch sẽ chuyển về ví mặc định.'),
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
    if (confirm == true) {
      try {
        await ref.read(walletRepositoryProvider).delete(wallet.id);
        if (mounted) showSuccessSnackBar(context, 'Đã xóa ví');
        _loadWallets();
      } catch (e) {
        if (mounted) showErrorSnackBar(context, extractErrorMessage(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () {
                        HapticUtils.selection();
                        Navigator.pop(context);
                      },
                    ),
                    Expanded(
                      child: Text(
                        'Quản lý ví',
                        style: GoogleFonts.nunito(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded),
                      onPressed: () {
                        HapticUtils.selection();
                        _showWalletSheet();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : _error != null
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: CardContainer(
                              child: Column(
                                children: [
                                  Text(_error!, style: GoogleFonts.nunito(color: AppColors.accent)),
                                  const SizedBox(height: 16),
                                  TextButton(
                                    onPressed: _loadWallets,
                                    child: const Text('Thử lại'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadWallets,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: _wallets.length,
                              itemBuilder: (context, index) {
                                final wallet = _wallets[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: CardContainer(
                                    onTap: () {
                                      HapticUtils.selection();
                                      _showWalletSheet(wallet);
                                    },
                                    child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Icon(
                                          Icons.account_balance_wallet_rounded,
                                          color: AppColors.primary,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  wallet.name,
                                                  style: GoogleFonts.nunito(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                ),
                                                if (wallet.isDefault) ...[
                                                  const SizedBox(width: 6),
                                                  Icon(Icons.star_rounded, size: 18, color: AppColors.primary),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${wallet.currencyCode} · ${NumberFormat('#,###', 'vi').format(wallet.initialBalance)}',
                                              style: GoogleFonts.nunito(
                                                fontSize: 13,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!wallet.isDefault)
                                        IconButton(
                                          icon: Icon(Icons.delete_outline_rounded, color: AppColors.textMuted),
                                          onPressed: () => _deleteWallet(wallet),
                                        )
                                      else
                                        const SizedBox(width: 48),
                                    ],
                                  ),
                                ),
                              );
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletFormSheet extends ConsumerStatefulWidget {
  final Wallet? wallet;
  final TextEditingController nameController;
  final TextEditingController balanceController;
  final String currency;
  final bool isDefault;
  final ValueChanged<String> onCurrencyChanged;
  final ValueChanged<bool> onDefaultChanged;

  const _WalletFormSheet({
    this.wallet,
    required this.nameController,
    required this.balanceController,
    required this.currency,
    required this.isDefault,
    required this.onCurrencyChanged,
    required this.onDefaultChanged,
  });

  @override
  ConsumerState<_WalletFormSheet> createState() => _WalletFormSheetState();
}

class _WalletFormSheetState extends ConsumerState<_WalletFormSheet> {
  late String _currency;
  late bool _isDefault;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currency = widget.currency;
    _isDefault = widget.isDefault;
  }

  Future<void> _save() async {
    final name = widget.nameController.text.trim();
    if (name.isEmpty) return;
    final balance = double.tryParse(widget.balanceController.text.replaceAll(',', '')) ?? 0;

    setState(() => _isSaving = true);
    widget.onCurrencyChanged(_currency);
    widget.onDefaultChanged(_isDefault);
    if (mounted) {
      Navigator.pop(context, {
        'name': name,
        'currencyCode': _currency,
        'initialBalance': balance,
        'isDefault': _isDefault,
      });
    }
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.textMuted, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.wallet == null ? 'Thêm ví' : 'Sửa ví',
            style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: widget.nameController,
            decoration: InputDecoration(
              labelText: 'Tên ví',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _currency,
                  decoration: InputDecoration(
                    labelText: 'Tiền tệ',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'VND', child: Text('VND (₫)')),
                    DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                  ],
                  onChanged: (v) => setState(() => _currency = v ?? 'VND'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: widget.balanceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Số dư ban đầu',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Đặt làm ví mặc định',
                  style: GoogleFonts.nunito(fontSize: 15, color: AppColors.textPrimary),
                ),
              ),
              Switch(
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
                activeTrackColor: AppColors.primary.withOpacity(0.5),
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSaving
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Lưu', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
