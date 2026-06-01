import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/providers/app_providers.dart';

Future<void> showEditWalletSheet(BuildContext context, {required String walletName, required String currency, required double initialBalance}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _EditWalletSheet(
      walletName: walletName,
      currency: currency,
      initialBalance: initialBalance,
    ),
  );
}

class _EditWalletSheet extends ConsumerStatefulWidget {
  final String walletName;
  final String currency;
  final double initialBalance;

  const _EditWalletSheet({
    required this.walletName,
    required this.currency,
    required this.initialBalance,
  });

  @override
  ConsumerState<_EditWalletSheet> createState() => _EditWalletSheetState();
}

class _EditWalletSheetState extends ConsumerState<_EditWalletSheet> {
  late TextEditingController _nameController;
  late String _currency;
  late TextEditingController _balanceController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.walletName);
    _currency = widget.currency;
    _balanceController = TextEditingController(
      text: widget.initialBalance > 0 ? NumberFormat().format(widget.initialBalance) : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final balance = double.tryParse(_balanceController.text.replaceAll(',', '')) ?? 0;

    setState(() => _isLoading = true);
    try {
      await ref.read(userRepositoryProvider).updateProfile(
            walletName: name,
            currencyCode: _currency,
            initialBalance: balance,
          );
      ref.invalidate(currentUserProvider);
      if (mounted) Navigator.pop(context);
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
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
              'Sửa ví',
              style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Tên ví',
                filled: true,
                fillColor: Colors.white,
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
                      fillColor: Colors.white,
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
                    controller: _balanceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Số dư ban đầu',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Lưu', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
