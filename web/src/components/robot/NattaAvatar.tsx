import { Stack, Typography } from '@mui/material';
import { useAuth } from '@/contexts/AuthContext';
import {
  PersonalityRobotAvatar,
  parseBotPersonality,
} from '@/components/robot/PersonalityRobotAvatar';
import { RobotAvatar } from '@/components/robot/RobotAvatar';

export type NattaAvatarProps = {
  size?: number;
  showGreeting?: boolean;
  animated?: boolean;
};

/**
 * Avatar Natta theo `botPersonality` user — tương đương `natta_avatar.dart`.
 */
export function NattaAvatar({
  size = 64,
  showGreeting = false,
  animated = true,
}: NattaAvatarProps) {
  const { user } = useAuth();
  const p = parseBotPersonality(user?.botPersonality);

  return (
    <Stack alignItems="center" spacing={showGreeting ? 1 : 0}>
      <PersonalityRobotAvatar
        type={p}
        size={size}
        animated={animated}
      />
      {showGreeting && (
        <Typography variant="caption" color="text.secondary" fontWeight={500}>
          Xin chào! Tôi là AI trợ lý tài chính
        </Typography>
      )}
    </Stack>
  );
}

/** Khi chưa có user (loading) — robot mặc định xanh */
export function NattaAvatarFallback({
  size = 64,
  animated = true,
}: {
  size?: number;
  animated?: boolean;
}) {
  return <RobotAvatar size={size} animated={animated} />;
}
