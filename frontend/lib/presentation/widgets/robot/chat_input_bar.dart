import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/presentation/widgets/robot/chat_mode.dart';

class ChatInputBar extends StatelessWidget {
  final ChatMode mode;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool disabled;
  final bool loadingSuggestions;
  final VoidCallback onSend;
  final ValueChanged<String> onSubmit;
  final VoidCallback onFetchSuggestions;
  final ValueChanged<String> onQuickRecord;
  final ValueChanged<String> onQuickAsk;

  const ChatInputBar({
    super.key,
    required this.mode,
    required this.controller,
    required this.focusNode,
    required this.disabled,
    required this.loadingSuggestions,
    required this.onSend,
    required this.onSubmit,
    required this.onFetchSuggestions,
    required this.onQuickRecord,
    required this.onQuickAsk,
  });

  static const _quickRecord = ['cafe 30k', 'grab 35k', 'ăn trưa 50k', 'siêu thị 200k'];
  static const _quickAsk = [
    'Tháng này tôi tiêu nhiều nhất vào đâu?',
    'Tôi nên cắt giảm khoản nào?',
    'Tóm tắt chi tiêu tháng này của tôi.',
    'Ngân sách của tôi còn lại bao nhiêu?',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.primary.withValues(alpha: 0.1))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 38,
            child: mode == ChatMode.ask
                ? ListView(
                    scrollDirection: Axis.horizontal,
                    children: _quickAsk
                        .map(
                          (q) => _QuickAskChip(
                            label: q,
                            onTap: disabled ? null : () => onQuickAsk(q),
                          ),
                        )
                        .toList(),
                  )
                : ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ..._quickRecord.map(
                        (q) => _QuickRecordChip(
                          label: q,
                          onTap: disabled ? null : () => onQuickRecord(q),
                        ),
                      ),
                      _SuggestionChip(
                        loading: loadingSuggestions,
                        onTap: disabled || loadingSuggestions ? null : onFetchSuggestions,
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 50,
            padding: const EdgeInsets.fromLTRB(14, 5, 5, 5),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    enabled: !disabled,
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      hintText: mode == ChatMode.ask
                          ? 'Hỏi Natta về chi tiêu…'
                          : 'Nhập chi tiêu, ví dụ: cơm trưa 45k',
                      hintStyle: GoogleFonts.nunito(
                        color: AppColors.textMuted,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                      border: InputBorder.none,
                      isCollapsed: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
                    ),
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                    maxLines: 3,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: disabled ? null : onSubmit,
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: disabled || controller.text.trim().isEmpty ? null : onSend,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: disabled
                              ? [AppColors.textMuted, AppColors.textMuted]
                              : [AppColors.primary, AppColors.primaryDark],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickRecordChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _QuickRecordChip({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
            ),
            child: Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAskChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _QuickAskChip({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
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

class _SuggestionChip extends StatelessWidget {
  final bool loading;
  final VoidCallback? onTap;

  const _SuggestionChip({required this.loading, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 14,
                color: loading ? AppColors.textMuted : AppColors.primary,
              ),
              const SizedBox(width: 4),
              Text(
                loading ? 'Đang tải…' : 'Gợi ý tiết kiệm',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: loading ? AppColors.textMuted : AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
