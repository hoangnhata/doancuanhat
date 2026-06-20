import { api, extractApiError } from '@/lib/api';

function parseFilenameFromContentDisposition(header: string | undefined): string | null {
  if (!header) return null;
  const m = /filename\*?=(?:UTF-8'')?["']?([^"';]+)/i.exec(header);
  return m?.[1]?.trim() ?? null;
}

/**
 * Tải báo cáo giao dịch từ backend (Excel hoặc PDF) và kích hoạt download trên trình duyệt.
 */
export async function downloadTransactionExport(
  format: 'excel' | 'pdf',
  startDate: string,
  endDate: string,
): Promise<void> {
  const params =
    format === 'excel'
      ? { format: 'excel', startDate, endDate }
      : { format: 'pdf', startDate, endDate };

  try {
    const response = await api.get<ArrayBuffer>('/export/transactions', {
      params,
      responseType: 'arraybuffer',
    });

    const mime =
      format === 'excel'
        ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        : 'application/pdf';
    const blob = new Blob([response.data], { type: mime });

    const fromHeader = parseFilenameFromContentDisposition(
      response.headers['content-disposition'] as string | undefined,
    );
    const ext = format === 'excel' ? 'xlsx' : 'pdf';
    const fallback = `bao-cao-giao-dich-${startDate.replace(/-/g, '')}-${endDate.replace(/-/g, '')}.${ext}`;
    const filename = fromHeader ?? fallback;

    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    a.style.display = 'none';
    document.body.appendChild(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(url);
  } catch (e) {
    throw new Error(extractApiError(e));
  }
}
