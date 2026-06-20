import {
  Box,
  Button,
  Divider,
  IconButton,
  InputAdornment,
  Popover,
  Stack,
  TextField,
  Typography,
  useTheme,
} from '@mui/material';
import {
  CalendarMonthRounded,
  ChevronLeftRounded,
  ChevronRightRounded,
} from '@mui/icons-material';
import { useMemo, useState } from 'react';
import {
  currentMonthYear,
  formatMonthGridLabel,
  formatMonthYearLabel,
  isSameMonthYear,
} from '@/lib/dateLabels';
import { palette } from '@/theme';

export type MonthYearValue = { year: number; month: number };

type Props = {
  value: MonthYearValue;
  onChange: (value: MonthYearValue) => void;
  label?: string;
  minYear?: number;
  maxYear?: number;
  fullWidth?: boolean;
};

export function MonthYearPicker({
  value,
  onChange,
  label = 'Chọn tháng',
  minYear = 2020,
  maxYear = new Date().getFullYear() + 1,
  fullWidth = true,
}: Props) {
  const theme = useTheme();
  const [anchor, setAnchor] = useState<HTMLElement | null>(null);
  const [draftYear, setDraftYear] = useState(value.year);
  const open = Boolean(anchor);
  const today = useMemo(() => currentMonthYear(), []);

  const openPicker = (el: HTMLElement) => {
    setDraftYear(value.year);
    setAnchor(el);
  };

  const closePicker = () => setAnchor(null);

  const pickMonth = (month: number) => {
    onChange({ year: draftYear, month });
    closePicker();
  };

  const goToday = () => {
    onChange(today);
    closePicker();
  };

  const canPrevYear = draftYear > minYear;
  const canNextYear = draftYear < maxYear;

  return (
    <>
      <TextField
        label={label}
        value={formatMonthYearLabel(value.year, value.month)}
        fullWidth={fullWidth}
        InputProps={{
          readOnly: true,
          sx: { cursor: 'pointer' },
          startAdornment: (
            <InputAdornment position="start">
              <CalendarMonthRounded sx={{ color: palette.primary.main, fontSize: 22 }} />
            </InputAdornment>
          ),
          endAdornment: (
            <InputAdornment position="end">
              <IconButton
                edge="end"
                aria-label="Mở lịch chọn tháng"
                onClick={(e) => {
                  e.stopPropagation();
                  openPicker(e.currentTarget.closest('.MuiInputBase-root') as HTMLElement);
                }}
                sx={{
                  color: palette.primary.main,
                  bgcolor: `${palette.primary.main}14`,
                  '&:hover': { bgcolor: `${palette.primary.main}22` },
                }}
              >
                <CalendarMonthRounded fontSize="small" />
              </IconButton>
            </InputAdornment>
          ),
        }}
        onClick={(e) => openPicker(e.currentTarget)}
        InputLabelProps={{ shrink: true }}
      />

      <Popover
        open={open}
        anchorEl={anchor}
        onClose={closePicker}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'left' }}
        transformOrigin={{ vertical: 'top', horizontal: 'left' }}
        slotProps={{
          paper: {
            sx: {
              width: { xs: 'min(340px, calc(100vw - 32px))', sm: 340 },
              borderRadius: 3,
              overflow: 'hidden',
            },
          },
        }}
      >
        <Box
          sx={{
            px: 2,
            py: 1.5,
            background: (t) =>
              t.palette.mode === 'dark'
                ? `linear-gradient(135deg, ${palette.primary.dark} 0%, ${t.palette.background.paper} 100%)`
                : `linear-gradient(135deg, ${palette.primary.main} 0%, ${palette.primary.light} 100%)`,
            color: 'white',
          }}
        >
          <Stack direction="row" alignItems="center" justifyContent="space-between">
            <IconButton
              size="small"
              disabled={!canPrevYear}
              onClick={() => setDraftYear((y) => Math.max(minYear, y - 1))}
              sx={{ color: 'white', opacity: canPrevYear ? 1 : 0.4 }}
            >
              <ChevronLeftRounded />
            </IconButton>
            <Box textAlign="center">
              <Typography variant="caption" sx={{ opacity: 0.9, fontWeight: 600 }}>
                Năm
              </Typography>
              <Typography variant="h5" fontWeight={800} letterSpacing="-0.02em">
                {draftYear}
              </Typography>
            </Box>
            <IconButton
              size="small"
              disabled={!canNextYear}
              onClick={() => setDraftYear((y) => Math.min(maxYear, y + 1))}
              sx={{ color: 'white', opacity: canNextYear ? 1 : 0.4 }}
            >
              <ChevronRightRounded />
            </IconButton>
          </Stack>
        </Box>

        <Box sx={{ p: 2 }}>
          <Box
            display="grid"
            gridTemplateColumns="repeat(3, 1fr)"
            gap={1}
          >
            {Array.from({ length: 12 }, (_, i) => {
              const month = i + 1;
              const selected =
                draftYear === value.year && month === value.month;
              const isToday =
                draftYear === today.year && month === today.month;

              return (
                <Button
                  key={month}
                  onClick={() => pickMonth(month)}
                  sx={{
                    py: 1.25,
                    borderRadius: 2.5,
                    fontWeight: 700,
                    fontSize: 13,
                    textTransform: 'none',
                    border: '1px solid',
                    borderColor: selected
                      ? palette.primary.main
                      : isToday
                        ? `${palette.primary.main}66`
                        : theme.palette.divider,
                    bgcolor: selected
                      ? palette.primary.main
                      : isToday
                        ? `${palette.primary.main}12`
                        : theme.palette.background.paper,
                    color: selected
                      ? '#fff'
                      : theme.palette.text.primary,
                    boxShadow: selected ? '0 4px 14px rgba(2, 136, 209, 0.35)' : 'none',
                    '&:hover': {
                      bgcolor: selected
                        ? palette.primary.dark
                        : `${palette.primary.main}18`,
                      borderColor: palette.primary.light,
                    },
                  }}
                >
                  {formatMonthGridLabel(month)}
                </Button>
              );
            })}
          </Box>
        </Box>

        <Divider />

        <Stack direction="row" justifyContent="space-between" px={2} py={1.5}>
          <Button
            size="small"
            color="inherit"
            onClick={closePicker}
            sx={{ color: 'text.secondary', fontWeight: 600 }}
          >
            Đóng
          </Button>
          <Button
            size="small"
            variant="contained"
            onClick={goToday}
            disabled={isSameMonthYear(value, today)}
            sx={{ borderRadius: 2, px: 2 }}
          >
            Tháng này
          </Button>
        </Stack>
      </Popover>
    </>
  );
}
