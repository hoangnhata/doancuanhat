import { format, isToday, isYesterday } from 'date-fns';

export function dateGroupLabel(dateKey: string): string {
  const d = new Date(`${dateKey}T12:00:00`);
  if (isToday(d)) return 'Hôm nay';
  if (isYesterday(d)) return 'Hôm qua';
  return format(d, 'dd/MM/yyyy');
}

export type DateTransactionGroup<T> = {
  dateKey: string;
  label: string;
  items: T[];
};

export function groupTransactionsByDate<T extends { transactionDate: string }>(
  items: T[],
): DateTransactionGroup<T>[] {
  const map = new Map<string, T[]>();
  for (const item of items) {
    const key = item.transactionDate.slice(0, 10);
    const list = map.get(key) ?? [];
    list.push(item);
    map.set(key, list);
  }

  return Array.from(map.entries())
    .sort((a, b) => b[0].localeCompare(a[0]))
    .map(([dateKey, groupItems]) => ({
      dateKey,
      label: dateGroupLabel(dateKey),
      items: groupItems,
    }));
}

export function summarizeTransactions(
  items: { type: 'EXPENSE' | 'INCOME'; amount: number }[],
) {
  let totalIncome = 0;
  let totalExpense = 0;
  for (const t of items) {
    if (t.type === 'INCOME') totalIncome += t.amount;
    else totalExpense += t.amount;
  }
  return {
    totalIncome,
    totalExpense,
    balance: totalIncome - totalExpense,
    count: items.length,
  };
}
