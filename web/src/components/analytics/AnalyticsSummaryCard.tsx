import { Box, Card, CardContent, Grid, Stack, Typography } from '@mui/material';
import {
  AccountBalanceWalletRounded,
  ArrowDownwardRounded,
  ArrowUpwardRounded,
} from '@mui/icons-material';
import { formatMoney } from '@/lib/format';
import { palette } from '@/theme';

type Props = {
  periodLabel: string;
  balance: number;
  totalIncome: number;
  totalExpense: number;
};

export function AnalyticsSummaryCard({
  periodLabel,
  balance,
  totalIncome,
  totalExpense,
}: Props) {
  const positive = balance >= 0;

  return (
    <Card
      sx={{
        mb: 2,
        borderRadius: 4,
        overflow: 'hidden',
        border: `1px solid ${palette.primary.main}33`,
        boxShadow: palette.shadowLift,
        background: `linear-gradient(160deg, ${palette.primary.main}10 0%, #FFFFFF 50%, ${palette.surface} 100%)`,
      }}
    >
      <CardContent sx={{ p: { xs: 2.5, sm: 3 } }}>
        <Stack direction="row" alignItems="center" spacing={1} mb={0.5}>
          <AccountBalanceWalletRounded sx={{ color: palette.primary.main, fontSize: 20 }} />
          <Typography color="text.secondary" fontWeight={700} fontSize={13}>
            Tổng quan kỳ · {periodLabel}
          </Typography>
        </Stack>
        <Typography
          variant="h4"
          fontWeight={800}
          letterSpacing="-0.03em"
          color={positive ? 'primary.main' : 'error.main'}
          sx={{ fontSize: { xs: '1.5rem', sm: '2rem' } }}
        >
          {formatMoney(balance)}
        </Typography>
        <Typography variant="caption" color="text.secondary" fontWeight={600}>
          Chênh lệch thu − chi
        </Typography>

        <Grid container spacing={1.5} sx={{ mt: 2 }}>
          <Grid item xs={6}>
            <Box
              sx={{
                p: 2,
                borderRadius: 3,
                bgcolor: `${palette.expense}0D`,
                border: `1px solid ${palette.expense}22`,
              }}
            >
              <Stack direction="row" alignItems="center" spacing={0.75} mb={0.75}>
                <ArrowUpwardRounded sx={{ color: palette.expense, fontSize: 18 }} />
                <Typography variant="caption" fontWeight={700} color="text.secondary">
                  Tổng chi
                </Typography>
              </Stack>
              <Typography fontWeight={800} color="error.main" fontSize={16}>
                {formatMoney(totalExpense)}
              </Typography>
            </Box>
          </Grid>
          <Grid item xs={6}>
            <Box
              sx={{
                p: 2,
                borderRadius: 3,
                bgcolor: `${palette.income}0D`,
                border: `1px solid ${palette.income}33`,
              }}
            >
              <Stack direction="row" alignItems="center" spacing={0.75} mb={0.75}>
                <ArrowDownwardRounded sx={{ color: palette.income, fontSize: 18 }} />
                <Typography variant="caption" fontWeight={700} color="text.secondary">
                  Tổng thu
                </Typography>
              </Stack>
              <Typography fontWeight={800} sx={{ color: palette.income, fontSize: 16 }}>
                {formatMoney(totalIncome)}
              </Typography>
            </Box>
          </Grid>
        </Grid>
      </CardContent>
    </Card>
  );
}
