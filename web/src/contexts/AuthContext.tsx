import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { STORAGE_ACCESS, STORAGE_USER } from '@/lib/constants';
import * as authService from '@/services/authService';
import type { User } from '@/types/models';

interface AuthState {
  user: User | null;
  loading: boolean;
  login: (email: string, password: string) => Promise<User>;
  register: (
    fullName: string,
    email: string,
    password: string,
    phone?: string,
  ) => Promise<User>;
  /** Hoàn tất verify OTP đăng ký → set user state (backend đã trả token + user info). */
  setAuthUser: (user: User) => void;
  logout: () => void;
  refreshUser: () => Promise<void>;
}

const AuthContext = createContext<AuthState | null>(null);

function readStoredUser(): User | null {
  try {
    const raw = localStorage.getItem(STORAGE_USER);
    if (!raw) return null;
    return JSON.parse(raw) as User;
  } catch {
    return null;
  }
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(() => readStoredUser());
  const [loading, setLoading] = useState(true);

  const refreshUser = useCallback(async () => {
    const u = await authService.fetchMe();
    setUser(u);
    localStorage.setItem(STORAGE_USER, JSON.stringify(u));
  }, []);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const token = localStorage.getItem(STORAGE_ACCESS);
      if (!token) {
        setLoading(false);
        return;
      }
      try {
        const u = await authService.fetchMe();
        if (!cancelled) {
          setUser(u);
          localStorage.setItem(STORAGE_USER, JSON.stringify(u));
        }
      } catch {
        if (!cancelled) {
          authService.logout();
          setUser(null);
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  const login = useCallback(async (email: string, password: string) => {
    const res = await authService.login(email, password);
    setUser(res.user);
    return res.user;
  }, []);

  const register = useCallback(
    async (
      fullName: string,
      email: string,
      password: string,
      phone?: string,
    ) => {
      const res = await authService.register(fullName, email, password, phone);
      setUser(res.user);
      return res.user;
    },
    [],
  );

  const setAuthUser = useCallback((u: User) => {
    setUser(u);
    localStorage.setItem(STORAGE_USER, JSON.stringify(u));
  }, []);

  const logout = useCallback(() => {
    authService.logout();
    setUser(null);
  }, []);

  const value = useMemo(
    () => ({
      user,
      loading,
      login,
      register,
      setAuthUser,
      logout,
      refreshUser,
    }),
    [user, loading, login, register, setAuthUser, logout, refreshUser],
  );

  return (
    <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
  );
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}
