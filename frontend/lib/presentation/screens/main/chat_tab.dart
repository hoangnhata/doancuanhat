import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/di/injection.dart';
import 'package:expense_manager/core/providers/app_providers.dart';
import 'package:expense_manager/presentation/widgets/robot/personality_robot_avatar.dart';
import 'package:expense_manager/domain/models/ai_categorize.dart';
import 'package:expense_manager/domain/models/category.dart';
import 'package:expense_manager/domain/repositories/transaction_repository.dart';
import 'package:expense_manager/presentation/widgets/robot/chat_bubble.dart';
import 'package:expense_manager/presentation/widgets/robot/chat_header.dart';
import 'package:expense_manager/presentation/widgets/robot/chat_input_bar.dart';
import 'package:expense_manager/presentation/widgets/robot/chat_mode.dart';
import 'package:expense_manager/presentation/widgets/robot/chat_mode_toggle.dart';
import 'package:expense_manager/presentation/widgets/robot/chat_typing_indicator.dart';

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

  static final _batchPattern = RegExp(
    r'(;|\n|\+|&)|,\s*(?!\d)|\s+và\s+',
    caseSensitive: false,
  );

  static final _moneyFmt = NumberFormat('#,###', 'vi');

  static const _welcomeMessages = [
    'Xin chào! 👋 Tôi là Natta, trợ lý AI quản lý chi tiêu của bạn.',
    'Có 2 chế độ:\n• Ghi chi tiêu — gõ "ăn trưa 50k", tôi sẽ phân loại + ghi nhận.\n• Hỏi Natta — hỏi tự nhiên về chi tiêu của bạn.',
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
      final repo = ref.read(transactionRepositoryProvider);
      final isBatch = _batchPattern.hasMatch(input);
      final results = isBatch
          ? await repo.aiCategorizeBatch(input, personality: user?.botPersonality)
          : [
              await repo.aiCategorize(input, personality: user?.botPersonality),
            ];

      final savedLines = <String>[];
      for (final result in results) {
        final line = await _saveCategorizedTransaction(result);
        if (line != null) savedLines.add(line);
      }

      if (savedLines.isNotEmpty) {
        ref.read(transactionListRefreshTriggerProvider.notifier).state++;
        final botText = savedLines.length == 1 && !isBatch
            ? _singleRecordReply(results.first, savedLines.first)
            : '✓ Đã ghi ${savedLines.length} giao dịch:\n${savedLines.map((s) => '• $s').join('\n')}';
        _messages.add(ChatMessage(
          text: botText,
          type: ChatBubbleType.bot,
          time: DateTime.now(),
        ));
      } else {
        _messages.add(ChatMessage(
          text: isBatch
              ? 'Không ghi được giao dịch nào. Thử tách từng khoản: "ăn trưa 50k, lương 5 tr".'
              : 'Tôi chưa hiểu rõ. Bạn có thể nhập ví dụ: "ăn trưa 50k" hoặc dùng form thêm giao dịch.',
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

      if (suggestions.isEmpty) {
        _messages.add(ChatMessage(
          text: 'Chưa đủ dữ liệu chi tiêu để gợi ý. Hãy ghi thêm vài giao dịch nhé!',
          type: ChatBubbleType.bot,
          time: DateTime.now(),
        ));
      } else {
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
      }
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

  Future<String?> _saveCategorizedTransaction(AICategorizeResult result) async {
    final isIncome = result.transactionType.toUpperCase() == 'INCOME';
    final categoryId = result.categoryId ??
        _findCategoryId(
          result.categoryName,
          result.suggestedCategoryName,
          isIncome: isIncome,
        );
    if (categoryId == null || result.amount == null || result.amount! <= 0) return null;

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

    final pool = isIncome ? _incomeCategories : _expenseCategories;
    final catName = pool.where((c) => c.id == categoryId).map((c) => c.name).firstOrNull ??
        (result.categoryName.isNotEmpty ? result.categoryName : 'Danh mục');
    final kind = isIncome ? 'Thu' : 'Chi';
    return '$kind · $catName · ${_moneyFmt.format(result.amount!)} ₫';
  }

  String _singleRecordReply(AICategorizeResult result, String savedLine) {
    if (result.rollyResponse != null && result.rollyResponse!.isNotEmpty) {
      return '${result.rollyResponse}\n\n✓ Đã ghi: $savedLine';
    }
    return 'Đã ghi nhận! ✓ $savedLine';
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
    final subtitle = _mode == ChatMode.ask
        ? 'Hỏi Natta về chi tiêu cá nhân của bạn'
        : 'Gõ chi tiêu tự nhiên — AI gợi ý danh mục';

    return ColoredBox(
      color: AppColors.surface,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ChatHeader(subtitle: subtitle, botPersonality: botType),
                ChatModeToggle(
                  mode: _mode,
                  onChanged: (m) => setState(() => _mode = m),
                ),
              ],
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: Colors.white,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_isLoading && index == _messages.length) {
                    return ChatTypingIndicator(
                      label: _mode == ChatMode.ask
                          ? 'Natta đang suy nghĩ…'
                          : 'Đang phân loại…',
                    );
                  }
                  final msg = _messages[index];
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
          ),
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => ChatInputBar(
              mode: _mode,
              controller: _controller,
              focusNode: _focusNode,
              disabled: _isLoading,
              loadingSuggestions: _isLoadingSuggestions,
              onSend: () => _processInput(_controller.text),
              onSubmit: _processInput,
              onFetchSuggestions: _fetchSuggestions,
              onQuickRecord: _processInput,
              onQuickAsk: _askAssistant,
            ),
          ),
        ],
      ),
    );
  }
}
