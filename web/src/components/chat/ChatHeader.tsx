import { Box, Stack, Typography } from '@mui/material';
import {
  parseBotPersonality,
  PersonalityRobotAvatar,
} from '@/components/robot/PersonalityRobotAvatar';
import { palette } from '@/theme';

type Props = {
  subtitle: string;
  botPersonality?: string | null;
};

export function ChatHeader({ subtitle, botPersonality }: Props) {
  return (
    <Stack
      direction="row"
      alignItems="center"
      spacing={1.75}
      sx={{
        px: { xs: 2, md: 2.5 },
        py: { xs: 1.75, md: 2 },
        borderBottom: `1px solid ${palette.primary.main}12`,
        background: `linear-gradient(180deg, ${palette.primary.main}0A 0%, #FFFFFF 72%)`,
      }}
    >
      <Box
        sx={{
          width: 48,
          height: 48,
          borderRadius: '50%',
          flexShrink: 0,
          display: 'grid',
          placeItems: 'center',
          bgcolor: '#fff',
          border: `2px solid ${palette.primary.main}14`,
          boxShadow: '0 2px 12px rgba(2, 136, 209, 0.1)',
        }}
      >
        <PersonalityRobotAvatar
          type={parseBotPersonality(botPersonality)}
          size={40}
          animated
        />
      </Box>
      <Box flex={1} minWidth={0}>
        <Typography
          fontWeight={800}
          letterSpacing="-0.03em"
          fontSize={{ xs: '1.125rem', md: '1.25rem' }}
          lineHeight={1.25}
          color="text.primary"
        >
          Trợ lý AI Natta
        </Typography>
        <Typography
          color="text.secondary"
          fontWeight={500}
          fontSize={{ xs: 13, md: 14 }}
          lineHeight={1.4}
          sx={{
            mt: 0.35,
            display: '-webkit-box',
            WebkitLineClamp: 2,
            WebkitBoxOrient: 'vertical',
            overflow: 'hidden',
          }}
        >
          {subtitle}
        </Typography>
      </Box>
      <Box
        sx={{
          px: 1.1,
          py: 0.45,
          borderRadius: 999,
          flexShrink: 0,
          bgcolor: `${palette.primary.main}0C`,
          border: `1px solid ${palette.primary.main}18`,
        }}
      >
        <Typography fontSize={11} fontWeight={800} color="primary.main" letterSpacing="0.04em">
          AI
        </Typography>
      </Box>
    </Stack>
  );
}
