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
} from '@mui/material';
import {
  CalendarMonthRounded,
  ChevronLeftRounded,
  ChevronRightRounded,
  EventRounded,
} from '@mui/icons-material';
import {
  addMonths,
  eachDayOfInterval,
  endOfMonth,
  endOfWeek,
  format,
  isBefore,
  isSameDay,
  isSameMonth,
  isValid,
  parseISO,
  startOfMonth,
  startOfToday,
  startOfWeek,
  subMonths,
} from 'date-fns';
import { vi } from 'date-fns/locale';
import { useMemo, useState } from 'react';
import { palette } from '@/theme';

type Props = {
  value: string;
  onChange: (isoDate: string) => void;
  label?: string;
  minDate?: Date;
  maxDate?: Date;
  fullWidth?: boolean;
  placeholder?: string;
  /** Cho phép chọn ngày trong quá khứ (mặc định: chỉ từ hôm nay trở đi). */
  allowPast?: boolean;
  margin?: 'none' | 'normal' | 'dense';
};

const WEEKDAYS = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

function parseValue(value: string): Date | null {
  if (!value) return null;
  const d = parseISO(value);
  return isValid(d) ? d : null;
}

function toIsoDate(d: Date): string {
  return format(d, 'yyyy-MM-dd');
}

function formatDisplay(d: Date): string {
  const raw = format(d, 'EEEE, dd/MM/yyyy', { locale: vi });
  return raw.charAt(0).toUpperCase() + raw.slice(1);
}

export function DatePickerField({
  value,
  onChange,
  label = 'Chọn ngày',
  minDate,
  maxDate,
  fullWidth = true,
  placeholder = 'Nhấn để chọn ngày',
  allowPast = false,
  margin = 'normal',
}: Props) {
  const [anchor, setAnchor] = useState<HTMLElement | null>(null);
  const selected = parseValue(value);
  const today = useMemo(() => startOfToday(), []);
  const min = minDate ?? (allowPast ? new Date(2000, 0, 1) : today);

  const [viewMonth, setViewMonth] = useState(() =>
    selected ? startOfMonth(selected) : startOfMonth(today),
  );

  const open = Boolean(anchor);

  const openPicker = (el: HTMLElement) => {
    setViewMonth(startOfMonth(selected ?? today));
    setAnchor(el);
  };

  const closePicker = () => setAnchor(null);

  const pickDate = (d: Date) => {
    onChange(toIsoDate(d));
    closePicker();
  };

  const clearDate = () => {
    onChange('');
    closePicker();
  };

  const calendarDays = useMemo(() => {
    const start = startOfWeek(startOfMonth(viewMonth), { weekStartsOn: 1 });
    const end = endOfWeek(endOfMonth(viewMonth), { weekStartsOn: 1 });
    return eachDayOfInterval({ start, end });
  }, [viewMonth]);

  const isDisabled = (d: Date) => {
    if (isBefore(d, min)) return true;
    if (maxDate && isBefore(maxDate, d)) return true;
    return false;
  };

  const monthLabel = format(viewMonth, 'MMMM yyyy', { locale: vi });
  const displayMonth =
    monthLabel.charAt(0).toUpperCase() + monthLabel.slice(1);

  return (
    <>
      <TextField
        label={label}
        value={selected ? formatDisplay(selected) : ''}
        placeholder={placeholder}
        fullWidth={fullWidth}
        margin={margin}
        InputProps={{
          readOnly: true,
          sx: { cursor: 'pointer' },
          startAdornment: (
            <InputAdornment position="start">
              <EventRounded sx={{ color: palette.primary.main, fontSize: 22 }} />
            </InputAdornment>
          ),
          endAdornment: (
            <InputAdornment position="end">
              <IconButton
                edge="end"
                aria-label="Mở lịch chọn ngày"
                onClick={(e) => {
                  e.stopPropagation();
                  openPicker(
                    e.currentTarget.closest('.MuiInputBase-root') as HTMLElement,
                  );
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
              onClick={() => setViewMonth((m) => subMonths(m, 1))}
              sx={{ color: 'white' }}
            >
              <ChevronLeftRounded />
            </IconButton>
            <Box textAlign="center">
              <Typography variant="caption" sx={{ opacity: 0.9, fontWeight: 600 }}>
                Chọn ngày
              </Typography>
              <Typography variant="h6" fontWeight={800} letterSpacing="-0.02em">
                {displayMonth}
              </Typography>
            </Box>
            <IconButton
              size="small"
              onClick={() => setViewMonth((m) => addMonths(m, 1))}
              sx={{ color: 'white' }}
            >
              <ChevronRightRounded />
            </IconButton>
          </Stack>
        </Box>

        <Box sx={{ px: 2, pt: 1.5, pb: 1 }}>
          <Box display="grid" gridTemplateColumns="repeat(7, 1fr)" gap={0.5} mb={0.5}>
            {WEEKDAYS.map((wd) => (
              <Typography
                key={wd}
                variant="caption"
                fontWeight={700}
                color="text.secondary"
                textAlign="center"
                sx={{ py: 0.5 }}
              >
                {wd}
              </Typography>
            ))}
          </Box>

          <Box display="grid" gridTemplateColumns="repeat(7, 1fr)" gap={0.5}>
            {calendarDays.map((day) => {
              const inMonth = isSameMonth(day, viewMonth);
              const selectedDay = selected ? isSameDay(day, selected) : false;
              const isToday = isSameDay(day, today);
              const disabled = isDisabled(day);

              return (
                <Button
                  key={day.toISOString()}
                  disabled={disabled}
                  onClick={() => pickDate(day)}
                  sx={{
                    minWidth: 0,
                    p: 0,
                    width: '100%',
                    aspectRatio: '1',
                    borderRadius: 2,
                    fontWeight: selectedDay ? 800 : 600,
                    fontSize: 13,
                    color: !inMonth
                      ? 'text.disabled'
                      : selectedDay
                        ? '#fff'
                        : 'text.primary',
                    bgcolor: selectedDay
                      ? palette.primary.main
                      : isToday
                        ? `${palette.primary.main}12`
                        : 'transparent',
                    border: isToday && !selectedDay ? `1px solid ${palette.primary.main}66` : 'none',
                    opacity: inMonth ? 1 : 0.45,
                    '&:hover': {
                      bgcolor: selectedDay
                        ? palette.primary.dark
                        : disabled
                          ? 'transparent'
                          : `${palette.primary.main}18`,
                    },
                    '&.Mui-disabled': {
                      opacity: inMonth ? 0.35 : 0.2,
                    },
                  }}
                >
                  {format(day, 'd')}
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
            onClick={clearDate}
            sx={{ color: 'text.secondary', fontWeight: 600 }}
          >
            Xóa ngày
          </Button>
          <Button
            size="small"
            variant="contained"
            onClick={() => pickDate(today)}
            disabled={isDisabled(today)}
            sx={{ borderRadius: 2, px: 2 }}
          >
            Hôm nay
          </Button>
        </Stack>
      </Popover>
    </>
  );
}
