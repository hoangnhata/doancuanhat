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
import 'package:expense_manager/domain/models/ai_categorize.dart';
import 'package:expense_manager/domain/models/ocr_receipt.dart';

/// Quét bill chuyển khoản:
///   1. OCR → số tiền + ngày
///   2. User nhập mô tả → AI classify phân loại
///   3. Trả [OcrReceiptResult] để điền form
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
  bool _isOcrLoading = false;
  bool _isClassifyLoading = false;
  String? _error;

  double? _ocrAmount;
  DateTime? _ocrDate;
  double? _ocrConfidence;
  bool _ocrNeedsReview = false;
  String? _ocrEngine;

  final _descriptionController = TextEditingController();
  AICategorizeResult? _classifyResult;
  String? _classifyError;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

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
        _ocrAmount = null;
        _ocrDate = null;
        _classifyResult = null;
        _classifyError = null;
        _descriptionController.clear();
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
      _isOcrLoading = true;
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
        _ocrAmount = r.amount;
        _ocrDate = r.transactionDate;
        _ocrConfidence = r.confidence;
        _ocrNeedsReview = r.needsReview;
        _ocrEngine = r.ocrEngine;
        _isOcrLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Không phân tích được bill chuyển khoản. ${extractErrorMessage(e)}';
        _isOcrLoading = false;
      });
    }
  }

  Future<void> _runClassify() async {
    final text = _descriptionController.text.trim();
    if (text.isEmpty) {
      setState(() => _classifyError = 'Vui lòng nhập mô tả chuyển khoản.');
      return;
    }
    setState(() {
      _isClassifyLoading = true;
      _classifyError = null;
    });
    try {
      final user = ref.read(currentUserProvider).value;
      final result = await ref.read(transactionRepositoryProvider).aiCategorize(
            text,
            personality: user?.botPersonality,
          );
      if (!mounted) return;
      setState(() {
        _classifyResult = result;
        _isClassifyLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _classifyError = 'Không phân loại được. ${extractErrorMessage(e)}';
        _isClassifyLoading = false;
      });
    }
  }

  bool get _canApply =>
      _ocrAmount != null &&
      _ocrAmount! > 0 &&
      _classifyResult != null &&
      !_isOcrLoading &&
      !_isClassifyLoading;

  OcrReceiptResult _buildResult() {
    final cls = _classifyResult!;
    return OcrReceiptResult(
      transactionType: cls.transactionType,
      amount: _ocrAmount,
      transactionDate: _ocrDate ?? cls.transactionDate,
      description: cls.description.isNotEmpty ? cls.description : _descriptionController.text.trim(),
      categoryName: cls.categoryName,
      categoryId: cls.categoryId,
      confidence: _ocrConfidence,
      needsReview: _ocrNeedsReview || cls.categoryId == null,
      ocrEngine: _ocrEngine,
      bankTransfer: true,
    );
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
        child: SingleChildScrollView(
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
                      'Quét bill chuyển khoản',
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
                  'Chụp screenshot bill chuyển khoản (MB, MoMo, VietinBank…). AI sẽ đọc số tiền và ngày, sau đó bạn mô tả để phân loại.',
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
                    constraints: const BoxConstraints(maxHeight: 160),
                    child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 12),
                if (_isOcrLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  _AlertBox(message: _error!, isError: true)
                else if (!_isOcrLoading && _imageBytes != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đã đọc từ bill',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _Row(label: 'Số tiền', value: _money(_ocrAmount), strong: true),
                        _Row(
                          label: 'Ngày',
                          value: _ocrDate != null
                              ? DateFormat('dd/MM/yyyy').format(_ocrDate!)
                              : '—',
                        ),
                        if (_ocrAmount == null || _ocrAmount! <= 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Không đọc được số tiền — nhập thủ công sau khi đóng sheet hoặc chọn ảnh rõ hơn.',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else if (_ocrNeedsReview)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Kiểm tra lại số tiền/ngày trước khi lưu.',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: Colors.amber.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Mô tả chuyển khoản',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Nhập nội dung để AI phân loại danh mục (vd: trà sữa, tiền điện, quà sinh nhật).',
                    style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 2,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _runClassify(),
                    decoration: InputDecoration(
                      hintText: 'Ví dụ: Tang em sinh nhật 100k',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isClassifyLoading ? null : _runClassify,
                      icon: _isClassifyLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome_rounded),
                      label: Text(
                        'Phân loại với AI',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  if (_classifyError != null) ...[
                    const SizedBox(height: 8),
                    _AlertBox(message: _classifyError!, isError: true),
                  ],
                  if (_classifyResult != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withOpacity(0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kết quả phân loại',
                            style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: Colors.green.shade800),
                          ),
                          const SizedBox(height: 6),
                          _Row(
                            label: 'Loại',
                            value: _classifyResult!.transactionType == 'INCOME' ? 'Thu nhập' : 'Chi tiêu',
                          ),
                          _Row(label: 'Danh mục', value: _classifyResult!.categoryName),
                          _Row(label: 'Mô tả', value: _classifyResult!.description),
                        ],
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isOcrLoading
                            ? null
                            : () {
                                setState(() {
                                  _imageBytes = null;
                                  _ocrAmount = null;
                                  _classifyResult = null;
                                  _error = null;
                                  _descriptionController.clear();
                                });
                              },
                        icon: const Icon(Icons.replay_rounded),
                        label: Text('Chọn ảnh khác', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _canApply
                            ? () {
                                HapticUtils.medium();
                                Navigator.pop(context, _buildResult());
                              }
                            : null,
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
      ),
    );
  }
}

class _AlertBox extends StatelessWidget {
  final String message;
  final bool isError;
  const _AlertBox({required this.message, this.isError = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isError ? AppColors.accent : Colors.amber).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (isError ? AppColors.accent : Colors.amber).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
            color: isError ? AppColors.accent : Colors.amber,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.nunito(
                color: isError ? AppColors.accent : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
            Text(label, style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.primary)),
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.nunito(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.nunito(
                fontWeight: strong ? FontWeight.w800 : FontWeight.w700,
                fontSize: strong ? 16 : 13,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
