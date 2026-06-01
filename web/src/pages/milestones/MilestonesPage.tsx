import {
  Box,
  Button,
  Card,
  CardContent,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  TextField,
  Typography,
} from '@mui/material';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { GradientBackground } from '@/components/common/GradientBackground';
import { useAuth } from '@/contexts/AuthContext';
import { extractApiError } from '@/lib/api';
import { formatMoney } from '@/lib/format';
import * as statisticsService from '@/services/statisticsService';
import * as transactionService from '@/services/transactionService';
import * as userService from '@/services/userService';

export function MilestonesPage() {
  const qc = useQueryClient();
  const { user, refreshUser } = useAuth();
  const [open, setOpen] = useState(false);
  const [goalInput, setGoalInput] = useState('');

  const now = new Date();
  const y = now.getFullYear();
  const m = now.getMonth() + 1;

  const { data: monthStats } = useQuery({
    queryKey: ['stats', 'month', y, m],
    queryFn: () => statisticsService.getStatsByMonth(y, m),
  });

  const { data: txPage } = useQuery({
    queryKey: ['transactions', 'milestone'],
    queryFn: () => transactionService.fetchTransactionsPage(0, 500, {}),
  });

  const savings =
    monthStats != null
      ? Math.max(0, monthStats.totalIncome - monthStats.totalExpense)
      : 0;

  const saveGoal = useMutation({
    mutationFn: () =>
      userService.patchProfile({
        savingsGoalMonthly: Number(goalInput.replace(/\D/g, '')) || null,
      }),
    onSuccess: async () => {
      await refreshUser();
      await qc.invalidateQueries({ queryKey: ['stats'] });
      setOpen(false);
    },
  });

  return (
    <GradientBackground>
      <Box sx={{ p: 2, pb: 10, maxWidth: 560, mx: 'auto' }}>
        <Typography variant="h6" fontWeight={800} gutterBottom>
          Cột mốc & mục tiêu
        </Typography>

        <Card sx={{ mb: 2 }} elevation={2}>
          <CardContent>
            <Typography color="text.secondary">Mục tiêu tiết kiệm tháng</Typography>
            <Typography variant="h5" fontWeight={800}>
              {user?.savingsGoalMonthly
                ? formatMoney(user.savingsGoalMonthly)
                : 'Chưa đặt'}
            </Typography>
            <Button sx={{ mt: 1 }} onClick={() => setOpen(true)}>
              Đặt / sửa mục tiêu
            </Button>
          </CardContent>
        </Card>

        <Card sx={{ mb: 2 }} elevation={2}>
          <CardContent>
            <Typography fontWeight={700}>Tháng hiện tại</Typography>
            <Typography>Tiết kiệm (thu − chi): {formatMoney(savings)}</Typography>
            <Typography variant="body2" color="text.secondary">
              Tổng giao dịch: {txPage?.totalElements ?? 0}
            </Typography>
          </CardContent>
        </Card>

        <Dialog open={open} onClose={() => setOpen(false)} fullWidth>
          <DialogTitle>Mục tiêu tiết kiệm tháng (₫)</DialogTitle>
          <DialogContent>
            <TextField
              autoFocus
              fullWidth
              label="Số tiền"
              value={goalInput}
              onChange={(e) => setGoalInput(e.target.value)}
              margin="normal"
            />
            {saveGoal.error && (
              <Typography color="error" variant="body2">
                {extractApiError(saveGoal.error)}
              </Typography>
            )}
          </DialogContent>
          <DialogActions>
            <Button onClick={() => setOpen(false)}>Hủy</Button>
            <Button variant="contained" onClick={() => saveGoal.mutate()}>
              Lưu
            </Button>
          </DialogActions>
        </Dialog>
      </Box>
    </GradientBackground>
  );
}
