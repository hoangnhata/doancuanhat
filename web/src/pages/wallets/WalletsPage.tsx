import {
  Box,
  Button,
  Card,
  CardContent,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  IconButton,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { DeleteOutlineRounded } from '@mui/icons-material';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { GradientBackground } from '@/components/common/GradientBackground';
import { extractApiError } from '@/lib/api';
import { formatMoney } from '@/lib/format';
import * as walletService from '@/services/walletService';

export function WalletsPage() {
  const qc = useQueryClient();
  const [open, setOpen] = useState(false);
  const [name, setName] = useState('');
  const [currency, setCurrency] = useState('VND');
  const [balance, setBalance] = useState('0');

  const { data: wallets = [], isLoading } = useQuery({
    queryKey: ['wallets'],
    queryFn: walletService.fetchWallets,
  });

  const createMut = useMutation({
    mutationFn: () =>
      walletService.createWallet({
        name: name.trim(),
        currencyCode: currency,
        initialBalance: Number(balance.replace(/\D/g, '')) || 0,
        isDefault: wallets.length === 0,
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['wallets'] });
      setOpen(false);
      setName('');
    },
  });

  const delMut = useMutation({
    mutationFn: (id: number) => walletService.deleteWallet(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['wallets'] }),
  });

  return (
    <GradientBackground>
      <Box sx={{ p: 2, pb: 10, maxWidth: 560, mx: 'auto' }}>
        <Stack direction="row" justifyContent="space-between" alignItems="center" mb={2}>
          <Typography variant="h6" fontWeight={800}>
            Ví
          </Typography>
          <Button variant="contained" onClick={() => setOpen(true)}>
            Thêm ví
          </Button>
        </Stack>

        {isLoading ? (
          <Typography>Đang tải…</Typography>
        ) : (
          <Stack spacing={1}>
            {wallets.map((w) => (
              <Card key={w.id} elevation={2}>
                <CardContent>
                  <Stack direction="row" alignItems="center" spacing={1}>
                    <Box flex={1}>
                      <Typography fontWeight={700}>
                        {w.name}{' '}
                        {w.isDefault && (
                          <Typography component="span" variant="caption" color="primary">
                            (Mặc định)
                          </Typography>
                        )}
                      </Typography>
                      <Typography variant="body2" color="text.secondary">
                        {w.currencyCode}
                      </Typography>
                      <Typography fontWeight={800}>
                        {formatMoney(w.initialBalance)}
                      </Typography>
                    </Box>
                    <IconButton
                      color="error"
                      onClick={() => {
                        if (confirm('Xóa ví?')) delMut.mutate(w.id);
                      }}
                    >
                      <DeleteOutlineRounded />
                    </IconButton>
                  </Stack>
                </CardContent>
              </Card>
            ))}
          </Stack>
        )}

        <Dialog open={open} onClose={() => setOpen(false)} fullWidth>
          <DialogTitle>Ví mới</DialogTitle>
          <DialogContent>
            <TextField
              autoFocus
              fullWidth
              label="Tên ví"
              value={name}
              onChange={(e) => setName(e.target.value)}
              margin="normal"
            />
            <TextField
              fullWidth
              label="Tiền tệ"
              value={currency}
              onChange={(e) => setCurrency(e.target.value)}
              margin="normal"
            />
            <TextField
              fullWidth
              label="Số dư ban đầu"
              value={balance}
              onChange={(e) => setBalance(e.target.value)}
              margin="normal"
            />
            {createMut.error && (
              <Typography color="error" variant="body2">
                {extractApiError(createMut.error)}
              </Typography>
            )}
          </DialogContent>
          <DialogActions>
            <Button onClick={() => setOpen(false)}>Hủy</Button>
            <Button
              variant="contained"
              onClick={() => createMut.mutate()}
              disabled={!name.trim()}
            >
              Tạo
            </Button>
          </DialogActions>
        </Dialog>
      </Box>
    </GradientBackground>
  );
}
