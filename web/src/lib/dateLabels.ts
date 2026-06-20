import { format } from 'date-fns';
import { vi } from 'date-fns/locale';

/** Hiển thị: "Tháng Sáu 2026" */
export function formatMonthYearLabel(year: number, month: number): string {
  const d = new Date(year, month - 1, 1);
  const raw = format(d, "MMMM yyyy", { locale: vi });
  return raw.charAt(0).toUpperCase() + raw.slice(1);
}

/** Nhãn ngắn trong lưới: "T1" … "T12" */
export function formatMonthShort(month: number): string {
  return `T${month}`;
}

/** Nhãn đầy đủ trong lưới: "Tháng 6" */
export function formatMonthGridLabel(month: number): string {
  const d = new Date(2026, month - 1, 1);
  const raw = format(d, 'MMMM', { locale: vi });
  return raw.charAt(0).toUpperCase() + raw.slice(1);
}

export function isSameMonthYear(
  a: { year: number; month: number },
  b: { year: number; month: number },
): boolean {
  return a.year === b.year && a.month === b.month;
}

export function currentMonthYear(): { year: number; month: number } {
  const now = new Date();
  return { year: now.getFullYear(), month: now.getMonth() + 1 };
}
