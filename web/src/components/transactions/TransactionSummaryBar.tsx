import { Box, Chip, Stack, Typography } from '@mui/material';
import {
  ArrowDownwardRounded,
  ArrowUpwardRounded,
  AccountBalanceWalletRounded,
} from '@mui/icons-material';
import { formatMoney } from '@/lib/format';
import { palette } from '@/theme';

type Props = {
  totalIncome: number;
  totalExpense: number;
  balance: number;
  count: number;
};

export function TransactionSummaryBar({
  totalIncome,
  totalExpense,
  balance,
  count,
}: Props) {
  const positive = balance >= 0;

  return (
    <Box
      sx={{
        mb: 2,
        p: { xs: 2, sm: 2.5 },
        borderRadius: 4,
        border: `1px solid ${palette.primary.main}33`,
        boxShadow: palette.shadowLift,
        background: `linear-gradient(160deg, ${palette.primary.main}10 0%, #FFFFFF 55%, ${palette.surface} 100%)`,
      }}
    >
      <Stack direction="row" alignItems="center" spacing={1} mb={1}>
        <AccountBalanceWalletRounded sx={{ color: palette.primary.main, fontSize: 20 }} />
        <Typography fontWeight={700} fontSize={13} color="text.secondary">
          Tóm tắt danh sách · {count} giao dịch
        </Typography>
      </Stack>
      <Typography
        fontWeight={800}
        letterSpacing="-0.03em"
        sx={{
          fontSize: { xs: '1.35rem', sm: '1.75rem' },
          color: positive ? palette.income : palette.expense,
        }}
      >
        {formatMoney(balance)}
      </Typography>
      <Typography variant="caption" color="text.secondary" fontWeight={600}>
        Chênh lệch thu − chi (theo bộ lọc hiện tại)
      </Typography>

      <Stack direction="row" spacing={1.5} sx={{ mt: 2 }}>
        <Box
          sx={{
            flex: 1,
            p: 1.5,
            borderRadius: 3,
            bgcolor: `${palette.income}0D`,
            border: `1px solid ${palette.income}33`,
          }}
        >
          <Stack direction="row" alignItems="center" spacing={0.5} mb={0.5}>
            <ArrowDownwardRounded sx={{ fontSize: 16, color: palette.income }} />
            <Typography variant="caption" fontWeight={700} color="text.secondary">
              Thu
            </Typography>
          </Stack>
          <Typography fontWeight={800} sx={{ color: palette.income, fontSize: 15 }}>
            {formatMoney(totalIncome)}
          </Typography>
        </Box>
        <Box
          sx={{
            flex: 1,
            p: 1.5,
            borderRadius: 3,
            bgcolor: `${palette.expense}0D`,
            border: `1px solid ${palette.expense}22`,
          }}
        >
          <Stack direction="row" alignItems="center" spacing={0.5} mb={0.5}>
            <ArrowUpwardRounded sx={{ fontSize: 16, color: palette.expense }} />
            <Typography variant="caption" fontWeight={700} color="text.secondary">
              Chi
            </Typography>
          </Stack>
          <Typography fontWeight={800} color="error.main" fontSize={15}>
            {formatMoney(totalExpense)}
          </Typography>
        </Box>
      </Stack>
    </Box>
  );
}

type ChipProps = {
  value: '' | 'EXPENSE' | 'INCOME';
  onChange: (v: '' | 'EXPENSE' | 'INCOME') => void;
};

export function TransactionTypeChips({ value, onChange }: ChipProps) {
  const options: { id: '' | 'EXPENSE' | 'INCOME'; label: string }[] = [
    { id: '', label: 'Tất cả' },
    { id: 'EXPENSE', label: 'Chi tiêu' },
    { id: 'INCOME', label: 'Thu nhập' },
  ];

  return (
    <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap sx={{ mb: 1.5 }}>
      {options.map((opt) => (
        <Chip
          key={opt.id || 'all'}
          label={opt.label}
          clickable
          onClick={() => onChange(opt.id)}
          color={value === opt.id ? 'primary' : 'default'}
          variant={value === opt.id ? 'filled' : 'outlined'}
          sx={{ fontWeight: 700, borderRadius: 2 }}
        />
      ))}
    </Stack>
  );
}
