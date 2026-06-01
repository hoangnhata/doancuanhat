import { api, type ApiEnvelope } from '@/lib/api';
import { parseCategory } from '@/services/mappers';
import type { RecurringTransaction } from '@/types/models';

function parseRecurring(raw: Record<string, unknown>): RecurringTransaction {
  const cat = raw.category as Record<string, unknown> | undefined;
  const typeStr = String(raw.type ?? 'EXPENSE').toUpperCase();
  return {
    id: Number(raw.id),
    amount: Number(raw.amount ?? 0),
    description: (raw.description as string | null) ?? undefined,
    type: typeStr === 'INCOME' ? 'INCOME' : 'EXPENSE',
    dayOfMonth: Number(raw.dayOfMonth ?? 1),
    categoryId: Number(raw.categoryId),
    walletId: raw.walletId != null ? Number(raw.walletId) : undefined,
    active: Boolean(raw['isActive'] ?? true),
    category: cat ? parseCategory(cat) : undefined,
  };
}

export async function fetchRecurring(): Promise<RecurringTransaction[]> {
  const { data } = await api.get<ApiEnvelope<Record<string, unknown>[]>>(
    '/recurring-transactions',
  );
  return (data.data ?? []).map((r) =>
    parseRecurring(r as Record<string, unknown>),
  );
}

export async function createRecurring(body: {
  type: 'EXPENSE' | 'INCOME';
  amount: number;
  description?: string;
  dayOfMonth: number;
  startDate: string;
  endDate?: string;
  categoryId: number;
}): Promise<RecurringTransaction> {
  const { data } = await api.post<ApiEnvelope<Record<string, unknown>>>(
    '/recurring-transactions',
    body,
  );
  return parseRecurring(data.data as Record<string, unknown>);
}

export async function deleteRecurring(id: number): Promise<void> {
  await api.delete(`/recurring-transactions/${id}`);
}

export async function toggleRecurring(id: number): Promise<void> {
  await api.patch(`/recurring-transactions/${id}/toggle`);
}
