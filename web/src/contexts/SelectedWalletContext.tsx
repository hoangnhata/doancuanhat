import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { STORAGE_WALLET } from '@/lib/constants';

interface SelectedWalletState {
  selectedWalletId: number | null;
  setSelectedWalletId: (id: number | null) => void;
}

const SelectedWalletContext = createContext<SelectedWalletState | null>(null);

export function SelectedWalletProvider({ children }: { children: ReactNode }) {
  const [selectedWalletId, setId] = useState<number | null>(() => {
    const raw = localStorage.getItem(STORAGE_WALLET);
    if (!raw) return null;
    const n = Number(raw);
    return Number.isFinite(n) ? n : null;
  });

  const setSelectedWalletId = useCallback((id: number | null) => {
    setId(id);
    if (id == null) localStorage.removeItem(STORAGE_WALLET);
    else localStorage.setItem(STORAGE_WALLET, String(id));
  }, []);

  const value = useMemo(
    () => ({ selectedWalletId, setSelectedWalletId }),
    [selectedWalletId, setSelectedWalletId],
  );

  return (
    <SelectedWalletContext.Provider value={value}>
      {children}
    </SelectedWalletContext.Provider>
  );
}

/** Đồng bộ khi mở tab khác */
export function WalletStorageSync() {
  const { setSelectedWalletId } = useSelectedWallet();

  useEffect(() => {
    const onStorage = (e: StorageEvent) => {
      if (e.key !== STORAGE_WALLET) return;
      if (e.newValue == null) setSelectedWalletId(null);
      else {
        const n = Number(e.newValue);
        if (Number.isFinite(n)) setSelectedWalletId(n);
      }
    };
    window.addEventListener('storage', onStorage);
    return () => window.removeEventListener('storage', onStorage);
  }, [setSelectedWalletId]);

  return null;
}

export function useSelectedWallet(): SelectedWalletState {
  const ctx = useContext(SelectedWalletContext);
  if (!ctx) {
    throw new Error(
      'useSelectedWallet must be used within SelectedWalletProvider',
    );
  }
  return ctx;
}
