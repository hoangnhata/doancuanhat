import { Box, Chip, Stack, Typography, useMediaQuery, useTheme } from '@mui/material';
import {
  AutoGraphRounded,
  SavingsRounded,
  SmartToyRounded,
} from '@mui/icons-material';
import type { ReactNode } from 'react';
import { GradientBackground } from '@/components/common/GradientBackground';
import { RobotAvatar } from '@/components/robot';
import { palette } from '@/theme';

type Props = {
  title: string;
  subtitle: string;
  children: ReactNode;
  footer?: ReactNode;
  showDemoHint?: boolean;
};

const features = [
  { icon: <SmartToyRounded fontSize="small" />, label: 'Trợ lý AI tài chính' },
  { icon: <AutoGraphRounded fontSize="small" />, label: 'Dự báo chi tiêu' },
  { icon: <SavingsRounded fontSize="small" />, label: 'Theo dõi ngân sách' },
];

function BrandPanel() {
  return (
    <Box
      sx={{
        height: '100%',
        minHeight: { md: 560 },
        p: { xs: 3, md: 5 },
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'center',
        background: `linear-gradient(145deg, ${palette.primary.dark} 0%, ${palette.primary.main} 48%, ${palette.primary.light} 100%)`,
        color: '#fff',
        position: 'relative',
        overflow: 'hidden',
        borderRadius: { xs: '24px 24px 0 0', md: '28px 0 0 28px' },
      }}
    >
      <Box
        sx={{
          position: 'absolute',
          top: -80,
          right: -80,
          width: 240,
          height: 240,
          borderRadius: '50%',
          bgcolor: 'rgba(255,255,255,0.08)',
        }}
      />
      <Box
        sx={{
          position: 'absolute',
          bottom: -40,
          left: -40,
          width: 160,
          height: 160,
          borderRadius: '50%',
          bgcolor: 'rgba(255,255,255,0.06)',
        }}
      />

      <Stack spacing={2.5} sx={{ position: 'relative', zIndex: 1 }}>
        <Box
          sx={{
            alignSelf: 'flex-start',
            p: 1.25,
            borderRadius: 3,
            bgcolor: 'rgba(255,255,255,0.15)',
            backdropFilter: 'blur(8px)',
            border: '1px solid rgba(255,255,255,0.2)',
          }}
        >
          <RobotAvatar size={72} animated />
        </Box>

        <Box>
          <Typography variant="h3" fontWeight={800} letterSpacing="-0.03em" lineHeight={1.15}>
            Natta
          </Typography>
          <Typography sx={{ opacity: 0.92, fontWeight: 600, fontSize: '1.05rem' }}>
            Quản lý chi tiêu thông minh
          </Typography>
        </Box>

        <Typography sx={{ opacity: 0.88, maxWidth: 320, lineHeight: 1.65 }}>
          Ghi chép giao dịch, phân tích chi tiêu và nhận gợi ý từ AI — tất cả trong một ứng dụng gọn nhẹ.
        </Typography>

        <Stack spacing={1.25} sx={{ pt: 1 }}>
          {features.map((f) => (
            <Stack key={f.label} direction="row" alignItems="center" spacing={1.25}>
              <Box
                sx={{
                  width: 32,
                  height: 32,
                  borderRadius: 2,
                  display: 'grid',
                  placeItems: 'center',
                  bgcolor: 'rgba(255,255,255,0.18)',
                }}
              >
                {f.icon}
              </Box>
              <Typography fontWeight={600}>{f.label}</Typography>
            </Stack>
          ))}
        </Stack>
      </Stack>
    </Box>
  );
}

export function AuthShell({ title, subtitle, children, footer, showDemoHint }: Props) {
  const theme = useTheme();
  const isMd = useMediaQuery(theme.breakpoints.up('md'));

  return (
    <GradientBackground sx={{ minHeight: '100vh', width: '100%' }}>
      <Box
        sx={{
          minHeight: '100vh',
          width: '100%',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          py: { xs: 2, md: 4 },
          px: { xs: 2, sm: 3 },
          boxSizing: 'border-box',
        }}
      >
        <Box
          sx={{
            width: '100%',
            maxWidth: 980,
            mx: 'auto',
          }}
        >
          <Box
            sx={{
              display: 'grid',
              gridTemplateColumns: { xs: '1fr', md: '1fr 1fr' },
              borderRadius: { xs: 3, md: 3.5 },
              overflow: 'hidden',
              boxShadow: palette.shadowLift,
              border: `1px solid ${palette.outline}`,
              bgcolor: 'background.paper',
            }}
          >
            <BrandPanel />

            <Box
              sx={{
                p: { xs: 3, sm: 4, md: 5 },
                display: 'flex',
                flexDirection: 'column',
                justifyContent: 'center',
              }}
            >
              {!isMd && (
                <Stack direction="row" alignItems="center" spacing={1.5} mb={2}>
                  <RobotAvatar size={44} animated={false} />
                  <Box>
                    <Typography fontWeight={800} lineHeight={1.2}>
                      Natta
                    </Typography>
                    <Typography variant="caption" color="text.secondary">
                      Quản lý chi tiêu
                    </Typography>
                  </Box>
                </Stack>
              )}

              <Typography variant="h4" fontWeight={800} letterSpacing="-0.02em" gutterBottom>
                {title}
              </Typography>
              <Typography color="text.secondary" sx={{ mb: showDemoHint ? 1.5 : 2.5, lineHeight: 1.6 }}>
                {subtitle}
              </Typography>

              {showDemoHint && (
                <Chip
                  label="Demo AI: ai.demo@local.test / Demo@123456"
                  size="small"
                  sx={{
                    alignSelf: 'flex-start',
                    mb: 2,
                    fontWeight: 600,
                    bgcolor: `${palette.primary.main}12`,
                    color: palette.primary.dark,
                    border: `1px solid ${palette.primary.main}33`,
                  }}
                />
              )}

              <Box component="div">{children}</Box>

              {footer && (
                <Box textAlign="center" mt={2.5}>
                  {footer}
                </Box>
              )}
            </Box>
          </Box>
        </Box>
      </Box>
    </GradientBackground>
  );
}
