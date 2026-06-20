import { Box, Card, CardContent, ToggleButton, ToggleButtonGroup, Typography } from '@mui/material';
import { CalendarMonthRounded, DateRangeRounded } from '@mui/icons-material';
import { MonthYearPicker } from '@/components/common/MonthYearPicker';
import { YearPickerField } from '@/components/common/YearPickerField';
import { palette } from '@/theme';

type Props = {
  period: 'month' | 'year';
  onPeriodChange: (period: 'month' | 'year') => void;
  year: number;
  month: number;
  onMonthYearChange: (year: number, month: number) => void;
  onYearChange: (year: number) => void;
  minYear?: number;
  maxYear?: number;
};

export function PeriodFilterBar({
  period,
  onPeriodChange,
  year,
  month,
  onMonthYearChange,
  onYearChange,
  minYear,
  maxYear,
}: Props) {
  return (
    <Card
      sx={{
        mb: 2,
        background: (t) =>
          t.palette.mode === 'dark'
            ? t.palette.background.paper
            : `linear-gradient(145deg, #FFFFFF 0%, ${palette.surface} 100%)`,
        border: `1px solid ${palette.outline}`,
        boxShadow: palette.shadowSoft,
      }}
    >
      <CardContent sx={{ p: { xs: 2, sm: 2.5 }, '&:last-child': { pb: { xs: 2, sm: 2.5 } } }}>
        <Typography
          variant="overline"
          sx={{
            color: 'text.secondary',
            fontWeight: 700,
            letterSpacing: '0.08em',
            display: 'block',
            mb: 1.5,
          }}
        >
          Kỳ xem dữ liệu
        </Typography>

        <ToggleButtonGroup
          exclusive
          fullWidth
          value={period}
          onChange={(_, v) => v && onPeriodChange(v)}
          sx={{ mb: 2 }}
        >
          <ToggleButton value="month" sx={{ flex: 1, gap: 0.75 }}>
            <CalendarMonthRounded sx={{ fontSize: 18 }} />
            Theo tháng
          </ToggleButton>
          <ToggleButton value="year" sx={{ flex: 1, gap: 0.75 }}>
            <DateRangeRounded sx={{ fontSize: 18 }} />
            Theo năm
          </ToggleButton>
        </ToggleButtonGroup>

        <Box>
          {period === 'month' ? (
            <MonthYearPicker
              value={{ year, month }}
              onChange={(v) => onMonthYearChange(v.year, v.month)}
              minYear={minYear}
              maxYear={maxYear}
            />
          ) : (
            <YearPickerField
              value={year}
              onChange={onYearChange}
              minYear={minYear}
              maxYear={maxYear}
            />
          )}
        </Box>
      </CardContent>
    </Card>
  );
}
