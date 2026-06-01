import { useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  CircularProgress,
  Collapse,
  Divider,
  LinearProgress,
  Stack,
  Typography,
} from '@mui/material';
import {
  AutoGraphRounded,
  ExpandLess,
  ExpandMore,
  RefreshRounded,
  SavingsOutlined,
  TrendingDownRounded,
  TrendingUpRounded,
  WarningAmberRounded,
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { addDays, format, isValid, parseISO } from 'date-fns';
import { vi } from 'date-fns/locale';
import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import { formatMoneyFull } from '@/lib/format';
import type { ForecastBudgetAlert, ForecastInsight, SpendingForecast } from '@/types/models';
import { palette } from '@/theme';

/* ------------------------------------------------------------------ */
/* Types                                                                */
/* ------------------------------------------------------------------ */
type Props = {
  loading: boolean;
  error: string | null;
  forecast: SpendingForecast | null;
  onRun: () => void;
  walletLabel?: string;
};

/* ------------------------------------------------------------------ */
/* Helpers                                                              */
/* ------------------------------------------------------------------ */
function buildRows(forecast: SpendingForecast) {
  let base: Date;
  try {
    base = parseISO(forecast.lastObservationDate);
    if (!isValid(base)) throw new Error('invalid');
  } catch {
    base = new Date();
  }

  const amounts = forecast.predictedNextDaysVnd;
  const total = amounts.reduce((a, b) => a + b, 0);
  const avg = amounts.length ? total / amounts.length : 0;
  const maxV = Math.max(...amounts, 1);
  const minV = amounts.length ? Math.min(...amounts) : 0;
  const maxIdx = amounts.indexOf(maxV);

  const rows = amounts.map((amount, i) => {
    const d = addDays(base, i + 1);
    return {
      amount,
      dayKey: format(d, 'dd/MM', { locale: vi }),
      weekday: format(d, 'EEEE', { locale: vi }),
      fullLabel: format(d, 'EEEE, dd/MM/yyyy', { locale: vi }),
      idx: i,
    };
  });

  const chartData = amounts.map((amount, i) => {
    const d = addDays(base, i + 1);
    return { amount, label: format(d, 'dd/MM', { locale: vi }), idx: i + 1 };
  });

  return { rows, chartData, total, avg, maxV, minV, maxIdx, base };
}

function severityColor(sev: ForecastBudgetAlert['severity']) {
  if (sev === 'OVER') return palette.expense;
  if (sev === 'WARN') return '#F59E0B';
  return palette.textMuted;
}

function levelColor(level: ForecastInsight['level']) {
  if (level === 'ALERT') return palette.expense;
  if (level === 'WATCH') return '#F59E0B';
  return palette.primary.main;
}

/** Nhãn nhẹ, cùng tone với các thẻ trên trang chủ (không dùng từ quá “báo động”). */
function levelLabel(level: ForecastInsight['level']) {
  if (level === 'ALERT') return 'Cần lưu ý';
  if (level === 'WATCH') return 'Nên theo dõi';
  return 'Bình thường';
}

/* ------------------------------------------------------------------ */
/* Zone 1 — How much will I spend?                                     */
/* ------------------------------------------------------------------ */
function SpendZone({ insight, total }: { insight: ForecastInsight | undefined; total: number }) {
  const c = insight ? levelColor(insight.level) : palette.primary.main;
  const pace = insight?.paceVsBaselinePercent;

  return (
    <Box
      sx={{
        p: 2,
        mb: 2,
        borderRadius: 2.5,
        background:
          `linear-gradient(135deg, ${c}10 0%, ${c}04 100%)`,
        border: `1px solid ${c}35`,
      }}
    >
      <Stack direction="row" alignItems="flex-start" justifyContent="space-between" flexWrap="wrap" gap={1}>
        <Box>
          <Typography variant="body2" color="text.secondary" fontWeight={600}>
            Ước tính 7 ngày tới
          </Typography>
          <Typography variant="h4" fontWeight={900} sx={{ color: c, lineHeight: 1.1, mt: 0.25 }}>
            {formatMoneyFull(insight?.totalNext7DaysVnd ?? total)}
          </Typography>
          <Typography variant="caption" color="text.secondary" fontWeight={600}>
            ~ {formatMoneyFull(insight?.avgPerDayVnd ?? Math.round(total / 7))} / ngày
          </Typography>
        </Box>

        <Stack spacing={0.75} alignItems="flex-end">
          {insight && (
            <Chip
              size="small"
              label={levelLabel(insight.level)}
              icon={
                insight.level === 'ALERT' ? (
                  <WarningAmberRounded style={{ fontSize: 14 }} />
                ) : insight.level === 'WATCH' ? (
                  <TrendingUpRounded style={{ fontSize: 14 }} />
                ) : (
                  <TrendingDownRounded style={{ fontSize: 14 }} />
                )
              }
              sx={{
                fontWeight: 800,
                bgcolor: `${c}18`,
                color: c,
                border: `1px solid ${c}44`,
                '& .MuiChip-icon': { color: c },
              }}
            />
          )}
          {pace != null && (
            <Typography variant="caption" color="text.secondary" fontWeight={600} textAlign="right">
              {pace > 0 ? '+' : ''}
              {pace}% so với mức trung bình gần đây
            </Typography>
          )}
          {insight?.projectedMonthFloorVnd != null && (
            <Typography variant="caption" color="text.secondary" textAlign="right">
              Tháng này (dự kiến tối thiểu):{' '}
              <strong>{formatMoneyFull(insight.projectedMonthFloorVnd)}</strong>
            </Typography>
          )}
        </Stack>
      </Stack>

      {insight?.headlineVi && (
        <Typography
          variant="body2"
          sx={{ mt: 1.5, lineHeight: 1.6, color: 'text.primary', fontWeight: 600 }}
        >
          {insight.headlineVi}
        </Typography>
      )}
      <Typography variant="caption" color="text.disabled" sx={{ display: 'block', mt: 1.25 }}>
        Dự báo dựa trên lịch sử chi — chỉ mang tính gợi ý.
      </Typography>
    </Box>
  );
}

/* ------------------------------------------------------------------ */
/* Zone 2 — Budget status                                              */
/* ------------------------------------------------------------------ */
function BudgetZone({
  alerts,
  onSetupBudget,
}: {
  alerts: ForecastBudgetAlert[];
  onSetupBudget: () => void;
}) {
  const hasIssue = alerts.length > 0 && alerts.some((a) => a.severity !== 'OK');

  if (!alerts.length) {
    return (
      <Box
        sx={{
          mb: 2,
          p: 2,
          borderRadius: 2.5,
          border: `1px dashed ${palette.outline}`,
          bgcolor: 'action.hover',
        }}
      >
        <Stack direction="row" spacing={1.25} alignItems="flex-start">
          <SavingsOutlined sx={{ fontSize: 20, color: 'text.secondary', mt: 0.25 }} />
          <Box flex={1}>
            <Typography variant="subtitle2" fontWeight={800} gutterBottom>
              So với ngân sách đã đặt
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ lineHeight: 1.55, mb: 1.5 }}>
              Chưa có ngân sách theo danh mục còn hiệu lực trong tháng này. Thêm ngân sách để so sánh mức đã chi với hạn mức.
            </Typography>
            <Button variant="outlined" size="small" startIcon={<SavingsOutlined />} onClick={onSetupBudget} sx={{ fontWeight: 700, borderRadius: 2 }}>
              Đặt ngân sách
            </Button>
          </Box>
        </Stack>
      </Box>
    );
  }

  return (
    <Box sx={{ mb: 2 }}>
      <Typography
        variant="subtitle2"
        fontWeight={800}
        gutterBottom
        sx={{ display: 'flex', alignItems: 'center', gap: 0.75 }}
      >
        <SavingsOutlined sx={{ fontSize: 16 }} />
        So với ngân sách đã đặt
        {hasIssue && (
          <Chip
            size="small"
            label="Có mục cần xem"
            color="warning"
            sx={{ fontWeight: 800, fontSize: 10, height: 20, ml: 0.5 }}
          />
        )}
      </Typography>
      <Stack spacing={1}>
        {alerts.slice(0, 6).map((a) => {
          const c = severityColor(a.severity);
          const pct = Math.min(a.percentUsed, 100);
          return (
            <Box
              key={a.categoryName}
              sx={{
                p: 1.5,
                borderRadius: 2,
                border: `1px solid ${c}44`,
                bgcolor: a.severity !== 'OK' ? `${c}08` : 'background.paper',
              }}
            >
              <Stack direction="row" justifyContent="space-between" alignItems="center" mb={0.75}>
                <Stack direction="row" alignItems="center" spacing={0.75}>
                  {a.severity === 'OVER' && <WarningAmberRounded sx={{ fontSize: 14, color: c }} />}
                  <Typography variant="body2" fontWeight={700}>
                    {a.categoryName}
                  </Typography>
                </Stack>
                <Stack direction="row" spacing={1} alignItems="center">
                  <Typography variant="caption" color="text.secondary">
                    {formatMoneyFull(a.spentVnd)} / {formatMoneyFull(a.budgetAmountVnd)}
                  </Typography>
                  <Chip
                    size="small"
                    label={
                      a.severity === 'OVER'
                        ? `Vượt ${Math.abs(a.remainingVnd) >= 1000 ? formatMoneyFull(Math.abs(a.remainingVnd)) : `${a.percentUsed}%`}`
                        : `${a.percentUsed}%`
                    }
                    sx={{
                      fontWeight: 800,
                      bgcolor: `${c}18`,
                      color: c,
                      height: 20,
                      fontSize: 10,
                    }}
                  />
                </Stack>
              </Stack>
              <LinearProgress
                variant="determinate"
                value={pct}
                sx={{
                  height: 5,
                  borderRadius: 3,
                  bgcolor: `${c}18`,
                  '& .MuiLinearProgress-bar': {
                    bgcolor: c,
                    borderRadius: 3,
                  },
                }}
              />
              {a.severity === 'OVER' && (
                <Typography variant="caption" sx={{ color: c, fontWeight: 700, mt: 0.5, display: 'block' }}>
                  Còn lại: -{formatMoneyFull(Math.abs(a.remainingVnd))} (vượt ngân sách)
                </Typography>
              )}
              {a.severity === 'WARN' && (
                <Typography variant="caption" color="text.secondary" sx={{ mt: 0.5, display: 'block' }}>
                  Còn lại: {formatMoneyFull(a.remainingVnd)}
                </Typography>
              )}
            </Box>
          );
        })}
      </Stack>
    </Box>
  );
}

/* ------------------------------------------------------------------ */
/* Zone 3 — Actions                                                    */
/* ------------------------------------------------------------------ */
function ActionZone({
  tips,
  level,
  onBudget,
}: {
  tips: string[];
  level: ForecastInsight['level'];
  onBudget: () => void;
}) {
  if (!tips.length) return null;
  const c = levelColor(level);

  return (
    <Box sx={{ mb: 1 }}>
      <Divider sx={{ mb: 1.5 }} />
      <Typography variant="subtitle2" fontWeight={800} gutterBottom>
        Gợi ý cho bạn
      </Typography>
      <Stack component="ul" sx={{ m: 0, pl: 2.5, mb: 1.5, color: 'text.secondary', fontSize: 13.5, lineHeight: 1.75 }}>
        {tips.map((t) => (
          <li key={t.slice(0, 40)}>{t}</li>
        ))}
      </Stack>
      <Button
        variant={level === 'ALERT' ? 'contained' : 'outlined'}
        startIcon={<SavingsOutlined />}
        onClick={onBudget}
        sx={{
          borderRadius: 2,
          fontWeight: 700,
          ...(level === 'ALERT'
            ? { bgcolor: c, '&:hover': { bgcolor: c }, boxShadow: `0 4px 14px ${c}44` }
            : { borderColor: `${c}80`, color: c }),
        }}
      >
        {level === 'ALERT' ? 'Chỉnh ngân sách' : 'Mở Ngân sách'}
      </Button>
    </Box>
  );
}

/* ------------------------------------------------------------------ */
/* Chart + detail rows                                                 */
/* ------------------------------------------------------------------ */
function ForecastDetail({ meta }: { meta: ReturnType<typeof buildRows> }) {
  const [detailOpen, setDetailOpen] = useState(false);

  return (
    <>
      {/* Đặt trước biểu đồ để luôn thấy (tránh bị khuất dưới fold) */}
      <Box
        onClick={() => setDetailOpen((o) => !o)}
        role="button"
        aria-expanded={detailOpen}
        aria-label={detailOpen ? 'Thu gọn chi tiết từng ngày' : 'Mở chi tiết từng ngày'}
        tabIndex={0}
        onKeyDown={(e) => {
          if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault();
            setDetailOpen((o) => !o);
          }
        }}
        sx={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: 1,
          cursor: 'pointer',
          borderRadius: 1,
          py: 0.75,
          px: 0.5,
          mx: -0.5,
          mb: 1,
          '&:hover': { bgcolor: 'action.hover' },
        }}
      >
        <Typography variant="subtitle2" fontWeight={700} color="text.secondary">
          Chi tiết từng ngày (dự báo)
        </Typography>
        {detailOpen ? <ExpandLess color="action" fontSize="small" /> : <ExpandMore color="action" fontSize="small" />}
      </Box>
      <Collapse in={detailOpen} timeout="auto" unmountOnExit>
        <Stack spacing={0.5} sx={{ mb: 2 }}>
          {meta.rows.map((row) => {
            const pct = meta.maxV > 0 ? (row.amount / meta.maxV) * 100 : 0;
            return (
              <Box
                key={row.idx}
                sx={{
                  py: 1.25,
                  px: 1.5,
                  borderRadius: 1.5,
                  border: `1px solid ${palette.outline}55`,
                  bgcolor: 'background.paper',
                }}
              >
                <Stack direction="row" justifyContent="space-between" alignItems="center" mb={0.75}>
                  <Box>
                    <Typography variant="caption" color="text.disabled" display="block" sx={{ textTransform: 'capitalize' }}>
                      {row.weekday}
                    </Typography>
                    <Typography variant="body2" fontWeight={700}>{row.fullLabel}</Typography>
                  </Box>
                  <Typography variant="body1" fontWeight={800} color="primary.main" sx={{ whiteSpace: 'nowrap' }}>
                    {formatMoneyFull(row.amount)}
                  </Typography>
                </Stack>
                <LinearProgress
                  variant="determinate"
                  value={pct}
                  sx={{
                    height: 4,
                    borderRadius: 2,
                    bgcolor: `${palette.primary.main}14`,
                    '& .MuiLinearProgress-bar': { borderRadius: 2, bgcolor: palette.primary.main },
                  }}
                />
              </Box>
            );
          })}
        </Stack>
      </Collapse>

      <Box sx={{ width: '100%', height: 190, mb: 2 }}>
        <ResponsiveContainer>
          <AreaChart data={meta.chartData} margin={{ top: 8, right: 8, left: 0, bottom: 0 }}>
            <defs>
              <linearGradient id="forecastGrad" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor={palette.primary.main} stopOpacity={0.3} />
                <stop offset="100%" stopColor={palette.primary.main} stopOpacity={0.02} />
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" vertical={false} stroke={palette.outline} />
            <XAxis dataKey="label" tick={{ fontSize: 11, fill: palette.textMuted }} axisLine={false} />
            <YAxis hide />
            <Tooltip
              contentStyle={{ borderRadius: 12, border: `1px solid ${palette.outline}`, boxShadow: palette.shadowSoft }}
              formatter={(v: number) => [formatMoneyFull(v), 'Dự báo']}
              labelFormatter={(label) => {
                const entry = meta.chartData.find((c) => c.label === label);
                const row = entry ? meta.rows[entry.idx - 1] : undefined;
                return row?.fullLabel ?? String(label);
              }}
            />
            <Area
              type="monotone"
              dataKey="amount"
              stroke={palette.primary.main}
              strokeWidth={2.5}
              fill="url(#forecastGrad)"
              dot={{ r: 3, fill: palette.primary.main, strokeWidth: 0 }}
              activeDot={{ r: 5 }}
            />
          </AreaChart>
        </ResponsiveContainer>
      </Box>

      <Stack
        direction={{ xs: 'column', sm: 'row' }}
        spacing={1}
        sx={{ mb: 0 }}
      >
        {[
          { label: 'Tổng 7 ngày', value: formatMoneyFull(meta.total), em: true },
          { label: 'Trung bình / ngày', value: formatMoneyFull(Math.round(meta.avg)) },
          { label: 'Thấp nhất', value: formatMoneyFull(meta.minV) },
          { label: 'Cao nhất', value: formatMoneyFull(meta.maxV), hint: `Ngày ${meta.maxIdx + 1}` },
        ].map(({ label, value, em, hint }) => (
          <Box
            key={label}
            sx={{
              flex: 1,
              minWidth: 0,
              p: 1.25,
              borderRadius: 2,
              border: em ? `2px solid ${palette.primary.main}55` : `1px solid ${palette.outline}`,
              bgcolor: em ? `${palette.primary.main}08` : 'background.paper',
            }}
          >
            <Typography variant="caption" color="text.secondary" fontWeight={600} display="block">
              {label}
            </Typography>
            <Typography variant="subtitle2" fontWeight={800} noWrap title={value}>
              {value}
            </Typography>
            {hint && <Typography variant="caption" color="text.disabled">{hint}</Typography>}
          </Box>
        ))}
      </Stack>
    </>
  );
}

/* ------------------------------------------------------------------ */
/* Main card                                                            */
/* ------------------------------------------------------------------ */
export function SpendingForecastCard({ loading, error, forecast, onRun, walletLabel }: Props) {
  const navigate = useNavigate();
  const hasData = !!forecast && forecast.predictedNextDaysVnd.length > 0;
  const meta = hasData ? buildRows(forecast!) : null;
  const insight = forecast?.insight ?? undefined;

  return (
    <Card
      elevation={0}
      sx={{
        mb: 2,
        overflow: 'hidden',
        border: `1px solid ${palette.outline}`,
        borderRadius: 3,
        boxShadow: '0 8px 32px rgba(15,23,42,0.06)',
        background: (t) =>
          t.palette.mode === 'dark'
            ? `linear-gradient(180deg, ${palette.primary.main}14 0%, ${t.palette.background.paper} 120px)`
            : `linear-gradient(180deg, ${palette.primary.main}0f 0%, #fff 140px)`,
      }}
    >
      {/* accent bar */}
      <Box sx={{ height: 4, background: `linear-gradient(90deg, ${palette.primary.main}, ${palette.income})` }} />

      <CardContent sx={{ pt: 2.5 }}>
        {/* Header */}
        <Stack direction="row" alignItems="flex-start" justifyContent="space-between" spacing={2} mb={2}>
          <Stack direction="row" spacing={1.5} alignItems="flex-start" flex={1}>
            <Box sx={{ p: 1, borderRadius: 2, bgcolor: `${palette.primary.main}18`, color: 'primary.main', display: 'flex' }}>
              <AutoGraphRounded sx={{ fontSize: 28 }} />
            </Box>
            <Box>
              <Typography variant="h6" fontWeight={800} color="text.primary">
                Dự báo chi tiêu · 7 ngày tới
              </Typography>
              <Typography variant="body2" color="text.secondary" sx={{ lineHeight: 1.5, maxWidth: 480 }}>
                {walletLabel
                  ? `Theo ví “${walletLabel}” và các khoản chi gần đây — cùng kiểu thống kê với biểu đồ bên dưới, không thay thế sổ giao dịch.`
                  : 'Theo ví đang chọn và lịch sử chi gần đây — gợi ý tham khảo, không phải cam kết.'}
              </Typography>
            </Box>
          </Stack>
          <Button
            variant="contained"
            size="medium"
            disabled={loading}
            onClick={onRun}
            startIcon={loading ? <CircularProgress size={18} color="inherit" /> : hasData ? <RefreshRounded /> : <TrendingUpRounded />}
            sx={{ borderRadius: 2, px: 2, fontWeight: 700, whiteSpace: 'nowrap', boxShadow: `0 4px 14px ${palette.primary.main}44` }}
          >
            {loading ? 'Đang tính…' : hasData ? 'Cập nhật' : 'Xem dự báo'}
          </Button>
        </Stack>

        {/* Empty prompt */}
        {!hasData && !loading && !error && (
          <Box sx={{ py: 2, px: 2, mb: 1, borderRadius: 2, bgcolor: 'action.hover', border: `1px dashed ${palette.textMuted}55` }}>
            <Typography variant="subtitle2" fontWeight={700} gutterBottom>
              Xem gợi ý chi tuần tới
            </Typography>
            <Stack component="ul" sx={{ m: 0, pl: 2.5, color: 'text.secondary', fontSize: 14, lineHeight: 1.75 }}>
              <li>So khớp với mức chi trung bình và ngân sách đã đặt</li>
              <li>Nút bên phải chỉ cần bấm một lần để tính lại</li>
            </Stack>
          </Box>
        )}

        {/* Error */}
        {error && (
          <Alert severity="error" sx={{ mt: 1, mb: 1 }}>
            {error}
          </Alert>
        )}

        {/* Loading */}
        {loading && !hasData && (
          <Box sx={{ py: 2 }}>
            <LinearProgress sx={{ borderRadius: 1, mb: 1 }} />
            <Typography variant="caption" color="text.secondary">
              Đang tính gợi ý…
            </Typography>
          </Box>
        )}

        {/* ── Data sections ── */}
        {hasData && meta && (
          <>
            {/* ZONE 1: How much */}
            <SpendZone insight={insight} total={meta.total} />

            {/* ZONE 2: Budget (cần insight từ API — parse trong statisticsService.getSpendingForecast) */}
            <BudgetZone alerts={insight?.budgetAlerts ?? []} onSetupBudget={() => navigate('/app/budget')} />

            {/* ZONE 3: Actions */}
            {insight?.tipsVi?.length ? (
              <ActionZone
                tips={insight.tipsVi}
                level={insight.level}
                onBudget={() => navigate('/app/budget')}
              />
            ) : (
              <Box sx={{ mb: 1.5 }}>
                <Divider sx={{ mb: 1.5 }} />
                <Button
                  variant="outlined"
                  startIcon={<SavingsOutlined />}
                  onClick={() => navigate('/app/budget')}
                  sx={{ borderRadius: 2, fontWeight: 700 }}
                >
                  Mở Ngân sách
                </Button>
              </Box>
            )}

            <Divider sx={{ my: 1.5 }} />

            {/* Chart + day detail */}
            <ForecastDetail meta={meta} />
          </>
        )}
      </CardContent>
    </Card>
  );
}
