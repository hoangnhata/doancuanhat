import {
  Box,
  Button,
  Chip,
  Dialog,
  DialogActions,
  DialogContent,
  LinearProgress,
  Paper,
  Slider,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { AddRounded, DeleteOutlineRounded, EditOutlined, SpeedOutlined } from '@mui/icons-material';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import type { SpendingLimit } from '@/services/spendingLimitService';
import { GradientBackground } from '@/components/common/GradientBackground';
import { CategorySelectField } from '@/components/category/CategorySelectField';
import { CategoryIconBadge } from '@/lib/categoryIcons';
import { extractApiError } from '@/lib/api';
import { formatMoneyFull } from '@/lib/format';
import { formatAmountInput } from '@/components/common/OnboardingField';
import * as categoryService from '@/services/categoryService';
import * as spendingLimitService from '@/services/spendingLimitService';
import type { SpendingLimitStatus } from '@/services/spendingLimitService';
import { palette } from '@/theme';

const STATUS_LABEL: Record<SpendingLimitStatus, string> = {
  SAFE: 'An toàn',
  WARNING: 'Sắp vượt hạn mức',
  EXCEEDED: 'Vượt hạn mức chi tiêu',
};

const STATUS_COLOR: Record<SpendingLimitStatus, string> = {
  SAFE: '#2E7D32',
  WARNING: '#F57C00',
  EXCEEDED: palette.error.main,
};

export function BudgetPage() {
  const qc = useQueryClient();
  const [open, setOpen] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [amount, setAmount] = useState('');
  const [categoryId, setCategoryId] = useState<number | ''>('');
  const [warningThreshold, setWarningThreshold] = useState(80);

  const { data: limits = [], isLoading } = useQuery({
    queryKey: ['spending-limits'],
    queryFn: spendingLimitService.fetchSpendingLimits,
  });

  const usedCategoryIds = useMemo(
    () => limits.filter((l) => l.id !== editingId).map((l) => l.categoryId),
    [limits, editingId],
  );

  function resetLimitForm() {
    setEditingId(null);
    setAmount('');
    setCategoryId('');
    setWarningThreshold(80);
  }

  function openCreateDialog() {
    resetLimitForm();
    setOpen(true);
  }

  function openEditDialog(limit: SpendingLimit) {
    setEditingId(limit.id);
    setAmount(formatAmountInput(String(Math.round(limit.limitAmount))));
    setCategoryId(limit.categoryId);
    setWarningThreshold(limit.warningThresholdPercent ?? 80);
    setOpen(true);
  }

  const { data: categories = [] } = useQuery({
    queryKey: ['categories', 'EXPENSE'],
    queryFn: () => categoryService.fetchCategories('EXPENSE'),
  });

  const saveMut = useMutation({
    mutationFn: () => {
      const body = {
        amount: Number(amount.replace(/\D/g, '')),
        categoryId: Number(categoryId),
        warningThresholdPercent: warningThreshold,
      };
      if (editingId) {
        return spendingLimitService.updateSpendingLimit(editingId, body);
      }
      return spendingLimitService.createSpendingLimit({
        ...body,
        periodType: 'MONTHLY',
        alertsEnabled: true,
      });
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['spending-limits'] });
      qc.invalidateQueries({ queryKey: ['spending-limit-alerts'] });
      setOpen(false);
      resetLimitForm();
    },
  });

  const delMut = useMutation({
    mutationFn: (id: number) => spendingLimitService.deleteSpendingLimit(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['spending-limits'] });
      qc.invalidateQueries({ queryKey: ['spending-limit-alerts'] });
    },
  });

  const warningCount = limits.filter((l) => l.status !== 'SAFE').length;

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
                  bgcolor: `${palette.primary.main}14`,
                  color: palette.primary.main,
                }}
              >
                <SpeedOutlined />
              </Box>
              <Typography variant="h5" fontWeight={800}>
                Hạn mức chi tiêu
              </Typography>
            </Stack>
            <Typography variant="body2" color="text.secondary" maxWidth={480}>
              Kiểm soát chi tiêu theo danh mục trong từng tháng. Chỉ tính giao dịch chi tiêu (EXPENSE).
            </Typography>
          </Box>
          <Button
            variant="contained"
            startIcon={<AddRounded />}
            onClick={openCreateDialog}
            sx={{ borderRadius: 2.5, fontWeight: 700, display: { xs: 'none', sm: 'flex' } }}
          >
            Tạo hạn mức
          </Button>
        </Stack>

        {!isLoading && limits.length > 0 && (
          <Stack direction="row" spacing={1} mb={2} flexWrap="wrap" useFlexGap>
            <Chip
              icon={<SpeedOutlined />}
              label={`${limits.length} hạn mức`}
              color="primary"
              variant="outlined"
              sx={{ fontWeight: 700 }}
            />
            {warningCount > 0 && (
              <Chip
                label={`${warningCount} cảnh báo`}
                sx={{ fontWeight: 700, bgcolor: '#FFF3E0', color: '#E65100', border: '1px solid #FFB74D' }}
              />
            )}
          </Stack>
        )}

        {isLoading ? (
          <Typography color="text.secondary">Đang tải…</Typography>
        ) : limits.length === 0 ? (
          <Paper
            elevation={0}
            sx={{
              p: 4,
              textAlign: 'center',
              borderRadius: 3,
              border: '1px solid',
              borderColor: 'divider',
              boxShadow: '0 8px 32px rgba(2, 136, 209, 0.08)',
            }}
          >
            <Box
              sx={{
                width: 72,
                height: 72,
                borderRadius: 3,
                mx: 'auto',
                mb: 2,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                bgcolor: `${palette.primary.main}12`,
                color: palette.primary.main,
              }}
            >
              <SpeedOutlined sx={{ fontSize: 36 }} />
            </Box>
            <Typography fontWeight={800} fontSize={18} gutterBottom>
              Chưa có hạn mức chi tiêu
            </Typography>
            <Typography color="text.secondary" mb={3}>
              Đặt hạn mức theo danh mục để kiểm soát chi tiêu hàng tháng.
            </Typography>
            <Button variant="contained" startIcon={<AddRounded />} onClick={openCreateDialog}>
              Tạo hạn mức đầu tiên
            </Button>
          </Paper>
        ) : (
          <Stack spacing={2}>
            {limits.map((l, i) => {
              const color = STATUS_COLOR[l.status];
              const name = l.category?.name ?? 'Danh mục';
              return (
              <Paper
                key={l.id}
                elevation={0}
                sx={{
                  p: 2.5,
                  borderRadius: 3,
                  border: '1px solid',
                  borderColor: l.status === 'EXCEEDED' ? `${palette.error.main}44` : 'divider',
                  boxShadow: l.status !== 'SAFE' ? '0 4px 20px rgba(245, 124, 0, 0.12)' : '0 4px 16px rgba(0,0,0,0.04)',
                }}
              >
                <Stack direction="row" spacing={1.5} alignItems="flex-start" mb={2}>
                  <CategoryIconBadge name={name} icon={l.category?.icon} colorIndex={i} size={44} />
                  <Box flex={1} minWidth={0}>
                    <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap" useFlexGap mb={0.25}>
                      <Typography variant="h6" fontWeight={800} noWrap>
                        {name}
                      </Typography>
                      <Chip
                        size="small"
                        label={STATUS_LABEL[l.status]}
                        sx={{
                          fontWeight: 700,
                          bgcolor: `${color}18`,
                          color,
                        }}
                      />
                    </Stack>
                    <Typography variant="caption" color="text.secondary" display="block">
                      Kỳ: {l.startDate} → {l.endDate}
                    </Typography>
                  </Box>
                </Stack>

                <Stack direction="row" justifyContent="space-between" mb={0.5}>
                  <Typography variant="caption" fontWeight={700} color="text.secondary">
                    Tiến độ chi tiêu
                  </Typography>
                  <Typography variant="caption" fontWeight={800} sx={{ color }}>
                    {l.usagePercent.toFixed(1)}%
                  </Typography>
                </Stack>
                <LinearProgress
                  variant="determinate"
                  value={Math.min(100, l.usagePercent)}
                  sx={{
                    height: 10,
                    borderRadius: 999,
                    bgcolor: `${color}18`,
                    '& .MuiLinearProgress-bar': {
                      borderRadius: 999,
                      bgcolor: color,
                    },
                  }}
                />

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
                      Đã chi
                    </Typography>
                    <Typography fontWeight={800} fontSize={15} sx={{ color }}>
                      {formatMoneyFull(l.currentSpent)}
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
                      Hạn mức
                    </Typography>
                    <Typography fontWeight={800} fontSize={15}>
                      {formatMoneyFull(l.limitAmount)}
                    </Typography>
                  </Box>
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
                    <SpeedOutlined sx={{ fontSize: 20, color: palette.primary.main, flexShrink: 0 }} />
                    <Box minWidth={0}>
                      <Typography variant="caption" color="text.secondary" fontWeight={700} display="block">
                        Còn lại · Cảnh báo {l.warningThresholdPercent ?? 80}%
                      </Typography>
                      <Typography fontWeight={800} fontSize={14} noWrap>
                        {formatMoneyFull(Math.max(0, l.remainingAmount))}
                      </Typography>
                    </Box>
                  </Box>
                </Stack>

                {l.statusMessage && (
                  <Typography variant="caption" color="text.secondary" display="block" mt={1}>
                    {l.statusMessage}
                  </Typography>
                )}

                <Stack direction="row" spacing={1} mt={2}>
                  <Button size="small" variant="outlined" startIcon={<EditOutlined />} onClick={() => openEditDialog(l)}>
                    Sửa
                  </Button>
                  <Button
                    size="small"
                    variant="outlined"
                    color="error"
                    startIcon={<DeleteOutlineRounded />}
                    onClick={() => {
                      if (confirm('Vô hiệu hóa hạn mức này?')) delMut.mutate(l.id);
                    }}
                  >
                    Xóa
                  </Button>
                </Stack>
              </Paper>
            );})}
          </Stack>
        )}

        <Button
          variant="contained"
          startIcon={<AddRounded />}
          onClick={openCreateDialog}
          fullWidth
          sx={{
            mt: 3,
            display: { xs: 'flex', sm: 'none' },
            borderRadius: 2.5,
            py: 1.4,
            fontWeight: 700,
          }}
        >
          Tạo hạn mức
        </Button>

        <Dialog
          open={open}
          onClose={() => {
            setOpen(false);
            resetLimitForm();
          }}
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
                {editingId ? <EditOutlined /> : <SpeedOutlined />}
              </Box>
              <Box>
                <Typography fontWeight={800} fontSize={18}>
                  {editingId ? 'Sửa hạn mức chi tiêu' : 'Tạo hạn mức chi tiêu'}
                </Typography>
                <Typography variant="body2" sx={{ opacity: 0.9 }}>
                  {editingId ? 'Chỉnh số tiền hoặc ngưỡng cảnh báo' : 'Giới hạn chi tiêu theo danh mục hàng tháng'}
                </Typography>
              </Box>
            </Stack>
          </Box>
          <DialogContent sx={{ pt: 2.5 }}>
            <CategorySelectField
              categories={categories}
              value={categoryId}
              onChange={setCategoryId}
              disabledCategoryIds={usedCategoryIds}
            />
            <TextField
              fullWidth
              label="Số tiền hạn mức"
              value={amount}
              onChange={(e) => setAmount(formatAmountInput(e.target.value))}
              placeholder="VD: 2.000.000"
              margin="normal"
              InputLabelProps={{ shrink: true }}
              InputProps={{
                endAdornment: <Typography color="text.secondary" fontWeight={600}>₫</Typography>,
              }}
            />
            <Typography variant="body2" color="text.secondary" sx={{ mt: 2, mb: 1 }}>
              Chu kỳ: Theo tháng
            </Typography>
            <Typography variant="body2" fontWeight={700} gutterBottom>
              Cảnh báo khi đạt {warningThreshold}%
            </Typography>
            <Slider
              value={warningThreshold}
              min={50}
              max={100}
              step={5}
              marks={[
                { value: 50, label: '50%' },
                { value: 80, label: '80%' },
                { value: 100, label: '100%' },
              ]}
              onChange={(_, v) => setWarningThreshold(v as number)}
            />
            {saveMut.error && (
              <Typography color="error" variant="body2" mt={1}>
                {extractApiError(saveMut.error)}
              </Typography>
            )}
          </DialogContent>
          <DialogActions sx={{ px: 3, pb: 2.5, pt: 0 }}>
            <Button
              onClick={() => {
                setOpen(false);
                resetLimitForm();
              }}
            >
              Hủy
            </Button>
            <Button
              variant="contained"
              onClick={() => saveMut.mutate()}
              disabled={!amount || categoryId === '' || saveMut.isPending}
              sx={{ borderRadius: 2, fontWeight: 700, px: 3 }}
            >
              {saveMut.isPending
                ? 'Đang lưu…'
                : editingId
                  ? 'Cập nhật hạn mức'
                  : 'Tạo hạn mức'}
            </Button>
          </DialogActions>
        </Dialog>
      </Box>
    </GradientBackground>
  );
}
