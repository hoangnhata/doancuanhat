import { Box, type SxProps, type Theme } from '@mui/material';
import { AnimatedNattaRobot } from '@/components/robot/AnimatedNattaRobot';
import type { Personality } from '@/components/robot/types';

/** Giữ export để code cũ không gãy; mascot không còn dùng PNG. */
export const NATTA_MASCOT_SRC = '/images/natta-mascot.png';

export type NattaMascotImageProps = {
  size: number;
  personality?: Personality;
  isSelected?: boolean;
  animated?: boolean;
  alt?: string;
  sx?: SxProps<Theme>;
};

/**
 * Mascot Natta — robot vẽ SVG + animation (float, vẫy tay, đuôi, chớp mắt).
 */
export function NattaMascotImage({
  size,
  personality,
  isSelected = false,
  animated = false,
  alt = 'Natta — trợ lý AI',
  sx,
}: NattaMascotImageProps) {
  return (
    <Box
      sx={{
        width: size,
        height: size,
        flexShrink: 0,
        display: 'flex',
        alignItems: 'flex-end',
        justifyContent: 'center',
        ...sx,
      }}
    >
      <AnimatedNattaRobot
        size={size}
        personality={personality}
        isSelected={isSelected}
        animated={animated}
        alt={alt}
      />
    </Box>
  );
}
