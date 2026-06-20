import { InputAdornment, TextField, type TextFieldProps } from '@mui/material';
import type { ReactNode } from 'react';
import { palette } from '@/theme';

type Props = TextFieldProps & {
  startIcon?: ReactNode;
};

export function OnboardingField({ startIcon, sx, InputProps, ...rest }: Props) {
  return (
    <TextField
      fullWidth
      margin="normal"
      InputLabelProps={{ shrink: true }}
      InputProps={{
        ...InputProps,
        startAdornment: startIcon ? (
          <InputAdornment position="start" sx={{ color: palette.primary.main }}>
            {startIcon}
          </InputAdornment>
        ) : (
          InputProps?.startAdornment
        ),
        sx: {
          borderRadius: 2.5,
          bgcolor: 'background.paper',
          ...InputProps?.sx,
        },
      }}
      sx={{
        '& .MuiOutlinedInput-root': {
          borderRadius: 2.5,
          '& fieldset': {
            borderColor: 'divider',
          },
          '&:hover fieldset': {
            borderColor: `${palette.primary.main}66`,
          },
          '&.Mui-focused fieldset': {
            borderColor: palette.primary.main,
            borderWidth: 2,
          },
        },
        ...sx,
      }}
      {...rest}
    />
  );
}

export function formatAmountInput(raw: string): string {
  const digits = raw.replace(/\D/g, '');
  if (!digits) return '';
  return Number(digits).toLocaleString('vi-VN');
}

export function parseAmountInput(formatted: string): number {
  return Number(formatted.replace(/\D/g, '')) || 0;
}
