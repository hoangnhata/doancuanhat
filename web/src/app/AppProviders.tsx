import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { type ReactNode, useState } from 'react';
import { AuthProvider } from '@/contexts/AuthContext';
import {
  AppThemeProvider,
} from '@/contexts/ThemeModeContext';
import { SelectedWalletProvider } from '@/contexts/SelectedWalletContext';

function makeQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 20_000,
        retry: 1,
        /** Quay lại tab / cửa sổ trình duyệt → luôn kéo lại dữ liệu (không cần F5 sau khi mobile đồng bộ). */
        refetchOnWindowFocus: 'always',
        /** Mạng vừa khôi phục (vd. bật Wi‑Fi) → refetch. */
        refetchOnReconnect: true,
        /**
         * Polling nhẹ khi tab đang hiển thị — server không push realtime,
         * nên đây là cách thấy giao dịch/ví mới sau khi app mobile sync.
         */
        refetchInterval: 12_000,
        refetchIntervalInBackground: false,
      },
    },
  });
}

export function AppProviders({ children }: { children: ReactNode }) {
  const [client] = useState(makeQueryClient);

  return (
    <QueryClientProvider client={client}>
      <AppThemeProvider>
        <AuthProvider>
          <SelectedWalletProvider>{children}</SelectedWalletProvider>
        </AuthProvider>
      </AppThemeProvider>
    </QueryClientProvider>
  );
}
