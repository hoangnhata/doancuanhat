import {
  Box,
  Button,
  Card,
  Chip,
  CircularProgress,
  Fab,
  Stack,
  TextField,
  ToggleButton,
  ToggleButtonGroup,
  Typography,
} from '@mui/material';
import {
  ChatBubbleOutlineRounded,
  EditNoteRounded,
  SendRounded,
  SmartToyRounded,
  BoltRounded,
} from '@mui/icons-material';
import { useMutation, useQuery } from '@tanstack/react-query';
import { format } from 'date-fns';
import { useEffect, useRef, useState } from 'react';
import { GradientBackground } from '@/components/common/GradientBackground';
import {
  parseBotPersonality,
  PersonalityRobotAvatar,
} from '@/components/robot/PersonalityRobotAvatar';
import { useAuth } from '@/contexts/AuthContext';
import { extractApiError } from '@/lib/api';
import * as categoryService from '@/services/categoryService';
import * as transactionService from '@/services/transactionService';
import { palette } from '@/theme';

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

const QUICK_QUESTIONS = [
  'Tháng này tôi tiêu nhiều nhất vào đâu?',
  'Tôi nên cắt giảm khoản nào?',
  'Tóm tắt chi tiêu tháng này của tôi.',
  'Ngân sách của tôi còn lại bao nhiêu?',
];

export function ChatPage() {
  const { user } = useAuth();
  const [messages, setMessages] = useState<Msg[]>(WELCOME);
  const [input, setInput] = useState('');
  const [mode, setMode] = useState<ChatMode>('record');
  const bottomRef = useRef<HTMLDivElement>(null);

  const { data: expenseCats = [] } = useQuery({
    queryKey: ['categories', 'EXPENSE'],
    queryFn: () => categoryService.fetchCategories('EXPENSE'),
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
  }, [messages]);

  async function sendRecord(text: string) {
    const t = text.trim();
    if (!t || busy) return;
    setInput('');
    setMessages((m) => [
      ...m,
      { id: crypto.randomUUID(), role: 'user', text: t, time: new Date() },
    ]);
    try {
      const res = await categorize.mutateAsync(t);
      const catName =
        expenseCats.find((c) => c.id === res.categoryId)?.name ?? res.categoryName;
      const botText = res.rollyResponse
        ? `${res.rollyResponse}\n\n— Gợi ý: ${catName}${res.amount != null ? `, ${res.amount}` : ''}`
        : `Đã phân loại: ${catName}${res.amount != null ? ` · ${res.amount}₫` : ''}. Bạn có thể xác nhận trong màn hình thêm giao dịch.`;
      setMessages((m) => [
        ...m,
        { id: crypto.randomUUID(), role: 'bot', text: botText, time: new Date() },
      ]);
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
      const subtext =
        res.engine === 'gemini'
          ? 'Trả lời bởi Gemini AI'
          : res.engine === 'rule'
            ? 'Trả lời rule-based (chưa cấu hình GEMINI_API_KEY)'
            : undefined;
      setMessages((m) => [
        ...m,
        {
          id: crypto.randomUUID(),
          role: 'bot',
          text: res.reply,
          subtext,
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

  function send() {
    if (mode === 'ask') sendAsk(input);
    else sendRecord(input);
  }

  return (
    <GradientBackground>
      <Box
        sx={{
          width: '100%',
          maxWidth: { xs: '100%', sm: 800, md: 1000, lg: 1280, xl: 1440 },
          mx: 'auto',
          minHeight: '70vh',
          display: 'flex',
          flexDirection: 'column',
          px: { xs: 2, sm: 3, md: 4, lg: 5 },
          py: { xs: 4, sm: 5, md: 7 },
          pb: 12,
        }}
      >
        <Stack
          direction="row"
          alignItems="center"
          spacing={2}
          mb={2}
          sx={{
            p: 2,
            borderRadius: 3,
            background: `linear-gradient(135deg, ${palette.primary.main}14, transparent)`,
            border: `1px solid ${palette.primary.main}22`,
            bgcolor: 'background.paper',
            boxShadow: 1,
          }}
        >
          <Box
            sx={{
              p: 0.75,
              borderRadius: 2,
              bgcolor: 'background.paper',
              boxShadow: 1,
            }}
          >
            <PersonalityRobotAvatar
              type={parseBotPersonality(user?.botPersonality)}
              size={52}
              animated
            />
          </Box>
          <Box flex={1} minWidth={0}>
            <Typography variant="h6" fontWeight={800}>
              Trợ lý AI Natta
            </Typography>
            <Typography variant="caption" color="text.secondary">
              {mode === 'ask'
                ? 'Hỏi Natta về chi tiêu cá nhân của bạn'
                : 'Gõ chi tiêu tự nhiên — AI gợi ý danh mục'}
            </Typography>
          </Box>
          <SmartToyRounded sx={{ color: 'primary.main', opacity: 0.5 }} />
        </Stack>

        <ToggleButtonGroup
          value={mode}
          exclusive
          fullWidth
          size="small"
          color="primary"
          onChange={(_, v) => {
            if (v) setMode(v);
          }}
          sx={{ mb: 2 }}
        >
          <ToggleButton value="record">
            <EditNoteRounded sx={{ mr: 1, fontSize: 18 }} /> Ghi chi tiêu
          </ToggleButton>
          <ToggleButton value="ask">
            <ChatBubbleOutlineRounded sx={{ mr: 1, fontSize: 18 }} /> Hỏi Natta
          </ToggleButton>
        </ToggleButtonGroup>

        <Stack spacing={1.5} flex={1}>
          {messages.map((m) => (
            <Card
              key={m.id}
              sx={{
                alignSelf: m.role === 'user' ? 'flex-end' : 'flex-start',
                maxWidth: { xs: '100%', sm: '92%', md: 720 },
                bgcolor:
                  m.role === 'user' ? `${palette.primary.main}18` : 'background.paper',
                boxShadow: 2,
              }}
            >
              <Box sx={{ p: 2 }}>
                <Stack direction="row" spacing={1} alignItems="flex-start">
                  {m.role === 'bot' && (
                    <Box sx={{ flexShrink: 0, mt: 0.25 }}>
                      <PersonalityRobotAvatar
                        type={parseBotPersonality(user?.botPersonality)}
                        size={36}
                      />
                    </Box>
                  )}
                  <Box flex={1} minWidth={0}>
                    <Typography
                      whiteSpace="pre-wrap"
                      color="text.primary"
                      fontSize={15}
                    >
                      {m.text}
                    </Typography>
                    {m.subtext && (
                      <Typography
                        variant="caption"
                        color="text.secondary"
                        sx={{ display: 'block', mt: 0.5, fontStyle: 'italic' }}
                      >
                        {m.subtext}
                      </Typography>
                    )}
                    <Typography variant="caption" color="text.secondary" sx={{ display: 'block' }}>
                      {format(m.time, 'HH:mm')}
                    </Typography>
                  </Box>
                </Stack>
              </Box>
            </Card>
          ))}
          {busy && (
            <Stack direction="row" spacing={1} alignItems="center">
              <CircularProgress size={20} />
              <Typography variant="body2" color="text.secondary">
                {mode === 'ask' ? 'Natta đang suy nghĩ…' : 'Đang phân loại…'}
              </Typography>
            </Stack>
          )}
          <div ref={bottomRef} />
        </Stack>

        {mode === 'ask' && (
          <Box
            sx={{
              mt: 2,
              display: 'flex',
              gap: 1,
              overflowX: 'auto',
              pb: 0.5,
            }}
          >
            {QUICK_QUESTIONS.map((q) => (
              <Chip
                key={q}
                icon={<BoltRounded />}
                label={q}
                onClick={() => sendAsk(q)}
                color="primary"
                variant="outlined"
                sx={{ flexShrink: 0, fontWeight: 600 }}
              />
            ))}
          </Box>
        )}

        <Stack
          direction="row"
          spacing={1.5}
          alignItems="flex-end"
          sx={{
            position: 'sticky',
            bottom: 0,
            mt: 2,
            pt: 2,
            pb: 0.5,
            bgcolor: 'background.default',
          }}
        >
          <TextField
            fullWidth
            placeholder={
              mode === 'ask'
                ? 'Hỏi Natta về chi tiêu của bạn…'
                : 'Nhập chi tiêu, ví dụ: cơm trưa 45k'
            }
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                send();
              }
            }}
            multiline
            maxRows={3}
          />
          <Fab
            color="primary"
            size="medium"
            onClick={send}
            disabled={busy}
            aria-label="Gửi"
            sx={{
              flexShrink: 0,
              width: 48,
              height: 48,
              minHeight: 48,
              boxShadow: '0 2px 10px rgba(2, 136, 209, 0.38)',
              '&:hover': { boxShadow: '0 4px 14px rgba(2, 136, 209, 0.45)' },
            }}
          >
            <SendRounded sx={{ fontSize: 22 }} />
          </Fab>
        </Stack>
        {mode === 'record' && (
          <Button
            size="small"
            sx={{ mt: 1.5 }}
            onClick={() =>
              setMessages((m) => [
                ...m,
                {
                  id: crypto.randomUUID(),
                  role: 'bot',
                  text: 'Gợi ý: thử "cafe 30k" hoặc mở Cài đặt để đổi tính cách Natta.',
                  time: new Date(),
                },
              ])
            }
          >
            Gợi ý nhanh
          </Button>
        )}
      </Box>
    </GradientBackground>
  );
}
