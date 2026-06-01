import { Alert, Box, Snackbar, Typography } from '@mui/material';
import { useQuery } from '@tanstack/react-query';
import { useCallback, useState } from 'react';
import { GradientBackground } from '@/components/common/GradientBackground';
import { SpendingForecastCard } from '@/components/dashboard/SpendingForecastCard';
import { useSelectedWallet } from '@/contexts/SelectedWalletContext';
import { extractApiError } from '@/lib/api';
import type { SpendingForecast } from '@/types/models';
import * as statisticsService from '@/services/statisticsService';
import * as walletService from '@/services/walletService';

export function SpendingForecastPage() {
  const { selectedWalletId } = useSelectedWallet();
  const walletId = selectedWalletId ?? undefined;

  const [forecast, setForecast] = useState<SpendingForecast | null>(null);
  const [forecastLoading, setForecastLoading] = useState(false);
  const [forecastError, setForecastError] = useState<string | null>(null);
  const [snackOpen, setSnackOpen] = useState(false);
  const [snackMsg, setSnackMsg] = useState('');

  const { data: wallets = [] } = useQuery({
    queryKey: ['wallets'],
    queryFn: walletService.fetchWallets,
  });

  const { data: eligibility, isLoading: eligibilityLoading } = useQuery({
    queryKey: ['forecast-eligibility', walletId],
    queryFn: () => statisticsService.getForecastEligibility(walletId),
    enabled: walletId != null,
  });

  const walletLabel = wallets.find((w) => w.id === selectedWalletId)?.name;

  const runForecast = useCallback(async () => {
    if (walletId == null) return;
    setForecastLoading(true);
    setForecastError(null);
    setForecast(null);
    try {
      const f = await statisticsService.getSpendingForecast(walletId);
      setForecast(f);
    } catch (e) {
      setForecastError(extractApiError(e));
    } finally {
      setForecastLoading(false);
    }
  }, [walletId]);

  const handleRun = () => {
    if (walletId == null) {
      setSnackMsg('Vui lòng chọn ví trên Trang chủ trước khi xem dự báo.');
      setSnackOpen(true);
      return;
    }
    if (!eligibility?.eligible && eligibility?.messageVi) {
      setSnackMsg(eligibility.messageVi);
      setSnackOpen(true);
      return;
    }
    void runForecast();
  };

  return (
    <GradientBackground>
      <Box sx={{ p: { xs: 2, md: 3 }, pb: 10, maxWidth: 900, mx: 'auto' }}>
        <Typography variant="h5" fontWeight={800} gutterBottom>
          Dự báo chi tiêu
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 2, maxWidth: 560 }}>
          Ước lượng chi tuần tới dựa trên lịch sử ví đang chọn. Chỉ khả dụng khi đã có đủ ngày có chi trong cửa sổ gần nhất.
        </Typography>

        {walletId == null && (
          <Alert severity="info" sx={{ mb: 2 }}>
            Chọn một ví trên Trang chủ để xem dự báo theo ví đó.
          </Alert>
        )}

        {!eligibilityLoading &&
          eligibility &&
          !eligibility.eligible &&
          eligibility.messageVi && (
            <Alert severity="warning" sx={{ mb: 2 }}>
              {eligibility.messageVi}
            </Alert>
          )}

        <SpendingForecastCard
          loading={forecastLoading || (walletId != null && eligibilityLoading)}
          error={forecastError}
          forecast={forecast}
          onRun={handleRun}
          walletLabel={walletLabel}
        />

        <Snackbar
          open={snackOpen}
          autoHideDuration={8000}
          onClose={() => setSnackOpen(false)}
          message={snackMsg}
          anchorOrigin={{ vertical: 'bottom', horizontal: 'center' }}
        />
      </Box>
    </GradientBackground>
  );
}
