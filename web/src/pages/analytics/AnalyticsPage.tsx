import {
  Alert,
  Box,
  Button,
  CircularProgress,
  Stack,
  ToggleButton,
  ToggleButtonGroup,
  Typography,
} from '@mui/material';
import { AnalyticsOutlined, PictureAsPdfRounded, TableChartRounded } from '@mui/icons-material';
import { useQuery } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { GradientBackground } from '@/components/common/GradientBackground';
import { PeriodFilterBar } from '@/components/common/PeriodFilterBar';
import { AnalyticsSummaryCard } from '@/components/analytics/AnalyticsSummaryCard';
import { CategoryBreakdownChart } from '@/components/analytics/CategoryBreakdownChart';
import { ChartCard } from '@/components/analytics/ChartCard';
import { DailyFlowChart } from '@/components/analytics/DailyFlowChart';
import { SectionLabel } from '@/components/dashboard/SectionLabel';
import * as statisticsService from '@/services/statisticsService';
import { downloadTransactionExport } from '@/services/exportService';
import { palette } from '@/theme';

export function AnalyticsPage() {
  const now = new Date();
  const [period, setPeriod] = useState<'month' | 'year'>('month');
  const [year, setYear] = useState(now.getFullYear());
  const [month, setMonth] = useState(now.getMonth() + 1);
  const [showExpense, setShowExpense] = useState(true);
  const [exporting, setExporting] = useState<'excel' | 'pdf' | null>(null);
  const [exportError, setExportError] = useState<string | null>(null);

  const periodLabel = period === 'month' ? `Tháng ${month}/${year}` : `Năm ${year}`;

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

  const { data: expenseStats, isLoading: loadingExp } = useQuery({
    queryKey: ['analytics', period, year, month, 'EXPENSE'],
    queryFn: () =>
      period === 'month'
        ? statisticsService.getStatsByMonth(year, month, 'EXPENSE')
        : statisticsService.getStatsByYear(year, 'EXPENSE'),
  });

  const { data: incomeStats, isLoading: loadingInc } = useQuery({
    queryKey: ['analytics', period, year, month, 'INCOME'],
    queryFn: () =>
      period === 'month'
        ? statisticsService.getStatsByMonth(year, month, 'INCOME')
        : statisticsService.getStatsByYear(year, 'INCOME'),
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

  const barData = useMemo(
    () =>
      daily.map((d) => ({
        day: d.date.slice(8, 10),
        Chi: d.expense,
        Thu: d.income,
      })),
    [daily],
  );

  const loading = loadingExp || loadingInc;

  return (
    <GradientBackground>
      <Box sx={{ p: { xs: 2, md: 3 }, pb: 10, maxWidth: 900, mx: 'auto' }}>
        <Stack direction="row" alignItems="flex-start" justifyContent="space-between" gap={2} mb={2}>
          <Box>
            <Stack direction="row" alignItems="center" spacing={1} mb={0.5}>
              <AnalyticsOutlined sx={{ color: palette.primary.main }} />
              <Typography variant="h5" fontWeight={800}>
                Phân tích
              </Typography>
            </Stack>
            <Typography variant="body2" color="text.secondary">
              Thống kê chi tiết theo kỳ, danh mục và ngày
            </Typography>
          </Box>
          <Stack direction="row" spacing={1} flexShrink={0}>
            <Button
              size="small"
              variant="outlined"
              startIcon={
                exporting === 'excel' ? <CircularProgress size={16} /> : <TableChartRounded />
              }
              disabled={exporting !== null}
              onClick={() => void handleExport('excel')}
              sx={{ borderRadius: 2 }}
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
              sx={{ borderRadius: 2 }}
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

        <PeriodFilterBar
          period={period}
          onPeriodChange={setPeriod}
          year={year}
          month={month}
          onMonthYearChange={(y, m) => {
            setYear(y);
            setMonth(m);
          }}
          onYearChange={setYear}
        />

        {loading ? (
          <Box display="flex" justifyContent="center" py={8}>
            <CircularProgress />
          </Box>
        ) : (
          <>
            <Box sx={{ mt: 2.5 }}>
              <AnalyticsSummaryCard
                periodLabel={periodLabel}
                balance={balance}
                totalIncome={totalIncome}
                totalExpense={totalExpense}
              />
            </Box>

            <SectionLabel>Phân bổ theo loại</SectionLabel>
            <ToggleButtonGroup
              fullWidth
              exclusive
              value={showExpense ? 'exp' : 'inc'}
              onChange={(_, v) => v && setShowExpense(v === 'exp')}
              sx={{ mb: 2 }}
            >
              <ToggleButton value="exp">Chi phí</ToggleButton>
              <ToggleButton value="inc">Thu nhập</ToggleButton>
            </ToggleButtonGroup>

            <ChartCard
              subtitle="DANH MỤC"
              title={showExpense ? 'Chi tiêu theo danh mục' : 'Thu nhập theo danh mục'}
            >
              <CategoryBreakdownChart data={chartData} isExpense={showExpense} />
            </ChartCard>

            {period === 'month' && barData.length > 0 && (
              <ChartCard subtitle="XU HƯỚNG" title="Thu / chi theo ngày trong tháng">
                <DailyFlowChart data={barData} />
              </ChartCard>
            )}
          </>
        )}
      </Box>
    </GradientBackground>
  );
}
