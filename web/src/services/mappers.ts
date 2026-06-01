import type {
  Category,
  Transaction,
  User,
} from '@/types/models';

export function parseUser(raw: Record<string, unknown>): User {
  return {
    id: Number(raw.id),
    fullName: String(raw.fullName ?? ''),
    email: String(raw.email ?? ''),
    phone: (raw.phone as string | null) ?? undefined,
    botPersonality: (raw.botPersonality as string | null) ?? undefined,
    onboardingCompleted: Boolean(raw.onboardingCompleted ?? false),
    savingsGoalMonthly:
      raw.savingsGoalMonthly != null
        ? Number(raw.savingsGoalMonthly)
        : undefined,
  };
}

export function parseCategory(raw: Record<string, unknown>): Category {
  const t = String(raw.type ?? 'EXPENSE').toUpperCase();
  return {
    id: Number(raw.id),
    name: String(raw.name ?? ''),
    description: (raw.description as string | null) ?? undefined,
    icon: (raw.icon as string | null) ?? undefined,
    type: t === 'INCOME' ? 'INCOME' : 'EXPENSE',
  };
}

export function parseTransaction(raw: Record<string, unknown>): Transaction {
  const cat = raw.category as Record<string, unknown>;
  const wallet = raw.wallet as Record<string, unknown> | undefined | null;
  const typeStr = String(raw.type ?? 'EXPENSE').toUpperCase();
  return {
    id: Number(raw.id),
    type: typeStr === 'INCOME' ? 'INCOME' : 'EXPENSE',
    amount: Number(raw.amount ?? 0),
    description: (raw.description as string | null) ?? undefined,
    transactionDate: String(raw.transactionDate ?? ''),
    category: parseCategory(cat),
    walletId: wallet?.id != null ? Number(wallet.id) : undefined,
    createdAt: String(raw.createdAt ?? ''),
  };
}
