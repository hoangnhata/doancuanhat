import { Box, Stack, Typography, useMediaQuery, useTheme } from '@mui/material';
import { SwipeRounded } from '@mui/icons-material';
import {
  Bar,
  BarChart,
  CartesianGrid,
  Legend,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import { formatMoney } from '@/lib/format';
import { palette } from '@/theme';

type Row = { day: string; Chi: number; Thu: number };

type Props = {
  data: Row[];
};

const DAY_SLOT_WIDTH = 36;

function AxisMoneyTick({ x, y, payload }: { x?: number; y?: number; payload?: { value: number } }) {
  if (x == null || y == null || payload == null) return null;
  return (
    <g transform={`translate(${x},${y})`}>
      <text x={0} y={0} dy={4} textAnchor="end" fill={palette.textMuted} fontSize={11} fontWeight={600}>
        {formatMoney(payload.value).replace(' ₫', '')}
      </text>
    </g>
  );
}

function FlowTooltip({
  active,
  payload,
  label,
}: {
  active?: boolean;
  payload?: { name: string; value: number; color: string }[];
  label?: string;
}) {
  if (!active || !payload?.length) return null;
  return (
    <Box
      sx={{
        px: 1.5,
        py: 1,
        borderRadius: 2,
        bgcolor: 'background.paper',
        border: `1px solid ${palette.outline}`,
        boxShadow: palette.shadowLift,
      }}
    >
      <Typography fontWeight={700} fontSize={12} mb={0.5}>
        Ngày {label}
      </Typography>
      {payload.map((p) => (
        <Stack key={p.name} direction="row" alignItems="center" spacing={0.75}>
          <Box width={8} height={8} borderRadius="50%" bgcolor={p.color} />
          <Typography fontSize={12} fontWeight={600}>
            {p.name}: {formatMoney(p.value)}
          </Typography>
        </Stack>
      ))}
    </Box>
  );
}

export function DailyFlowChart({ data }: Props) {
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));
  if (data.length === 0) return null;

  const scrollWidth = Math.max(data.length * DAY_SLOT_WIDTH, 320);
  const scrollable = isMobile && data.length > 10;

  const chart = (
    <BarChart
      data={data}
      barGap={2}
      barCategoryGap={scrollable ? '28%' : '18%'}
      margin={{ top: 8, right: scrollable ? 16 : 8, left: 0, bottom: 0 }}
    >
      <CartesianGrid strokeDasharray="4 4" vertical={false} stroke={palette.outline} />
      <XAxis
        dataKey="day"
        axisLine={false}
        tickLine={false}
        interval={scrollable ? 0 : 'preserveStartEnd'}
        minTickGap={scrollable ? 8 : 24}
        tick={{ fill: palette.textMuted, fontSize: 11, fontWeight: 600 }}
      />
      <YAxis axisLine={false} tickLine={false} width={56} tick={<AxisMoneyTick />} />
      <Tooltip content={<FlowTooltip />} cursor={{ fill: `${palette.primary.main}08` }} />
      <Legend
        wrapperStyle={{ paddingTop: 12 }}
        formatter={(value) => (
          <span style={{ color: palette.textSecondary, fontWeight: 700, fontSize: 12 }}>{value}</span>
        )}
      />
      <Bar dataKey="Chi" fill={palette.expense} radius={[6, 6, 0, 0]} maxBarSize={scrollable ? 20 : 28} />
      <Bar dataKey="Thu" fill={palette.income} radius={[6, 6, 0, 0]} maxBarSize={scrollable ? 20 : 28} />
    </BarChart>
  );

  return (
    <Box>
      {scrollable && (
        <Stack direction="row" alignItems="center" spacing={0.5} sx={{ mb: 1.5 }}>
          <SwipeRounded sx={{ fontSize: 16, color: palette.textMuted }} />
          <Typography variant="caption" fontWeight={600} color="text.secondary">
            Vuốt ngang để xem toàn bộ các ngày trong tháng
          </Typography>
        </Stack>
      )}
      <Box
        sx={{
          height: 300,
          overflowX: scrollable ? 'auto' : 'visible',
          overflowY: 'hidden',
          mx: scrollable ? -0.5 : 0,
          pb: scrollable ? 0.5 : 0,
          WebkitOverflowScrolling: 'touch',
        }}
      >
        <Box sx={{ width: scrollable ? scrollWidth : '100%', minWidth: '100%', height: '100%' }}>
          <ResponsiveContainer width="100%" height="100%">
            {chart}
          </ResponsiveContainer>
        </Box>
      </Box>
    </Box>
  );
}
