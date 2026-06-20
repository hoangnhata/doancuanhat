import { format } from 'date-fns';
import { Box, Stack, Typography } from '@mui/material';
import {
  parseBotPersonality,
  PersonalityRobotAvatar,
} from '@/components/robot/PersonalityRobotAvatar';
import { palette } from '@/theme';

type Role = 'bot' | 'user';

type Props = {
  role: Role;
  text: string;
  time: Date;
  subtext?: string;
  botPersonality?: string | null;
};

export function ChatMessageBubble({ role, text, time, subtext, botPersonality }: Props) {
  const isUser = role === 'user';

  if (isUser) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'flex-end', mb: 2 }}>
        <Box
          sx={{
            maxWidth: { xs: '90%', sm: '78%', md: '70%' },
            px: 2.25,
            py: 1.75,
            borderRadius: '20px 20px 4px 20px',
            background: `linear-gradient(135deg, ${palette.primary.main}, ${palette.primary.dark})`,
            boxShadow: '0 4px 16px rgba(2, 136, 209, 0.28)',
          }}
        >
          <Typography whiteSpace="pre-wrap" fontSize={{ xs: 15, md: 16 }} fontWeight={600} color="#fff" lineHeight={1.5}>
            {text}
          </Typography>
          <Typography variant="caption" sx={{ display: 'block', mt: 0.75, color: '#ffffffaa' }}>
            {format(time, 'HH:mm')}
          </Typography>
        </Box>
      </Box>
    );
  }

  return (
    <Stack direction="row" spacing={1.25} alignItems="flex-end" sx={{ mb: 2, maxWidth: { xs: '95%', md: '88%' } }}>
      <Box sx={{ flexShrink: 0, pb: 0.5 }}>
        <PersonalityRobotAvatar
          type={parseBotPersonality(botPersonality)}
          size={40}
        />
      </Box>
      <Box
        sx={{
          px: 2.25,
          py: 1.75,
          borderRadius: '4px 20px 20px 20px',
          bgcolor: '#fff',
          border: `1px solid ${palette.outline}`,
          boxShadow: palette.shadowSoft,
        }}
      >
        <Typography whiteSpace="pre-wrap" fontSize={{ xs: 15, md: 16 }} color="text.primary" lineHeight={1.55}>
          {text}
        </Typography>
        {subtext && (
          <Typography
            variant="caption"
            color="text.secondary"
            sx={{ display: 'block', mt: 0.75, fontStyle: 'italic' }}
          >
            {subtext}
          </Typography>
        )}
        <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 0.5 }}>
          {format(time, 'HH:mm')}
        </Typography>
      </Box>
    </Stack>
  );
}

export function ChatTypingIndicator({ label }: { label: string }) {
  return (
    <Stack direction="row" spacing={1.5} alignItems="center" sx={{ mb: 1.5, pl: 5 }}>
      <Box sx={{ display: 'flex', gap: 0.5 }}>
        {[0, 1, 2].map((i) => (
          <Box
            key={i}
            sx={{
              width: 7,
              height: 7,
              borderRadius: '50%',
              bgcolor: palette.primary.main,
              animation: 'chatBounce 1.2s infinite',
              animationDelay: `${i * 0.15}s`,
              '@keyframes chatBounce': {
                '0%, 80%, 100%': { transform: 'scale(0.6)', opacity: 0.4 },
                '40%': { transform: 'scale(1)', opacity: 1 },
              },
            }}
          />
        ))}
      </Box>
      <Typography variant="body2" color="text.secondary" fontWeight={600} fontSize={{ xs: 14, md: 15 }}>
        {label}
      </Typography>
    </Stack>
  );
}
