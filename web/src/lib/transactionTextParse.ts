/** Trích ngày dd/mm/yyyy từ câu nhập (fallback khi API thiếu field). */
export function extractDateFromNaturalText(text: string): string | null {
  const t = text.trim();
  if (!t) return null;

  const m = t.match(
    /(?:ngày\s+)?(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})\b/i,
  );
  if (!m) return null;

  const day = Number(m[1]);
  const month = Number(m[2]);
  let year = Number(m[3]);
  if (year < 100) year += 2000;

  const mm = String(month).padStart(2, '0');
  const dd = String(day).padStart(2, '0');
  return `${year}-${mm}-${dd}`;
}

/** Chuẩn hóa transactionDate từ API (string | array | object). */
export function normalizeTransactionDate(raw: unknown): string | null {
  if (raw == null) return null;

  if (typeof raw === 'string') {
    const s = raw.trim();
    if (!s) return null;
    if (/^\d{4}-\d{2}-\d{2}/.test(s)) return s.slice(0, 10);
    const vn = s.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
    if (vn) {
      const y = vn[3];
      const mm = vn[2].padStart(2, '0');
      const dd = vn[1].padStart(2, '0');
      return `${y}-${mm}-${dd}`;
    }
    return null;
  }

  if (Array.isArray(raw) && raw.length >= 3) {
    const y = Number(raw[0]);
    const m = Number(raw[1]);
    const d = Number(raw[2]);
    if (!Number.isNaN(y) && !Number.isNaN(m) && !Number.isNaN(d)) {
      return `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
    }
  }

  if (typeof raw === 'object') {
    const o = raw as Record<string, unknown>;
    const y = o.year ?? o.Year;
    const m = o.month ?? o.monthValue ?? o.Month;
    const d = o.day ?? o.dayOfMonth ?? o.Day;
    if (y != null && m != null && d != null) {
      return `${Number(y)}-${String(Number(m)).padStart(2, '0')}-${String(Number(d)).padStart(2, '0')}`;
    }
  }

  return null;
}

function mapAiRow(d: Record<string, unknown>): import('@/types/models').AICategorizeResponse {
  const txDate =
    normalizeTransactionDate(d.transactionDate) ??
    normalizeTransactionDate(d.transaction_date);

  return {
    transactionType: (d.transactionType as string | null) ?? undefined,
    categoryName: String(d.categoryName ?? ''),
    categoryId: d.categoryId != null ? Number(d.categoryId) : null,
    amount: d.amount != null ? Number(d.amount) : null,
    description: (d.description as string | null) ?? undefined,
    transactionDate: txDate,
    suggestedCategoryName: (d.suggestedCategoryName as string | null) ?? undefined,
    rollyResponse: (d.rollyResponse as string | null) ?? undefined,
  };
}

export function mapAiCategorizeResponse(
  d: Record<string, unknown>,
): import('@/types/models').AICategorizeResponse {
  return mapAiRow(d);
}

export function mapAiCategorizeBatchRow(
  row: unknown,
): import('@/types/models').AICategorizeResponse {
  return mapAiRow(row as Record<string, unknown>);
}
