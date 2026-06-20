import {
  Alert,
  Box,
  Button,
  Card,
  CardActionArea,
  Chip,
  Divider,
  Grid,
  IconButton,
  InputAdornment,
  LinearProgress,
  Paper,
  Slider,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import {
  AccountBalanceWalletOutlined,
  ArrowBackRounded,
  CalendarMonthOutlined,
  DeleteOutlineRounded,
  EditOutlined,
  EmojiEventsOutlined,
  InfoOutlined,
  LockOutlined,
  NotificationsActiveOutlined,
  PaymentsOutlined,
  SavingsOutlined,
  SpeedOutlined,
  TrackChangesOutlined,
} from '@mui/icons-material';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { GradientBackground } from '@/components/common/GradientBackground';
import { CategorySelectField } from '@/components/category/CategorySelectField';
import { DatePickerField } from '@/components/common/DatePickerField';
import {
  formatAmountInput,
  OnboardingField,
} from '@/components/common/OnboardingField';
import { PersonalityRobotAvatar } from '@/components/robot/PersonalityRobotAvatar';
import { useAuth } from '@/contexts/AuthContext';
import { extractApiError } from '@/lib/api';
import { CategoryIconBadge } from '@/lib/categoryIcons';
import { formatMoneyFull } from '@/lib/format';
import * as savingGoalService from '@/services/savingGoalService';
import * as spendingLimitService from '@/services/spendingLimitService';
import type { SpendingLimit } from '@/services/spendingLimitService';
import * as categoryService from '@/services/categoryService';
import * as userService from '@/services/userService';
import { palette } from '@/theme';

const PERSONALITIES = [
  {
    id: 'HAPPY' as const,
    label: 'Cổ Động Viên Ủng Hộ',
    desc: 'Người đồng hành tràn đầy năng lượng, sẵn sàng ăn mừng mọi bước trong hành trình tài chính.',
    color: palette.primary.main,
  },
  {
    id: 'ANGRY' as const,
    label: 'Mẹ Giận Dữ',
    desc: 'Nhắc nhở mạnh mẽ, giúp bạn kiểm soát chi tiêu và không chi tiêu quá tay.',
    color: palette.error.main,
  },
  {
    id: 'SAD' as const,
    label: 'Người Cố Vấn Thông Thái',
    desc: 'Trợ lý nhẹ nhàng, phân tích và đưa ra lời khuyên tài chính hợp lý.',
    color: '#3F51B5',
  },
];

const TOTAL_STEPS = 4;

function OnboardingBackButton({ onClick }: { onClick: () => void }) {
  return (
    <Button
      startIcon={<ArrowBackRounded />}
      onClick={onClick}
      sx={{ fontWeight: 600, color: 'text.secondary', alignSelf: 'flex-start' }}
    >
      Quay về bước trước
    </Button>
  );
}

export function OnboardingPage() {
  const navigate = useNavigate();
  const qc = useQueryClient();
  const { user, refreshUser } = useAuth();
  const [step, setStep] = useState(0);
  const [personality, setPersonality] = useState<'HAPPY' | 'SAD' | 'ANGRY'>('HAPPY');
  const [walletName, setWalletName] = useState('Ví của tôi');
  const [currency, setCurrency] = useState<'VND' | 'USD'>('VND');
  const [initialBalance, setInitialBalance] = useState('0');
  const [goalName, setGoalName] = useState('');
  const [goalTarget, setGoalTarget] = useState('');
  const [goalInitial, setGoalInitial] = useState('');
  const [goalDate, setGoalDate] = useState('');
  const [linkedGoalId, setLinkedGoalId] = useState<number | null>(null);
  const stepHydrated = useRef(false);
  const goalFormSynced = useRef(false);
  const [limitCategoryId, setLimitCategoryId] = useState<number | ''>('');
  const [limitAmount, setLimitAmount] = useState('');
  const [limitWarning, setLimitWarning] = useState('80');
  const [editingLimitId, setEditingLimitId] = useState<number | null>(null);
  const [savingLimit, setSavingLimit] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const { data: savedGoals = [] } = useQuery({
    queryKey: ['saving-goals'],
    queryFn: savingGoalService.fetchSavingGoals,
    enabled: step === 2,
  });

  const { data: expenseCategories = [] } = useQuery({
    queryKey: ['categories', 'EXPENSE'],
    queryFn: () => categoryService.fetchCategories('EXPENSE'),
    enabled: step === 3,
  });

  const { data: savedLimits = [] } = useQuery({
    queryKey: ['spending-limits'],
    queryFn: spendingLimitService.fetchSpendingLimits,
    enabled: step === 3,
  });

  const usedCategoryIds = useMemo(
    () =>
      savedLimits
        .filter((l) => l.id !== editingLimitId)
        .map((l) => l.categoryId),
    [savedLimits, editingLimitId],
  );

  const resetLimitForm = useCallback(() => {
    setEditingLimitId(null);
    setLimitAmount('');
    setLimitWarning('80');
  }, []);

  const pickFirstAvailableCategory = useCallback(() => {
    const available = expenseCategories.find((c) => !usedCategoryIds.includes(c.id));
    setLimitCategoryId(available?.id ?? '');
  }, [expenseCategories, usedCategoryIds]);

  useEffect(() => {
    if (!user || stepHydrated.current) return;
    stepHydrated.current = true;
    if (user.spendingLimitSetupCompleted || user.spendingLimitSetupSkipped) {
      setStep(3);
    } else if (user.savingGoalSetupCompleted || user.savingGoalSetupSkipped) {
      setStep(3);
    } else if (user.walletSetupCompleted) {
      setStep(2);
    } else if (user.botSetupCompleted) {
      setStep(1);
    }
  }, [user]);

  useEffect(() => {
    if (step !== 2) {
      goalFormSynced.current = false;
      return;
    }
    if (goalFormSynced.current || savedGoals.length === 0) return;
    const primary = [...savedGoals].sort((a, b) => b.id - a.id)[0];
    setLinkedGoalId(primary.id);
    setGoalName(primary.name);
    setGoalTarget(formatAmountInput(String(Math.round(primary.targetAmount))));
    setGoalDate(primary.targetDate?.split('T')[0] ?? primary.targetDate ?? '');
    goalFormSynced.current = true;
  }, [step, savedGoals]);

  useEffect(() => {
    if (step !== 3 || expenseCategories.length === 0 || editingLimitId) return;
    const currentOk =
      limitCategoryId !== '' && !usedCategoryIds.includes(Number(limitCategoryId));
    if (!currentOk) pickFirstAvailableCategory();
  }, [step, expenseCategories, usedCategoryIds, limitCategoryId, editingLimitId, pickFirstAvailableCategory]);

  async function saveCurrentLimit(): Promise<boolean> {
    if (!limitCategoryId || !limitAmount) return false;
    const body = {
      amount: Number(limitAmount.replace(/\D/g, '')),
      categoryId: Number(limitCategoryId),
      periodType: 'MONTHLY' as const,
      warningThresholdPercent: Number(limitWarning) || 80,
    };
    if (editingLimitId) {
      await spendingLimitService.updateSpendingLimit(editingLimitId, body);
    } else {
      if (usedCategoryIds.includes(Number(limitCategoryId))) {
        setError('Danh mục này đã có hạn mức');
        return false;
      }
      await spendingLimitService.createSpendingLimit(body);
    }
    await qc.invalidateQueries({ queryKey: ['spending-limits'] });
    resetLimitForm();
    pickFirstAvailableCategory();
    return true;
  }

  function startEditLimit(limit: SpendingLimit) {
    setEditingLimitId(limit.id);
    setLimitCategoryId(limit.categoryId);
    setLimitAmount(formatAmountInput(String(Math.round(limit.limitAmount))));
    setLimitWarning(String(limit.warningThresholdPercent ?? 80));
    setError(null);
  }

  async function handleDeleteLimit(id: number) {
    if (!confirm('Xóa hạn mức này?')) return;
    setSavingLimit(true);
    try {
      await spendingLimitService.deleteSpendingLimit(id);
      if (editingLimitId === id) {
        resetLimitForm();
        pickFirstAvailableCategory();
      }
      await qc.invalidateQueries({ queryKey: ['spending-limits'] });
      setError(null);
    } catch (e) {
      setError(extractApiError(e));
    } finally {
      setSavingLimit(false);
    }
  }

  async function handleSaveLimitClick() {
    setSavingLimit(true);
    try {
      await saveCurrentLimit();
      setError(null);
    } catch (e) {
      setError(extractApiError(e));
    } finally {
      setSavingLimit(false);
    }
  }

  const progress = ((step + 1) / TOTAL_STEPS) * 100;

  const botMut = useMutation({
    mutationFn: () =>
      userService.patchProfile({
        botPersonality: personality,
        botSetupCompleted: true,
      }),
    onSuccess: async () => {
      await refreshUser();
      setStep(1);
      setError(null);
    },
    onError: (e) => setError(extractApiError(e)),
  });

  const walletMut = useMutation({
    mutationFn: () =>
      userService.patchProfile({
        walletName: walletName.trim() || 'Ví của tôi',
        currencyCode: currency,
        initialBalance: Number(initialBalance.replace(/\D/g, '')) || 0,
        walletSetupCompleted: true,
      }),
    onSuccess: async () => {
      await refreshUser();
      setStep(2);
      setError(null);
    },
    onError: (e) => setError(extractApiError(e)),
  });

  const skipSavingMut = useMutation({
    mutationFn: () =>
      userService.patchProfile({
        savingGoalSetupSkipped: true,
      }),
    onSuccess: async () => {
      await refreshUser();
      setStep(3);
      setError(null);
    },
    onError: (e) => setError(extractApiError(e)),
  });

  const savingMut = useMutation({
    mutationFn: async () => {
      const payload = {
        name: goalName.trim(),
        targetAmount: Number(goalTarget.replace(/\D/g, '')),
        targetDate: goalDate || undefined,
      };

      let goalId = linkedGoalId;
      if (goalId) {
        await savingGoalService.updateSavingGoal(goalId, payload);
      } else {
        const created = await savingGoalService.createSavingGoal({
          ...payload,
          initialAmount: Number(goalInitial.replace(/\D/g, '')) || undefined,
        });
        goalId = created.id;
      }

      if (!user?.savingGoalSetupCompleted) {
        await userService.patchProfile({ savingGoalSetupCompleted: true });
      }
      return goalId;
    },
    onSuccess: async (goalId) => {
      setLinkedGoalId(goalId);
      await qc.invalidateQueries({ queryKey: ['saving-goals'] });
      await refreshUser();
      setStep(3);
      setError(null);
    },
    onError: (e) => setError(extractApiError(e)),
  });

  const skipLimitMut = useMutation({
    mutationFn: () =>
      userService.patchProfile({
        spendingLimitSetupSkipped: true,
        onboardingCompleted: true,
      }),
    onSuccess: async () => {
      await refreshUser();
      navigate('/app/dashboard', { replace: true });
    },
    onError: (e) => setError(extractApiError(e)),
  });

  const limitMut = useMutation({
    mutationFn: async () => {
      if (limitCategoryId && limitAmount) {
        await saveCurrentLimit();
      }
      return userService.patchProfile({
        spendingLimitSetupCompleted: true,
        onboardingCompleted: true,
      });
    },
    onSuccess: async () => {
      await refreshUser();
      navigate('/app/dashboard', { replace: true });
    },
    onError: (e) => setError(extractApiError(e)),
  });

  const selectedDesc =
    PERSONALITIES.find((p) => p.id === personality)?.desc ?? '';

  return (
    <GradientBackground>
      <Box
        sx={{
          width: '100%',
          maxWidth: { xs: '100%', sm: 800, md: 1100, lg: 1400, xl: 1536 },
          mx: 'auto',
          px: { xs: 2, sm: 3, md: 3, lg: 4, xl: 5 },
          py: { xs: 3, md: 5 },
        }}
      >
        <LinearProgress
          variant="determinate"
          value={progress}
          sx={{ mb: 3, borderRadius: 999, height: 8, width: '100%' }}
        />
        <Typography variant="caption" color="text.secondary">
          Bước {step + 1}/{TOTAL_STEPS}
        </Typography>

        {step === 0 && (
          <>
            <Typography
              variant="h5"
              fontWeight={800}
              gutterBottom
              sx={{ mt: 1, typography: { md: 'h4' } }}
            >
              Thiết lập trợ lý tài chính — Natta
            </Typography>
            <Typography color="text.secondary" sx={{ mb: 3, fontSize: { md: '1.05rem' } }}>
              Bạn muốn Natta có tính cách như thế nào?
            </Typography>
            <Grid container spacing={{ xs: 2, md: 3, lg: 4 }}>
              {PERSONALITIES.map((p) => (
                <Grid item xs={12} sm={4} key={p.id}>
                  <Card
                    onClick={() => setPersonality(p.id)}
                    sx={{
                      height: '100%',
                      cursor: 'pointer',
                      border:
                        personality === p.id
                          ? `2px solid ${p.color}`
                          : '1px solid',
                      borderColor: personality === p.id ? p.color : 'divider',
                      bgcolor: personality === p.id ? `${p.color}22` : 'background.paper',
                    }}
                  >
                    <CardActionArea sx={{ p: { xs: 2, md: 3 }, textAlign: 'center' }}>
                      <Box display="flex" justifyContent="center" mb={1}>
                        <PersonalityRobotAvatar
                          type={p.id}
                          size={88}
                          isSelected={personality === p.id}
                          animated={personality === p.id}
                        />
                      </Box>
                      <Typography fontWeight={700} fontSize={{ xs: 13, md: 14 }}>
                        {p.label}
                      </Typography>
                    </CardActionArea>
                  </Card>
                </Grid>
              ))}
            </Grid>
            <Divider sx={{ my: 2 }} />
            <Stack direction="row" spacing={1} alignItems="flex-start">
              <InfoOutlined color="primary" fontSize="small" />
              <Typography variant="body2" color="text.secondary">
                {selectedDesc}
              </Typography>
            </Stack>
            <Stack direction="row" spacing={1} alignItems="flex-start" sx={{ mt: 2 }}>
              <LockOutlined sx={{ color: 'text.disabled', fontSize: 20 }} />
              <Typography variant="body2" color="text.secondary">
                Nhiều tính cách khác có thể mở khóa sau — bạn có thể đổi trong Cài đặt.
              </Typography>
            </Stack>
            {error && (
              <Typography color="error" variant="body2" sx={{ mt: 2 }}>
                {error}
              </Typography>
            )}
            <Button
              fullWidth
              variant="contained"
              size="large"
              sx={{ mt: 3, borderRadius: 999, py: 2, px: 4, fontSize: '1.05rem' }}
              onClick={() => botMut.mutate()}
              disabled={botMut.isPending}
            >
              {botMut.isPending ? 'Đang lưu…' : 'Tiếp tục'}
            </Button>
          </>
        )}

        {step === 1 && (
          <>
            <Typography
              variant="h5"
              fontWeight={800}
              gutterBottom
              sx={{ mt: 1, typography: { md: 'h4' } }}
            >
              Thiết lập ví chính
            </Typography>
            <Typography color="text.secondary" sx={{ mb: 3 }}>
              Ví chính là nơi quản lý dòng tiền hàng ngày. Mục tiêu tiết kiệm sẽ chuyển tiền nội bộ từ ví này.
            </Typography>
            <TextField
              fullWidth
              label="Tên ví"
              value={walletName}
              onChange={(e) => setWalletName(e.target.value)}
              margin="normal"
            />
            <Typography variant="body2" color="text.secondary" sx={{ mt: 2, mb: 1 }}>
              Tiền tệ
            </Typography>
            <Stack direction="row" spacing={1}>
              <Chip
                label="VND (₫)"
                onClick={() => setCurrency('VND')}
                color={currency === 'VND' ? 'primary' : 'default'}
                variant={currency === 'VND' ? 'filled' : 'outlined'}
              />
              <Chip
                label="USD ($)"
                onClick={() => setCurrency('USD')}
                color={currency === 'USD' ? 'primary' : 'default'}
                variant={currency === 'USD' ? 'filled' : 'outlined'}
              />
            </Stack>
            <TextField
              fullWidth
              label="Số dư ban đầu"
              value={initialBalance}
              onChange={(e) => setInitialBalance(e.target.value)}
              margin="normal"
            />
            {error && (
              <Typography color="error" variant="body2" sx={{ mt: 2 }}>
                {error}
              </Typography>
            )}
            <Stack spacing={2} sx={{ mt: 3 }}>
              <OnboardingBackButton onClick={() => setStep(0)} />
              <Stack direction="row" spacing={2}>
                <Button
                  fullWidth
                  variant="contained"
                  size="large"
                  onClick={() => walletMut.mutate()}
                  disabled={walletMut.isPending}
                >
                  {walletMut.isPending ? 'Đang lưu…' : 'Tiếp tục'}
                </Button>
              </Stack>
            </Stack>
          </>
        )}

        {step === 2 && (
          <>
            <Typography
              variant="h5"
              fontWeight={800}
              gutterBottom
              sx={{ mt: 1, typography: { md: 'h4' } }}
            >
              Thiết lập mục tiêu tiết kiệm
            </Typography>
            <Typography color="text.secondary" sx={{ mb: 3 }}>
              Tạo mục tiêu đầu tiên hoặc bỏ qua — bạn có thể thiết lập sau trong mục Mục tiêu tiết kiệm.
            </Typography>

            {linkedGoalId && (
              <Alert severity="info" sx={{ mb: 2, borderRadius: 2 }}>
                Mục tiêu đã được tạo. Chỉnh sửa và bấm Tiếp tục sẽ <strong>cập nhật</strong> mục tiêu hiện
                tại — không tạo thêm bản sao.
              </Alert>
            )}

            {savedGoals.length > 1 && (
              <Alert severity="warning" sx={{ mb: 2, borderRadius: 2 }}>
                Bạn có {savedGoals.length} mục tiêu trùng lặp. Vào mục{' '}
                <strong>Mục tiêu tiết kiệm</strong> để xóa các bản sao không cần thiết.
              </Alert>
            )}

            <Paper
              elevation={0}
              sx={{
                p: { xs: 2.5, md: 3 },
                borderRadius: 3,
                border: '1px solid',
                borderColor: 'divider',
                bgcolor: 'background.paper',
                boxShadow: '0 8px 32px rgba(2, 136, 209, 0.08)',
              }}
            >
              <Stack direction="row" spacing={1.5} alignItems="center" sx={{ mb: 2 }}>
                <Box
                  sx={{
                    width: 44,
                    height: 44,
                    borderRadius: 2,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    bgcolor: `${palette.primary.main}14`,
                    color: palette.primary.main,
                  }}
                >
                  <EmojiEventsOutlined />
                </Box>
                <Box>
                  <Typography fontWeight={700}>Mục tiêu mới</Typography>
                  <Typography variant="body2" color="text.secondary">
                    Điền thông tin cơ bản để bắt đầu tiết kiệm
                  </Typography>
                </Box>
              </Stack>

              <OnboardingField
                label="Tên mục tiêu"
                value={goalName}
                onChange={(e) => setGoalName(e.target.value)}
                placeholder="VD: Mua laptop, Du lịch Đà Lạt"
                startIcon={<TrackChangesOutlined fontSize="small" />}
              />
              <OnboardingField
                label="Số tiền mục tiêu"
                value={goalTarget}
                onChange={(e) => setGoalTarget(formatAmountInput(e.target.value))}
                placeholder="VD: 15.000.000"
                startIcon={<SavingsOutlined fontSize="small" />}
                InputProps={{
                  endAdornment: (
                    <InputAdornment position="end">
                      <Typography variant="body2" fontWeight={700} color="text.secondary">
                        ₫
                      </Typography>
                    </InputAdornment>
                  ),
                }}
              />
              <OnboardingField
                label="Số tiền đã có (tùy chọn)"
                value={goalInitial}
                onChange={(e) => setGoalInitial(formatAmountInput(e.target.value))}
                placeholder="VD: 2.000.000"
                startIcon={<AccountBalanceWalletOutlined fontSize="small" />}
                InputProps={{
                  endAdornment: (
                    <InputAdornment position="end">
                      <Typography variant="body2" fontWeight={700} color="text.secondary">
                        ₫
                      </Typography>
                    </InputAdornment>
                  ),
                }}
              />
              <DatePickerField
                label="Ngày dự kiến hoàn thành"
                value={goalDate}
                onChange={setGoalDate}
                placeholder="Nhấn để chọn ngày trên lịch"
              />

              <Stack
                direction="row"
                spacing={1}
                alignItems="flex-start"
                sx={{
                  mt: 1,
                  p: 1.5,
                  borderRadius: 2,
                  bgcolor: `${palette.primary.main}0A`,
                }}
              >
                <InfoOutlined sx={{ fontSize: 18, color: palette.primary.main, mt: 0.25 }} />
                <Typography variant="caption" color="text.secondary" lineHeight={1.6}>
                  Ngày dự kiến giúp theo dõi tiến độ. Bạn có thể bỏ trống và cập nhật sau.
                </Typography>
              </Stack>
            </Paper>

            {error && (
              <Typography color="error" variant="body2" sx={{ mt: 2 }}>
                {error}
              </Typography>
            )}
            <Stack spacing={2} sx={{ mt: 3 }}>
              <OnboardingBackButton onClick={() => setStep(1)} />
              <Stack direction="row" spacing={2}>
                <Button
                  onClick={() => skipSavingMut.mutate()}
                  disabled={skipSavingMut.isPending}
                  sx={{ fontWeight: 600, color: 'text.secondary' }}
                >
                  Thiết lập sau
                </Button>
                <Button
                  fullWidth
                  variant="contained"
                  size="large"
                  onClick={() => savingMut.mutate()}
                  disabled={
                    savingMut.isPending ||
                    !goalName.trim() ||
                    Number(goalTarget.replace(/\D/g, '')) <= 0
                  }
                  sx={{
                    borderRadius: 2.5,
                    py: 1.4,
                    fontWeight: 700,
                    boxShadow: '0 6px 20px rgba(2, 136, 209, 0.35)',
                  }}
                >
                  {savingMut.isPending
                    ? 'Đang lưu…'
                    : linkedGoalId
                      ? 'Cập nhật & tiếp tục'
                      : 'Tiếp tục'}
                </Button>
              </Stack>
            </Stack>
          </>
        )}

        {step === 3 && (
          <>
            <Typography
              variant="h5"
              fontWeight={800}
              gutterBottom
              sx={{ mt: 1, typography: { md: 'h4' } }}
            >
              Thiết lập hạn mức chi tiêu
            </Typography>
            <Typography color="text.secondary" sx={{ mb: 3 }}>
              Bạn có thể đặt hạn mức chi tiêu cho từng danh mục như ăn uống, di chuyển, mua sắm để kiểm soát tài chính tốt hơn. Bạn cũng có thể bỏ qua và thiết lập sau.
            </Typography>

            {savedLimits.length > 0 && (
              <Chip
                label={`Đã thêm ${savedLimits.length} hạn mức`}
                color="primary"
                variant="outlined"
                sx={{ mb: 2, fontWeight: 700 }}
              />
            )}

            {savedLimits.length > 0 && (
              <Stack spacing={1} sx={{ mb: 2 }}>
                {savedLimits.map((l, i) => {
                  const name = l.category?.name ?? 'Danh mục';
                  const isEditing = editingLimitId === l.id;
                  return (
                    <Paper
                      key={l.id}
                      elevation={0}
                      sx={{
                        p: 1.5,
                        borderRadius: 2.5,
                        border: '1px solid',
                        borderColor: isEditing ? palette.primary.main : 'divider',
                        bgcolor: isEditing ? `${palette.primary.main}08` : 'background.paper',
                      }}
                    >
                      <Stack direction="row" alignItems="center" spacing={1.25}>
                        <CategoryIconBadge name={name} icon={l.category?.icon} colorIndex={i} size={36} />
                        <Box flex={1} minWidth={0}>
                          <Typography fontWeight={700} noWrap>
                            {name}
                          </Typography>
                          <Typography variant="caption" color="text.secondary">
                            {formatMoneyFull(l.limitAmount)} · Cảnh báo {l.warningThresholdPercent ?? 80}%
                          </Typography>
                        </Box>
                        <IconButton
                          size="small"
                          aria-label="Sửa hạn mức"
                          onClick={() => startEditLimit(l)}
                          disabled={savingLimit}
                        >
                          <EditOutlined fontSize="small" />
                        </IconButton>
                        <IconButton
                          size="small"
                          color="error"
                          aria-label="Xóa hạn mức"
                          onClick={() => handleDeleteLimit(l.id)}
                          disabled={savingLimit}
                        >
                          <DeleteOutlineRounded fontSize="small" />
                        </IconButton>
                      </Stack>
                    </Paper>
                  );
                })}
              </Stack>
            )}

            <Paper
              elevation={0}
              sx={{
                p: { xs: 2.5, md: 3 },
                borderRadius: 3,
                border: '1px solid',
                borderColor: 'divider',
                bgcolor: 'background.paper',
                boxShadow: '0 8px 32px rgba(2, 136, 209, 0.08)',
              }}
            >
              <Stack direction="row" spacing={1.5} alignItems="center" sx={{ mb: 2 }}>
                <Box
                  sx={{
                    width: 44,
                    height: 44,
                    borderRadius: 2,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    bgcolor: `${palette.primary.main}14`,
                    color: palette.primary.main,
                  }}
                >
                  <SpeedOutlined />
                </Box>
                <Box>
                  <Typography fontWeight={700}>
                    {editingLimitId ? 'Sửa hạn mức' : 'Hạn mức theo tháng'}
                  </Typography>
                  <Typography variant="body2" color="text.secondary">
                    {editingLimitId
                      ? 'Chỉnh số tiền hoặc ngưỡng cảnh báo'
                      : 'Giới hạn chi tiêu theo từng danh mục'}
                  </Typography>
                </Box>
              </Stack>

              <CategorySelectField
                categories={expenseCategories}
                value={limitCategoryId}
                onChange={setLimitCategoryId}
                withOnboardingStyle
                disabledCategoryIds={usedCategoryIds}
              />

              <OnboardingField
                label="Số tiền hạn mức"
                value={limitAmount}
                onChange={(e) => setLimitAmount(formatAmountInput(e.target.value))}
                placeholder="VD: 2.000.000"
                startIcon={<PaymentsOutlined fontSize="small" />}
                InputProps={{
                  endAdornment: (
                    <InputAdornment position="end">
                      <Typography variant="body2" fontWeight={700} color="text.secondary">
                        ₫
                      </Typography>
                    </InputAdornment>
                  ),
                }}
              />

              <OnboardingField
                label="Chu kỳ"
                value="Theo tháng"
                disabled
                startIcon={<CalendarMonthOutlined fontSize="small" />}
              />

              <Box sx={{ px: 0.5, mt: 1, mb: 1 }}>
                <Stack direction="row" spacing={1} alignItems="center" sx={{ mb: 0.5 }}>
                  <NotificationsActiveOutlined sx={{ fontSize: 20, color: palette.primary.main }} />
                  <Typography variant="body2" fontWeight={700}>
                    Cảnh báo khi đạt {Number(limitWarning) || 80}%
                  </Typography>
                </Stack>
                <Slider
                  value={Number(limitWarning) || 80}
                  min={50}
                  max={100}
                  step={5}
                  marks={[
                    { value: 50, label: '50%' },
                    { value: 80, label: '80%' },
                    { value: 100, label: '100%' },
                  ]}
                  onChange={(_, v) => setLimitWarning(String(v))}
                  sx={{
                    color: palette.primary.main,
                    '& .MuiSlider-markLabel': { fontSize: 11 },
                  }}
                />
              </Box>

              <Stack
                direction="row"
                spacing={1}
                alignItems="flex-start"
                sx={{
                  p: 1.5,
                  borderRadius: 2,
                  bgcolor: `${palette.primary.main}0A`,
                }}
              >
                <InfoOutlined sx={{ fontSize: 18, color: palette.primary.main, mt: 0.25 }} />
                <Typography variant="caption" color="text.secondary" lineHeight={1.6}>
                  Hệ thống sẽ cảnh báo khi chi tiêu gần chạm hoặc vượt hạn mức. Bạn có thể thêm nhiều hạn mức cho các danh mục khác nhau.
                </Typography>
              </Stack>
            </Paper>

            {error && (
              <Typography color="error" variant="body2" sx={{ mt: 2 }}>
                {error}
              </Typography>
            )}

            <Stack spacing={2} sx={{ mt: 3 }}>
              <OnboardingBackButton onClick={() => setStep(2)} />
              {editingLimitId && (
                <Button
                  variant="text"
                  onClick={() => {
                    resetLimitForm();
                    pickFirstAvailableCategory();
                  }}
                  sx={{ alignSelf: 'flex-start', fontWeight: 600, color: 'text.secondary' }}
                >
                  Hủy sửa
                </Button>
              )}
              {limitCategoryId && limitAmount && (
                <Button
                  fullWidth
                  variant="outlined"
                  onClick={handleSaveLimitClick}
                  disabled={savingLimit || !limitCategoryId || !limitAmount}
                  sx={{ borderRadius: 2.5, fontWeight: 700 }}
                >
                  {savingLimit
                    ? 'Đang lưu…'
                    : editingLimitId
                      ? 'Cập nhật hạn mức'
                      : 'Lưu hạn mức'}
                </Button>
              )}
              <Stack direction="row" spacing={2}>
                <Button
                  onClick={() => skipLimitMut.mutate()}
                  disabled={skipLimitMut.isPending}
                  sx={{ fontWeight: 600, color: 'text.secondary' }}
                >
                  Thiết lập sau
                </Button>
                <Button
                  fullWidth
                  variant="contained"
                  size="large"
                  onClick={() => limitMut.mutate()}
                  disabled={limitMut.isPending}
                  sx={{
                    borderRadius: 2.5,
                    py: 1.4,
                    fontWeight: 700,
                    boxShadow: '0 6px 20px rgba(2, 136, 209, 0.35)',
                  }}
                >
                  {limitMut.isPending ? 'Đang lưu…' : 'Hoàn tất'}
                </Button>
              </Stack>
            </Stack>
          </>
        )}
      </Box>
    </GradientBackground>
  );
}
