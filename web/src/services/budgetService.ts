import { api, type ApiEnvelope } from '@/lib/api';
import { parseCategory } from '@/services/mappers';
import type { Budget } from '@/types/models';

function parseBudget(raw: Record<string, unknown>): Budget {
  const cat = raw.category as Record<string, unknown> | undefined;
  return {
    id: Number(raw.id),
    amount: Number(raw.amount ?? 0),
    startDate: String(raw.startDate ?? ''),
    endDate: String(raw.endDate ?? ''),
    categoryId: cat ? Number(cat.id) : Number(raw.categoryId ?? 0),
    note: (raw.note as string | null) ?? undefined,
    category: cat ? parseCategory(cat) : undefined,
  };
}

export async function fetchBudgets(): Promise<Budget[]> {
  const { data } = await api.get<
    ApiEnvelope<{ content: Record<string, unknown>[] }>
  >('/budgets', { params: { page: 0, size: 100 } });
  const content = data.data?.content ?? [];
  return content.map((b) => parseBudget(b as Record<string, unknown>));
}

export async function createBudget(body: {
  amount: number;
  startDate: string;
  endDate: string;
  categoryId: number;
  note?: string;
}): Promise<Budget> {
  const { data } = await api.post<ApiEnvelope<Record<string, unknown>>>(
    '/budgets',
    body,
  );
  return parseBudget(data.data as Record<string, unknown>);
}

export async function deleteBudget(id: number): Promise<void> {
  await api.delete(`/budgets/${id}`);
}
