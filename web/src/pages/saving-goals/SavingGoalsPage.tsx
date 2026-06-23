import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  IconButton,
  InputAdornment,
  LinearProgress,
  MenuItem,
  Paper,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import {
  AddRounded,
  AccountBalanceWalletRounded,
  AddCircleOutlineRounded,
  CalendarMonthOutlined,
  CelebrationRounded,
  CloseRounded,
  DeleteOutlineRounded,
  EmojiEventsRounded,
  HistoryRounded,
  RemoveCircleOutlineRounded,
  SavingsRounded,
  ShoppingBagRounded,
  TrendingUpRounded,
} from '@mui/icons-material';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { GradientBackground } from '@/components/common/GradientBackground';
import { DatePickerField } from '@/components/common/DatePickerField';
import { formatAmountInput } from '@/components/common/OnboardingField';
import { extractApiError } from '@/lib/api';
import { formatMoneyFull } from '@/lib/format';
import * as savingGoalService from '@/services/savingGoalService';
import * as walletService from '@/services/walletService';
import type { SavingGoal, SavingGoalStatus } from '@/types/models';
import { palette } from '@/theme';

const STATUS_LABEL: Record<SavingGoalStatus, string> = {
  ACTIVE: 'Đang tiết kiệm',
  COMPLETED: 'Đã hoàn thành',
  USED: 'Đã sử dụng',
  PAUSED: 'Tạm dừng',
  CANCELLED: 'Đã hủy',
};

const STATUS_COLOR: Record<SavingGoalStatus, 'default' | 'success' | 'warning' | 'error' | 'info'> = {
  ACTIVE: 'default',
  COMPLETED: 'success',
  USED: 'info',
  PAUSED: 'warning',
  CANCELLED: 'error',
};

function formatDuration(days: number | null | undefined): string {
  if (days == null) return '—';
  if (days <= 0) return '1 ngày';
  return `${days} ngày`;
}

function formatCompletedDate(iso: string | null | undefined): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '—';
  return d.toLocaleDateString('vi-VN', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  });
}

function goalCompletedDate(g: SavingGoal): string {
  return formatCompletedDate(g.completedAt ?? g.updatedAt ?? g.createdAt);
}

function goalDurationDays(g: SavingGoal): string {
  if (g.durationDays != null) return formatDuration(g.durationDays);
  const end = g.completedAt ?? g.updatedAt ?? g.createdAt;
  const start = g.createdAt;
  if (!end || !start) return '—';
  const days = Math.floor(
    (new Date(end).getTime() - new Date(start).getTime()) / (1000 * 60 * 60 * 24),
  );
  return formatDuration(days);
}

function parseAmount(raw: string): number {
  return Number(raw.replace(/\D/g, '')) || 0;
}

function progressColor(g: SavingGoal): string {
  if (g.isCompleted) return '#2E7D32';
  if (g.progressPercent >= 75) return palette.primary.main;
  return '#0288D1';
}

export function SavingGoalsPage() {
  const qc = useQueryClient();
  const navigate = useNavigate();
  const [createOpen, setCreateOpen] = useState(false);
  const [transferOpen, setTransferOpen] = useState<'deposit' | 'withdraw' | null>(null);
  const [historyOpen, setHistoryOpen] = useState(false);
  const [selectedGoal, setSelectedGoal] = useState<SavingGoal | null>(null);
  const [error, setError] = useState<string | null>(null);

  const [name, setName] = useState('');
  const [targetAmount, setTargetAmount] = useState('');
  const [initialAmount, setInitialAmount] = useState('');
  const [targetDate, setTargetDate] = useState('');
  const [note, setNote] = useState('');
  const [transferAmount, setTransferAmount] = useState('');
  const [walletId, setWalletId] = useState<number | ''>('');
  const [transferNote, setTransferNote] = useState('');

  const { data: goals = [], isLoading } = useQuery({
    queryKey: ['saving-goals'],
    queryFn: savingGoalService.fetchSavingGoals,
  });

  const { data: wallets = [] } = useQuery({
    queryKey: ['wallets'],
    queryFn: walletService.fetchWallets,
  });

  const { data: history = [] } = useQuery({
    queryKey: ['saving-goals', selectedGoal?.id, 'transactions'],
    queryFn: () => savingGoalService.fetchSavingTransactions(selectedGoal!.id),
    enabled: historyOpen && selectedGoal != null,
  });

  const defaultWalletId = useMemo(
    () => wallets.find((w) => w.isDefault)?.id ?? wallets[0]?.id,
    [wallets],
  );

  const totalSaved = goals.reduce((s, g) => s + g.currentAmount, 0);
  const completedCount = goals.filter((g) => g.isCompleted).length;

  const createMut = useMutation({
    mutationFn: () =>
      savingGoalService.createSavingGoal({
        name: name.trim(),
        targetAmount: parseAmount(targetAmount),
        initialAmount: parseAmount(initialAmount) || undefined,
        targetDate: targetDate || undefined,
        note: note.trim() || undefined,
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['saving-goals'] });
      setCreateOpen(false);
      resetCreateForm();
      setError(null);
    },
    onError: (e) => setError(extractApiError(e)),
  });

  const transferMut = useMutation({
    mutationFn: () => {
      if (!selectedGoal || !walletId) throw new Error('Thiếu thông tin');
      const body = {
        walletId: Number(walletId),
        amount: parseAmount(transferAmount),
        note: transferNote.trim() || undefined,
      };
      return transferOpen === 'deposit'
        ? savingGoalService.depositSavingGoal(selectedGoal.id, body)
        : savingGoalService.withdrawSavingGoal(selectedGoal.id, body);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['saving-goals'] });
      qc.invalidateQueries({ queryKey: ['wallets'] });
      if (selectedGoal) {
        qc.invalidateQueries({
          queryKey: ['saving-goals', selectedGoal.id, 'transactions'],
        });
      }
      setTransferOpen(null);
      setTransferAmount('');
      setTransferNote('');
      setError(null);
    },
    onError: (e) => setError(extractApiError(e)),
  });

  const delMut = useMutation({
    mutationFn: (id: number) => savingGoalService.deleteSavingGoal(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['saving-goals'] }),
  });

  function resetCreateForm() {
    setName('');
    setTargetAmount('');
    setInitialAmount('');
    setTargetDate('');
    setNote('');
  }

  function openTransfer(goal: SavingGoal, mode: 'deposit' | 'withdraw') {
    setSelectedGoal(goal);
    setTransferOpen(mode);
    setWalletId(defaultWalletId ?? '');
    setTransferAmount('');
    setTransferNote('');
    setError(null);
  }

  function openHistory(goal: SavingGoal) {
    setSelectedGoal(goal);
    setHistoryOpen(true);
  }

  function openSpendFromGoal(goal: SavingGoal) {
    navigate('/app/transactions/add', {
      state: {
        fromSavingGoal: {
          id: goal.id,
          name: goal.name,
          amount: goal.targetAmount,
        },
      },
    });
  }

  return (
    <GradientBackground>
      <Box sx={{ p: { xs: 2, md: 3 }, pb: 10, maxWidth: 720, mx: 'auto' }}>
        <Stack direction="row" justifyContent="space-between" alignItems="flex-start" mb={2}>
          <Box>
            <Stack direction="row" spacing={1.5} alignItems="center" mb={0.5}>
              <Box
                sx={{
                  width: 48,
                  height: 48,
                  borderRadius: 2,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  bgcolor: '#E8F5E9',
                  color: '#2E7D32',
                }}
              >
                <SavingsRounded />
              </Box>
              <Typography variant="h5" fontWeight={800}>
                Mục tiêu tiết kiệm
              </Typography>
            </Stack>
            <Typography variant="body2" color="text.secondary" maxWidth={480}>
              Mỗi mục tiêu là ví tiết kiệm nội bộ. Nạp/rút là chuyển khoản giữa ví và mục tiêu — không tính vào thu/chi.
            </Typography>
          </Box>
          <Button
            variant="contained"
            startIcon={<AddRounded />}
            onClick={() => {
              resetCreateForm();
              setCreateOpen(true);
              setError(null);
            }}
            sx={{ flexShrink: 0 }}
          >
            Tạo mục tiêu
          </Button>
        </Stack>

        {goals.length > 0 && (
          <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5} sx={{ mb: 2.5 }}>
            <Paper
              elevation={0}
              sx={{
                flex: 1,
                p: 2,
                borderRadius: 3,
                border: '1px solid',
                borderColor: '#A5D6A7',
                bgcolor: '#E8F5E9',
              }}
            >
              <Stack direction="row" spacing={1.5} alignItems="center">
                <Box
                  sx={{
                    width: 44,
                    height: 44,
                    borderRadius: 2,
                    bgcolor: '#2E7D3220',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    flexShrink: 0,
                  }}
                >
                  <SavingsRounded sx={{ color: '#2E7D32' }} />
                </Box>
                <Box minWidth={0}>
                  <Typography
                    variant="caption"
                    color="text.secondary"
                    fontWeight={700}
                    display="block"
                    sx={{ letterSpacing: 0.4 }}
                  >
                    Tổng đã tiết kiệm
                  </Typography>
                  <Typography variant="h6" fontWeight={800} color="#2E7D32" noWrap>
                    {formatMoneyFull(totalSaved)}
                  </Typography>
                </Box>
              </Stack>
            </Paper>
            <Paper
              elevation={0}
              sx={{
                flex: 1,
                p: 2,
                borderRadius: 3,
                border: '1px solid',
                borderColor: 'divider',
                bgcolor: 'background.paper',
              }}
            >
              <Stack direction="row" spacing={1.5} alignItems="center">
                <Box
                  sx={{
                    width: 44,
                    height: 44,
                    borderRadius: 2,
                    bgcolor: `${palette.primary.main}14`,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    flexShrink: 0,
                  }}
                >
                  <TrendingUpRounded sx={{ color: palette.primary.main }} />
                </Box>
                <Box minWidth={0}>
                  <Typography
                    variant="caption"
                    color="text.secondary"
                    fontWeight={700}
                    display="block"
                    sx={{ letterSpacing: 0.4 }}
                  >
                    Mục tiêu
                  </Typography>
                  <Typography variant="h6" fontWeight={800} noWrap>
                    {goals.length} · {completedCount} hoàn thành
                  </Typography>
                </Box>
              </Stack>
            </Paper>
          </Stack>
        )}

        {isLoading ? (
          <Typography color="text.secondary">Đang tải…</Typography>
        ) : goals.length === 0 ? (
          <Card
            elevation={0}
            sx={{
              borderRadius: 4,
              border: '1px dashed',
              borderColor: 'divider',
              textAlign: 'center',
              py: 5,
              px: 3,
            }}
          >
            <Box
              sx={{
                width: 72,
                height: 72,
                borderRadius: '50%',
                bgcolor: '#E8F5E9',
                color: '#2E7D32',
                display: 'grid',
                placeItems: 'center',
                mx: 'auto',
                mb: 2,
              }}
            >
              <SavingsRounded sx={{ fontSize: 36 }} />
            </Box>
            <Typography fontWeight={800} fontSize={18} gutterBottom>
              Chưa có mục tiêu tiết kiệm
            </Typography>
            <Typography variant="body2" color="text.secondary" mb={2.5} maxWidth={360} mx="auto">
              Tạo mục tiêu để theo dõi tiến độ tiết kiệm cho kế hoạch lớn của bạn — du lịch, mua xe, quỹ khẩn cấp…
            </Typography>
            <Button variant="contained" startIcon={<AddRounded />} onClick={() => setCreateOpen(true)}>
              Tạo mục tiêu đầu tiên
            </Button>
          </Card>
        ) : (
          <Stack spacing={2}>
            {goals.map((g) => {
              const color = progressColor(g);
              const isCompleted = g.status === 'COMPLETED';
              const isUsed = g.status === 'USED';
              const showCelebration = isCompleted || isUsed;
              const savedDisplay = g.totalSavedAmount ?? g.currentAmount;
              return (
                <Card
                  key={g.id}
                  elevation={0}
                  sx={{
                    borderRadius: 3,
                    border: '1px solid',
                    borderColor: showCelebration ? '#A5D6A766' : 'divider',
                    boxShadow: showCelebration
                      ? '0 8px 28px rgba(46, 125, 50, 0.1)'
                      : '0 4px 20px rgba(2, 136, 209, 0.06)',
                  }}
                >
                  <CardContent sx={{ p: 2.5 }}>
                    {showCelebration && (
                      <Paper
                        elevation={0}
                        sx={{
                          mb: 2,
                          p: 2,
                          borderRadius: 2.5,
                          background: 'linear-gradient(135deg, #E8F5E9 0%, #FFF8E1 100%)',
                          border: '1px solid #A5D6A7',
                        }}
                      >
                        <Stack direction="row" spacing={1.5} alignItems="center">
                          <Box
                            sx={{
                              width: 52,
                              height: 52,
                              borderRadius: '50%',
                              display: 'grid',
                              placeItems: 'center',
                              bgcolor: '#FFD54F',
                              color: '#F57F17',
                              boxShadow: '0 4px 12px rgba(245, 127, 23, 0.25)',
                            }}
                          >
                            {isUsed ? (
                              <ShoppingBagRounded />
                            ) : (
                              <EmojiEventsRounded sx={{ fontSize: 28 }} />
                            )}
                          </Box>
                          <Box flex={1} minWidth={0}>
                            <Stack direction="row" spacing={0.75} alignItems="center" mb={0.25}>
                              <CelebrationRounded sx={{ fontSize: 18, color: '#2E7D32' }} />
                              <Typography fontWeight={800} color="#2E7D32">
                                {isUsed ? 'Mục tiêu đã được sử dụng' : 'Chúc mừng! Bạn đã hoàn thành mục tiêu'}
                              </Typography>
                            </Stack>
                            <Stack direction="row" spacing={2} flexWrap="wrap" useFlexGap>
                              <Typography variant="caption" color="text.secondary" fontWeight={600}>
                                Hoàn thành: {goalCompletedDate(g)}
                              </Typography>
                              <Typography variant="caption" color="text.secondary" fontWeight={600}>
                                Thời gian: {goalDurationDays(g)}
                              </Typography>
                              <Typography variant="caption" color="text.secondary" fontWeight={600}>
                                Đã tiết kiệm: {formatMoneyFull(savedDisplay)}
                              </Typography>
                            </Stack>
                          </Box>
                        </Stack>
                      </Paper>
                    )}
                    <Stack direction="row" justifyContent="space-between" alignItems="flex-start">
                      <Stack direction="row" spacing={1.5} flex={1} minWidth={0}>
                        <Box
                          sx={{
                            width: 44,
                            height: 44,
                            borderRadius: 2,
                            flexShrink: 0,
                            display: 'grid',
                            placeItems: 'center',
                            bgcolor: `${color}14`,
                            color,
                          }}
                        >
                          {g.isCompleted ? <TrendingUpRounded /> : <SavingsRounded />}
                        </Box>
                        <Box minWidth={0}>
                          <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap" useFlexGap mb={0.25}>
                            <Typography variant="h6" fontWeight={800} noWrap>
                              {g.name}
                            </Typography>
                            <Chip
                              size="small"
                              label={STATUS_LABEL[g.status]}
                              color={STATUS_COLOR[g.status]}
                            />
                          </Stack>
                        </Box>
                      </Stack>
                      <IconButton
                        color="error"
                        size="small"
                        disabled={g.status === 'USED'}
                        onClick={() => {
                          if (confirm('Xóa mục tiêu này? (Chỉ xóa được khi số dư = 0)')) {
                            delMut.mutate(g.id);
                          }
                        }}
                      >
                        <DeleteOutlineRounded />
                      </IconButton>
                    </Stack>

                    <Box sx={{ mt: 2, mb: 1 }}>
                      <Stack direction="row" justifyContent="space-between" mb={0.5}>
                        <Typography variant="caption" fontWeight={700} color="text.secondary">
                          Tiến độ
                        </Typography>
                        <Typography variant="caption" fontWeight={800} sx={{ color }}>
                          {g.progressPercent.toFixed(1)}%
                        </Typography>
                      </Stack>
                      <LinearProgress
                        variant="determinate"
                        value={Math.min(100, g.progressPercent)}
                        sx={{
                          height: 10,
                          borderRadius: 999,
                          bgcolor: `${color}18`,
                          '& .MuiLinearProgress-bar': { bgcolor: color, borderRadius: 999 },
                        }}
                      />
                    </Box>

                    <Stack direction="row" spacing={1} mt={1.5} flexWrap="wrap" useFlexGap>
                      <Box
                        sx={{
                          flex: '1 1 120px',
                          px: 1.5,
                          py: 1,
                          borderRadius: 2,
                          bgcolor: `${color}10`,
                          border: '1px solid',
                          borderColor: `${color}33`,
                        }}
                      >
                        <Typography variant="caption" color="text.secondary" fontWeight={700} display="block">
                          Đã tiết kiệm
                        </Typography>
                        <Typography fontWeight={800} fontSize={15} sx={{ color }}>
                          {formatMoneyFull(g.currentAmount)}
                        </Typography>
                      </Box>
                      <Box
                        sx={{
                          flex: '1 1 120px',
                          px: 1.5,
                          py: 1,
                          borderRadius: 2,
                          bgcolor: 'action.hover',
                          border: '1px solid',
                          borderColor: 'divider',
                        }}
                      >
                        <Typography variant="caption" color="text.secondary" fontWeight={700} display="block">
                          Mục tiêu
                        </Typography>
                        <Typography fontWeight={800} fontSize={15}>
                          {formatMoneyFull(g.targetAmount)}
                        </Typography>
                      </Box>
                      {g.targetDate && (
                        <Box
                          sx={{
                            flex: '1 1 140px',
                            px: 1.5,
                            py: 1,
                            borderRadius: 2,
                            bgcolor: 'action.hover',
                            border: '1px solid',
                            borderColor: 'divider',
                            display: 'flex',
                            alignItems: 'center',
                            gap: 1,
                          }}
                        >
                          <CalendarMonthOutlined sx={{ fontSize: 20, color: palette.primary.main, flexShrink: 0 }} />
                          <Box minWidth={0}>
                            <Typography variant="caption" color="text.secondary" fontWeight={700} display="block">
                              Dự kiến hoàn thành
                            </Typography>
                            <Typography fontWeight={800} fontSize={14} noWrap>
                              {new Date(g.targetDate).toLocaleDateString('vi-VN', {
                                day: '2-digit',
                                month: '2-digit',
                                year: 'numeric',
                              })}
                            </Typography>
                          </Box>
                        </Box>
                      )}
                    </Stack>

                    <Typography variant="caption" color="text.secondary" display="block" mt={1}>
                      {isCompleted
                        ? 'Sẵn sàng chi tiêu cho mục tiêu này.'
                        : isUsed
                          ? 'Khoản tiết kiệm đã được chi tiêu.'
                          : g.isCompleted
                            ? 'Chúc mừng! Bạn đã đạt mục tiêu.'
                            : `Còn thiếu ${formatMoneyFull(g.remainingAmount)}`}
                    </Typography>

                    <Stack direction="row" spacing={1} mt={2} flexWrap="wrap" useFlexGap>
                      {isCompleted && (
                        <Button
                          size="small"
                          variant="contained"
                          color="success"
                          startIcon={<ShoppingBagRounded />}
                          onClick={() => openSpendFromGoal(g)}
                        >
                          Chi tiêu từ mục tiêu
                        </Button>
                      )}
                      <Button
                        size="small"
                        variant="contained"
                        disabled={
                          g.status === 'CANCELLED' ||
                          g.status === 'PAUSED' ||
                          g.status === 'COMPLETED' ||
                          g.status === 'USED'
                        }
                        onClick={() => openTransfer(g, 'deposit')}
                      >
                        Nạp tiền
                      </Button>
                      <Button
                        size="small"
                        variant="outlined"
                        disabled={
                          g.status === 'CANCELLED' ||
                          g.currentAmount <= 0 ||
                          g.status === 'USED'
                        }
                        onClick={() => openTransfer(g, 'withdraw')}
                      >
                        Rút tiền
                      </Button>
                      <Button
                        size="small"
                        variant="text"
                        startIcon={<HistoryRounded />}
                        onClick={() => openHistory(g)}
                      >
                        Lịch sử
                      </Button>
                    </Stack>
                  </CardContent>
                </Card>
              );
            })}
          </Stack>
        )}

        <Dialog open={createOpen} onClose={() => setCreateOpen(false)} fullWidth maxWidth="sm">
          <DialogTitle sx={{ fontWeight: 800 }}>Tạo mục tiêu tiết kiệm</DialogTitle>
          <DialogContent>
            <TextField
              fullWidth
              label="Tên mục tiêu"
              value={name}
              onChange={(e) => setName(e.target.value)}
              margin="normal"
              placeholder="Ví dụ: Du lịch Đà Lạt"
            />
            <TextField
              fullWidth
              label="Số tiền mục tiêu"
              value={targetAmount}
              onChange={(e) => setTargetAmount(formatAmountInput(e.target.value))}
              margin="normal"
              placeholder="10.000.000"
              inputMode="numeric"
            />
            <TextField
              fullWidth
              label="Số tiền đã có ban đầu (tùy chọn)"
              value={initialAmount}
              onChange={(e) => setInitialAmount(formatAmountInput(e.target.value))}
              margin="normal"
              helperText="Không trừ từ ví — chỉ ghi nhận số dư ban đầu của mục tiêu"
              inputMode="numeric"
            />
            <DatePickerField
              label="Ngày dự kiến hoàn thành"
              value={targetDate}
              onChange={setTargetDate}
              placeholder="Chọn ngày (tùy chọn)"
            />
            <TextField
              fullWidth
              label="Ghi chú"
              value={note}
              onChange={(e) => setNote(e.target.value)}
              margin="normal"
              multiline
              rows={2}
            />
            {error && (
              <Alert severity="error" sx={{ mt: 1 }}>
                {error}
              </Alert>
            )}
          </DialogContent>
          <DialogActions sx={{ px: 3, pb: 2 }}>
            <Button onClick={() => setCreateOpen(false)}>Hủy</Button>
            <Button
              variant="contained"
              disabled={!name.trim() || parseAmount(targetAmount) <= 0 || createMut.isPending}
              onClick={() => createMut.mutate()}
            >
              Tạo mục tiêu
            </Button>
          </DialogActions>
        </Dialog>

        <Dialog
          open={transferOpen != null}
          onClose={() => setTransferOpen(null)}
          fullWidth
          maxWidth="sm"
          PaperProps={{ sx: { borderRadius: 3, overflow: 'hidden' } }}
        >
          {transferOpen && selectedGoal && (
            <>
              <Box
                sx={{
                  px: 3,
                  py: 2.5,
                  background:
                    transferOpen === 'deposit'
                      ? 'linear-gradient(135deg, #2E7D32 0%, #1B5E20 100%)'
                      : 'linear-gradient(135deg, #F57C00 0%, #E65100 100%)',
                  color: 'white',
                }}
              >
                <Stack direction="row" justifyContent="space-between" alignItems="flex-start">
                  <Stack direction="row" spacing={1.5} alignItems="center">
                    <Box
                      sx={{
                        width: 44,
                        height: 44,
                        borderRadius: 2,
                        bgcolor: 'rgba(255,255,255,0.2)',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                      }}
                    >
                      {transferOpen === 'deposit' ? (
                        <AddCircleOutlineRounded />
                      ) : (
                        <RemoveCircleOutlineRounded />
                      )}
                    </Box>
                    <Box>
                      <Typography fontWeight={800} fontSize={18}>
                        {transferOpen === 'deposit' ? 'Nạp tiền vào mục tiêu' : 'Rút tiền từ mục tiêu'}
                      </Typography>
                      <Typography variant="body2" sx={{ opacity: 0.92 }}>
                        {selectedGoal.name}
                      </Typography>
                    </Box>
                  </Stack>
                  <IconButton
                    size="small"
                    onClick={() => setTransferOpen(null)}
                    sx={{ color: 'white', mt: -0.5, mr: -0.5 }}
                  >
                    <CloseRounded />
                  </IconButton>
                </Stack>
                <Paper
                  elevation={0}
                  sx={{
                    mt: 2,
                    px: 2,
                    py: 1.25,
                    borderRadius: 2,
                    bgcolor: 'rgba(255,255,255,0.15)',
                    border: '1px solid rgba(255,255,255,0.25)',
                  }}
                >
                  <Typography variant="caption" sx={{ opacity: 0.9 }}>
                    Số dư mục tiêu hiện tại
                  </Typography>
                  <Typography fontWeight={800} fontSize={20}>
                    {formatMoneyFull(selectedGoal.currentAmount)}
                  </Typography>
                </Paper>
              </Box>
              <DialogContent sx={{ pt: 2.5 }}>
                <TextField
                  select
                  fullWidth
                  label={transferOpen === 'deposit' ? 'Ví nguồn' : 'Ví nhận'}
                  value={walletId}
                  onChange={(e) => setWalletId(Number(e.target.value))}
                  margin="normal"
                  InputLabelProps={{ shrink: true }}
                  InputProps={{
                    startAdornment: (
                      <InputAdornment position="start">
                        <AccountBalanceWalletRounded color="primary" fontSize="small" />
                      </InputAdornment>
                    ),
                  }}
                >
                  {wallets.map((w) => (
                    <MenuItem key={w.id} value={w.id}>
                      <Stack direction="row" justifyContent="space-between" width="100%" spacing={2}>
                        <Typography fontWeight={600}>{w.name}</Typography>
                        <Typography color="text.secondary" fontSize={14}>
                          {w.currentBalance != null ? formatMoneyFull(w.currentBalance) : '—'}
                        </Typography>
                      </Stack>
                    </MenuItem>
                  ))}
                </TextField>
                <TextField
                  fullWidth
                  label="Số tiền"
                  value={transferAmount}
                  onChange={(e) => setTransferAmount(formatAmountInput(e.target.value))}
                  margin="normal"
                  inputMode="numeric"
                  placeholder="VD: 500.000"
                  InputLabelProps={{ shrink: true }}
                  InputProps={{
                    endAdornment: (
                      <InputAdornment position="end">
                        <Typography fontWeight={700} color="text.secondary">
                          ₫
                        </Typography>
                      </InputAdornment>
                    ),
                  }}
                />
                <TextField
                  fullWidth
                  label="Ghi chú (tùy chọn)"
                  value={transferNote}
                  onChange={(e) => setTransferNote(e.target.value)}
                  margin="normal"
                  placeholder="VD: Lương tháng 6"
                  InputLabelProps={{ shrink: true }}
                />
                <Alert severity="info" sx={{ mt: 1.5, borderRadius: 2 }}>
                  Giao dịch nạp/rút không tính vào chi tiêu hàng ngày.
                </Alert>
                {error && (
                  <Alert severity="error" sx={{ mt: 1.5, borderRadius: 2 }}>
                    {error}
                  </Alert>
                )}
              </DialogContent>
              <DialogActions sx={{ px: 3, pb: 2.5, pt: 0 }}>
                <Button onClick={() => setTransferOpen(null)}>Hủy</Button>
                <Button
                  variant="contained"
                  disabled={!walletId || parseAmount(transferAmount) <= 0 || transferMut.isPending}
                  onClick={() => transferMut.mutate()}
                  sx={{
                    borderRadius: 2,
                    fontWeight: 700,
                    px: 3,
                    bgcolor: transferOpen === 'deposit' ? '#2E7D32' : '#F57C00',
                    '&:hover': {
                      bgcolor: transferOpen === 'deposit' ? '#1B5E20' : '#E65100',
                    },
                  }}
                >
                  {transferMut.isPending
                    ? 'Đang xử lý…'
                    : transferOpen === 'deposit'
                      ? 'Nạp tiền'
                      : 'Rút tiền'}
                </Button>
              </DialogActions>
            </>
          )}
        </Dialog>

        <Dialog
          open={historyOpen}
          onClose={() => setHistoryOpen(false)}
          fullWidth
          maxWidth="sm"
          PaperProps={{ sx: { borderRadius: 3, overflow: 'hidden' } }}
        >
          <Box
            sx={{
              px: 3,
              py: 2.5,
              background: `linear-gradient(135deg, ${palette.primary.main} 0%, ${palette.primary.dark} 100%)`,
              color: 'white',
            }}
          >
            <Stack direction="row" justifyContent="space-between" alignItems="flex-start">
              <Stack direction="row" spacing={1.5} alignItems="center">
                <Box
                  sx={{
                    width: 44,
                    height: 44,
                    borderRadius: 2,
                    bgcolor: 'rgba(255,255,255,0.2)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                  }}
                >
                  <HistoryRounded />
                </Box>
                <Box>
                  <Typography fontWeight={800} fontSize={18}>
                    Lịch sử nạp/rút
                  </Typography>
                  <Typography variant="body2" sx={{ opacity: 0.92 }}>
                    {selectedGoal?.name}
                  </Typography>
                </Box>
              </Stack>
              <IconButton
                size="small"
                onClick={() => setHistoryOpen(false)}
                sx={{ color: 'white', mt: -0.5, mr: -0.5 }}
              >
                <CloseRounded />
              </IconButton>
            </Stack>
            {selectedGoal && (
              <Stack direction="row" spacing={1} mt={2}>
                <Chip
                  size="small"
                  label={`Đã tiết kiệm: ${formatMoneyFull(selectedGoal.currentAmount)}`}
                  sx={{ bgcolor: 'rgba(255,255,255,0.2)', color: 'white', fontWeight: 700 }}
                />
                <Chip
                  size="small"
                  label={`${history.length} giao dịch`}
                  sx={{ bgcolor: 'rgba(255,255,255,0.15)', color: 'white', fontWeight: 600 }}
                />
              </Stack>
            )}
          </Box>
          <DialogContent sx={{ pt: 2, pb: 1, maxHeight: 420 }}>
            {history.length === 0 ? (
              <Box textAlign="center" py={4}>
                <HistoryRounded sx={{ fontSize: 48, color: 'text.disabled', mb: 1 }} />
                <Typography color="text.secondary" fontWeight={600}>
                  Chưa có giao dịch nạp/rút
                </Typography>
                <Typography variant="body2" color="text.secondary" mt={0.5}>
                  Các lần nạp hoặc rút tiền sẽ hiển thị tại đây
                </Typography>
              </Box>
            ) : (
              <Stack spacing={1.25}>
                {history.map((tx) => {
                  const isDeposit = tx.type === 'DEPOSIT';
                  const isSpend = tx.type === 'SPEND';
                  const accent = isDeposit ? '#2E7D32' : isSpend ? '#7B1FA2' : '#F57C00';
                  const label = isDeposit ? 'Nạp tiền' : isSpend ? 'Chi tiêu từ mục tiêu' : 'Rút tiền';
                  return (
                    <Paper
                      key={tx.id}
                      elevation={0}
                      sx={{
                        p: 1.75,
                        borderRadius: 2.5,
                        border: '1px solid',
                        borderColor: `${accent}33`,
                        bgcolor: `${accent}08`,
                      }}
                    >
                      <Stack direction="row" spacing={1.5} alignItems="flex-start">
                        <Box
                          sx={{
                            width: 40,
                            height: 40,
                            borderRadius: 2,
                            bgcolor: `${accent}18`,
                            color: accent,
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            flexShrink: 0,
                          }}
                        >
                          {isDeposit ? (
                            <AddCircleOutlineRounded fontSize="small" />
                          ) : isSpend ? (
                            <ShoppingBagRounded fontSize="small" />
                          ) : (
                            <RemoveCircleOutlineRounded fontSize="small" />
                          )}
                        </Box>
                        <Box flex={1} minWidth={0}>
                          <Stack direction="row" justifyContent="space-between" alignItems="center">
                            <Typography fontWeight={800}>
                              {label}
                            </Typography>
                            <Typography fontWeight={800} color={accent}>
                              {isDeposit ? '+' : '-'}
                              {formatMoneyFull(tx.amount)}
                            </Typography>
                          </Stack>
                          <Typography variant="caption" color="text.secondary" display="block" mt={0.25}>
                            {tx.wallet?.name ?? 'Ví'} ·{' '}
                            {new Date(tx.createdAt).toLocaleString('vi-VN', {
                              day: '2-digit',
                              month: '2-digit',
                              year: 'numeric',
                              hour: '2-digit',
                              minute: '2-digit',
                            })}
                          </Typography>
                          {tx.note && (
                            <Typography variant="body2" color="text.secondary" mt={0.75}>
                              {tx.note}
                            </Typography>
                          )}
                        </Box>
                      </Stack>
                    </Paper>
                  );
                })}
              </Stack>
            )}
          </DialogContent>
          <DialogActions sx={{ px: 3, pb: 2.5 }}>
            <Button onClick={() => setHistoryOpen(false)} sx={{ fontWeight: 700 }}>
              Đóng
            </Button>
          </DialogActions>
        </Dialog>
      </Box>
    </GradientBackground>
  );
}
