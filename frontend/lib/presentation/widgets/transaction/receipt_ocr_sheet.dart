import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:expense_manager/core/providers/app_providers.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/utils/api_error.dart' show extractErrorMessage;
import 'package:expense_manager/core/utils/haptic_utils.dart';
import 'package:expense_manager/domain/models/ocr_receipt.dart';

/// Hiển thị bottom sheet:
///   1. Chọn nguồn ảnh (camera/gallery)
///   2. Hiện preview ảnh + spinner gọi backend OCR
///   3. Hiển thị kết quả nhận diện, cho user xác nhận hoặc hủy
///
/// Trả về [OcrReceiptResult] nếu user xác nhận, ngược lại null.
Future<OcrReceiptResult?> showReceiptOcrSheet(BuildContext context, WidgetRef ref) async {
  return showModalBottomSheet<OcrReceiptResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _ReceiptOcrSheet(parentRef: ref),
  );
}

class _ReceiptOcrSheet extends ConsumerStatefulWidget {
  const _ReceiptOcrSheet({required this.parentRef});
  final WidgetRef parentRef;

  @override
  ConsumerState<_ReceiptOcrSheet> createState() => _ReceiptOcrSheetState();
}

class _ReceiptOcrSheetState extends ConsumerState<_ReceiptOcrSheet> {
  Uint8List? _imageBytes;
  String? _imageName;
  bool _isLoading = false;
  String? _error;
  OcrReceiptResult? _result;

  Future<void> _pick(ImageSource source) async {
    HapticUtils.selection();
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 2000,
        imageQuality: 88,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageName = picked.name;
        _error = null;
        _result = null;
      });
      await _runOcr();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Không lấy được ảnh: ${extractErrorMessage(e)}');
    }
  }

  Future<void> _runOcr() async {
    if (_imageBytes == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final r = await repo.ocrReceipt(
        bytes: _imageBytes!,
        filename: _imageName ?? 'receipt.jpg',
      );
      if (!mounted) return;
      setState(() {
        _result = r;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Không phân tích được hóa đơn. ${extractErrorMessage(e)}';
        _isLoading = false;
      });
    }
  }

  String _money(double? v) {
    if (v == null) return '—';
    return '₫ ${NumberFormat('#,###', 'vi_VN').format(v.round())}';
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + viewInsets),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.document_scanner_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Quét hóa đơn',
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_imageBytes == null) ...[
              Text(
                'Chụp ảnh hoặc chọn từ thư viện để AI tự đọc số tiền, ngày và đề xuất danh mục.',
                style: GoogleFonts.nunito(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _SourceButton(
                      icon: Icons.photo_camera_rounded,
                      label: 'Chụp ảnh',
                      onTap: () => _pick(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SourceButton(
                      icon: Icons.photo_library_rounded,
                      label: 'Thư viện',
                      onTap: () => _pick(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
            ] else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accent.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: GoogleFonts.nunito(color: AppColors.accent, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_result != null) ...[
                if (_result!.needsReview)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'AI chưa chắc chắn — vui lòng kiểm tra lại trước khi lưu.',
                            style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                _Row(label: 'Số tiền', value: _money(_result!.amount), strong: true),
                _Row(
                  label: 'Ngày',
                  value: _result!.transactionDate != null
                      ? DateFormat('dd/MM/yyyy').format(_result!.transactionDate!)
                      : '—',
                ),
                _Row(label: 'Cửa hàng', value: _result!.merchant ?? '—'),
                _Row(
                  label: 'Danh mục',
                  value: (_result!.categoryName ?? '—') +
                      (_result!.categoryId == null ? ' (chọn lại sau khi áp dụng)' : ''),
                ),
                if (_result!.confidence != null)
                  _Row(
                    label: 'Độ tin cậy',
                    value: '${(_result!.confidence! * 100).toStringAsFixed(0)}%',
                  ),
                _Row(label: 'Engine', value: _result!.ocrEngine ?? '—'),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () {
                              setState(() {
                                _imageBytes = null;
                                _result = null;
                                _error = null;
                              });
                            },
                      icon: const Icon(Icons.replay_rounded),
                      label: Text('Chọn ảnh khác', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _result == null || _result!.amount == null
                          ? null
                          : () {
                              HapticUtils.medium();
                              Navigator.pop(context, _result);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.check_rounded),
                      label: Text('Dùng kết quả', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SourceButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;
  const _Row({required this.label, required this.value, this.strong = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.nunito(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.nunito(
                fontWeight: strong ? FontWeight.w800 : FontWeight.w700,
                fontSize: strong ? 16 : 14,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
