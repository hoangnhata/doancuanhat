import {
  BoltRounded,
  EditNoteRounded,
  LightbulbOutlined,
  QuestionAnswerRounded,
} from '@mui/icons-material';
import { Box, Stack, Typography } from '@mui/material';
import { palette } from '@/theme';

type ChatMode = 'record' | 'ask';

type Props = {
  mode: ChatMode;
};

const RECORD_TIPS = [
  'Gõ tự nhiên: "cơm trưa 45k", "grab 35k"',
  'AI tự phân loại danh mục và ghi nhận',
  'Dùng chip gợi ý nhanh phía trên ô chat',
];

const ASK_TIPS = [
  'Hỏi về chi tiêu tháng này, ngân sách, danh mục',
  'Ví dụ: "Tôi nên cắt giảm khoản nào?"',
  'Natta trả lời dựa trên dữ liệu thực của bạn',
];

export function ChatTipsPanel({ mode }: Props) {
  const isRecord = mode === 'record';
  const tips = isRecord ? RECORD_TIPS : ASK_TIPS;

  return (
    <Box
      sx={{
        display: { xs: 'none', lg: 'flex' },
        flexDirection: 'column',
        width: { lg: 280, xl: 320 },
        flexShrink: 0,
        overflowY: 'auto',
        p: 2.5,
        borderLeft: `1px solid ${palette.primary.main}18`,
        bgcolor: palette.surface,
      }}
    >
      <Stack direction="row" spacing={1} alignItems="center" mb={1.5}>
        <Box
          sx={{
            width: 36,
            height: 36,
            borderRadius: 1.5,
            display: 'grid',
            placeItems: 'center',
            bgcolor: `${palette.primary.main}12`,
            color: palette.primary.main,
          }}
        >
          {isRecord ? <EditNoteRounded sx={{ fontSize: 20 }} /> : <QuestionAnswerRounded sx={{ fontSize: 20 }} />}
        </Box>
        <Typography fontWeight={800} fontSize={{ xs: 15, md: 16 }}>
          {isRecord ? 'Ghi chi tiêu nhanh' : 'Hỏi Natta'}
        </Typography>
      </Stack>

      <Stack spacing={1} flex={1}>
        {tips.map((tip) => (
          <Stack key={tip} direction="row" spacing={0.75} alignItems="flex-start">
            <BoltRounded sx={{ fontSize: 17, color: palette.primary.main, mt: 0.2 }} />
            <Typography variant="body2" color="text.secondary" fontWeight={600} lineHeight={1.5} fontSize={{ xs: 14, md: 15 }}>
              {tip}
            </Typography>
          </Stack>
        ))}
      </Stack>

      <Box
        sx={{
          mt: 1.5,
          p: 1.5,
          borderRadius: 2,
          bgcolor: '#fff',
          border: `1px dashed ${palette.primary.main}33`,
        }}
      >
        <Stack direction="row" spacing={0.75} alignItems="center" mb={0.5}>
          <LightbulbOutlined sx={{ fontSize: 16, color: palette.primary.main }} />
          <Typography variant="body2" fontWeight={800} color="primary.main" fontSize={13}>
            Mẹo
          </Typography>
        </Stack>
        <Typography variant="body2" color="text.secondary" fontWeight={600} lineHeight={1.5} fontSize={13}>
          {isRecord
            ? 'Bấm "Gợi ý tiết kiệm" để xem khoản chi có thể cắt giảm trong 30 ngày qua.'
            : 'Shift+Enter để xuống dòng khi soạn câu hỏi dài.'}
        </Typography>
      </Box>
    </Box>
  );
}
