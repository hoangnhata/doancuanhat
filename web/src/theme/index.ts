import { createTheme, type ThemeOptions } from '@mui/material/styles';

/** Khớp Flutter; tinh chỉnh cho web: slate + ocean, bóng mềm */
export const palette = {
  primary: { main: '#0288D1', light: '#4FC3F7', dark: '#01579B' },
  secondary: { main: '#0288D1' },
  error: { main: '#E64A19' },
  income: '#22C55E',
  expense: '#EF4444',
  gradientStart: '#E0F2FE',
  gradientMid: '#F0F9FF',
  backgroundDefault: '#F1F5F9',
  surface: '#F8FAFC',
  textPrimary: '#0F172A',
  textSecondary: '#64748B',
  textMuted: '#94A3B8',
  outline: 'rgba(15, 23, 42, 0.08)',
  shadowSoft: '0 1px 2px rgba(15, 23, 42, 0.04), 0 4px 16px rgba(15, 23, 42, 0.06)',
  shadowLift: '0 4px 24px rgba(15, 23, 42, 0.08)',
  robotFace: '#0288D1',
  robotBody: '#0288D1',
  chartCategory: [
    '#0288D1',
    '#D32F2F',
    '#4CAF50',
    '#FF9800',
    '#9C27B0',
    '#00ACC1',
    '#795548',
    '#E91E63',
    '#3F51B5',
    '#8BC34A',
    '#FFC107',
    '#607D8B',
    '#FF7043',
    '#5C6BC0',
  ],
} as const;

export function chartCategoryColor(index: number): string {
  return palette.chartCategory[index % palette.chartCategory.length];
}

const base: ThemeOptions = {
  shape: { borderRadius: 14 },
  typography: {
    fontFamily: '"Nunito", "Roboto", "Helvetica", "Arial", sans-serif',
    h3: { fontWeight: 800, letterSpacing: '-0.02em' },
    h4: { fontWeight: 800, letterSpacing: '-0.02em' },
    h5: { fontWeight: 700, letterSpacing: '-0.01em' },
    h6: { fontWeight: 700, letterSpacing: '-0.01em' },
    subtitle1: { fontWeight: 600 },
    subtitle2: { fontWeight: 600, letterSpacing: '0.02em' },
    body1: { lineHeight: 1.65 },
    body2: { lineHeight: 1.6 },
    button: { textTransform: 'none', fontWeight: 600, letterSpacing: '0.02em' },
  },
  components: {
    MuiCssBaseline: {
      styleOverrides: {
        body: {
          WebkitFontSmoothing: 'antialiased',
          MozOsxFontSmoothing: 'grayscale',
        },
      },
    },
    MuiButton: {
      defaultProps: { disableElevation: true },
      styleOverrides: {
        root: { borderRadius: 14, paddingTop: 12, paddingBottom: 12 },
        containedPrimary: {
          boxShadow: '0 2px 8px rgba(2, 136, 209, 0.28)',
          '&:hover': {
            boxShadow: '0 4px 16px rgba(2, 136, 209, 0.38)',
          },
        },
      },
    },
    MuiCard: {
      defaultProps: { elevation: 0 },
      styleOverrides: {
        root: ({ theme, ownerState }) => {
          const dark = theme.palette.mode === 'dark';
          const base = { borderRadius: 20 };
          if (ownerState.variant === 'outlined') {
            return {
              ...base,
              boxShadow: 'none',
              border: `1px solid ${dark ? 'rgba(255,255,255,0.12)' : palette.outline}`,
            };
          }
          return {
            ...base,
            border: `1px solid ${dark ? 'rgba(255,255,255,0.08)' : palette.outline}`,
            boxShadow: dark ? '0 4px 24px rgba(0,0,0,0.35)' : palette.shadowSoft,
          };
        },
      },
    },
    MuiPaper: {
      styleOverrides: {
        rounded: { borderRadius: 20 },
      },
    },
    MuiTextField: {
      defaultProps: { variant: 'outlined' },
    },
    MuiOutlinedInput: {
      styleOverrides: {
        root: ({ theme }) => ({
          borderRadius: 14,
          backgroundColor:
            theme.palette.mode === 'dark' ? theme.palette.grey[800] : '#FFFFFF',
          transition: 'box-shadow 0.2s ease, border-color 0.2s ease',
          '&:hover .MuiOutlinedInput-notchedOutline': {
            borderColor: theme.palette.primary.light,
          },
          '&.Mui-focused': {
            boxShadow: `0 0 0 3px ${theme.palette.primary.main}22`,
          },
        }),
      },
    },
    MuiFab: {
      styleOverrides: {
        root: {
          borderRadius: 18,
          boxShadow: '0 8px 24px rgba(2, 136, 209, 0.4), 0 2px 8px rgba(15, 23, 42, 0.12)',
          '&:hover': {
            boxShadow: '0 12px 28px rgba(2, 136, 209, 0.45), 0 4px 12px rgba(15, 23, 42, 0.14)',
          },
        },
      },
    },
    MuiChip: {
      styleOverrides: {
        root: { fontWeight: 600, borderRadius: 12 },
      },
    },
    MuiToggleButton: {
      styleOverrides: {
        root: { borderRadius: 12, textTransform: 'none', fontWeight: 600 },
      },
    },
    MuiAppBar: {
      styleOverrides: {
        root: ({ theme }) => ({
          backdropFilter: 'saturate(180%) blur(12px)',
          backgroundColor:
            theme.palette.mode === 'dark'
              ? 'rgba(30, 41, 59, 0.85)'
              : 'rgba(248, 250, 252, 0.85)',
        }),
      },
    },
  },
};

export const lightTheme = createTheme({
  ...base,
  palette: {
    mode: 'light',
    primary: { main: palette.primary.main, light: palette.primary.light, dark: palette.primary.dark },
    secondary: { main: palette.secondary.main },
    error: { main: palette.error.main },
    background: { default: palette.backgroundDefault, paper: '#FFFFFF' },
    text: { primary: palette.textPrimary, secondary: palette.textSecondary },
    divider: 'rgba(15, 23, 42, 0.08)',
  },
});

export const darkTheme = createTheme({
  ...base,
  palette: {
    mode: 'dark',
    primary: { main: palette.primary.light, dark: palette.primary.main, light: '#81D4FA' },
    secondary: { main: palette.primary.main },
    error: { main: palette.error.main },
    background: { default: '#0F172A', paper: '#1E293B' },
    text: { primary: '#F8FAFC', secondary: '#CBD5E1' },
    divider: 'rgba(148, 163, 184, 0.16)',
  },
});
