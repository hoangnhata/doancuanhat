import { api, type ApiEnvelope } from '@/lib/api';
import {
  mapAiCategorizeBatchRow,
  mapAiCategorizeResponse,
} from '@/lib/transactionTextParse';
import { parseTransaction } from '@/services/mappers';
import type {
  AICategorizeResponse,
  PageResponse,
  Transaction,
} from '@/types/models';

export interface TransactionFilters {
  type?: 'EXPENSE' | 'INCOME';
  categoryId?: number;
  walletId?: number | null;
  startDate?: string;
  endDate?: string;
}

export async function fetchTransaction(id: number): Promise<Transaction> {
  const { data } = await api.get<ApiEnvelope<Record<string, unknown>>>(
    `/transactions/${id}`,
  );
  return parseTransaction(data.data as Record<string, unknown>);
}

export async function fetchTransactionsPage(
  page: number,
  size: number,
  filters?: TransactionFilters,
): Promise<PageResponse<Transaction>> {
  const { data } = await api.get<ApiEnvelope<Record<string, unknown>>>(
    '/transactions',
    {
      params: {
        page,
        size,
        ...(filters?.type ? { type: filters.type } : {}),
        ...(filters?.categoryId != null
          ? { categoryId: filters.categoryId }
          : {}),
        ...(filters?.walletId != null ? { walletId: filters.walletId } : {}),
        ...(filters?.startDate ? { startDate: filters.startDate } : {}),
        ...(filters?.endDate ? { endDate: filters.endDate } : {}),
      },
    },
  );
  const d = data.data;
  const content = (d.content as Record<string, unknown>[]) ?? [];
  return {
    content: content.map((row) => parseTransaction(row)),
    page: Number(d.page ?? 0),
    size: Number(d.size ?? 0),
    totalElements: Number(d.totalElements ?? 0),
    totalPages: Number(d.totalPages ?? 0),
  };
}

export async function createTransaction(body: {
  type: 'EXPENSE' | 'INCOME';
  amount: number;
  description?: string;
  transactionDate: string;
  categoryId: number;
  walletId?: number | null;
}): Promise<Transaction> {
  const { data } = await api.post<ApiEnvelope<Record<string, unknown>>>(
    '/transactions',
    body,
  );
  return parseTransaction(data.data as Record<string, unknown>);
}

export async function updateTransaction(
  id: number,
  body: {
    type: 'EXPENSE' | 'INCOME';
    amount: number;
    description?: string;
    transactionDate: string;
    categoryId: number;
    walletId?: number | null;
  },
): Promise<Transaction> {
  const { data } = await api.put<ApiEnvelope<Record<string, unknown>>>(
    `/transactions/${id}`,
    body,
  );
  return parseTransaction(data.data as Record<string, unknown>);
}

export async function deleteTransaction(id: number): Promise<void> {
  await api.delete(`/transactions/${id}`);
}

export async function aiCategorize(
  text: string,
  personality?: string | null,
): Promise<AICategorizeResponse> {
  const { data } = await api.post<ApiEnvelope<Record<string, unknown>>>(
    '/transactions/ai/categorize',
    { text, ...(personality ? { personality } : {}) },
    { timeout: 20_000 },
  );
  return mapAiCategorizeResponse(data.data as Record<string, unknown>);
}

export interface ChatAssistantResult {
  reply: string;
  engine: string; // 'gemini' | 'rule' | 'error' | 'unknown'
}

export async function askAssistant(message: string): Promise<ChatAssistantResult> {
  const { data } = await api.post<ApiEnvelope<Record<string, unknown>>>(
    '/ai/chat',
    { message },
    { timeout: 30_000 },
  );
  const d = data.data;
  return {
    reply: (d.reply as string | null) ?? 'Không có phản hồi.',
    engine: (d.engine as string | null) ?? 'unknown',
  };
}

export interface AISuggestionItem {
  categoryName: string;
  amount: number;
  suggestion: string;
  percentPossible: number;
}

export async function fetchSuggestions(): Promise<AISuggestionItem[]> {
  const { data } = await api.get<ApiEnvelope<Record<string, unknown>[]>>('/ai/suggestions');
  const list = data.data ?? [];
  return list.map((item) => ({
    categoryName: String(item.categoryName ?? ''),
    amount: Number(item.amount ?? 0),
    suggestion: String(item.suggestion ?? ''),
    percentPossible: Number(item.percentPossible ?? 0),
  }));
}

export interface OcrReceiptResult {
  transactionType: 'EXPENSE' | 'INCOME';
  amount: number | null;
  transactionDate: string | null;
  merchant: string | null;
  description: string | null;
  categoryName: string | null;
  categoryId: number | null;
  confidence: number | null;
  needsReview: boolean;
  ocrEngine: string | null;
  bankTransfer: boolean;
  senderName: string | null;
  recipientName: string | null;
}

export async function ocrReceipt(file: File): Promise<OcrReceiptResult> {
  const form = new FormData();
  form.append('file', file, file.name || 'receipt.jpg');
  const { data } = await api.post<ApiEnvelope<Record<string, unknown>>>(
    '/transactions/ai/ocr/receipt',
    form,
    {
      headers: { 'Content-Type': 'multipart/form-data' },
      timeout: 60_000,
    },
  );
  const d = data.data;
  return {
    transactionType:
      (d.transactionType as string | null)?.toUpperCase() === 'INCOME'
        ? 'INCOME'
        : 'EXPENSE',
    amount: d.amount != null ? Number(d.amount) : null,
    transactionDate: (d.transactionDate as string | null) ?? null,
    merchant: (d.merchant as string | null) ?? null,
    description: (d.description as string | null) ?? null,
    categoryName: (d.categoryName as string | null) ?? null,
    categoryId: d.categoryId != null ? Number(d.categoryId) : null,
    confidence: d.confidence != null ? Number(d.confidence) : null,
    needsReview: Boolean(d.needsReview ?? true),
    ocrEngine: (d.ocrEngine as string | null) ?? null,
    bankTransfer: Boolean(d.bankTransfer ?? false),
    senderName: (d.senderName as string | null) ?? null,
    recipientName: (d.recipientName as string | null) ?? null,
  };
}

export async function aiCategorizeBatch(
  text: string,
  personality?: string | null,
): Promise<AICategorizeResponse[]> {
  const { data } = await api.post<ApiEnvelope<unknown>>(
    '/transactions/ai/categorize/batch',
    { text, ...(personality ? { personality } : {}) },
  );

  const raw = (data.data as unknown[]) ?? [];
  return raw.map((row) => mapAiCategorizeBatchRow(row));
}
