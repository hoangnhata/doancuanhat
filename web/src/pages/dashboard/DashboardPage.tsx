import {
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  CircularProgress,
  Grid,
  LinearProgress,
  Stack,
  TextField,
  ToggleButton,
  ToggleButtonGroup,
  Typography,
  useMediaQuery,
  useTheme,
} from '@mui/material';
import {
  ArrowDownwardRounded,
  ArrowUpwardRounded,
  EmojiEventsRounded,
  BarChartRounded,
} from '@mui/icons-material';
import { useQuery } from '@tanstack/react-query';
import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Cell,
  Legend,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
} from 'recharts';
import { GradientBackground } from '@/components/common/GradientBackground';
import { NattaAvatar } from '@/components/robot';
import { useAuth } from '@/contexts/AuthContext';
import { useSelectedWallet } from '@/contexts/SelectedWalletContext';
import { formatMoney } from '@/lib/format';
import * as statisticsService from '@/services/statisticsService';
import * as walletService from '@/services/walletService';
import { chartCategoryColor, palette } from '@/theme';

export function DashboardPage() {
  const theme = useTheme();
  const isMd = useMediaQuery(theme.breakpoints.up('md'));
  const navigate = useNavigate();
  const { user } = useAuth();
  const { selectedWalletId, setSelectedWalletId } = useSelectedWallet();

  const now = new Date();
  const [year, setYear] = useState(now.getFullYear());
  const [month, setMonth] = useState(now.getMonth() + 1);
  const [showExpense, setShowExpense] = useState(true);
  const monthStr = `${year}-${String(month).padStart(2, '0')}`;

  const { data: wallets = [], isLoading: walletsLoading } = useQuery({
    queryKey: ['wallets'],
    queryFn: walletService.fetchWallets,
  });

  useEffect(() => {
    if (!wallets.length) return;
    if (selectedWalletId == null) {
      const def = wallets.find((w) => w.isDefault) ?? wallets[0];
      setSelectedWalletId(def.id);
    }
  }, [wallets, selectedWalletId, setSelectedWalletId]);

  const walletId = selectedWalletId ?? undefined;

  const { data: expenseStats, isLoading: loadingExp } = useQuery({
    queryKey: ['stats', 'month', year, month, walletId, 'EXPENSE'],
    queryFn: () =>
      statisticsService.getStatsByMonth(year, month, 'EXPENSE', walletId),
    enabled: walletId != null,
  });

  const { data: incomeStats, isLoading: loadingInc } = useQuery({
    queryKey: ['stats', 'month', year, month, walletId, 'INCOME'],
    queryFn: () =>
      statisticsService.getStatsByMonth(year, month, 'INCOME', walletId),
    enabled: walletId != null,
  });

  const loading = walletsLoading || loadingExp || loadingInc || walletId == null;

  const totalIncome = incomeStats?.totalIncome ?? 0;
  const totalExpense = expenseStats?.totalExpense ?? 0;
  const balance = totalIncome - totalExpense;

  const chartData = useMemo(() => {
    const src = showExpense ? expenseStats?.byCategory : incomeStats?.byCategory;
    return (src ?? []).map((c) => ({
      name: c.categoryName,
      amount: c.amount,
    }));
  }, [showExpense, expenseStats, incomeStats]);

  const goal = user?.savingsGoalMonthly;
  const pct =
    goal && goal > 0 ? Math.min(1, Math.max(0, (balance > 0 ? balance : 0) / goal)) : 0;

  return (
    <GradientBackground>
      <Box sx={{ p: { xs: 2, md: 3 }, pb: 10, maxWidth: 900, mx: 'auto' }}>
        {isMd && (
          <Stack direction="row" spacing={2} justifyContent="flex-end" mb={2}>
            <Button
              variant="contained"
              startIcon={<EmojiEventsRounded />}
              onClick={() => navigate('/app/milestones')}
              sx={{
                borderRadius: 3,
                background: 'linear-gradient(90deg, #FFB347 0%, #FFCC70 100%)',
                color: 'white',
                '&:hover': { opacity: 0.95 },
              }}
            >
              Những cột mốc
            </Button>
            <Button
              variant="contained"
              startIcon={<BarChartRounded />}
              onClick={() => navigate('/app/analytics')}
              sx={{
                borderRadius: 3,
                background: 'linear-gradient(90deg, #4FC3F7 0%, #81D4FA 100%)',
                color: 'white',
                '&:hover': { opacity: 0.95 },
              }}
            >
              Phân tích thêm
            </Button>
          </Stack>
        )}

        <Stack alignItems="center" spacing={1.5} mb={3}>
          <Box
            sx={{
              p: 1.5,
              borderRadius: 4,
              bgcolor: 'background.paper',
              border: '1px solid',
              borderColor: 'divider',
              boxShadow: palette.shadowLift,
            }}
          >
            <NattaAvatar size={isMd ? 72 : 64} animated />
          </Box>
          <Chip
            label="Chào bạn! 👋"
            sx={{
              fontWeight: 700,
              px: 1.5,
              py: 2.5,
              borderRadius: 3,
              border: '1px solid',
              borderColor: 'divider',
              bgcolor: 'background.paper',
              boxShadow: palette.shadowSoft,
            }}
          />
        </Stack>

        <Typography variant="subtitle2" color="text.secondary" gutterBottom>
          Ví
        </Typography>
        <Stack
          direction="row"
          spacing={1.5}
          sx={{ overflowX: 'auto', pb: 1, mb: 2 }}
        >
          {wallets.map((w) => (
            <Card
              key={w.id}
              onClick={() => setSelectedWalletId(w.id)}
              sx={{
                minWidth: 180,
                cursor: 'pointer',
                border:
                  selectedWalletId === w.id
                    ? `2px solid ${palette.primary.main}`
                    : `1px solid ${palette.outline}`,
                boxShadow: selectedWalletId === w.id ? palette.shadowLift : undefined,
              }}
            >
              <CardContent>
                <Stack direction="row" alignItems="center" spacing={1} mb={1}>
                  <Typography fontWeight={700} noWrap flex={1}>
                    {w.name}
                  </Typography>
                  <Button
                    size="small"
                    onClick={(e) => {
                      e.stopPropagation();
                      navigate('/app/wallets');
                    }}
                  >
                    Sửa
                  </Button>
                </Stack>
                <Typography variant="h6" color="primary" fontWeight={800}>
                  {formatMoney(selectedWalletId === w.id ? balance : 0)}
                </Typography>
              </CardContent>
            </Card>
          ))}
          <Card
            onClick={() => navigate('/app/wallets')}
            sx={{
              minWidth: 120,
              cursor: 'pointer',
              bgcolor: 'action.hover',
              border: `1px dashed ${palette.textMuted}`,
            }}
          >
            <CardContent
              sx={{
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
                py: 3,
              }}
            >
              <Typography color="text.secondary" fontWeight={700}>
                + Ví mới
              </Typography>
            </CardContent>
          </Card>
        </Stack>

        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2} mb={2}>
          <TextField
            label="Tháng"
            type="month"
            value={monthStr}
            onChange={(e) => {
              const v = e.target.value;
              if (!v) return;
              const [y, m] = v.split('-').map(Number);
              setYear(y);
              setMonth(m);
            }}
            InputLabelProps={{ shrink: true }}
            fullWidth
          />
        </Stack>

        {goal != null && goal > 0 ? (
          <Card sx={{ mb: 3 }} onClick={() => navigate('/app/milestones')}>
            <CardContent>
              <Stack direction="row" alignItems="center" spacing={1} mb={1}>
                <EmojiEventsRounded color="primary" />
                <Typography fontWeight={700} flex={1}>
                  Mục tiêu tiết kiệm · Tháng {month}/{year}
                </Typography>
                <Typography fontWeight={800} color="primary">
                  {(pct * 100).toFixed(0)}%
                </Typography>
              </Stack>
              <LinearProgress
                variant="determinate"
                value={pct * 100}
                sx={{
                  height: 10,
                  borderRadius: 1,
                  mb: 1,
                  bgcolor: `${palette.textMuted}33`,
                  '& .MuiLinearProgress-bar': {
                    bgcolor: pct >= 1 ? palette.income : palette.primary.main,
                  },
                }}
              />
              <Typography variant="caption" color="text.secondary">
                {formatMoney(balance > 0 ? balance : 0)} / {formatMoney(goal)} · Chọn để xem cột mốc
              </Typography>
            </CardContent>
          </Card>
        ) : (
          <Card
            variant="outlined"
            sx={{ mb: 3, cursor: 'pointer' }}
            onClick={() => navigate('/app/milestones')}
          >
            <CardContent sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
              <EmojiEventsRounded color="primary" />
              <Typography variant="body2" color="text.secondary" flex={1}>
                Đặt mục tiêu tiết kiệm tháng để theo dõi ngay trên trang chủ
              </Typography>
            </CardContent>
          </Card>
        )}

        {loading ? (
          <Box display="flex" justifyContent="center" py={6}>
            <CircularProgress />
          </Box>
        ) : totalIncome === 0 && totalExpense === 0 ? (
          <Card sx={{ p: 4, textAlign: 'center' }}>
            <Typography gutterBottom>Chưa có giao dịch nào</Typography>
            <Button variant="contained" onClick={() => navigate('/app/transactions/add')}>
              Thêm giao dịch
            </Button>
          </Card>
        ) : (
          <>
            <Card
              sx={{
                mb: 2,
                background: (t) =>
                  t.palette.mode === 'dark'
                    ? `linear-gradient(135deg, ${palette.primary.main}33, ${t.palette.background.paper})`
                    : `linear-gradient(135deg, ${palette.primary.main}18, #fff)`,
                border: `1px solid ${palette.primary.main}44`,
                boxShadow: palette.shadowSoft,
              }}
            >
              <CardContent>
                <Typography color="text.secondary" fontWeight={600}>
                  Thay đổi ròng
                </Typography>
                <Typography variant="h4" fontWeight={800} color={balance >= 0 ? 'primary' : 'error'}>
                  {formatMoney(balance)}
                </Typography>
                <Grid container spacing={1.5} sx={{ mt: 1 }}>
                  <Grid item xs={6}>
                    <Card variant="outlined" sx={{ p: 2 }}>
                      <Stack direction="row" alignItems="center" spacing={0.5}>
                        <ArrowUpwardRounded sx={{ color: palette.expense, fontSize: 20 }} />
                        <Typography variant="caption" color="text.secondary">
                          Chi phí
                        </Typography>
                      </Stack>
                      <Typography fontWeight={800} color="error.main">
                        {formatMoney(totalExpense)}
                      </Typography>
                    </Card>
                  </Grid>
                  <Grid item xs={6}>
                    <Card variant="outlined" sx={{ p: 2 }}>
                      <Stack direction="row" alignItems="center" spacing={0.5}>
                        <ArrowDownwardRounded sx={{ color: palette.income, fontSize: 20 }} />
                        <Typography variant="caption" color="text.secondary">
                          Thu nhập
                        </Typography>
                      </Stack>
                      <Typography fontWeight={800} sx={{ color: palette.income }}>
                        {formatMoney(totalIncome)}
                      </Typography>
                    </Card>
                  </Grid>
                </Grid>
              </CardContent>
            </Card>

            <Stack direction="row" spacing={1} mb={2}>
              <ToggleButtonGroup
                fullWidth
                value={showExpense ? 'exp' : 'inc'}
                exclusive
                onChange={(_, v) => {
                  if (v) setShowExpense(v === 'exp');
                }}
              >
                <ToggleButton value="exp">Chi phí</ToggleButton>
                <ToggleButton value="inc">Thu nhập</ToggleButton>
              </ToggleButtonGroup>
            </Stack>

            <Card>
              <CardContent>
                <Typography fontWeight={700} gutterBottom>
                  {showExpense ? 'Chi tiêu theo danh mục' : 'Thu nhập theo danh mục'}
                </Typography>
                {chartData.length === 0 ? (
                  <Typography color="text.secondary" py={2}>
                    Chưa có dữ liệu danh mục trong kỳ này.
                  </Typography>
                ) : (
                  <>
                    <Box height={220}>
                      <ResponsiveContainer width="100%" height="100%">
                        <PieChart>
                          <Pie
                            data={chartData}
                            dataKey="amount"
                            nameKey="name"
                            cx="50%"
                            cy="50%"
                            innerRadius={50}
                            outerRadius={75}
                            paddingAngle={2}
                          >
                            {chartData.map((_, i) => (
                              <Cell key={i} fill={chartCategoryColor(i)} />
                            ))}
                          </Pie>
                          <Tooltip formatter={(v: number) => formatMoney(v)} />
                          <Legend />
                        </PieChart>
                      </ResponsiveContainer>
                    </Box>
                    <Stack spacing={1} mt={2}>
                      {chartData.map((row, i) => (
                        <Stack
                          key={row.name}
                          direction="row"
                          alignItems="center"
                          spacing={1}
                        >
                          <Box
                            width={12}
                            height={12}
                            borderRadius={1}
                            bgcolor={chartCategoryColor(i)}
                          />
                          <Typography flex={1}>{row.name}</Typography>
                          <Typography fontWeight={700}>{formatMoney(row.amount)}</Typography>
                        </Stack>
                      ))}
                    </Stack>
                  </>
                )}
              </CardContent>
            </Card>
          </>
        )}
      </Box>
    </GradientBackground>
  );
}
