import { EditNoteRounded, ChatBubbleOutlineRounded } from '@mui/icons-material';
import { Box, Stack, Typography } from '@mui/material';
import { palette } from '@/theme';

type ChatMode = 'record' | 'ask';

type Props = {
  mode: ChatMode;
  onChange: (mode: ChatMode) => void;
};

export function ChatModeToggle({ mode, onChange }: Props) {
  return (
    <Box
      sx={{
        px: { xs: 2, md: 2.5 },
        pb: 1.5,
        pt: 1.25,
        bgcolor: '#fff',
        borderBottom: `1px solid ${palette.primary.main}10`,
      }}
    >
      <Box
        sx={{
          display: 'flex',
          p: '3px',
          borderRadius: 2.5,
          bgcolor: palette.surface,
          border: `1px solid ${palette.primary.main}10`,
        }}
      >
        <ModeOption
          label="Ghi chi tiêu"
          icon={<EditNoteRounded sx={{ fontSize: 17 }} />}
          selected={mode === 'record'}
          onClick={() => onChange('record')}
        />
        <ModeOption
          label="Hỏi Natta"
          icon={<ChatBubbleOutlineRounded sx={{ fontSize: 17 }} />}
          selected={mode === 'ask'}
          onClick={() => onChange('ask')}
        />
      </Box>
    </Box>
  );
}

function ModeOption({
  label,
  icon,
  selected,
  onClick,
}: {
  label: string;
  icon: React.ReactNode;
  selected: boolean;
  onClick: () => void;
}) {
  return (
    <Box
      onClick={onClick}
      sx={{
        flex: 1,
        py: 1,
        px: 1,
        borderRadius: 2,
        cursor: 'pointer',
        textAlign: 'center',
        transition: 'background-color 0.18s ease, box-shadow 0.18s ease, color 0.18s ease',
        bgcolor: selected ? '#fff' : 'transparent',
        color: selected ? palette.primary.main : palette.textSecondary,
        boxShadow: selected ? '0 1px 4px rgba(15, 23, 42, 0.08)' : 'none',
        border: selected ? `1px solid ${palette.primary.main}18` : '1px solid transparent',
        '&:hover': {
          bgcolor: selected ? '#fff' : `${palette.primary.main}06`,
        },
      }}
    >
      <Stack direction="row" spacing={0.75} alignItems="center" justifyContent="center">
        {icon}
        <Typography fontWeight={700} fontSize={{ xs: 13, md: 14 }}>
          {label}
        </Typography>
      </Stack>
    </Box>
  );
}
