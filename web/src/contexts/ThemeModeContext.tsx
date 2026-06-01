import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { ThemeProvider, CssBaseline } from '@mui/material';
import { STORAGE_THEME } from '@/lib/constants';
import { darkTheme, lightTheme } from '@/theme';

type Mode = 'light' | 'dark' | 'system';
type Effective = 'light' | 'dark';

interface ThemeModeState {
  /** Mode user đã chọn (có thể là 'system'). */
  mode: Mode;
  /** Mode đang áp dụng thực tế ('light' | 'dark'). */
  effective: Effective;
  setMode: (value: Mode) => void;
  /** Giữ API cũ — toggle giữa light/dark. */
  setDark: (value: boolean) => void;
  toggle: () => void;
}

const ThemeModeContext = createContext<ThemeModeState | null>(null);

function readMode(): Mode {
  const v = localStorage.getItem(STORAGE_THEME);
  if (v === 'dark' || v === 'light' || v === 'system') return v;
  return 'system';
}

function systemEffective(): Effective {
  if (typeof window === 'undefined' || !window.matchMedia) return 'light';
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

export function AppThemeProvider({ children }: { children: ReactNode }) {
  const [mode, setModeState] = useState<Mode>(() =>
    typeof window === 'undefined' ? 'system' : readMode(),
  );
  const [systemPref, setSystemPref] = useState<Effective>(() => systemEffective());

  // Theo dõi thay đổi prefers-color-scheme khi đang ở mode 'system'.
  useEffect(() => {
    if (typeof window === 'undefined' || !window.matchMedia) return;
    const mq = window.matchMedia('(prefers-color-scheme: dark)');
    const handler = () => setSystemPref(mq.matches ? 'dark' : 'light');
    mq.addEventListener('change', handler);
    return () => mq.removeEventListener('change', handler);
  }, []);

  const setMode = useCallback((value: Mode) => {
    setModeState(value);
    localStorage.setItem(STORAGE_THEME, value);
  }, []);

  const effective: Effective = mode === 'system' ? systemPref : mode;

  const setDark = useCallback((value: boolean) => {
    setMode(value ? 'dark' : 'light');
  }, [setMode]);

  const toggle = useCallback(() => {
    setDark(effective !== 'dark');
  }, [effective, setDark]);

  const theme = effective === 'dark' ? darkTheme : lightTheme;

  const value = useMemo(
    () => ({ mode, effective, setMode, setDark, toggle }),
    [mode, effective, setMode, setDark, toggle],
  );

  return (
    <ThemeModeContext.Provider value={value}>
      <ThemeProvider theme={theme}>
        <CssBaseline />
        {children}
      </ThemeProvider>
    </ThemeModeContext.Provider>
  );
}

export function useThemeMode(): ThemeModeState {
  const ctx = useContext(ThemeModeContext);
  if (!ctx) throw new Error('useThemeMode must be used within AppThemeProvider');
  return ctx;
}
