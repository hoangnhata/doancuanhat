import { InputAdornment, TextField, type TextFieldProps } from '@mui/material';
import type { ReactNode } from 'react';
import { palette } from '@/theme';

type Props = TextFieldProps & {
  startIcon?: ReactNode;
};

export function AuthTextField({ startIcon, sx, ...rest }: Props) {
  return (
    <TextField
      fullWidth
      margin="normal"
      InputLabelProps={{ shrink: true }}
      InputProps={
        startIcon
          ? {
              startAdornment: (
                <InputAdornment position="start" sx={{ color: palette.primary.main }}>
                  {startIcon}
                </InputAdornment>
              ),
            }
          : undefined
      }
      sx={{
        '& .MuiOutlinedInput-root': {
          bgcolor: '#FFFFFF',
        },
        ...sx,
      }}
      {...rest}
    />
  );
}
