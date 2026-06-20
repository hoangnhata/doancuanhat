import { Box } from '@mui/material';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useRef, useState } from 'react';
import { ChatHeader } from '@/components/chat/ChatHeader';
import { ChatInputBar } from '@/components/chat/ChatInputBar';
import {
  ChatMessageBubble,
  ChatTypingIndicator,
} from '@/components/chat/ChatMessageBubble';
import { ChatModeToggle } from '@/components/chat/ChatModeToggle';
import { ChatTipsPanel } from '@/components/chat/ChatTipsPanel';
import { useAuth } from '@/contexts/AuthContext';
import { useSelectedWallet } from '@/contexts/SelectedWalletContext';
import { extractApiError } from '@/lib/api';
import { formatMoneyFull } from '@/lib/format';
import { palette } from '@/theme';
import * as categoryService from '@/services/categoryService';
import * as transactionService from '@/services/transactionService';
import type { AICategorizeResponse, Category } from '@/types/models';

/** Giống app Flutter / AddTransactionPage — tách nhiều khoản trong một câu. */
const BATCH_PATTERN = /(;|\n|\+|&)|,\s*(?!\d)|\s+và\s+/i;

function findCategoryId(
  categories: Category[],
  categoryName: string,
  suggested?: string | null,
): number | null {
  const terms = [categoryName, suggested].filter((s): s is string => Boolean(s?.trim()));
  for (const term of terms) {
    const lower = term.toLowerCase();
    const exact = categories.find((c) => c.name.toLowerCase() === lower);
    if (exact) return exact.id;
    const partial = categories.find((c) => {
      const n = c.name.toLowerCase();
      return n.includes(lower) || lower.includes(n);
    });
    if (partial) return partial.id;
  }
  return categories[0]?.id ?? null;
}

type Role = 'bot' | 'user';
type ChatMode = 'record' | 'ask';

interface Msg {
  id: string;
  role: Role;
  text: string;
  time: Date;
  subtext?: string;
}

const WELCOME: Msg[] = [
  {
    id: 'w1',
    role: 'bot',
    text: 'Xin chào! 👋 Tôi là Natta, trợ lý AI quản lý chi tiêu của bạn.',
    time: new Date(),
  },
  {
    id: 'w2',
    role: 'bot',
    text:
      'Có 2 chế độ:\n• Ghi chi tiêu — gõ "ăn trưa 50k", tôi sẽ phân loại + ghi nhận.\n• Hỏi Natta — hỏi tự nhiên về chi tiêu của bạn.',
    time: new Date(),
  },
];

export function ChatPage() {
  const { user } = useAuth();
  const qc = useQueryClient();
  const { selectedWalletId } = useSelectedWallet();
  const [messages, setMessages] = useState<Msg[]>(WELCOME);
  const [input, setInput] = useState('');
  const [mode, setMode] = useState<ChatMode>('record');
  const [loadingSuggestions, setLoadingSuggestions] = useState(false);
  const bottomRef = useRef<HTMLDivElement>(null);

  const { data: expenseCats = [] } = useQuery({
    queryKey: ['categories', 'EXPENSE'],
    queryFn: () => categoryService.fetchCategories('EXPENSE'),
  });

  const { data: incomeCats = [] } = useQuery({
    queryKey: ['categories', 'INCOME'],
    queryFn: () => categoryService.fetchCategories('INCOME'),
  });

  const categorize = useMutation({
    mutationFn: (text: string) =>
      transactionService.aiCategorize(text, user?.botPersonality),
  });

  const askChat = useMutation({
    mutationFn: (text: string) => transactionService.askAssistant(text),
  });

  const busy = categorize.isPending || askChat.isPending;

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, busy]);

  async function sendRecord(text: string) {
    const t = text.trim();
    if (!t || busy) return;
    setInput('');
    setMessages((m) => [
      ...m,
      { id: crypto.randomUUID(), role: 'user', text: t, time: new Date() },
    ]);
    try {
      const isBatch = BATCH_PATTERN.test(t);
      const results: AICategorizeResponse[] = isBatch
        ? await transactionService.aiCategorizeBatch(t, user?.botPersonality)
        : [await categorize.mutateAsync(t)];

      const savedLines: string[] = [];
      for (const res of results) {
        const isIncome = (res.transactionType ?? 'EXPENSE').toUpperCase() === 'INCOME';
        const pool = isIncome ? incomeCats : expenseCats;
        const categoryId =
          res.categoryId ??
          findCategoryId(pool, res.categoryName, res.suggestedCategoryName);
        if (categoryId == null || res.amount == null || res.amount <= 0) continue;

        const catName =
          pool.find((c) => c.id === categoryId)?.name ??
          res.categoryName ??
          res.suggestedCategoryName ??
          'Danh mục';
        const txDate = res.transactionDate ?? new Date().toISOString().slice(0, 10);
        await transactionService.createTransaction({
          type: isIncome ? 'INCOME' : 'EXPENSE',
          amount: res.amount,
          description: res.description?.trim() || undefined,
          transactionDate: txDate,
          categoryId,
          walletId: selectedWalletId,
        });
        savedLines.push(
          `${isIncome ? 'Thu' : 'Chi'} · ${catName} · ${formatMoneyFull(res.amount)}`,
        );
      }

      if (savedLines.length > 0) {
        await qc.invalidateQueries({ queryKey: ['transactions'] });
        await qc.invalidateQueries({ queryKey: ['statistics'] });
        await qc.invalidateQueries({ queryKey: ['wallets'] });

        let botText: string;
        if (savedLines.length === 1 && !isBatch) {
          const res = results[0];
          const isIncome = (res.transactionType ?? 'EXPENSE').toUpperCase() === 'INCOME';
          const pool = isIncome ? incomeCats : expenseCats;
          const catName =
            pool.find((c) => c.id === res.categoryId)?.name ??
            res.categoryName ??
            'Danh mục';
          botText = res.rollyResponse
            ? `${res.rollyResponse}\n\n✓ Đã ghi: ${catName} · ${formatMoneyFull(res.amount!)}`
            : `Đã ghi nhận! ✓ ${res.description?.trim() || catName} · ${formatMoneyFull(res.amount!)}`;
        } else {
          botText = `✓ Đã ghi ${savedLines.length} giao dịch:\n${savedLines.map((line) => `• ${line}`).join('\n')}`;
        }
        setMessages((m) => [
          ...m,
          { id: crypto.randomUUID(), role: 'bot', text: botText, time: new Date() },
        ]);
      } else {
        setMessages((m) => [
          ...m,
          {
            id: crypto.randomUUID(),
            role: 'bot',
            text: isBatch
              ? 'Không ghi được giao dịch nào. Thử tách từng khoản: "ăn trưa 50k, lương 5 tr".'
              : 'Tôi chưa hiểu rõ. Thử "ăn trưa 50k" hoặc thêm giao dịch thủ công.',
            subtext: 'Thử nhập số tiền rõ ràng (ví dụ: 50k, 100 nghìn)',
            time: new Date(),
          },
        ]);
      }
    } catch (e) {
      setMessages((m) => [
        ...m,
        {
          id: crypto.randomUUID(),
          role: 'bot',
          text: extractApiError(e),
          time: new Date(),
        },
      ]);
    }
  }

  async function sendAsk(text: string) {
    const t = text.trim();
    if (!t || busy) return;
    setInput('');
    setMessages((m) => [
      ...m,
      { id: crypto.randomUUID(), role: 'user', text: t, time: new Date() },
    ]);
    try {
      const res = await askChat.mutateAsync(t);
      setMessages((m) => [
        ...m,
        {
          id: crypto.randomUUID(),
          role: 'bot',
          text: res.reply,
          time: new Date(),
        },
      ]);
    } catch (e) {
      setMessages((m) => [
        ...m,
        {
          id: crypto.randomUUID(),
          role: 'bot',
          text: 'Xin lỗi, Natta tạm thời chưa trả lời được: ' + extractApiError(e),
          time: new Date(),
        },
      ]);
    }
  }

  async function fetchSuggestions() {
    if (busy || loadingSuggestions) return;
    setLoadingSuggestions(true);
    try {
      const suggestions = await transactionService.fetchSuggestions();
      if (suggestions.length === 0) {
        setMessages((m) => [
          ...m,
          {
            id: crypto.randomUUID(),
            role: 'bot',
            text: 'Chưa đủ dữ liệu chi tiêu để gợi ý. Hãy ghi thêm vài giao dịch nhé!',
            time: new Date(),
          },
        ]);
        return;
      }
      const lines = suggestions.map(
        (s) =>
          `• ${s.categoryName}: ${formatMoneyFull(s.amount)}\n  ${s.suggestion}\n  (Có thể giảm ~${s.percentPossible}%)`,
      );
      setMessages((m) => [
        ...m,
        {
          id: crypto.randomUUID(),
          role: 'bot',
          text: `💡 Gợi ý tiết kiệm (30 ngày qua):\n\n${lines.join('\n\n')}`,
          time: new Date(),
        },
      ]);
    } catch (e) {
      setMessages((m) => [
        ...m,
        {
          id: crypto.randomUUID(),
          role: 'bot',
          text: 'Không thể tải gợi ý: ' + extractApiError(e),
          time: new Date(),
        },
      ]);
    } finally {
      setLoadingSuggestions(false);
    }
  }

  function send() {
    if (mode === 'ask') sendAsk(input);
    else sendRecord(input);
  }

  const subtitle =
    mode === 'ask'
      ? 'Hỏi Natta về chi tiêu cá nhân của bạn'
      : 'Gõ chi tiêu tự nhiên — AI gợi ý danh mục';

  return (
    <Box
      sx={{
        position: 'absolute',
        inset: 0,
        display: 'flex',
        flexDirection: 'column',
        overflow: 'hidden',
        background: (theme) =>
          theme.palette.mode === 'dark'
            ? `linear-gradient(180deg, ${theme.palette.background.default} 0%, #0C1222 100%)`
            : `linear-gradient(165deg, ${palette.gradientStart} 0%, ${palette.gradientMid} 38%, ${palette.backgroundDefault} 72%, #FFFFFF 100%)`,
      }}
    >
      <Box
        sx={{
          flex: 1,
          display: 'flex',
          flexDirection: 'column',
          minHeight: 0,
          pt: { xs: 2.5, sm: 3, md: 4 },
          px: { xs: 1.5, sm: 2, md: 2.5 },
          pb: { xs: 10, md: 3 },
        }}
      >
        <Box
          sx={{
            flex: 1,
            display: 'flex',
            flexDirection: 'column',
            minHeight: 0,
            maxHeight: '100%',
            bgcolor: '#fff',
            borderRadius: { xs: 2.5, md: 3 },
            border: `1px solid ${palette.primary.main}20`,
            boxShadow: palette.shadowLift,
            overflow: 'hidden',
          }}
        >
          <Box sx={{ flexShrink: 0 }}>
            <ChatHeader botPersonality={user?.botPersonality} subtitle={subtitle} />
            <ChatModeToggle mode={mode} onChange={setMode} />
          </Box>

          <Box
            sx={{
              flex: 1,
              display: 'flex',
              minHeight: 0,
              borderTop: `1px solid ${palette.primary.main}12`,
            }}
          >
            <Box
              sx={{
                flex: 1,
                minWidth: 0,
                overflowY: 'auto',
                px: { xs: 2, md: 2.5 },
                py: { xs: 1.5, md: 2 },
              }}
            >
              {messages.map((m) => (
                <ChatMessageBubble
                  key={m.id}
                  role={m.role}
                  text={m.text}
                  time={m.time}
                  subtext={m.subtext}
                  botPersonality={user?.botPersonality}
                />
              ))}
              {busy && (
                <ChatTypingIndicator
                  label={mode === 'ask' ? 'Natta đang suy nghĩ…' : 'Đang phân loại…'}
                />
              )}
              <div ref={bottomRef} />
            </Box>

            <ChatTipsPanel mode={mode} />
          </Box>

          <ChatInputBar
            mode={mode}
            value={input}
            onChange={setInput}
            onSend={send}
            disabled={busy}
            onQuickRecord={sendRecord}
            onQuickAsk={sendAsk}
            onFetchSuggestions={fetchSuggestions}
            loadingSuggestions={loadingSuggestions}
          />
        </Box>
      </Box>
    </Box>
  );
}
