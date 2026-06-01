import { api, type ApiEnvelope } from '@/lib/api';
import type {
  DaySummary,
  ForecastBudgetAlert,
  ForecastEligibility,
  ForecastInsight,
  SpendingForecast,
  Statistics,
} from '@/types/models';

function parseBudgetAlerts(raw: unknown): ForecastBudgetAlert[] {
  if (!Array.isArray(raw)) return [];
  return raw.map((x) => {
    const o = x as Record<string, unknown>;
    const sev = String(o.severity ?? 'OK');
    return {
      categoryName: String(o.categoryName ?? ''),
      budgetAmountVnd: Number(o.budgetAmountVnd ?? 0),
      spentVnd: Number(o.spentVnd ?? 0),
      remainingVnd: Number(o.remainingVnd ?? 0),
      percentUsed: Number(o.percentUsed ?? 0),
      severity: sev === 'OVER' || sev === 'WARN' || sev === 'OK' ? sev : 'OK',
    };
  });
}

function parseInsight(raw: unknown): ForecastInsight | undefined {
  if (raw == null || typeof raw !== 'object') return undefined;
  const o = raw as Record<string, unknown>;
  const tips = o.tipsVi;
  const level = String(o.level ?? 'OK');
  return {
    totalNext7DaysVnd: Number(o.totalNext7DaysVnd ?? 0),
    avgPerDayVnd: Number(o.avgPerDayVnd ?? 0),
    baseline7DaysVnd: Number(o.baseline7DaysVnd ?? 0),
    paceVsBaselinePercent:
      o.paceVsBaselinePercent === null || o.paceVsBaselinePercent === undefined
        ? null
        : Number(o.paceVsBaselinePercent),
    level: level === 'ALERT' || level === 'WATCH' || level === 'OK' ? level : 'OK',
    headlineVi: String(o.headlineVi ?? ''),
    tipsVi: Array.isArray(tips) ? tips.map((t) => String(t)) : [],
    expenseMonthToDateVnd:
      o.expenseMonthToDateVnd === null || o.expenseMonthToDateVnd === undefined
        ? null
        : Number(o.expenseMonthToDateVnd),
    forecastOverlapSameMonthVnd:
      o.forecastOverlapSameMonthVnd === null || o.forecastOverlapSameMonthVnd === undefined
        ? null
        : Number(o.forecastOverlapSameMonthVnd),
    projectedMonthFloorVnd:
      o.projectedMonthFloorVnd === null || o.projectedMonthFloorVnd === undefined
        ? null
        : Number(o.projectedMonthFloorVnd),
    budgetAlerts: parseBudgetAlerts(o.budgetAlerts),
  };
}

function parseStats(raw: Record<string, unknown>): Statistics {
  const byCategory = (raw.byCategory as Record<string, unknown>[] | undefined) ?? [];
  return {
    totalIncome: Number(raw.totalIncome ?? 0),
    totalExpense: Number(raw.totalExpense ?? 0),
    balance: Number(raw.balance ?? 0),
    byCategory: byCategory.map((c) => ({
      categoryId: Number(c.categoryId),
      categoryName: String(c.categoryName ?? ''),
      amount: Number(c.amount ?? 0),
    })),
  };
}

export async function getStatsByMonth(
  year: number,
  month: number,
  categoryType?: 'EXPENSE' | 'INCOME',
  walletId?: number | null,
): Promise<Statistics> {
  const { data } = await api.get<ApiEnvelope<Record<string, unknown>>>(
    '/statistics/month',
    {
      params: {
        year,
        month,
        ...(categoryType ? { categoryType } : {}),
        ...(walletId != null ? { walletId } : {}),
      },
    },
  );
  return parseStats(data.data);
}

export async function getStatsByYear(
  year: number,
  categoryType?: 'EXPENSE' | 'INCOME',
  walletId?: number | null,
): Promise<Statistics> {
  const { data } = await api.get<ApiEnvelope<Record<string, unknown>>>(
    '/statistics/year',
    {
      params: {
        year,
        ...(categoryType ? { categoryType } : {}),
        ...(walletId != null ? { walletId } : {}),
      },
    },
  );
  return parseStats(data.data);
}

export async function getStatsRange(
  startDate: string,
  endDate: string,
  categoryType?: 'EXPENSE' | 'INCOME',
  walletId?: number | null,
): Promise<Statistics> {
  const { data } = await api.get<ApiEnvelope<Record<string, unknown>>>(
    '/statistics/range',
    {
      params: {
        startDate,
        endDate,
        ...(categoryType ? { categoryType } : {}),
        ...(walletId != null ? { walletId } : {}),
      },
    },
  );
  return parseStats(data.data);
}

export async function getDailyBreakdown(
  startDate: string,
  endDate: string,
): Promise<DaySummary[]> {
  const { data } = await api.get<
    ApiEnvelope<{ days: Record<string, unknown>[] }>
  >('/statistics/daily-breakdown', {
    params: { startDate, endDate },
  });
  return (data.data.days ?? []).map((d) => ({
    date: String(d.date),
    income: Number(d.income ?? 0),
    expense: Number(d.expense ?? 0),
  }));
}

export async function getForecastEligibility(
  walletId?: number | null,
  lastObservationDate?: string | null,
): Promise<ForecastEligibility> {
  const { data } = await api.get<ApiEnvelope<Record<string, unknown>>>(
    '/statistics/spending-forecast/eligibility',
    {
      params: {
        ...(walletId != null ? { walletId } : {}),
        ...(lastObservationDate ? { lastObservationDate } : {}),
      },
    },
  );
  const d = data.data as Record<string, unknown>;
  return {
    eligible: Boolean(d.eligible),
    requiredDaysWithExpense: Number(d.requiredDaysWithExpense ?? 4),
    daysWithExpenseInWindow: Number(d.daysWithExpenseInWindow ?? 0),
    windowDays: Number(d.windowDays ?? 30),
    messageVi:
      d.messageVi === null || d.messageVi === undefined ? null : String(d.messageVi),
  };
}

export async function getSpendingForecast(
  walletId?: number | null,
  lastObservationDate?: string | null,
): Promise<SpendingForecast> {
  const { data } = await api.get<ApiEnvelope<Record<string, unknown>>>(
    '/statistics/spending-forecast',
    {
      params: {
        ...(walletId != null ? { walletId } : {}),
        ...(lastObservationDate ? { lastObservationDate } : {}),
      },
    },
  );
  const d = data.data as Record<string, unknown>;
  const raw = (d.predictedNextDaysVnd as unknown[]) ?? [];
  return {
    predictedNextDaysVnd: raw.map((x) => Number(x)),
    horizon: Number(d.horizon ?? raw.length),
    window: Number(d.window ?? 30),
    lastObservationDate: String(d.lastObservationDate ?? ''),
    insight: parseInsight(d.insight),
  };
}
