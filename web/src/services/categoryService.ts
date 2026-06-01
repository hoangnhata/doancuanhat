import { api, type ApiEnvelope } from '@/lib/api';
import { parseCategory } from '@/services/mappers';
import type { Category } from '@/types/models';

export async function fetchCategories(
  type?: 'EXPENSE' | 'INCOME',
): Promise<Category[]> {
  if (type) {
    const { data } = await api.get<ApiEnvelope<Record<string, unknown>[]>>(
      `/categories/by-type/${type}`,
    );
    return (data.data ?? []).map((c) =>
      parseCategory(c as Record<string, unknown>),
    );
  }
  const { data } = await api.get<
    ApiEnvelope<{
      content: Record<string, unknown>[];
    }>
  >('/categories', { params: { page: 0, size: 200 } });
  const content = data.data?.content ?? [];
  return content.map((c) => parseCategory(c));
}

export async function createCategory(body: {
  name: string;
  description?: string;
  icon?: string;
  type: 'EXPENSE' | 'INCOME';
}): Promise<Category> {
  const { data } = await api.post<ApiEnvelope<Record<string, unknown>>>(
    '/categories',
    body,
  );
  return parseCategory(data.data as Record<string, unknown>);
}

export async function updateCategory(
  id: number,
  body: {
    name: string;
    description?: string;
    icon?: string;
    type: 'EXPENSE' | 'INCOME';
  },
): Promise<Category> {
  const { data } = await api.put<ApiEnvelope<Record<string, unknown>>>(
    `/categories/${id}`,
    body,
  );
  return parseCategory(data.data as Record<string, unknown>);
}

export async function deleteCategory(id: number): Promise<void> {
  await api.delete(`/categories/${id}`);
}
