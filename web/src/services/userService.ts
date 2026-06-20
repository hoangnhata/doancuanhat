import { api, type ApiEnvelope } from '@/lib/api';
import { parseUser } from '@/services/mappers';
import { STORAGE_USER } from '@/lib/constants';
import type { User } from '@/types/models';

export async function patchProfile(body: {
  fullName?: string;
  phone?: string | null;
  botPersonality?: 'HAPPY' | 'SAD' | 'ANGRY';
  botSetupCompleted?: boolean;
  onboardingCompleted?: boolean;
  walletSetupCompleted?: boolean;
  savingGoalSetupCompleted?: boolean;
  savingGoalSetupSkipped?: boolean;
  spendingLimitSetupCompleted?: boolean;
  spendingLimitSetupSkipped?: boolean;
  onboardingStep?: string;
  walletName?: string;
  currencyCode?: string;
  initialBalance?: number;
}): Promise<User> {
  const { data } = await api.patch<ApiEnvelope<Record<string, unknown>>>(
    '/users/me/profile',
    body,
  );
  const u = parseUser(data.data as Record<string, unknown>);
  localStorage.setItem(STORAGE_USER, JSON.stringify(u));
  return u;
}

export async function changePassword(
  currentPassword: string,
  newPassword: string,
): Promise<void> {
  await api.patch('/users/me/password', { currentPassword, newPassword });
}
