import { Chip, Stack, TextField, Typography } from '@mui/material';
import { formatMoneyFull } from '@/lib/format';
import { palette } from '@/theme';

const QUICK_AMOUNTS = [
  { label: '+10k', value: 10_000 },
  { label: '+50k', value: 50_000 },
  { label: '+100k', value: 100_000 },
  { label: '+500k', value: 500_000 },
];

type Props = {
  value: string;
  onChange: (v: string) => void;
  isExpense: boolean;
  showQuick?: boolean;
};

export function AmountInputSection({
  value,
  onChange,
  isExpense,
  showQuick = true,
}: Props) {
  const numeric = Number(value.replace(/\D/g, '')) || 0;
  const accent = isExpense ? palette.expense : palette.income;

  function addQuick(delta: number) {
    const current = Number(value.replace(/\D/g, '')) || 0;
    onChange(String(current + delta));
  }

  return (
    <>
      <Typography variant="overline" fontWeight={800} color="text.secondary" sx={{ letterSpacing: '0.08em' }}>
        Số tiền
      </Typography>
      <TextField
        fullWidth
        placeholder="0"
        value={value}
        onChange={(e) => onChange(e.target.value.replace(/[^\d]/g, ''))}
        inputProps={{ inputMode: 'numeric' }}
        sx={{
          mt: 1,
          mb: 0.5,
          '& .MuiOutlinedInput-root': {
            borderRadius: 3,
            fontSize: 28,
            fontWeight: 800,
            bgcolor: '#fff',
          },
          '& input': { textAlign: 'center', color: accent },
        }}
      />
      {numeric > 0 && (
        <Typography textAlign="center" fontWeight={700} color="text.secondary" fontSize={13} mb={1}>
          {formatMoneyFull(numeric)}
        </Typography>
      )}
      {showQuick && (
        <Stack direction="row" flexWrap="wrap" useFlexGap spacing={1} sx={{ mt: 1 }}>
          {QUICK_AMOUNTS.map((q) => (
            <Chip
              key={q.label}
              label={q.label}
              clickable
              onClick={() => addQuick(q.value)}
              sx={{
                fontWeight: 700,
                borderRadius: 2,
                bgcolor: `${palette.primary.main}10`,
                border: `1px solid ${palette.primary.main}33`,
              }}
            />
          ))}
        </Stack>
      )}
    </>
  );
}
