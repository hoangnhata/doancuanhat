import {
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControlLabel,
  IconButton,
  Stack,
  Switch,
  TextField,
  Typography,
} from '@mui/material';
import {
  AccountBalanceWalletRounded,
  AddRounded,
  DeleteOutlineRounded,
  EditRounded,
  StarRounded,
} from '@mui/icons-material';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { GradientBackground } from '@/components/common/GradientBackground';
import { extractApiError } from '@/lib/api';
import { formatMoney, formatMoneyFull } from '@/lib/format';
import * as walletService from '@/services/walletService';
import type { Wallet } from '@/types/models';
import { palette } from '@/theme';

type FormState = {
  name: string;
  currency: string;
  balance: string;
  isDefault: boolean;
};

const emptyForm = (): FormState => ({
  name: '',
  currency: 'VND',
  balance: '0',
  isDefault: false,
});

export function WalletsPage() {
  const qc = useQueryClient();
  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<Wallet | null>(null);
  const [form, setForm] = useState<FormState>(emptyForm);

  const { data: wallets = [], isLoading } = useQuery({
    queryKey: ['wallets'],
    queryFn: walletService.fetchWallets,
  });

  const openCreate = () => {
    setEditing(null);
    setForm({ ...emptyForm(), isDefault: wallets.length === 0 });
    setOpen(true);
  };

  const openEdit = (w: Wallet) => {
    setEditing(w);
    setForm({
      name: w.name,
      currency: w.currencyCode,
      balance: String(w.initialBalance),
      isDefault: w.isDefault,
    });
    setOpen(true);
  };

  const closeDialog = () => {
    setOpen(false);
    setEditing(null);
    setForm(emptyForm());
  };

  const saveMut = useMutation({
    mutationFn: async () => {
      const body = {
        name: form.name.trim(),
        currencyCode: form.currency,
        initialBalance: Number(form.balance.replace(/\D/g, '')) || 0,
        isDefault: form.isDefault,
      };
      if (editing) return walletService.updateWallet(editing.id, body);
      return walletService.createWallet(body);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['wallets'] });
      closeDialog();
    },
  });

  const delMut = useMutation({
    mutationFn: (id: number) => walletService.deleteWallet(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['wallets'] }),
  });

  const totalBalance = wallets.reduce(
    (sum, w) => sum + (w.currentBalance ?? w.initialBalance ?? 0),
    0,
  );

  return (
    <GradientBackground>
      <Box sx={{ p: { xs: 2, md: 3 }, pb: 10, maxWidth: 640, mx: 'auto' }}>
        <Stack direction="row" justifyContent="space-between" alignItems="flex-start" mb={2.5}>
          <Box>
            <Typography variant="h5" fontWeight={800} letterSpacing="-0.02em">
              Quản lý ví
            </Typography>
            <Typography variant="body2" color="text.secondary" mt={0.5}>
              {wallets.length} ví · Tổng số dư {formatMoney(totalBalance)}
            </Typography>
          </Box>
          <Button variant="contained" startIcon={<AddRounded />} onClick={openCreate} sx={{ borderRadius: 2.5 }}>
            Thêm ví
          </Button>
        </Stack>

        {isLoading ? (
          <Typography color="text.secondary">Đang tải…</Typography>
        ) : wallets.length === 0 ? (
          <Card
            elevation={0}
            sx={{
              p: 4,
              textAlign: 'center',
              borderRadius: 3,
              border: `1px dashed ${palette.textMuted}`,
              bgcolor: palette.surface,
            }}
          >
            <Box
              sx={{
                width: 72,
                height: 72,
                mx: 'auto',
                mb: 2,
                borderRadius: '50%',
                display: 'grid',
                placeItems: 'center',
                bgcolor: `${palette.primary.main}14`,
                color: palette.primary.main,
              }}
            >
              <AccountBalanceWalletRounded sx={{ fontSize: 36 }} />
            </Box>
            <Typography fontWeight={800} fontSize={18} gutterBottom>
              Chưa có ví nào
            </Typography>
            <Typography color="text.secondary" mb={3}>
              Tạo ví để theo dõi số dư và ghi nhận giao dịch.
            </Typography>
            <Button variant="contained" startIcon={<AddRounded />} onClick={openCreate}>
              Tạo ví đầu tiên
            </Button>
          </Card>
        ) : (
          <Stack spacing={1.5}>
            {wallets.map((w) => {
              const balance = w.currentBalance ?? w.initialBalance ?? 0;
              return (
                <Card
                  key={w.id}
                  elevation={0}
                  sx={{
                    borderRadius: 3,
                    border: w.isDefault ? `2px solid ${palette.primary.main}` : `1px solid ${palette.outline}`,
                    boxShadow: w.isDefault ? palette.shadowLift : palette.shadowSoft,
                    background: w.isDefault
                      ? `linear-gradient(145deg, ${palette.primary.main}10 0%, #FFFFFF 50%)`
                      : '#FFFFFF',
                    transition: 'transform 0.15s ease',
                    '&:hover': { transform: 'translateY(-2px)' },
                  }}
                >
                  <CardContent sx={{ p: 2.5 }}>
                    <Stack direction="row" spacing={1.5} alignItems="flex-start">
                      <Box
                        sx={{
                          width: 48,
                          height: 48,
                          borderRadius: 2.5,
                          display: 'grid',
                          placeItems: 'center',
                          background: w.isDefault
                            ? `linear-gradient(135deg, ${palette.primary.main}, ${palette.primary.light})`
                            : `${palette.primary.main}14`,
                          color: w.isDefault ? '#fff' : palette.primary.main,
                          flexShrink: 0,
                        }}
                      >
                        <AccountBalanceWalletRounded />
                      </Box>
                      <Box flex={1} minWidth={0}>
                        <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap" mb={0.5}>
                          <Typography fontWeight={800} fontSize={17} noWrap>
                            {w.name}
                          </Typography>
                          {w.isDefault && (
                            <Chip
                              size="small"
                              icon={<StarRounded sx={{ fontSize: '14px !important' }} />}
                              label="Mặc định"
                              sx={{
                                fontWeight: 700,
                                bgcolor: `${palette.primary.main}14`,
                                color: palette.primary.main,
                              }}
                            />
                          )}
                        </Stack>
                        <Typography
                          variant="h5"
                          fontWeight={800}
                          color="primary.main"
                          letterSpacing="-0.02em"
                          sx={{ fontSize: { xs: '1.25rem', sm: '1.4rem' } }}
                        >
                          {formatMoney(balance)}
                        </Typography>
                        <Typography variant="caption" color="text.secondary" fontWeight={600} display="block" mt={0.25}>
                          Số dư hiện tại
                        </Typography>
                        <Stack direction="row" spacing={1} mt={1.25} flexWrap="wrap" useFlexGap>
                          <Chip
                            size="small"
                            label={w.currencyCode}
                            variant="outlined"
                            sx={{ fontWeight: 700, borderRadius: 2 }}
                          />
                          {w.currentBalance != null && w.currentBalance !== w.initialBalance && (
                            <Chip
                              size="small"
                              label={`Ban đầu: ${formatMoneyFull(w.initialBalance)}`}
                              sx={{ fontWeight: 600, bgcolor: palette.surface }}
                            />
                          )}
                        </Stack>
                      </Box>
                      <Stack direction="row" spacing={0.25}>
                        <IconButton
                          size="small"
                          onClick={() => openEdit(w)}
                          sx={{
                            bgcolor: `${palette.primary.main}0A`,
                            '&:hover': { bgcolor: `${palette.primary.main}18` },
                          }}
                        >
                          <EditRounded fontSize="small" color="primary" />
                        </IconButton>
                        {!w.isDefault && (
                          <IconButton
                            size="small"
                            color="error"
                            onClick={() => {
                              if (confirm(`Xóa ví "${w.name}"? Giao dịch sẽ chuyển về ví mặc định.`)) {
                                delMut.mutate(w.id);
                              }
                            }}
                          >
                            <DeleteOutlineRounded fontSize="small" />
                          </IconButton>
                        )}
                      </Stack>
                    </Stack>
                  </CardContent>
                </Card>
              );
            })}
          </Stack>
        )}

        <Dialog open={open} onClose={closeDialog} fullWidth maxWidth="sm" PaperProps={{ sx: { borderRadius: 3 } }}>
          <DialogTitle sx={{ fontWeight: 800, pb: 1 }}>
            <Stack direction="row" spacing={1.5} alignItems="center">
              <Box
                sx={{
                  width: 40,
                  height: 40,
                  borderRadius: 2,
                  display: 'grid',
                  placeItems: 'center',
                  bgcolor: `${palette.primary.main}14`,
                  color: palette.primary.main,
                }}
              >
                <AccountBalanceWalletRounded fontSize="small" />
              </Box>
              <Box>{editing ? 'Sửa ví' : 'Thêm ví mới'}</Box>
            </Stack>
          </DialogTitle>
          <DialogContent>
            <TextField
              autoFocus
              fullWidth
              label="Tên ví"
              placeholder="VD: Ví của tôi, Tiền mặt"
              value={form.name}
              onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
              margin="normal"
              sx={{ '& .MuiOutlinedInput-root': { borderRadius: 2.5 } }}
            />
            <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2}>
              <TextField
                fullWidth
                label="Tiền tệ"
                value={form.currency}
                onChange={(e) => setForm((f) => ({ ...f, currency: e.target.value.toUpperCase() }))}
                margin="normal"
                sx={{ '& .MuiOutlinedInput-root': { borderRadius: 2.5 } }}
              />
              <TextField
                fullWidth
                label="Số dư ban đầu"
                value={form.balance}
                onChange={(e) => setForm((f) => ({ ...f, balance: e.target.value }))}
                margin="normal"
                inputMode="numeric"
                sx={{ '& .MuiOutlinedInput-root': { borderRadius: 2.5 } }}
              />
            </Stack>
            <FormControlLabel
              control={
                <Switch
                  checked={form.isDefault}
                  onChange={(e) => setForm((f) => ({ ...f, isDefault: e.target.checked }))}
                />
              }
              label="Đặt làm ví mặc định"
              sx={{ mt: 1, ml: 0.5 }}
            />
            {saveMut.error && (
              <Typography color="error" variant="body2" mt={1}>
                {extractApiError(saveMut.error)}
              </Typography>
            )}
          </DialogContent>
          <DialogActions sx={{ px: 3, pb: 2.5 }}>
            <Button onClick={closeDialog} sx={{ borderRadius: 2 }}>
              Hủy
            </Button>
            <Button
              variant="contained"
              onClick={() => saveMut.mutate()}
              disabled={!form.name.trim() || saveMut.isPending}
              sx={{ borderRadius: 2, px: 3, fontWeight: 700 }}
            >
              {saveMut.isPending ? 'Đang lưu…' : editing ? 'Cập nhật' : 'Tạo ví'}
            </Button>
          </DialogActions>
        </Dialog>
      </Box>
    </GradientBackground>
  );
}
