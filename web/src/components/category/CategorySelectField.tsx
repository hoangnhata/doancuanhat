import {
  Box,
  MenuItem,
  TextField,
  Typography,
  type TextFieldProps,
} from '@mui/material';
import { CheckCircleRounded } from '@mui/icons-material';
import type { Category } from '@/types/models';
import {
  CategoryLabel,
} from '@/lib/categoryIcons';
import { palette } from '@/theme';

type Props = Omit<TextFieldProps, 'select' | 'value' | 'onChange'> & {
  categories: Category[];
  value: number | '';
  onChange: (categoryId: number | '') => void;
  withOnboardingStyle?: boolean;
  allowEmpty?: boolean;
  emptyLabel?: string;
  /** Danh mục đã có hạn mức — hiển thị dấu tick và không cho chọn lại. */
  disabledCategoryIds?: number[];
  disabledHint?: string;
};

export function CategorySelectField({
  categories,
  value,
  onChange,
  label = 'Danh mục chi tiêu',
  withOnboardingStyle = false,
  allowEmpty = false,
  emptyLabel = 'Tất cả',
  disabledCategoryIds = [],
  disabledHint = 'Đã có hạn mức',
  ...rest
}: Props) {
  const fieldSx = withOnboardingStyle
    ? {
        '& .MuiOutlinedInput-root': {
          borderRadius: 2.5,
          '& fieldset': { borderColor: 'divider' },
          '&:hover fieldset': { borderColor: `${palette.primary.main}66` },
          '&.Mui-focused fieldset': {
            borderColor: palette.primary.main,
            borderWidth: 2,
          },
        },
      }
    : undefined;

  return (
    <TextField
      select
      fullWidth
      margin="normal"
      label={label}
      value={value}
      onChange={(e) => {
        const v = e.target.value;
        onChange(v === '' ? '' : Number(v));
      }}
      InputLabelProps={{ shrink: true }}
      SelectProps={{
        renderValue: (v) => {
          if (v === '' || v == null) return emptyLabel;
          const cat = categories.find((c) => c.id === Number(v));
          if (!cat) return '';
          const idx = categories.findIndex((c) => c.id === cat.id);
          return (
            <CategoryLabel name={cat.name} icon={cat.icon} colorIndex={idx} />
          );
        },
        MenuProps: {
          PaperProps: {
            sx: {
              borderRadius: 2.5,
              mt: 0.5,
              maxHeight: 360,
              boxShadow: '0 12px 40px rgba(0,0,0,0.12)',
            },
          },
        },
      }}
      sx={fieldSx}
      {...rest}
    >
      {allowEmpty && (
        <MenuItem value="" sx={{ py: 1.25, borderRadius: 1.5, mx: 0.75, my: 0.25 }}>
          {emptyLabel}
        </MenuItem>
      )}
      {categories.map((c, i) => {
        const isUsed = disabledCategoryIds.includes(c.id);
        return (
          <MenuItem
            key={c.id}
            value={c.id}
            disabled={isUsed}
            sx={{
              py: 1.25,
              borderRadius: 1.5,
              mx: 0.75,
              my: 0.25,
              opacity: isUsed ? 0.72 : 1,
              '&.Mui-selected': {
                bgcolor: `${palette.primary.main}12`,
              },
              '&.Mui-disabled': {
                opacity: 0.72,
              },
            }}
          >
            <Box display="flex" alignItems="center" width="100%" gap={1}>
              <Box flex={1}>
                <CategoryLabel name={c.name} icon={c.icon} colorIndex={i} />
              </Box>
              {isUsed && (
                <Box display="flex" alignItems="center" gap={0.5} flexShrink={0}>
                  <CheckCircleRounded sx={{ fontSize: 18, color: 'success.main' }} />
                  <Typography variant="caption" color="text.secondary" fontWeight={600}>
                    {disabledHint}
                  </Typography>
                </Box>
              )}
            </Box>
          </MenuItem>
        );
      })}
    </TextField>
  );
}
