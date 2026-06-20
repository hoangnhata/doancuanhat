import { Box, Grid, Stack, Typography, useMediaQuery, useTheme } from '@mui/material';
import { AutoGraphRounded, BarChartRounded, SavingsRounded } from '@mui/icons-material';
import { NattaAvatar } from '@/components/robot';
import { palette } from '@/theme';

function timeGreeting(): string {
  const h = new Date().getHours();
  if (h < 12) return 'Chào buổi sáng';
  if (h < 18) return 'Chào buổi chiều';
  return 'Chào buổi tối';
}

function displayName(fullName?: string | null): string {
  if (!fullName?.trim()) return 'bạn';
  const parts = fullName.trim().split(/\s+/);
  return parts[parts.length - 1] ?? fullName;
}

type ActionTileProps = {
  label: string;
  icon: React.ReactNode;
  onClick: () => void;
  highlighted?: boolean;
};

function HeroActionTile({ label, icon, onClick, highlighted }: ActionTileProps) {
  return (
    <Box
      onClick={onClick}
      role="button"
      tabIndex={0}
      onKeyDown={(e) => {
        if (e.key === 'Enter' || e.key === ' ') onClick();
      }}
      sx={{
        py: 1.5,
        px: 1,
        borderRadius: 2.5,
        textAlign: 'center',
        cursor: 'pointer',
        userSelect: 'none',
        transition: 'transform 0.15s ease, background 0.15s ease',
        bgcolor: highlighted ? '#fff' : 'rgba(255,255,255,0.16)',
        border: highlighted ? 'none' : '1px solid rgba(255,255,255,0.22)',
        color: highlighted ? palette.primary.dark : '#fff',
        '&:hover': {
          transform: 'translateY(-1px)',
          bgcolor: highlighted ? 'rgba(255,255,255,0.95)' : 'rgba(255,255,255,0.24)',
        },
      }}
    >
      <Box sx={{ display: 'grid', placeItems: 'center', mb: 0.75, '& svg': { fontSize: 24 } }}>
        {icon}
      </Box>
      <Typography variant="caption" fontWeight={800} lineHeight={1.2} fontSize={12}>
        {label}
      </Typography>
    </Box>
  );
}

type Props = {
  userName?: string | null;
  periodLabel: string;
  onSavingGoals: () => void;
  onAnalytics: () => void;
  onForecast: () => void;
};

export function DashboardHero({
  userName,
  periodLabel,
  onSavingGoals,
  onAnalytics,
  onForecast,
}: Props) {
  const theme = useTheme();
  const isMd = useMediaQuery(theme.breakpoints.up('md'));

  return (
    <Box
      sx={{
        mb: 3,
        borderRadius: 4,
        position: 'relative',
        overflow: 'hidden',
        background: `linear-gradient(135deg, ${palette.primary.dark} 0%, ${palette.primary.main} 55%, ${palette.primary.light} 100%)`,
        color: '#fff',
        boxShadow: '0 12px 40px rgba(2, 136, 209, 0.28)',
      }}
    >
      <Box
        sx={{
          position: 'absolute',
          top: -60,
          right: -40,
          width: 180,
          height: 180,
          borderRadius: '50%',
          bgcolor: 'rgba(255,255,255,0.1)',
        }}
      />
      <Box
        sx={{
          position: 'absolute',
          bottom: -40,
          left: -30,
          width: 120,
          height: 120,
          borderRadius: '50%',
          bgcolor: 'rgba(255,255,255,0.06)',
        }}
      />

      <Box sx={{ position: 'relative', zIndex: 1, p: { xs: 2.5, sm: 3 } }}>
        <Stack direction="row" spacing={2.5} alignItems="center" mb={2.25}>
          <Box
            sx={{
              width: { xs: 84, sm: 92 },
              height: { xs: 84, sm: 92 },
              borderRadius: '50%',
              flexShrink: 0,
              display: 'grid',
              placeItems: 'center',
              bgcolor: 'rgba(255,255,255,0.22)',
              border: '2px solid rgba(255,255,255,0.38)',
              boxShadow: '0 4px 16px rgba(0,0,0,0.12)',
            }}
          >
            <Box
              sx={{
                width: { xs: 72, sm: 78 },
                height: { xs: 72, sm: 78 },
                borderRadius: '50%',
                bgcolor: '#fff',
                display: 'grid',
                placeItems: 'center',
              }}
            >
              <NattaAvatar size={isMd ? 68 : 62} animated />
            </Box>
          </Box>
          <Box minWidth={0} flex={1}>
            <Typography variant="caption" sx={{ opacity: 0.85, fontWeight: 800, letterSpacing: 1.2 }}>
              TRANG CHỦ
            </Typography>
            <Typography
              variant="h5"
              fontWeight={800}
              lineHeight={1.2}
              sx={{ fontSize: { xs: '1.2rem', sm: '1.55rem' }, mt: 0.25 }}
            >
              {timeGreeting()}, {displayName(userName)}!
            </Typography>
            <Typography
              variant="body2"
              sx={{ opacity: 0.9, mt: 0.5 }}
              noWrap
            >
              Tổng quan · {periodLabel}
            </Typography>
          </Box>
        </Stack>

        <Box sx={{ height: 1, bgcolor: 'rgba(255,255,255,0.18)', mb: 1.75 }} />

        <Grid container spacing={1}>
          <Grid item xs={4}>
            <HeroActionTile
              label="Tiết kiệm"
              icon={<SavingsRounded />}
              onClick={onSavingGoals}
            />
          </Grid>
          <Grid item xs={4}>
            <HeroActionTile
              label="Phân tích"
              icon={<BarChartRounded />}
              onClick={onAnalytics}
            />
          </Grid>
          <Grid item xs={4}>
            <HeroActionTile
              label="Dự báo"
              icon={<AutoGraphRounded />}
              onClick={onForecast}
              highlighted
            />
          </Grid>
        </Grid>
      </Box>
    </Box>
  );
}
