import { api, type ApiEnvelope } from "@/lib/api";
import type { Wallet } from "@/types/models";

function parseWallet(raw: Record<string, unknown>): Wallet {
  return {
    id: Number(raw.id),
    name: String(raw.name ?? ""),
    currencyCode: String(raw.currencyCode ?? "VND"),
    initialBalance: Number(raw.initialBalance ?? 0),
    currentBalance:
      raw.currentBalance != null ? Number(raw.currentBalance) : undefined,
    isDefault: Boolean(raw.isDefault),
  };
}

export async function fetchWallets(): Promise<Wallet[]> {
  const { data } =
    await api.get<ApiEnvelope<Record<string, unknown>[]>>("/wallets");
  return (data.data ?? []).map((w) =>
    parseWallet(w as Record<string, unknown>),
  );
}

export async function createWallet(body: {
  name: string;
  currencyCode: string;
  initialBalance: number;
  isDefault?: boolean;
}): Promise<Wallet> {
  const { data } = await api.post<ApiEnvelope<Record<string, unknown>>>(
    "/wallets",
    body,
  );
  return parseWallet(data.data as Record<string, unknown>);
}

export async function updateWallet(
  id: number,
  body: {
    name: string;
    currencyCode: string;
    initialBalance: number;
    isDefault?: boolean;
  },
): Promise<Wallet> {
  const { data } = await api.put<ApiEnvelope<Record<string, unknown>>>(
    `/wallets/${id}`,
    body,
  );
  return parseWallet(data.data as Record<string, unknown>);
}

export async function deleteWallet(id: number): Promise<void> {
  await api.delete(`/wallets/${id}`);
}
