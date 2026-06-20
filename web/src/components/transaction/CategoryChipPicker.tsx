import {
  AccountBalanceWalletRounded,
  CategoryRounded,
} from '@mui/icons-material';
import { Box, Chip, Stack, Typography } from '@mui/material';
import { chartCategoryColor } from '@/theme';
import { palette } from '@/theme';
import { resolveCategoryIcon, CategoryIconBadge } from '@/lib/categoryIcons';
import type { Category } from '@/types/models';

type Props = {
  categories: Category[];
  value: number | '';
  onChange: (id: number) => void;
};

export function CategoryChipPicker({ categories, value, onChange }: Props) {
  if (categories.length === 0) {
    return (
      <Typography variant="body2" color="text.secondary">
        Chưa có danh mục. Thêm tại Cài đặt → Danh mục.
      </Typography>
    );
  }

  return (
    <Stack direction="row" flexWrap="wrap" useFlexGap spacing={1}>
      {categories.map((c, i) => {
        const selected = value === c.id;
        const color = chartCategoryColor(i);
        const Icon = resolveCategoryIcon(c.name, c.icon);
        return (
          <Chip
            key={c.id}
            icon={
              <Box component="span" sx={{ display: 'flex', pl: 0.5 }}>
                <Icon sx={{ fontSize: 18, color: selected ? '#fff' : color }} />
              </Box>
            }
            label={c.name}
            clickable
            onClick={() => onChange(c.id)}
            sx={{
              fontWeight: 700,
              borderRadius: 2.5,
              py: 2.25,
              px: 0.5,
              bgcolor: selected ? color : '#fff',
              color: selected ? '#fff' : palette.textPrimary,
              border: `2px solid ${selected ? color : palette.outline}`,
              '& .MuiChip-icon': { color: 'inherit' },
            }}
          />
        );
      })}
    </Stack>
  );
}

type WalletProps = {
  wallets: { id: number; name: string; isDefault: boolean }[];
  value: number | '';
  onChange: (id: number) => void;
};

export function WalletChipPicker({ wallets, value, onChange }: WalletProps) {
  if (wallets.length === 0) {
    return (
      <Typography variant="body2" color="text.secondary">
        Chưa có ví. Tạo ví tại màn hình Ví.
      </Typography>
    );
  }

  return (
    <Stack direction="row" flexWrap="wrap" useFlexGap spacing={1}>
      {wallets.map((w) => {
        const selected = value === w.id;
        return (
          <Chip
            key={w.id}
            icon={<AccountBalanceWalletRounded sx={{ fontSize: 18 }} />}
            label={w.isDefault ? `${w.name} ★` : w.name}
            clickable
            onClick={() => onChange(w.id)}
            color={selected ? 'primary' : 'default'}
            variant={selected ? 'filled' : 'outlined'}
            sx={{ fontWeight: 700, borderRadius: 2.5, py: 2 }}
          />
        );
      })}
    </Stack>
  );
}

export { CategoryIconBadge, CategoryRounded };
