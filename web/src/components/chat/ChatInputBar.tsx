import { BoltRounded, LightbulbOutlined, SendRounded } from '@mui/icons-material';
import { Box, Chip, IconButton, Stack, TextField, Typography } from '@mui/material';
import { palette } from '@/theme';

type ChatMode = 'record' | 'ask';

type Props = {
  mode: ChatMode;
  value: string;
  onChange: (v: string) => void;
  onSend: () => void;
  disabled?: boolean;
  onQuickRecord?: (text: string) => void;
  onQuickAsk?: (text: string) => void;
  onFetchSuggestions?: () => void;
  loadingSuggestions?: boolean;
};

const QUICK_ASK = [
  'Tháng này tôi tiêu nhiều nhất vào đâu?',
  'Tôi nên cắt giảm khoản nào?',
  'Tóm tắt chi tiêu tháng này của tôi.',
  'Ngân sách của tôi còn lại bao nhiêu?',
];

const QUICK_RECORD = ['cafe 30k', 'grab 35k', 'ăn trưa 50k', 'siêu thị 200k'];

export function ChatInputBar({
  mode,
  value,
  onChange,
  onSend,
  disabled,
  onQuickRecord,
  onQuickAsk,
  onFetchSuggestions,
  loadingSuggestions,
}: Props) {
  return (
    <Box
      sx={{
        flexShrink: 0,
        pt: 1.5,
        pb: 1.25,
        px: { xs: 2, md: 2.5 },
        bgcolor: '#fff',
        borderTop: `1px solid ${palette.primary.main}18`,
      }}
    >
      {mode === 'ask' ? (
        <Stack direction="row" spacing={1} sx={{ mb: 1.5, overflowX: 'auto', pb: 0.5 }}>
          {QUICK_ASK.map((q) => (
            <Chip
              key={q}
              icon={<BoltRounded />}
              label={q}
              clickable
              onClick={() => onQuickAsk?.(q)}
              variant="outlined"
              sx={{
                flexShrink: 0,
                fontWeight: 700,
                fontSize: { xs: 13, md: 14 },
                height: 36,
                borderRadius: 2,
                borderColor: `${palette.primary.main}44`,
                bgcolor: '#fff',
              }}
            />
          ))}
        </Stack>
      ) : (
        <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap sx={{ mb: 1.5 }}>
          {QUICK_RECORD.map((q) => (
            <Chip
              key={q}
              label={q}
              clickable
              onClick={() => onQuickRecord?.(q)}
              sx={{
                fontWeight: 700,
                fontSize: { xs: 13, md: 14 },
                height: 36,
                borderRadius: 2,
                bgcolor: `${palette.primary.main}10`,
                border: `1px solid ${palette.primary.main}33`,
              }}
            />
          ))}
          <Chip
            icon={<LightbulbOutlined />}
            label={loadingSuggestions ? 'Đang tải…' : 'Gợi ý tiết kiệm'}
            clickable
            onClick={onFetchSuggestions}
            disabled={loadingSuggestions || disabled}
            variant="outlined"
            color="primary"
            sx={{ fontWeight: 700, fontSize: { xs: 13, md: 14 }, height: 36, borderRadius: 2 }}
          />
        </Stack>
      )}

      <Stack
        direction="row"
        spacing={1}
        alignItems="center"
        sx={{
          py: 0.75,
          pl: 2,
          pr: 0.75,
          minHeight: { xs: 50, md: 52 },
          borderRadius: 3,
          bgcolor: palette.surface,
          border: `1px solid ${palette.primary.main}22`,
        }}
      >
        <TextField
          fullWidth
          placeholder={
            mode === 'ask'
              ? 'Hỏi Natta về chi tiêu của bạn…'
              : 'Nhập chi tiêu, ví dụ: cơm trưa 45k'
          }
          value={value}
          onChange={(e) => onChange(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
              e.preventDefault();
              onSend();
            }
          }}
          multiline
          maxRows={4}
          variant="standard"
          InputProps={{ disableUnderline: true }}
          sx={{
            '& .MuiInputBase-root': {
              fontSize: { xs: 15, md: 16 },
              fontWeight: 500,
              alignItems: 'center',
              py: 0.25,
            },
            '& .MuiInputBase-input': {
              py: 1.1,
              lineHeight: 1.5,
              '&::placeholder': { opacity: 0.65 },
            },
          }}
        />
        <IconButton
          onClick={onSend}
          disabled={disabled || !value.trim()}
          aria-label="Gửi"
          sx={{
            width: 44,
            height: 44,
            flexShrink: 0,
            bgcolor: palette.primary.main,
            color: '#fff',
            boxShadow: disabled ? 'none' : '0 2px 10px rgba(2, 136, 209, 0.35)',
            '&:hover': { bgcolor: palette.primary.dark },
            '&.Mui-disabled': { bgcolor: palette.textMuted, color: '#fff' },
          }}
        >
          <SendRounded sx={{ fontSize: 22 }} />
        </IconButton>
      </Stack>
      <Typography variant="body2" color="text.secondary" fontSize={13} sx={{ display: 'block', mt: 1.25, textAlign: 'center' }}>
        Enter để gửi · Shift+Enter xuống dòng
      </Typography>
    </Box>
  );
}
