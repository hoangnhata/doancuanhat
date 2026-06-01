import { Box, type BoxProps, useTheme } from '@mui/material';
import { palette } from '@/theme';

/** Lớp blob mờ — chiều sâu nền (light). */
function DecorativeBlobs() {
  return (
    <>
      <Box
        sx={{
          pointerEvents: 'none',
          position: 'absolute',
          top: '-12%',
          right: '-8%',
          width: { xs: 280, md: 360 },
          height: { xs: 280, md: 360 },
          borderRadius: '50%',
          background: `radial-gradient(circle at 30% 30%, ${palette.primary.light}55 0%, transparent 65%)`,
          filter: 'blur(1px)',
        }}
      />
      <Box
        sx={{
          pointerEvents: 'none',
          position: 'absolute',
          top: '35%',
          left: '-15%',
          width: 260,
          height: 260,
          borderRadius: '50%',
          background: `radial-gradient(circle, ${palette.primary.main}12 0%, transparent 70%)`,
        }}
      />
      <Box
        sx={{
          pointerEvents: 'none',
          position: 'absolute',
          bottom: '-5%',
          right: '15%',
          width: 200,
          height: 200,
          borderRadius: '50%',
          background: `radial-gradient(circle, #38BDF822 0%, transparent 70%)`,
        }}
      />
    </>
  );
}

export function GradientBackground({ children, sx, ...rest }: BoxProps) {
  const theme = useTheme();
  const isDark = theme.palette.mode === 'dark';
  const bg = isDark
    ? `linear-gradient(180deg, ${theme.palette.background.default} 0%, #0C1222 100%)`
    : `linear-gradient(165deg, ${palette.gradientStart} 0%, ${palette.gradientMid} 38%, ${palette.backgroundDefault} 72%, #FFFFFF 100%)`;

  return (
    <Box
      sx={{
        position: 'relative',
        minHeight: '100%',
        background: bg,
        overflow: 'hidden',
        ...sx,
      }}
      {...rest}
    >
      {!isDark && <DecorativeBlobs />}
      <Box sx={{ position: 'relative', zIndex: 1, minHeight: '100%' }}>{children}</Box>
    </Box>
  );
}
