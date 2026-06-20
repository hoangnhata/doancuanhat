import { Box, Typography } from '@mui/material';

type Props = {
  title: string;
  subtitle?: string;
  children: React.ReactNode;
};

export function FormSection({ title, subtitle, children }: Props) {
  return (
    <Box
      sx={{
        mb: 2,
        p: { xs: 2, sm: 2.5 },
        borderRadius: 4,
        bgcolor: '#fff',
        border: '1px solid rgba(15, 23, 42, 0.08)',
        boxShadow: '0 1px 2px rgba(15, 23, 42, 0.04), 0 4px 16px rgba(15, 23, 42, 0.06)',
      }}
    >
      <Typography fontWeight={800} fontSize={14} mb={subtitle ? 0.25 : 1.25}>
        {title}
      </Typography>
      {subtitle && (
        <Typography variant="caption" color="text.secondary" fontWeight={600} sx={{ display: 'block', mb: 1.25 }}>
          {subtitle}
        </Typography>
      )}
      {children}
    </Box>
  );
}
