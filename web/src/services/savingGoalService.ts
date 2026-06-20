import { api, type ApiEnvelope } from '@/lib/api';
import type {
  SavingGoal,
  SavingGoalStatus,
  SavingTransaction,
  SavingTransactionType,
} from '@/types/models';

function parseGoal(raw: Record<string, unknown>): SavingGoal {
  return {
    id: Number(raw.id),
    name: String(raw.name ?? ''),
    targetAmount: Number(raw.targetAmount ?? 0),
    currentAmount: Number(raw.currentAmount ?? 0),
    targetDate: (raw.targetDate as string | null) ?? undefined,
    status: String(raw.status ?? 'ACTIVE') as SavingGoalStatus,
    note: (raw.note as string | null) ?? undefined,
    remainingAmount: Number(raw.remainingAmount ?? 0),
    progressPercent: Number(raw.progressPercent ?? 0),
    isCompleted: Boolean(raw.isCompleted ?? false),
    createdAt: raw.createdAt != null ? String(raw.createdAt) : undefined,
    updatedAt: raw.updatedAt != null ? String(raw.updatedAt) : undefined,
  };
}

function parseSavingTx(raw: Record<string, unknown>): SavingTransaction {
  const wallet = raw.wallet as Record<string, unknown> | undefined;
  return {
    id: Number(raw.id),
    savingGoalId: Number(raw.savingGoalId),
    wallet: wallet
      ? {
          id: Number(wallet.id),
          name: String(wallet.name ?? ''),
          currencyCode: String(wallet.currencyCode ?? 'VND'),
          initialBalance: Number(wallet.initialBalance ?? 0),
          isDefault: Boolean(wallet.isDefault),
        }
      : undefined,
    amount: Number(raw.amount ?? 0),
    type: String(raw.type ?? 'DEPOSIT') as SavingTransactionType,
    note: (raw.note as string | null) ?? undefined,
    createdAt: String(raw.createdAt ?? ''),
  };
}

export async function fetchSavingGoals(): Promise<SavingGoal[]> {
  const { data } = await api.get<ApiEnvelope<Record<string, unknown>[]>>(
    '/saving-goals',
  );
  return (data.data ?? []).map((g) => parseGoal(g as Record<string, unknown>));
}

export async function fetchSavingGoal(id: number): Promise<SavingGoal> {
  const { data } = await api.get<ApiEnvelope<Record<string, unknown>>>(
    `/saving-goals/${id}`,
  );
  return parseGoal(data.data as Record<string, unknown>);
}

export async function createSavingGoal(body: {
  name: string;
  targetAmount: number;
  initialAmount?: number;
  targetDate?: string;
  note?: string;
}): Promise<SavingGoal> {
  const { data } = await api.post<ApiEnvelope<Record<string, unknown>>>(
    '/saving-goals',
    body,
  );
  return parseGoal(data.data as Record<string, unknown>);
}

export async function updateSavingGoal(
  id: number,
  body: {
    name: string;
    targetAmount: number;
    targetDate?: string;
    note?: string;
    status?: SavingGoalStatus;
  },
): Promise<SavingGoal> {
  const { data } = await api.put<ApiEnvelope<Record<string, unknown>>>(
    `/saving-goals/${id}`,
    body,
  );
  return parseGoal(data.data as Record<string, unknown>);
}

export async function deleteSavingGoal(id: number): Promise<void> {
  await api.delete(`/saving-goals/${id}`);
}

export async function depositSavingGoal(
  id: number,
  body: { walletId: number; amount: number; note?: string },
): Promise<SavingGoal> {
  const { data } = await api.post<ApiEnvelope<Record<string, unknown>>>(
    `/saving-goals/${id}/deposit`,
    body,
  );
  return parseGoal(data.data as Record<string, unknown>);
}

export async function withdrawSavingGoal(
  id: number,
  body: { walletId: number; amount: number; note?: string },
): Promise<SavingGoal> {
  const { data } = await api.post<ApiEnvelope<Record<string, unknown>>>(
    `/saving-goals/${id}/withdraw`,
    body,
  );
  return parseGoal(data.data as Record<string, unknown>);
}

export async function fetchSavingTransactions(
  id: number,
): Promise<SavingTransaction[]> {
  const { data } = await api.get<ApiEnvelope<Record<string, unknown>[]>>(
    `/saving-goals/${id}/transactions`,
  );
  return (data.data ?? []).map((t) =>
    parseSavingTx(t as Record<string, unknown>),
  );
}
