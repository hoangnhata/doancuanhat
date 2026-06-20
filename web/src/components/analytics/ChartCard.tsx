import { Box, Card, CardContent, Typography } from '@mui/material';
import { palette } from '@/theme';

type Props = {
  title: string;
  subtitle?: string;
  children: React.ReactNode;
};

export function ChartCard({ title, subtitle, children }: Props) {
  return (
    <Card
      sx={{
        mb: 2,
        borderRadius: 4,
        border: `1px solid ${palette.outline}`,
        boxShadow: palette.shadowSoft,
      }}
    >
      <CardContent sx={{ p: { xs: 2, sm: 3 } }}>
        {subtitle && (
          <Typography
            variant="overline"
            sx={{ display: 'block', fontWeight: 800, letterSpacing: '0.1em', color: 'text.secondary', mb: 0.5 }}
          >
            {subtitle}
          </Typography>
        )}
        <Typography fontWeight={800} fontSize={17} gutterBottom>
          {title}
        </Typography>
        <Box mt={1}>{children}</Box>
      </CardContent>
    </Card>
  );
}
