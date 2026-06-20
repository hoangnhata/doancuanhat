import { Typography } from '@mui/material';

export function SectionLabel({ children }: { children: React.ReactNode }) {
  return (
    <Typography
      variant="overline"
      sx={{
        display: 'block',
        mb: 1.25,
        fontWeight: 800,
        letterSpacing: '0.1em',
        color: 'text.secondary',
      }}
    >
      {children}
    </Typography>
  );
}
