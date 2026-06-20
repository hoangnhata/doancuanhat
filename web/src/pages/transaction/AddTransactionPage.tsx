import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  IconButton,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import {
  AddRounded,
  DeleteOutlineRounded,
  EditRounded,
  ReceiptLongRounded,
} from '@mui/icons-material';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useNavigate, useParams, useLocation } from 'react-router-dom';
import { useEffect, useState } from 'react';
import { GradientBackground } from '@/components/common/GradientBackground';
import { AiAssistCard } from '@/components/transaction/AiAssistCard';
import { AmountInputSection } from '@/components/transaction/AmountInputSection';
import {
  CategoryChipPicker,
  WalletChipPicker,
} from '@/components/transaction/CategoryChipPicker';
import { FormSection } from '@/components/transaction/FormSection';
import { DatePickerField } from '@/components/common/DatePickerField';
import { ReceiptOcrDialog } from '@/components/transaction/ReceiptOcrDialog';
import { TransactionTypeToggle } from '@/components/transaction/TransactionTypeToggle';
import { useAuth } from '@/contexts/AuthContext';
import { useSelectedWallet } from '@/contexts/SelectedWalletContext';
import { extractApiError } from '@/lib/api';
import { formatMoneyFull } from '@/lib/format';
import { extractDateFromNaturalText } from '@/lib/transactionTextParse';
import * as categoryService from '@/services/categoryService';
import * as transactionService from '@/services/transactionService';
import * as walletService from '@/services/walletService';
import type { OcrReceiptResult } from '@/services/transactionService';
import * as spendingLimitService from '@/services/spendingLimitService';
import type { CheckTransactionResult } from '@/services/spendingLimitService';
import { palette } from '@/theme';
import type { AICategorizeResponse } from '@/types/models';

export function AddTransactionPage() {
  const { id } = useParams();
  const editId = id ? Number(id) : undefined;
  const navigate = useNavigate();
  const location = useLocation();
  const qc = useQueryClient();
  const { user } = useAuth();
  const { selectedWalletId, setSelectedWalletId } = useSelectedWallet();

  const [showCreatedHint, setShowCreatedHint] = useState(false);

  const [isExpense, setIsExpense] = useState(true);
  const [amount, setAmount] = useState('');
  const [description, setDescription] = useState('');
  const [natural, setNatural] = useState('');
  const [categoryId, setCategoryId] = useState<number | ''>('');
  const [date, setDate] = useState(() => new Date().toISOString().slice(0, 10));
  const [walletId, setWalletId] = useState<number | ''>('');
  const [error, setError] = useState<string | null>(null);
  const [aiSuggestions, setAiSuggestions] = useState<AICategorizeResponse[]>([]);
  const [aiDialogOpen, setAiDialogOpen] = useState(false);
  const [ocrOpen, setOcrOpen] = useState(false);
  const [limitCheck, setLimitCheck] = useState<CheckTransactionResult | null>(null);
  const [limitDialogOpen, setLimitDialogOpen] = useState(false);

  const { data: existing, isLoading: loadingTx } = useQuery({
    queryKey: ['transaction', editId],
    queryFn: () => transactionService.fetchTransaction(editId!),
    enabled: editId != null && !Number.isNaN(editId),
  });

  const { data: wallets = [] } = useQuery({
    queryKey: ['wallets'],
    queryFn: walletService.fetchWallets,
  });

  const { data: expenseCats = [] } = useQuery({
    queryKey: ['categories', 'EXPENSE'],
    queryFn: () => categoryService.fetchCategories('EXPENSE'),
  });

  const { data: incomeCats = [] } = useQuery({
    queryKey: ['categories', 'INCOME'],
    queryFn: () => categoryService.fetchCategories('INCOME'),
  });

  const categories = isExpense ? expenseCats : incomeCats;

  useEffect(() => {
    const created = (location.state as { justCreated?: boolean } | null)?.justCreated;
    if (!created) return;
    setShowCreatedHint(true);
    navigate(location.pathname, { replace: true, state: null });
  }, [location.pathname, location.state, navigate]);

  useEffect(() => {
    if (!existing) return;
    setIsExpense(existing.type === 'EXPENSE');
    setAmount(String(Math.round(existing.amount)));
    setDescription(existing.description ?? '');
    setCategoryId(existing.category.id);
    setDate(existing.transactionDate.slice(0, 10));
    setWalletId(existing.walletId ?? '');
  }, [existing]);

  useEffect(() => {
    if (wallets.length && walletId === '') {
      const w =
        (selectedWalletId && wallets.find((x) => x.id === selectedWalletId)) ||
        wallets.find((x) => x.isDefault) ||
        wallets[0];
      setWalletId(w.id);
    }
  }, [wallets, selectedWalletId, walletId]);

  useEffect(() => {
    if (categoryId === '' && categories.length > 0) {
      setCategoryId(categories[0].id);
    }
  }, [categories, categoryId]);

  const aiMut = useMutation({
    mutationFn: () =>
      transactionService.aiCategorizeBatch(natural.trim(), user?.botPersonality),
  });

  function applyAiSuggestion(r: AICategorizeResponse) {
    const t = (r.transactionType ?? '').toString().toUpperCase();
    const nextIsExpense = t !== 'INCOME';

    setIsExpense(nextIsExpense);
    if (r.amount != null) setAmount(String(Math.round(r.amount)));
    if (r.description) setDescription(r.description);

    const txDate =
      r.transactionDate?.slice(0, 10) ?? extractDateFromNaturalText(natural);
    if (txDate) setDate(txDate);

    const cats = nextIsExpense ? expenseCats : incomeCats;
    const match = cats.find(
      (c) => c.id === r.categoryId || c.name === r.categoryName,
    );
    if (match) setCategoryId(match.id);
  }

  function applyOcrResult(r: OcrReceiptResult) {
    const nextIsExpense = r.transactionType !== 'INCOME';
    setIsExpense(nextIsExpense);
    if (r.amount != null) setAmount(String(Math.round(r.amount)));
    if (r.transactionDate) setDate(r.transactionDate.slice(0, 10));
    const desc = r.description ?? r.merchant;
    if (desc) setDescription(desc);
    const cats = nextIsExpense ? expenseCats : incomeCats;
    const match = cats.find(
      (c) => c.id === r.categoryId || c.name === r.categoryName,
    );
    if (match) setCategoryId(match.id);
    setError(
      r.needsReview
        ? 'AI chưa chắc chắn — kiểm tra lại số tiền/danh mục trước khi lưu.'
        : null,
    );
  }

  const saveMut = useMutation({
    mutationFn: async () => {
      const amt = Number(amount.replace(/\D/g, ''));
      if (!categoryId || !amt || amt <= 0) throw new Error('Nhập đủ danh mục và số tiền');
      const body = {
        type: (isExpense ? 'EXPENSE' : 'INCOME') as 'EXPENSE' | 'INCOME',
        amount: amt,
        description: description || undefined,
        transactionDate: date,
        categoryId: Number(categoryId),
        walletId: walletId === '' ? null : Number(walletId),
      };
      if (editId) {
        await transactionService.updateTransaction(editId, body);
        return { createdId: null as number | null };
      }
      const created = await transactionService.createTransaction(body);
      return { createdId: created.id };
    },
    onSuccess: async (result) => {
      const savedWalletId = walletId === '' ? null : Number(walletId);
      if (savedWalletId != null) setSelectedWalletId(savedWalletId);
      await qc.invalidateQueries({ queryKey: ['transactions'] });
      await qc.invalidateQueries({ queryKey: ['stats'] });
      await qc.invalidateQueries({ queryKey: ['wallets'] });
      await qc.invalidateQueries({ queryKey: ['spending-limits'] });
      await qc.invalidateQueries({ queryKey: ['spending-limit-alerts'] });
      if (result.createdId != null) {
        navigate(`/app/transactions/${result.createdId}/edit`, {
          replace: true,
          state: { justCreated: true },
        });
      }
    },
  });

  const undoMut = useMutation({
    mutationFn: () => {
      if (!editId) throw new Error('Không có giao dịch để thu hồi');
      return transactionService.deleteTransaction(editId);
    },
    onSuccess: async () => {
      await qc.invalidateQueries({ queryKey: ['transactions'] });
      await qc.invalidateQueries({ queryKey: ['stats'] });
      await qc.invalidateQueries({ queryKey: ['wallets'] });
      await qc.invalidateQueries({ queryKey: ['spending-limits'] });
      await qc.invalidateQueries({ queryKey: ['spending-limit-alerts'] });
      navigate('/app/transactions');
    },
  });

  async function handleSaveClick() {
    setError(null);
    const amt = Number(amount.replace(/\D/g, ''));
    if (!categoryId || !amt || amt <= 0) {
      setError('Nhập đủ danh mục và số tiền');
      return;
    }
    if (wallets.length > 0 && walletId === '') {
      setError('Chọn ví trước khi lưu');
      return;
    }
    if (isExpense) {
      try {
        const check = await spendingLimitService.checkTransactionLimit({
          categoryId: Number(categoryId),
          amount: amt,
          transactionDate: date,
          type: 'EXPENSE',
          excludeTransactionId: editId,
        });
        if (check.hasWarning && check.message) {
          setLimitCheck(check);
          setLimitDialogOpen(true);
          return;
        }
      } catch {
        /* tiếp tục lưu nếu API check lỗi */
      }
    }
    saveMut.mutate();
  }

  function confirmSaveDespiteLimit() {
    setLimitDialogOpen(false);
    saveMut.mutate();
  }

  const saveBatchMut = useMutation({
    mutationFn: async () => {
      const wid = walletId === '' ? null : Number(walletId);
      if (wid == null) throw new Error('Chọn ví trước khi xác nhận');
      if (!date) throw new Error('Chọn ngày trước khi xác nhận');

      const items = aiSuggestions;
      if (!items.length) throw new Error('Không có giao dịch để xác nhận');

      const undoTransactionIds: number[] = [];
      for (const s of items) {
        const t = (s.transactionType ?? '').toString().toUpperCase();
        const nextIsExpense = t !== 'INCOME';

        const cats = nextIsExpense ? expenseCats : incomeCats;
        const match = cats.find((c) => c.id === s.categoryId || c.name === s.categoryName);
        const resolvedCategoryId = match?.id;
        const resolvedAmount = s.amount != null ? Math.round(s.amount) : null;

        if (!resolvedCategoryId || !resolvedAmount || resolvedAmount <= 0) {
          throw new Error(
            'Có giao dịch AI chưa đủ danh mục/số tiền. Hãy xóa dòng thừa hoặc nhập lại câu gợi ý rõ hơn.',
          );
        }

        const created = await transactionService.createTransaction({
          type: nextIsExpense ? 'EXPENSE' : 'INCOME',
          amount: resolvedAmount,
          description: s.description || undefined,
          transactionDate: date,
          categoryId: resolvedCategoryId,
          walletId: wid,
        });
        undoTransactionIds.push(created.id);
      }
      return { undoTransactionIds };
    },
    onSuccess: async (result) => {
      const savedWalletId = walletId === '' ? null : Number(walletId);
      if (savedWalletId != null) setSelectedWalletId(savedWalletId);
      await qc.invalidateQueries({ queryKey: ['transactions'] });
      await qc.invalidateQueries({ queryKey: ['stats'] });
      await qc.invalidateQueries({ queryKey: ['wallets'] });
      setAiDialogOpen(false);
      setAiSuggestions([]);
      const ids = result.undoTransactionIds;
      if (ids.length === 1) {
        navigate(`/app/transactions/${ids[0]}/edit`, {
          replace: true,
          state: { justCreated: true },
        });
      } else {
        navigate('/app/transactions');
      }
    },
  });

  async function runAi() {
    setError(null);
    try {
      const rs = await aiMut.mutateAsync();
      const cleaned = (rs ?? []).filter((x) => x && x.categoryName);
      if (cleaned.length <= 0) return;
      if (cleaned.length === 1) {
        applyAiSuggestion(cleaned[0]);
        return;
      }
      setAiSuggestions(cleaned);
      setAiDialogOpen(true);
    } catch (e) {
      setError(extractApiError(e));
    }
  }

  if (editId && loadingTx) {
    return (
      <GradientBackground>
        <Box display="flex" justifyContent="center" py={8}>
          <CircularProgress />
        </Box>
      </GradientBackground>
    );
  }

  const accent = isExpense ? palette.expense : palette.income;

  return (
    <GradientBackground>
      <Box sx={{ p: { xs: 2, md: 3 }, pb: 10, maxWidth: 560, mx: 'auto' }}>
        <Stack direction="row" alignItems="center" spacing={1.5} mb={2.5}>
          <Box
            sx={{
              width: 48,
              height: 48,
              borderRadius: 2.5,
              display: 'grid',
              placeItems: 'center',
              background: `linear-gradient(145deg, ${palette.primary.main}, ${palette.primary.dark})`,
              color: '#fff',
              boxShadow: '0 2px 10px rgba(2, 136, 209, 0.35)',
            }}
          >
            {editId ? <EditRounded /> : <AddRounded />}
          </Box>
          <Box>
            <Typography variant="h5" fontWeight={800}>
              {editId ? 'Sửa giao dịch' : 'Thêm giao dịch'}
            </Typography>
            <Typography variant="body2" color="text.secondary">
              Ghi chép thu chi nhanh, chính xác
            </Typography>
          </Box>
        </Stack>

        <AiAssistCard
          hidden={!!editId}
          value={natural}
          onChange={setNatural}
          onCategorize={runAi}
          onScanReceipt={() => setOcrOpen(true)}
          isLoading={aiMut.isPending}
        />

        <ReceiptOcrDialog
          open={ocrOpen}
          onClose={() => setOcrOpen(false)}
          onApply={applyOcrResult}
        />

        <TransactionTypeToggle
          isExpense={isExpense}
          onChange={(exp) => {
            setIsExpense(exp);
            setCategoryId('');
          }}
        />

        <FormSection title="Chi tiết giao dịch">
          <AmountInputSection
            value={amount}
            onChange={setAmount}
            isExpense={isExpense}
            showQuick={!editId}
          />
        </FormSection>

        <FormSection title="Mô tả" subtitle="Tùy chọn — giúp bạn nhớ khoản này">
          <TextField
            fullWidth
            placeholder="VD: Cơm trưa với team"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            sx={{ '& .MuiOutlinedInput-root': { borderRadius: 3 } }}
          />
        </FormSection>

        <FormSection title="Ngày giao dịch">
          <DatePickerField
            label="Chọn ngày"
            value={date}
            onChange={setDate}
            allowPast
            maxDate={new Date()}
            margin="none"
            placeholder="Nhấn để mở lịch chọn ngày"
          />
        </FormSection>

        <FormSection title="Danh mục" subtitle={`Chọn danh mục ${isExpense ? 'chi tiêu' : 'thu nhập'}`}>
          <CategoryChipPicker
            categories={categories}
            value={categoryId}
            onChange={setCategoryId}
          />
        </FormSection>

        <FormSection title="Ví" subtitle="Giao dịch sẽ ghi vào ví này">
          <WalletChipPicker wallets={wallets} value={walletId} onChange={setWalletId} />
        </FormSection>

        {error && (
          <Alert severity="warning" sx={{ mb: 2, borderRadius: 3 }} onClose={() => setError(null)}>
            {error}
          </Alert>
        )}
        {saveMut.error && (
          <Alert severity="error" sx={{ mb: 2, borderRadius: 3 }}>
            {extractApiError(saveMut.error)}
          </Alert>
        )}
        {undoMut.error && (
          <Alert severity="error" sx={{ mb: 2, borderRadius: 3 }}>
            {extractApiError(undoMut.error)}
          </Alert>
        )}

        {showCreatedHint && (
          <Alert severity="success" sx={{ mb: 2, borderRadius: 3 }}>
            Giao dịch đã được lưu. Bạn có thể cập nhật hoặc thu hồi nếu nhập nhầm.
          </Alert>
        )}

        <Stack spacing={1.5} sx={{ mt: 1 }}>
          {editId && (
            <Button
              fullWidth
              variant="outlined"
              color="error"
              startIcon={<DeleteOutlineRounded />}
              onClick={() => {
                if (confirm('Thu hồi (xóa) giao dịch này?')) undoMut.mutate();
              }}
              disabled={undoMut.isPending || saveMut.isPending}
              sx={{ borderRadius: 2, py: 1.25, fontWeight: 700 }}
            >
              {undoMut.isPending ? 'Đang thu hồi…' : 'Thu hồi giao dịch'}
            </Button>
          )}
          <Stack direction="row" spacing={1.5}>
            <Button fullWidth variant="outlined" onClick={() => navigate('/app/transactions')} sx={{ borderRadius: 2, py: 1.25 }}>
              {editId ? 'Xong' : 'Hủy'}
            </Button>
            <Button
              fullWidth
              variant="contained"
              onClick={handleSaveClick}
              disabled={saveMut.isPending || undoMut.isPending}
              sx={{
                borderRadius: 2,
                py: 1.25,
                fontWeight: 800,
                bgcolor: accent,
                '&:hover': { bgcolor: accent, filter: 'brightness(0.92)' },
              }}
            >
              {saveMut.isPending ? 'Đang lưu…' : editId ? 'Cập nhật' : 'Lưu giao dịch'}
            </Button>
          </Stack>
        </Stack>
      </Box>

      <Dialog
        open={aiDialogOpen}
        onClose={() => setAiDialogOpen(false)}
        fullWidth
        maxWidth="sm"
        PaperProps={{ sx: { borderRadius: 3 } }}
      >
        <DialogTitle fontWeight={800}>AI phát hiện nhiều giao dịch</DialogTitle>
        <DialogContent>
          <Typography variant="body2" color="text.secondary" mb={2}>
            Xem lại từng khoản trước khi lưu tất cả vào ví đã chọn.
          </Typography>
          <Stack spacing={1.5}>
            {aiSuggestions.map((s, idx) => {
              const t = (s.transactionType ?? '').toString().toUpperCase();
              const isInc = t === 'INCOME';
              const label = isInc ? 'Thu nhập' : 'Chi tiêu';
              const amt = s.amount != null ? Math.round(s.amount) : null;
              const itemAccent = isInc ? palette.income : palette.expense;
              return (
                <Card
                  key={idx}
                  variant="outlined"
                  sx={{
                    borderRadius: 3,
                    borderColor: `${itemAccent}44`,
                    bgcolor: `${itemAccent}08`,
                  }}
                >
                  <CardContent sx={{ py: 1.5, '&:last-child': { pb: 1.5 } }}>
                    <Stack direction="row" alignItems="flex-start" justifyContent="space-between">
                      <Box flex={1} minWidth={0}>
                        <Stack direction="row" alignItems="center" spacing={1} mb={0.5}>
                          <ReceiptLongRounded sx={{ fontSize: 18, color: itemAccent }} />
                          <Typography fontWeight={800} color={itemAccent}>
                            {label}
                            {amt != null ? ` · ${formatMoneyFull(amt)}` : ''}
                          </Typography>
                        </Stack>
                        <Typography variant="body2" color="text.secondary" fontWeight={600}>
                          {s.categoryName}
                        </Typography>
                        {s.description ? (
                          <Typography variant="body2" mt={0.5}>
                            {s.description}
                          </Typography>
                        ) : null}
                      </Box>
                      <IconButton
                        aria-label="Xóa giao dịch"
                        onClick={() =>
                          setAiSuggestions((prev) => prev.filter((_, i) => i !== idx))
                        }
                        size="small"
                      >
                        <DeleteOutlineRounded />
                      </IconButton>
                    </Stack>
                  </CardContent>
                </Card>
              );
            })}
          </Stack>
          {saveBatchMut.error && (
            <Alert severity="error" sx={{ mt: 2 }}>
              {extractApiError(saveBatchMut.error)}
            </Alert>
          )}
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2 }}>
          <Button onClick={() => setAiDialogOpen(false)}>Đóng</Button>
          <Button
            variant="contained"
            onClick={() => saveBatchMut.mutate()}
            disabled={saveBatchMut.isPending || aiSuggestions.length === 0}
          >
            {saveBatchMut.isPending ? 'Đang lưu…' : 'Xác nhận tất cả'}
          </Button>
        </DialogActions>
      </Dialog>

      <Dialog open={limitDialogOpen} onClose={() => setLimitDialogOpen(false)} fullWidth maxWidth="sm">
        <DialogTitle fontWeight={800}>Cảnh báo hạn mức chi tiêu</DialogTitle>
        <DialogContent>
          <Typography>{limitCheck?.message}</Typography>
        </DialogContent>
        <DialogActions>
          <Button
            onClick={() => setLimitDialogOpen(false)}
          >
            Hủy
          </Button>
          <Button variant="contained" onClick={confirmSaveDespiteLimit} disabled={saveMut.isPending}>
            Tiếp tục tạo
          </Button>
        </DialogActions>
      </Dialog>
    </GradientBackground>
  );
}
