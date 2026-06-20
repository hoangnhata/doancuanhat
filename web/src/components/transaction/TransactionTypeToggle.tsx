import { ArrowDownwardRounded, ArrowUpwardRounded } from '@mui/icons-material';
import { Box, Stack, Typography } from '@mui/material';
import { palette } from '@/theme';

type Props = {
  isExpense: boolean;
  onChange: (isExpense: boolean) => void;
};

export function TransactionTypeToggle({ isExpense, onChange }: Props) {
  return (
    <Stack direction="row" spacing={1.5} sx={{ mb: 2 }}>
      <TypeOption
        label="Chi tiêu"
        icon={<ArrowUpwardRounded />}
        selected={isExpense}
        accent={palette.expense}
        onClick={() => onChange(true)}
      />
      <TypeOption
        label="Thu nhập"
        icon={<ArrowDownwardRounded />}
        selected={!isExpense}
        accent={palette.income}
        onClick={() => onChange(false)}
      />
    </Stack>
  );
}

function TypeOption({
  label,
  icon,
  selected,
  accent,
  onClick,
}: {
  label: string;
  icon: React.ReactNode;
  selected: boolean;
  accent: string;
  onClick: () => void;
}) {
  return (
    <Box
      onClick={onClick}
      sx={{
        flex: 1,
        p: 1.75,
        borderRadius: 3,
        cursor: 'pointer',
        textAlign: 'center',
        transition: 'all 0.2s',
        border: `2px solid ${selected ? accent : palette.outline}`,
        bgcolor: selected ? `${accent}14` : '#fff',
        boxShadow: selected ? palette.shadowSoft : 'none',
        '&:hover': { borderColor: accent, bgcolor: `${accent}0A` },
      }}
    >
      <Box
        sx={{
          width: 36,
          height: 36,
          mx: 'auto',
          mb: 0.75,
          borderRadius: 2,
          display: 'grid',
          placeItems: 'center',
          bgcolor: `${accent}${selected ? '33' : '18'}`,
          color: accent,
        }}
      >
        {icon}
      </Box>
      <Typography fontWeight={800} fontSize={14} color={selected ? accent : 'text.secondary'}>
        {label}
      </Typography>
    </Box>
  );
}
