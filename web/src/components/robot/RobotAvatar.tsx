import { type SxProps, type Theme } from '@mui/material';
import { NattaMascotImage } from '@/components/robot/NattaMascotImage';

export type RobotAvatarProps = {
  size?: number;
  animated?: boolean;
  sx?: SxProps<Theme>;
};

/**
 * Robot mascot mặc định — SVG có animation (float, vẫy tay, đuôi).
 */
export function RobotAvatar({
  size = 80,
  animated = true,
  sx,
}: RobotAvatarProps) {
  return (
    <NattaMascotImage
      size={size}
      animated={animated}
      alt="Natta trợ lý AI"
      sx={sx}
    />
  );
}
