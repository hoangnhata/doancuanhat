import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  CircularProgress,
  Stack,
  TextField,
  ToggleButton,
  ToggleButtonGroup,
  Typography,
} from '@mui/material';
import { PictureAsPdfRounded, TableChartRounded } from '@mui/icons-material';
import { useQuery } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Legend,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import { GradientBackground } from '@/components/common/GradientBackground';
import { formatMoney } from '@/lib/format';
import * as statisticsService from '@/services/statisticsService';
import { downloadTransactionExport } from '@/services/exportService';
import { chartCategoryColor, palette } from '@/theme';

export function AnalyticsPage() {
  const now = new Date();
  const [period, setPeriod] = useState<'month' | 'year'>('month');
  const [year, setYear] = useState(now.getFullYear());
  const [month, setMonth] = useState(now.getMonth() + 1);
  const [showExpense, setShowExpense] = useState(true);
  const [exporting, setExporting] = useState<'excel' | 'pdf' | null>(null);
  const [exportError, setExportError] = useState<string | null>(null);

  const monthStr = `${year}-${String(month).padStart(2, '0')}`;

  const exportRange = useMemo(() => {
    if (period === 'month') {
      const start = `${year}-${String(month).padStart(2, '0')}-01`;
      const last = new Date(year, month, 0).getDate();
      const end = `${year}-${String(month).padStart(2, '0')}-${String(last).padStart(2, '0')}`;
      return { start, end };
    }
    return { start: `${year}-01-01`, end: `${year}-12-31` };
  }, [period, year, month]);

  async function handleExport(format: 'excel' | 'pdf') {
    setExportError(null);
    setExporting(format);
    try {
      await downloadTransactionExport(format, exportRange.start, exportRange.end);
    } catch (e) {
      setExportError(e instanceof Error ? e.message : 'Xuất thất bại');
    } finally {
      setExporting(null);
    }
  }

  const { data: stats } = useQuery({
    queryKey: ['analytics', period, year, month, showExpense],
    queryFn: () =>
      period === 'month'
        ? statisticsService.getStatsByMonth(
            year,
            month,
            showExpense ? 'EXPENSE' : 'INCOME',
          )
        : statisticsService.getStatsByYear(
            year,
            showExpense ? 'EXPENSE' : 'INCOME',
          ),
  });

  const dailyRange = useMemo(() => {
    if (period !== 'month') return { start: '', end: '' };
    const start = `${year}-${String(month).padStart(2, '0')}-01`;
    const last = new Date(year, month, 0).getDate();
    const end = `${year}-${String(month).padStart(2, '0')}-${String(last).padStart(2, '0')}`;
    return { start, end };
  }, [period, year, month]);

  const { data: daily = [] } = useQuery({
    queryKey: ['daily', dailyRange.start, dailyRange.end],
    queryFn: () =>
      statisticsService.getDailyBreakdown(dailyRange.start, dailyRange.end),
    enabled: period === 'month' && !!dailyRange.start,
  });

  const chartData = useMemo(
    () =>
      (stats?.byCategory ?? []).map((c) => ({
        name: c.categoryName,
        amount: c.amount,
      })),
    [stats],
  );

  const barData = useMemo(
    () =>
      daily.map((d) => ({
        day: d.date.slice(8, 10),
        Chi: d.expense,
        Thu: d.income,
      })),
    [daily],
  );

  return (
    <GradientBackground>
      <Box sx={{ p: 2, pb: 10, maxWidth: 900, mx: 'auto' }}>
        <Stack direction="row" alignItems="center" justifyContent="space-between" gap={2} mb={1}>
          <Typography variant="h6" fontWeight={800}>
            Phân tích
          </Typography>
          <Stack direction="row" spacing={1} flexShrink={0}>
            <Button
              size="small"
              variant="outlined"
              startIcon={
                exporting === 'excel' ? <CircularProgress size={16} /> : <TableChartRounded />
              }
              disabled={exporting !== null}
              onClick={() => void handleExport('excel')}
            >
              Excel
            </Button>
            <Button
              size="small"
              variant="outlined"
              startIcon={
                exporting === 'pdf' ? <CircularProgress size={16} /> : <PictureAsPdfRounded />
              }
              disabled={exporting !== null}
              onClick={() => void handleExport('pdf')}
            >
              PDF
            </Button>
          </Stack>
        </Stack>

        {exportError && (
          <Alert severity="error" sx={{ mb: 2 }} onClose={() => setExportError(null)}>
            {exportError}
          </Alert>
        )}

        <ToggleButtonGroup
          exclusive
          value={period}
          onChange={(_, v) => v && setPeriod(v)}
          sx={{ mb: 2 }}
        >
          <ToggleButton value="month">Tháng</ToggleButton>
          <ToggleButton value="year">Năm</ToggleButton>
        </ToggleButtonGroup>

        {period === 'month' ? (
          <TextField
            type="month"
            label="Kỳ"
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
            sx={{ mb: 2 }}
          />
        ) : (
          <TextField
            type="number"
            label="Năm"
            value={year}
            onChange={(e) => setYear(Number(e.target.value))}
            fullWidth
            sx={{ mb: 2 }}
          />
        )}

        <ToggleButtonGroup
          exclusive
          value={showExpense ? 'exp' : 'inc'}
          onChange={(_, v) => v && setShowExpense(v === 'exp')}
          sx={{ mb: 2 }}
        >
          <ToggleButton value="exp">Chi phí</ToggleButton>
          <ToggleButton value="inc">Thu nhập</ToggleButton>
        </ToggleButtonGroup>

        {stats && (
          <Card sx={{ mb: 2 }} elevation={2}>
            <CardContent>
              <Typography color="text.secondary">Cân đối kỳ</Typography>
              <Typography variant="h5" fontWeight={800} color="primary">
                {formatMoney(stats.balance)}
              </Typography>
              <Stack direction="row" spacing={2} mt={1}>
                <Typography color="error.main" fontWeight={700}>
                  Chi: {formatMoney(stats.totalExpense)}
                </Typography>
                <Typography sx={{ color: palette.income }} fontWeight={700}>
                  Thu: {formatMoney(stats.totalIncome)}
                </Typography>
              </Stack>
            </CardContent>
          </Card>
        )}

        <Card sx={{ mb: 2 }} elevation={2}>
          <CardContent>
            <Typography fontWeight={700} gutterBottom>
              {showExpense ? 'Chi theo danh mục' : 'Thu theo danh mục'}
            </Typography>
            {chartData.length === 0 ? (
              <Typography color="text.secondary">Chưa có dữ liệu</Typography>
            ) : (
              <Box height={260}>
                <ResponsiveContainer>
                  <PieChart>
                    <Pie
                      data={chartData}
                      dataKey="amount"
                      nameKey="name"
                      innerRadius={45}
                      outerRadius={80}
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
            )}
          </CardContent>
        </Card>

        {period === 'month' && barData.length > 0 && (
          <Card elevation={2}>
            <CardContent>
              <Typography fontWeight={700} gutterBottom>
                Thu / chi theo ngày
              </Typography>
              <Box height={280}>
                <ResponsiveContainer>
                  <BarChart data={barData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="day" />
                    <YAxis />
                    <Tooltip formatter={(v: number) => formatMoney(v)} />
                    <Bar dataKey="Chi" fill={palette.expense} />
                    <Bar dataKey="Thu" fill={palette.income} />
                  </BarChart>
                </ResponsiveContainer>
              </Box>
            </CardContent>
          </Card>
        )}
      </Box>
    </GradientBackground>
  );
}
