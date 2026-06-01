import { api, clearAuth, persistAuth, type ApiEnvelope } from '@/lib/api';
import { parseUser } from '@/services/mappers';
import type { AuthPayload, User } from '@/types/models';

interface AuthResponseRaw {
  accessToken: string;
  refreshToken: string;
  user: Record<string, unknown>;
}

function mapAuth(raw: AuthResponseRaw): AuthPayload {
  return {
    accessToken: raw.accessToken,
    refreshToken: raw.refreshToken,
    user: parseUser(raw.user),
  };
}

export async function login(email: string, password: string): Promise<AuthPayload> {
  const { data } = await api.post<ApiEnvelope<AuthResponseRaw>>('/auth/login', {
    email,
    password,
  });
  const payload = mapAuth(data.data);
  persistAuth(payload);
  return payload;
}

export async function register(
  fullName: string,
  email: string,
  password: string,
  phone?: string,
): Promise<AuthPayload> {
  const { data } = await api.post<ApiEnvelope<AuthResponseRaw>>('/auth/register', {
    fullName,
    email,
    password,
    ...(phone ? { phone } : {}),
  });
  const payload = mapAuth(data.data);
  persistAuth(payload);
  return payload;
}

/** Bước 1 đăng ký OTP: backend gửi mã 6 số đến email, chưa tạo user thật. */
export async function requestRegistration(
  fullName: string,
  email: string,
  password: string,
  phone?: string,
): Promise<void> {
  await api.post<ApiEnvelope<null>>('/auth/register/request', {
    fullName,
    email,
    password,
    ...(phone ? { phone } : {}),
  });
}

/** Bước 2: verify OTP → backend tạo user thật + trả token. */
export async function verifyRegistration(
  email: string,
  otp: string,
): Promise<AuthPayload> {
  const { data } = await api.post<ApiEnvelope<AuthResponseRaw>>('/auth/register/verify', {
    email,
    otp,
  });
  const payload = mapAuth(data.data);
  persistAuth(payload);
  return payload;
}

export async function resendRegistrationOtp(email: string): Promise<void> {
  await api.post<ApiEnvelope<null>>('/auth/register/resend-otp', { email });
}

export async function forgotPassword(email: string): Promise<void> {
  await api.post<ApiEnvelope<null>>('/auth/forgot-password', { email });
}

export async function resetPassword(
  email: string,
  otp: string,
  newPassword: string,
): Promise<void> {
  await api.post<ApiEnvelope<null>>('/auth/reset-password', {
    email,
    otp,
    newPassword,
  });
}

export async function fetchMe(): Promise<User> {
  const { data } = await api.get<ApiEnvelope<Record<string, unknown>>>('/users/me');
  return parseUser(data.data);
}

export function logout() {
  clearAuth();
}
