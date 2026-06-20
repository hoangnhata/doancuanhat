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
  ChevronLeftRounded,
  ChevronRightRounded,
  DateRangeRounded,
} from '@mui/icons-material';
import { useMemo, useState } from 'react';
import { palette } from '@/theme';

type Props = {
  value: number;
  onChange: (year: number) => void;
  label?: string;
  minYear?: number;
  maxYear?: number;
  fullWidth?: boolean;
};

export function YearPickerField({
  value,
  onChange,
  label = 'Chọn năm',
  minYear = 2020,
  maxYear = new Date().getFullYear() + 1,
  fullWidth = true,
}: Props) {
  const theme = useTheme();
  const [anchor, setAnchor] = useState<HTMLElement | null>(null);
  const [viewStart, setViewStart] = useState(() => value - 4);
  const open = Boolean(anchor);
  const currentYear = useMemo(() => new Date().getFullYear(), []);

  const years = useMemo(
    () => Array.from({ length: 9 }, (_, i) => viewStart + i).filter((y) => y >= minYear && y <= maxYear),
    [viewStart, minYear, maxYear],
  );

  const openPicker = (el: HTMLElement) => {
    setViewStart(Math.max(minYear, Math.min(value - 4, maxYear - 8)));
    setAnchor(el);
  };

  const closePicker = () => setAnchor(null);

  const pickYear = (year: number) => {
    onChange(year);
    closePicker();
  };

  return (
    <>
      <TextField
        label={label}
        value={`Năm ${value}`}
        fullWidth={fullWidth}
        InputProps={{
          readOnly: true,
          sx: { cursor: 'pointer' },
          startAdornment: (
            <InputAdornment position="start">
              <DateRangeRounded sx={{ color: palette.primary.main, fontSize: 22 }} />
            </InputAdornment>
          ),
          endAdornment: (
            <InputAdornment position="end">
              <IconButton
                edge="end"
                aria-label="Mở chọn năm"
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
                <DateRangeRounded fontSize="small" />
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
              width: { xs: 'min(300px, calc(100vw - 32px))', sm: 300 },
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
              disabled={viewStart <= minYear}
              onClick={() => setViewStart((s) => Math.max(minYear, s - 9))}
              sx={{ color: 'white' }}
            >
              <ChevronLeftRounded />
            </IconButton>
            <Typography fontWeight={800}>Chọn năm</Typography>
            <IconButton
              size="small"
              disabled={viewStart + 8 >= maxYear}
              onClick={() => setViewStart((s) => Math.min(maxYear - 8, s + 9))}
              sx={{ color: 'white' }}
            >
              <ChevronRightRounded />
            </IconButton>
          </Stack>
        </Box>

        <Box sx={{ p: 2 }}>
          <Box display="grid" gridTemplateColumns="repeat(3, 1fr)" gap={1}>
            {years.map((y) => {
              const selected = y === value;
              const isCurrent = y === currentYear;
              return (
                <Button
                  key={y}
                  onClick={() => pickYear(y)}
                  sx={{
                    py: 1.5,
                    borderRadius: 2.5,
                    fontWeight: 800,
                    border: '1px solid',
                    borderColor: selected
                      ? palette.primary.main
                      : isCurrent
                        ? `${palette.primary.main}66`
                        : theme.palette.divider,
                    bgcolor: selected
                      ? palette.primary.main
                      : isCurrent
                        ? `${palette.primary.main}12`
                        : theme.palette.background.paper,
                    color: selected ? '#fff' : theme.palette.text.primary,
                    boxShadow: selected ? '0 4px 14px rgba(2, 136, 209, 0.35)' : 'none',
                    '&:hover': {
                      bgcolor: selected ? palette.primary.dark : `${palette.primary.main}18`,
                    },
                  }}
                >
                  {y}
                </Button>
              );
            })}
          </Box>
        </Box>

        <Divider />

        <Stack direction="row" justifyContent="space-between" px={2} py={1.5}>
          <Button size="small" color="inherit" onClick={closePicker} sx={{ color: 'text.secondary' }}>
            Đóng
          </Button>
          <Button
            size="small"
            variant="contained"
            onClick={() => pickYear(currentYear)}
            disabled={value === currentYear}
            sx={{ borderRadius: 2 }}
          >
            Năm nay
          </Button>
        </Stack>
      </Popover>
    </>
  );
}
