import { Button, CircularProgress, type ButtonProps } from '@mui/material';
import { palette } from '@/theme';

type Props = ButtonProps & {
  loading?: boolean;
  loadingLabel?: string;
};

export function AuthPrimaryButton({
  loading,
  loadingLabel,
  children,
  disabled,
  sx,
  ...rest
}: Props) {
  return (
    <Button
      fullWidth
      size="large"
      variant="contained"
      disabled={disabled || loading}
      sx={{
        mt: 2,
        py: 1.5,
        borderRadius: 3,
        fontWeight: 800,
        fontSize: '1rem',
        textTransform: 'none',
        background: `linear-gradient(135deg, ${palette.primary.main} 0%, ${palette.primary.light} 100%)`,
        boxShadow: '0 8px 24px rgba(2, 136, 209, 0.35)',
        '&:hover': {
          background: `linear-gradient(135deg, ${palette.primary.dark} 0%, ${palette.primary.main} 100%)`,
          boxShadow: '0 12px 28px rgba(2, 136, 209, 0.42)',
        },
        '&.Mui-disabled': {
          background: palette.textMuted,
          color: '#fff',
        },
        ...sx,
      }}
      {...rest}
    >
      {loading ? (
        <>
          <CircularProgress size={22} sx={{ color: '#fff', mr: 1 }} />
          {loadingLabel ?? 'Đang xử lý…'}
        </>
      ) : (
        children
      )}
    </Button>
  );
}
