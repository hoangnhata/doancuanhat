import axios, { type AxiosError, type InternalAxiosRequestConfig } from 'axios';
import {
  API_BASE,
  STORAGE_ACCESS,
  STORAGE_REFRESH,
  STORAGE_USER,
} from '@/lib/constants';
import type { AuthPayload, User } from '@/types/models';

export interface ApiEnvelope<T> {
  success: boolean;
  message?: string;
  data: T;
}

function getStoredAccess(): string | null {
  return localStorage.getItem(STORAGE_ACCESS);
}

function getStoredRefresh(): string | null {
  return localStorage.getItem(STORAGE_REFRESH);
}

function persistTokens(access: string, refresh: string) {
  localStorage.setItem(STORAGE_ACCESS, access);
  localStorage.setItem(STORAGE_REFRESH, refresh);
}

export function persistAuth(payload: AuthPayload) {
  persistTokens(payload.accessToken, payload.refreshToken);
  localStorage.setItem(
    STORAGE_USER,
    JSON.stringify({
      id: payload.user.id,
      fullName: payload.user.fullName,
      email: payload.user.email,
      phone: payload.user.phone,
      botPersonality: payload.user.botPersonality,
      onboardingCompleted: payload.user.onboardingCompleted,
      savingsGoalMonthly: payload.user.savingsGoalMonthly,
    } satisfies User),
  );
}

export function clearAuth() {
  localStorage.removeItem(STORAGE_ACCESS);
  localStorage.removeItem(STORAGE_REFRESH);
  localStorage.removeItem(STORAGE_USER);
}

export const api = axios.create({
  baseURL: API_BASE,
  headers: { 'Content-Type': 'application/json' },
});

let refreshPromise: Promise<string | null> | null = null;

async function refreshAccessToken(): Promise<string | null> {
  const refresh = getStoredRefresh();
  if (!refresh) return null;
  try {
    const { data } = await axios.post<ApiEnvelope<AuthPayload>>(
      `${API_BASE}/auth/refresh`,
      {},
      {
        headers: { Authorization: `Bearer ${refresh}` },
      },
    );
    const d = data.data;
    if (d?.accessToken && d?.refreshToken) {
      persistTokens(d.accessToken, d.refreshToken);
      return d.accessToken;
    }
  } catch {
    clearAuth();
  }
  return null;
}

api.interceptors.request.use((config: InternalAxiosRequestConfig) => {
  const skip = config.headers?.['X-Skip-Auth'] === '1';
  if (!skip) {
    const token = getStoredAccess();
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
  }
  return config;
});

api.interceptors.response.use(
  (r) => r,
  async (error: AxiosError) => {
    const original = error.config as InternalAxiosRequestConfig & {
      _retry?: boolean;
    };
    if (
      error.response?.status === 401 &&
      original &&
      !original._retry &&
      !original.headers?.['X-Skip-Auth']
    ) {
      original._retry = true;
      if (!refreshPromise) {
        refreshPromise = refreshAccessToken().finally(() => {
          refreshPromise = null;
        });
      }
      const newAccess = await refreshPromise;
      if (newAccess) {
        original.headers.Authorization = `Bearer ${newAccess}`;
        return api(original);
      }
    }
    return Promise.reject(error);
  },
);

export function extractApiError(err: unknown): string {
  if (axios.isAxiosError(err)) {
    const data = err.response?.data as { message?: string } | undefined;
    if (data?.message) return data.message;
    if (typeof err.message === 'string') return err.message;
  }
  if (err instanceof Error) return err.message;
  return 'Đã có lỗi xảy ra';
}
