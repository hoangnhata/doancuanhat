import { Box, Card, CardActionArea, CardContent, Stack, Typography } from '@mui/material';
import { AutoGraphRounded, ChevronRightRounded } from '@mui/icons-material';
import { palette } from '@/theme';

type Props = {
  onClick: () => void;
};

export function ForecastPromoCard({ onClick }: Props) {
  return (
    <Card
      sx={{
        mb: 2,
        border: `1px solid ${palette.primary.main}33`,
        background: `linear-gradient(90deg, ${palette.primary.main}10 0%, #FFFFFF 100%)`,
        boxShadow: palette.shadowSoft,
      }}
    >
      <CardActionArea onClick={onClick}>
        <CardContent sx={{ py: 2 }}>
          <Stack direction="row" alignItems="center" spacing={2}>
            <Box
              sx={{
                width: 48,
                height: 48,
                borderRadius: 2.5,
                display: 'grid',
                placeItems: 'center',
                background: `linear-gradient(135deg, ${palette.primary.main}, ${palette.primary.light})`,
                color: '#fff',
                boxShadow: '0 6px 16px rgba(2, 136, 209, 0.35)',
              }}
            >
              <AutoGraphRounded />
            </Box>
            <Box flex={1}>
              <Typography fontWeight={800} fontSize={16}>
                Dự báo chi tiêu 7 ngày tới
              </Typography>
              <Typography variant="body2" color="text.secondary" sx={{ mt: 0.25 }}>
                AI phân tích lịch sử chi tiêu và gợi ý xu hướng tuần tới
              </Typography>
            </Box>
            <ChevronRightRounded sx={{ color: palette.textMuted }} />
          </Stack>
        </CardContent>
      </CardActionArea>
    </Card>
  );
}
