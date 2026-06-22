import { api, type ApiEnvelope } from '@/lib/api';

export type SpendingLimitStatus = 'SAFE' | 'WARNING' | 'EXCEEDED';
export type PeriodType = 'MONTHLY' | 'WEEKLY' | 'YEARLY' | 'CUSTOM';

export interface SpendingLimit {
  id: number;
  limitAmount: number;
  amount: number;
  startDate: string;
  endDate: string;
  categoryId: number;
  category?: { id: number; name: string; icon?: string | null };
  note?: string | null;
  periodType?: PeriodType;
  warningThresholdPercent?: number;
  isActive?: boolean;
  alertsEnabled?: boolean;
  currentSpent: number;
  spentAmount: number;
  remainingAmount: number;
  usagePercent: number;
  status: SpendingLimitStatus;
  statusMessage?: string | null;
}

export interface SpendingLimitAlert {
  limitId: number;
  categoryId: number;
  categoryName: string;
  limitAmount: number;
  currentSpent: number;
  remainingAmount: number;
  usagePercent: number;
  exceededAmount: number;
  status: SpendingLimitStatus;
  message: string;
}

export interface CheckTransactionResult {
  hasWarning: boolean;
  status?: SpendingLimitStatus;
  message?: string | null;
  currentSpent?: number;
  projectedSpent?: number;
  limitAmount?: number;
  projectedUsagePercent?: number;
  categoryName?: string;
}

function parseLimit(raw: Record<string, unknown>): SpendingLimit {
  const cat = raw.category as Record<string, unknown> | undefined;
  return {
    id: Number(raw.id),
    amount: Number(raw.amount ?? raw.limitAmount ?? 0),
    limitAmount: Number(raw.limitAmount ?? raw.amount ?? 0),
    startDate: String(raw.startDate ?? ''),
    endDate: String(raw.endDate ?? ''),
    categoryId: cat ? Number(cat.id) : Number(raw.categoryId ?? 0),
    category: cat
      ? { id: Number(cat.id), name: String(cat.name ?? ''), icon: cat.icon as string | null }
      : undefined,
    note: (raw.note as string | null) ?? undefined,
    periodType: (raw.periodType as PeriodType) ?? 'MONTHLY',
    warningThresholdPercent: Number(raw.warningThresholdPercent ?? 80),
    isActive: raw.isActive !== false,
    alertsEnabled: raw.alertsEnabled !== false,
    currentSpent: Number(raw.currentSpent ?? raw.spentAmount ?? 0),
    spentAmount: Number(raw.spentAmount ?? raw.currentSpent ?? 0),
    remainingAmount: Number(raw.remainingAmount ?? 0),
    usagePercent: Number(raw.usagePercent ?? 0),
    status: String(raw.status ?? 'SAFE') as SpendingLimitStatus,
    statusMessage: (raw.statusMessage as string | null) ?? undefined,
  };
}

export async function fetchSpendingLimits(): Promise<SpendingLimit[]> {
  const { data } = await api.get<
    ApiEnvelope<{ content: Record<string, unknown>[] }>
  >('/spending-limits', { params: { page: 0, size: 100 } });
  return (data.data?.content ?? []).map((b) =>
    parseLimit(b as Record<string, unknown>),
  );
}

export async function createSpendingLimit(body: {
  amount: number;
  categoryId: number;
  periodType?: PeriodType;
  warningThresholdPercent?: number;
  alertsEnabled?: boolean;
  startDate?: string;
  endDate?: string;
  note?: string;
}): Promise<SpendingLimit> {
  const { data } = await api.post<ApiEnvelope<Record<string, unknown>>>(
    '/spending-limits',
    body,
  );
  return parseLimit(data.data as Record<string, unknown>);
}

export async function deleteSpendingLimit(id: number): Promise<void> {
  await api.delete(`/spending-limits/${id}`);
}

export async function updateSpendingLimit(
  id: number,
  body: {
    amount: number;
    categoryId: number;
    periodType?: PeriodType;
    warningThresholdPercent?: number;
    alertsEnabled?: boolean;
    startDate?: string;
    endDate?: string;
    note?: string;
  },
): Promise<SpendingLimit> {
  const { data } = await api.put<ApiEnvelope<Record<string, unknown>>>(
    `/spending-limits/${id}`,
    body,
  );
  return parseLimit(data.data as Record<string, unknown>);
}

export async function fetchSpendingLimitAlerts(): Promise<SpendingLimitAlert[]> {
  const { data } = await api.get<ApiEnvelope<Record<string, unknown>[]>>(
    '/spending-limits/alerts',
  );
  return (data.data ?? []).map((a) => ({
    limitId: Number(a.limitId),
    categoryId: Number(a.categoryId),
    categoryName: String(a.categoryName ?? ''),
    limitAmount: Number(a.limitAmount ?? 0),
    currentSpent: Number(a.currentSpent ?? 0),
    remainingAmount: Number(a.remainingAmount ?? 0),
    usagePercent: Number(a.usagePercent ?? 0),
    exceededAmount: Number(a.exceededAmount ?? 0),
    status: String(a.status ?? 'WARNING') as SpendingLimitStatus,
    message: String(a.message ?? ''),
  }));
}

export async function checkTransactionLimit(body: {
  categoryId: number;
  amount: number;
  transactionDate: string;
  type: 'EXPENSE' | 'INCOME';
  excludeTransactionId?: number;
}): Promise<CheckTransactionResult> {
  const { data } = await api.post<ApiEnvelope<Record<string, unknown>>>(
    '/spending-limits/check-transaction',
    body,
  );
  const r = data.data as Record<string, unknown>;
  return {
    hasWarning: Boolean(r.hasWarning),
    status: r.status as SpendingLimitStatus | undefined,
    message: (r.message as string | null) ?? undefined,
    currentSpent: r.currentSpent != null ? Number(r.currentSpent) : undefined,
    projectedSpent: r.projectedSpent != null ? Number(r.projectedSpent) : undefined,
    limitAmount: r.limitAmount != null ? Number(r.limitAmount) : undefined,
    projectedUsagePercent:
      r.projectedUsagePercent != null ? Number(r.projectedUsagePercent) : undefined,
    categoryName: r.categoryName as string | undefined,
  };
}
