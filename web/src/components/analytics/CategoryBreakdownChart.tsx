import { Box, Stack, Typography } from '@mui/material';
import { Cell, Pie, PieChart, ResponsiveContainer, Tooltip } from 'recharts';
import { formatMoney } from '@/lib/format';
import { chartCategoryColor, palette } from '@/theme';

type Row = { name: string; amount: number };

type Props = {
  data: Row[];
  isExpense: boolean;
};

function CustomTooltip({ active, payload }: { active?: boolean; payload?: { payload: Row }[] }) {
  if (!active || !payload?.length) return null;
  const row = payload[0].payload;
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
      <Typography fontWeight={700} fontSize={13}>
        {row.name}
      </Typography>
      <Typography fontWeight={800} color="primary.main" fontSize={14}>
        {formatMoney(row.amount)}
      </Typography>
    </Box>
  );
}

export function CategoryBreakdownChart({ data, isExpense }: Props) {
  const total = data.reduce((s, r) => s + r.amount, 0);

  if (data.length === 0) {
    return (
      <Box py={4} textAlign="center">
        <Typography color="text.secondary">Chưa có dữ liệu trong kỳ này</Typography>
      </Box>
    );
  }

  return (
    <Stack spacing={2.5}>
      <Box position="relative" height={240}>
        <ResponsiveContainer width="100%" height="100%">
          <PieChart>
            <Pie
              data={data}
              dataKey="amount"
              nameKey="name"
              cx="50%"
              cy="50%"
              innerRadius={62}
              outerRadius={88}
              paddingAngle={3}
              stroke="none"
            >
              {data.map((_, i) => (
                <Cell key={i} fill={chartCategoryColor(i)} />
              ))}
            </Pie>
            <Tooltip content={<CustomTooltip />} />
          </PieChart>
        </ResponsiveContainer>
        <Box
          sx={{
            position: 'absolute',
            top: '50%',
            left: '50%',
            transform: 'translate(-50%, -50%)',
            textAlign: 'center',
            pointerEvents: 'none',
            width: 100,
          }}
        >
          <Typography variant="caption" fontWeight={700} color="text.secondary" lineHeight={1.2}>
            {isExpense ? 'Tổng chi' : 'Tổng thu'}
          </Typography>
          <Typography fontWeight={800} fontSize={15} color="text.primary" lineHeight={1.2}>
            {formatMoney(total)}
          </Typography>
        </Box>
      </Box>

      <Stack spacing={1.25}>
        {data.map((row, i) => {
          const pct = total > 0 ? (row.amount / total) * 100 : 0;
          const color = chartCategoryColor(i);
          return (
            <Box
              key={row.name}
              sx={{
                p: 1.25,
                borderRadius: 2,
                bgcolor: `${color}10`,
                border: `1px solid ${color}22`,
              }}
            >
              <Stack direction="row" alignItems="center" spacing={1.25} mb={0.75}>
                <Box width={10} height={10} borderRadius={1} bgcolor={color} flexShrink={0} />
                <Typography flex={1} fontWeight={600} fontSize={14} noWrap>
                  {row.name}
                </Typography>
                <Typography fontWeight={800} fontSize={13}>
                  {formatMoney(row.amount)}
                </Typography>
                <Typography fontWeight={700} fontSize={12} color="text.secondary" minWidth={36} textAlign="right">
                  {pct.toFixed(0)}%
                </Typography>
              </Stack>
              <Box
                sx={{
                  height: 6,
                  borderRadius: 1,
                  bgcolor: `${color}18`,
                  overflow: 'hidden',
                }}
              >
                <Box
                  sx={{
                    height: '100%',
                    width: `${pct}%`,
                    borderRadius: 1,
                    bgcolor: color,
                    transition: 'width 0.4s ease',
                  }}
                />
              </Box>
            </Box>
          );
        })}
      </Stack>
    </Stack>
  );
}
