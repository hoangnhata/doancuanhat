import type { SxProps, Theme } from '@mui/material';
import { NattaMascotImage } from '@/components/robot/NattaMascotImage';
import type { Personality } from '@/components/robot/types';

export type { Personality } from '@/components/robot/types';

export function parseBotPersonality(bot?: string | null): Personality {
  switch (bot?.toUpperCase()) {
    case 'SAD':
      return 'SAD';
    case 'ANGRY':
      return 'ANGRY';
    default:
      return 'HAPPY';
  }
}

export type PersonalityRobotAvatarProps = {
  type: Personality;
  size?: number;
  isSelected?: boolean;
  animated?: boolean;
  sx?: SxProps<Theme>;
};

/**
 * Mascot full body theo tính cách — cùng SVG, khác màu / biểu cảm mặt.
 */
export function PersonalityRobotAvatar({
  type,
  size = 56,
  isSelected = false,
  animated = false,
  sx,
}: PersonalityRobotAvatarProps) {
  return (
    <NattaMascotImage
      size={size}
      personality={type}
      isSelected={isSelected}
      animated={animated}
      alt={`Natta — ${type === 'HAPPY' ? 'cổ động' : type === 'ANGRY' ? 'nghiêm khắc' : 'cố vấn'}`}
      sx={sx}
    />
  );
}
