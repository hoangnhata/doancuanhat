import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/router/app_router.dart';
import 'package:expense_manager/core/di/injection.dart';
import 'package:expense_manager/core/providers/app_providers.dart';
import 'package:expense_manager/presentation/widgets/robot/personality_robot_avatar.dart';
import 'package:expense_manager/domain/models/category.dart';
import 'package:expense_manager/domain/repositories/transaction_repository.dart';
import 'package:expense_manager/presentation/widgets/robot/natta_avatar.dart';
import 'package:expense_manager/presentation/widgets/robot/chat_bubble.dart';
import 'package:expense_manager/presentation/widgets/robot/bot_selector_sheet.dart';

class ChatMessage {
  final String text;
  final ChatBubbleType type;
  final DateTime time;
  final String? subtext;
  final bool isTransaction;

  ChatMessage({
    required this.text,
    required this.type,
    required this.time,
    this.subtext,
    this.isTransaction = false,
  });
}

/// Hai chế độ chat: ghi giao dịch (categorize + save) hoặc hỏi đáp Natta (LLM).
enum ChatMode { record, ask }

class ChatTab extends ConsumerStatefulWidget {
  const ChatTab({super.key});

  @override
  ConsumerState<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends ConsumerState<ChatTab> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isLoadingSuggestions = false;
  ChatMode _mode = ChatMode.record;
  List<Category> _expenseCategories = [];
  List<Category> _incomeCategories = [];

  static const _welcomeMessages = [
    'Xin chào! 👋 Tôi là Natta, trợ lý AI quản lý chi tiêu của bạn.',
    'Chỉ cần nhập chi tiêu theo cách tự nhiên, ví dụ:\n• "ăn trưa 50k"\n• "grab đi làm 35k"\n• "mua café 25 nghìn"',
    'Tôi sẽ tự động phân loại và ghi nhận cho bạn!',
  ];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _addWelcomeMessages();
  }

  void _addWelcomeMessages() {
    final now = DateTime.now();
    for (var i = 0; i < _welcomeMessages.length; i++) {
      _messages.add(ChatMessage(
        text: _welcomeMessages[i],
        type: ChatBubbleType.bot,
        time: now.add(Duration(milliseconds: i * 100)),
      ));
    }
  }

  Future<void> _loadCategories() async {
    try {
      final repo = ref.read(categoryRepositoryProvider);
      final expense = await repo.getAll(type: 'EXPENSE');
      final income = await repo.getAll(type: 'INCOME');
      if (mounted) {
        setState(() {
          _expenseCategories = expense;
          _incomeCategories = income;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _processInput(String text) async {
    final input = text.trim();
    if (input.isEmpty || _isLoading) return;

    if (_mode == ChatMode.ask) {
      await _askAssistant(input);
      return;
    }

    _controller.clear();
    _messages.add(ChatMessage(
      text: input,
      type: ChatBubbleType.user,
      time: DateTime.now(),
      isTransaction: true,
    ));
    setState(() => _isLoading = true);
    _scrollToBottom();

    try {
      if (_expenseCategories.isEmpty && _incomeCategories.isEmpty) await _loadCategories();
      final user = await localStorage.getUser();
      final result = await ref.read(transactionRepositoryProvider).aiCategorize(
            input,
            personality: user?.botPersonality,
          );
      final isIncome = result.transactionType.toUpperCase() == 'INCOME';
      final categoryId = result.categoryId ??
          _findCategoryId(
            result.categoryName,
            result.suggestedCategoryName,
            isIncome: isIncome,
          );

      if (categoryId != null && result.amount != null && result.amount! > 0) {
        await ref.read(transactionRepositoryProvider).create(
          TransactionCreateData(
            type: isIncome ? 'INCOME' : 'EXPENSE',
            amount: result.amount!,
            description: result.description.isNotEmpty ? result.description : null,
            transactionDate: result.transactionDate ?? DateTime.now(),
            categoryId: categoryId,
            walletId: ref.read(selectedWalletIdProvider),
          ),
        );

        final fmt = NumberFormat.compact(locale: 'vi');
        final rollyMsg = result.rollyResponse ?? 'Đã ghi nhận! ✓ ${result.description.isNotEmpty ? result.description : "Chi tiêu"} - ${fmt.format(result.amount!)}₫';
        final replies = [
          'Đã ghi nhận! ✓ ${result.description.isNotEmpty ? result.description : "Chi tiêu"} - ${fmt.format(result.amount!)}₫',
          rollyMsg,
        ];

        for (var r in replies) {
          _messages.add(ChatMessage(
            text: r,
            type: ChatBubbleType.bot,
            time: DateTime.now(),
          ));
          _scrollToBottom();
          await Future.delayed(const Duration(milliseconds: 400));
          if (mounted) setState(() {});
        }
      } else {
        _messages.add(ChatMessage(
          text: 'Tôi chưa hiểu rõ. Bạn có thể nhập ví dụ: "ăn trưa 50k" hoặc dùng form thêm giao dịch.',
          type: ChatBubbleType.bot,
          time: DateTime.now(),
          subtext: 'Thử nhập số tiền rõ ràng (ví dụ: 50k, 100 nghìn)',
        ));
      }
    } catch (e) {
      _messages.add(ChatMessage(
        text: 'Có lỗi xảy ra. Bạn có thể thử lại hoặc thêm giao dịch thủ công.',
        type: ChatBubbleType.bot,
        time: DateTime.now(),
      ));
    }

    if (mounted) {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  Future<void> _askAssistant(String text) async {
    _controller.clear();
    _messages.add(ChatMessage(
      text: text,
      type: ChatBubbleType.user,
      time: DateTime.now(),
    ));
    setState(() => _isLoading = true);
    _scrollToBottom();

    try {
      final r = await ref.read(transactionRepositoryProvider).askAssistant(text);
      _messages.add(ChatMessage(
        text: r.reply,
        type: ChatBubbleType.bot,
        time: DateTime.now(),
        subtext: r.engine == 'gemini'
            ? 'Trả lời bởi Gemini AI'
            : r.engine == 'rule'
                ? 'Trả lời rule-based (chưa cấu hình GEMINI_API_KEY)'
                : null,
      ));
    } catch (e) {
      _messages.add(ChatMessage(
        text: 'Xin lỗi, Natta tạm thời chưa trả lời được. Vui lòng thử lại sau.',
        type: ChatBubbleType.bot,
        time: DateTime.now(),
      ));
    }

    if (mounted) {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  Future<void> _fetchSuggestions() async {
    if (_isLoading || _isLoadingSuggestions) return;
    setState(() => _isLoadingSuggestions = true);
    _scrollToBottom();

    try {
      final suggestions = await ref.read(transactionRepositoryProvider).getSuggestions();
      if (!mounted) return;

      final fmt = NumberFormat('#,###', 'vi');
      final buf = StringBuffer('💡 Gợi ý tiết kiệm (30 ngày qua):\n\n');
      for (final s in suggestions) {
        buf.writeln('• ${s.categoryName}: ${fmt.format(s.amount)}₫');
        buf.writeln('  ${s.suggestion}');
        buf.writeln('  (Có thể giảm ~${s.percentPossible}%)\n');
      }

      _messages.add(ChatMessage(
        text: buf.toString().trim(),
        type: ChatBubbleType.bot,
        time: DateTime.now(),
      ));
    } catch (e) {
      _messages.add(ChatMessage(
        text: 'Không thể tải gợi ý. Vui lòng thử lại sau.',
        type: ChatBubbleType.bot,
        time: DateTime.now(),
      ));
    }

    if (mounted) {
      setState(() => _isLoadingSuggestions = false);
      _scrollToBottom();
    }
  }

  int? _findCategoryId(String categoryName, String suggested, {required bool isIncome}) {
    final pool = isIncome ? _incomeCategories : _expenseCategories;
    final searchTerms = [categoryName, suggested].where((s) => s.isNotEmpty);
    for (final term in searchTerms) {
      final lower = term.toLowerCase();
      final exact = pool.where((cat) => cat.name.toLowerCase() == lower).toList();
      if (exact.isNotEmpty) return exact.first.id;
      final partial = pool.where((cat) {
        final n = cat.name.toLowerCase();
        return n.contains(lower) || lower.contains(n);
      }).toList();
      if (partial.isNotEmpty) return partial.first.id;
    }
    return pool.isNotEmpty ? pool.first.id : null;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final botType = user?.botPersonality == 'SAD'
        ? PersonalityType.sad
        : user?.botPersonality == 'ANGRY'
            ? PersonalityType.angry
            : PersonalityType.happy;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.gradientStart,
              AppColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildModeSwitcher(),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: _messages.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: NattaAvatar(size: 56, showGreeting: false),
                      );
                    }
                    final msg = _messages[index - 1];
                    return ChatBubble(
                      message: msg.text,
                      type: msg.type,
                      timestamp: msg.time,
                      subtext: msg.subtext,
                      isTransaction: msg.isTransaction,
                      botPersonality: msg.type == ChatBubbleType.bot ? botType : null,
                    );
                  },
                ),
              ),
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Đang xử lý...',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              _buildInputArea(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => showBotSelectorSheet(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppColors.softShadow,
              ),
              child: NattaAvatar(size: 36),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => showBotSelectorSheet(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Trợ lý AI',
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Icon(Icons.arrow_drop_down_rounded, color: AppColors.textMuted, size: 24),
                    ],
                  ),
                  Text(
                    _mode == ChatMode.ask
                        ? 'Hỏi Natta về chi tiêu của bạn'
                        : 'Nhập chi tiêu tự nhiên để ghi nhanh',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              _HeaderIconButton(
                icon: Icons.add_chart_rounded,
                onTap: () => Navigator.pushNamed(context, AppRouter.addTransaction).then((_) {
                  ref.read(transactionListRefreshTriggerProvider.notifier).state++;
                }),
              ),
              const SizedBox(width: 8),
              _HeaderIconButton(
                icon: Icons.account_balance_wallet_rounded,
                onTap: () => Navigator.pushNamed(context, AppRouter.budget),
              ),
              const SizedBox(width: 8),
              _HeaderIconButton(
                icon: Icons.category_rounded,
                onTap: () => Navigator.pushNamed(context, AppRouter.categories),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeSwitcher() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Expanded(
              child: _ModeTab(
                icon: Icons.edit_note_rounded,
                label: 'Ghi chi tiêu',
                selected: _mode == ChatMode.record,
                onTap: () => setState(() => _mode = ChatMode.record),
              ),
            ),
            Container(width: 1, height: 36, color: AppColors.primary.withOpacity(0.15)),
            Expanded(
              child: _ModeTab(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Hỏi Natta',
                selected: _mode == ChatMode.ask,
                onTap: () => setState(() => _mode = ChatMode.ask),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_mode == ChatMode.record)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isLoading || _isLoadingSuggestions ? null : _fetchSuggestions,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lightbulb_outline_rounded,
                            size: 20,
                            color: _isLoadingSuggestions ? AppColors.textMuted : AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          _isLoadingSuggestions
                              ? Text(
                                  'Đang tải...',
                                  style: GoogleFonts.nunito(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textMuted,
                                  ),
                                )
                              : Text(
                                  'Gợi ý tiết kiệm',
                                  style: GoogleFonts.nunito(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _QuickQuestionChip(
                        label: 'Tháng này tiêu nhiều nhất vào đâu?',
                        onTap: () => _askAssistant('Tháng này tôi tiêu nhiều nhất vào đâu?'),
                      ),
                      _QuickQuestionChip(
                        label: 'Tôi nên cắt giảm gì?',
                        onTap: () => _askAssistant('Tôi nên cắt giảm khoản nào?'),
                      ),
                      _QuickQuestionChip(
                        label: 'Tóm tắt tháng này',
                        onTap: () => _askAssistant('Tóm tắt chi tiêu tháng này của tôi.'),
                      ),
                      _QuickQuestionChip(
                        label: 'Ngân sách còn lại?',
                        onTap: () => _askAssistant('Ngân sách của tôi còn lại bao nhiêu?'),
                      ),
                    ],
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: _mode == ChatMode.ask
                            ? 'Hỏi về chi tiêu...'
                            : 'ăn trưa 50k, grab 35k...',
                        hintStyle: GoogleFonts.nunito(color: AppColors.textMuted, fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      style: GoogleFonts.nunito(fontSize: 14),
                      maxLines: 3,
                      minLines: 1,
                      onSubmitted: _processInput,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isLoading ? null : () => _processInput(_controller.text),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isLoading
                              ? [AppColors.textMuted, AppColors.textMuted]
                              : [AppColors.primary, AppColors.primaryDark],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: _isLoading
                            ? null
                            : [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Tab chuyển chế độ — icon + label trên một hàng, tránh wrap của SegmentedButton.
class _ModeTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.primary : AppColors.textSecondary,
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

class _QuickQuestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickQuestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
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

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: AppColors.softShadow,
          ),
          child: Icon(icon, size: 22, color: AppColors.primary),
        ),
      ),
    );
  }
}
