import {
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
  MenuItem,
  Stack,
  TextField,
  ToggleButton,
  ToggleButtonGroup,
  Typography,
} from '@mui/material';
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline';
import DocumentScannerRoundedIcon from '@mui/icons-material/DocumentScannerRounded';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useNavigate, useParams } from 'react-router-dom';
import { useEffect, useState } from 'react';
import { GradientBackground } from '@/components/common/GradientBackground';
import { ReceiptOcrDialog } from '@/components/transaction/ReceiptOcrDialog';
import { useAuth } from '@/contexts/AuthContext';
import { useSelectedWallet } from '@/contexts/SelectedWalletContext';
import { extractApiError } from '@/lib/api';
import { extractDateFromNaturalText } from '@/lib/transactionTextParse';
import * as categoryService from '@/services/categoryService';
import * as transactionService from '@/services/transactionService';
import type { OcrReceiptResult } from '@/services/transactionService';
import * as walletService from '@/services/walletService';
import type { AICategorizeResponse } from '@/types/models';

export function AddTransactionPage() {
  const { id } = useParams();
  const editId = id ? Number(id) : undefined;
  const navigate = useNavigate();
  const qc = useQueryClient();
  const { user } = useAuth();
  const { selectedWalletId } = useSelectedWallet();

  const [isExpense, setIsExpense] = useState(true);
  const [amount, setAmount] = useState('');
  const [description, setDescription] = useState('');
  const [natural, setNatural] = useState('');
  const [categoryId, setCategoryId] = useState<number | ''>('');
  const [date, setDate] = useState(() =>
    new Date().toISOString().slice(0, 10),
  );
  const [walletId, setWalletId] = useState<number | ''>('');
  const [error, setError] = useState<string | null>(null);
  const [aiSuggestions, setAiSuggestions] = useState<AICategorizeResponse[]>([]);
  const [aiDialogOpen, setAiDialogOpen] = useState(false);
  const [ocrOpen, setOcrOpen] = useState(false);

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
        (selectedWalletId &&
          wallets.find((x) => x.id === selectedWalletId)) ||
        wallets.find((x) => x.isDefault) ||
        wallets[0];
      setWalletId(w.id);
    }
  }, [wallets, selectedWalletId, walletId]);

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
      r.transactionDate?.slice(0, 10) ??
      extractDateFromNaturalText(natural);
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
    if (r.needsReview) {
      setError('AI chưa chắc chắn — kiểm tra lại số tiền/danh mục trước khi lưu.');
    } else {
      setError(null);
    }
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
      } else {
        await transactionService.createTransaction(body);
      }
    },
    onSuccess: async () => {
      await qc.invalidateQueries({ queryKey: ['transactions'] });
      await qc.invalidateQueries({ queryKey: ['stats'] });
      await qc.invalidateQueries({ queryKey: ['wallets'] });
      navigate('/app/transactions');
    },
  });

  const saveBatchMut = useMutation({
    mutationFn: async () => {
      const wid = walletId === '' ? null : Number(walletId);
      if (wid == null) throw new Error('Chọn ví trước khi xác nhận');
      if (!date) throw new Error('Chọn ngày trước khi xác nhận');

      const items = aiSuggestions;
      if (!items.length) throw new Error('Không có giao dịch để xác nhận');

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

        await transactionService.createTransaction({
          type: nextIsExpense ? 'EXPENSE' : 'INCOME',
          amount: resolvedAmount,
          description: s.description || undefined,
          transactionDate: date,
          categoryId: resolvedCategoryId,
          walletId: wid,
        });
      }
    },
    onSuccess: async () => {
      await qc.invalidateQueries({ queryKey: ['transactions'] });
      await qc.invalidateQueries({ queryKey: ['stats'] });
      await qc.invalidateQueries({ queryKey: ['wallets'] });
      setAiDialogOpen(false);
      setAiSuggestions([]);
      navigate('/app/transactions');
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

  return (
    <GradientBackground>
      <Box sx={{ p: 2, pb: 10, maxWidth: 520, mx: 'auto' }}>
        <Typography variant="h6" fontWeight={800} gutterBottom>
          {editId ? 'Sửa giao dịch' : 'Thêm giao dịch'}
        </Typography>

        <Card sx={{ mb: 2 }}>
          <CardContent>
            <Typography variant="subtitle2" gutterBottom>
              Gợi ý AI (tùy chọn)
            </Typography>
            <TextField
              fullWidth
              placeholder='Ví dụ: "ăn trưa 50k"'
              value={natural}
              onChange={(e) => setNatural(e.target.value)}
              multiline
              minRows={2}
            />
            <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5} sx={{ mt: 1 }}>
              <Button
                variant="outlined"
                onClick={runAi}
                disabled={aiMut.isPending || !natural.trim()}
              >
                {aiMut.isPending ? 'Đang phân loại…' : 'Phân loại AI'}
              </Button>
              <Button
                variant="outlined"
                startIcon={<DocumentScannerRoundedIcon />}
                onClick={() => setOcrOpen(true)}
              >
                Quét hóa đơn
              </Button>
            </Stack>
          </CardContent>
        </Card>

        <ReceiptOcrDialog
          open={ocrOpen}
          onClose={() => setOcrOpen(false)}
          onApply={applyOcrResult}
        />

        <ToggleButtonGroup
          exclusive
          fullWidth
          value={isExpense ? 'exp' : 'inc'}
          onChange={(_, v) => {
            if (v) {
              setIsExpense(v === 'exp');
              setCategoryId('');
            }
          }}
          sx={{ mb: 2 }}
        >
          <ToggleButton value="exp">Chi tiêu</ToggleButton>
          <ToggleButton value="inc">Thu nhập</ToggleButton>
        </ToggleButtonGroup>

        <Stack spacing={2}>
          <TextField
            label="Số tiền"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            fullWidth
            required
          />
          <TextField
            label="Mô tả"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            fullWidth
          />
          <TextField
            label="Ngày"
            type="date"
            value={date}
            onChange={(e) => setDate(e.target.value)}
            fullWidth
            InputLabelProps={{ shrink: true }}
          />
          <TextField
            select
            label="Danh mục"
            value={categoryId}
            onChange={(e) => setCategoryId(Number(e.target.value))}
            fullWidth
            required
          >
            {categories.map((c) => (
              <MenuItem key={c.id} value={c.id}>
                {c.name}
              </MenuItem>
            ))}
          </TextField>
          <TextField
            select
            label="Ví"
            value={walletId}
            onChange={(e) =>
              setWalletId(
                e.target.value === '' ? '' : Number(e.target.value),
              )
            }
            fullWidth
          >
            {wallets.map((w) => (
              <MenuItem key={w.id} value={w.id}>
                {w.name}
              </MenuItem>
            ))}
          </TextField>
        </Stack>

        {error && (
          <Typography color="error" sx={{ mt: 2 }}>
            {error}
          </Typography>
        )}
        {saveMut.error && (
          <Typography color="error" sx={{ mt: 1 }}>
            {extractApiError(saveMut.error)}
          </Typography>
        )}

        <Stack direction="row" spacing={2} sx={{ mt: 3 }}>
          <Button fullWidth onClick={() => navigate(-1)}>
            Hủy
          </Button>
          <Button
            fullWidth
            variant="contained"
            onClick={() => saveMut.mutate()}
            disabled={saveMut.isPending}
          >
            {saveMut.isPending ? 'Đang lưu…' : 'Lưu'}
          </Button>
        </Stack>
      </Box>

      <Dialog open={aiDialogOpen} onClose={() => setAiDialogOpen(false)} fullWidth>
        <DialogTitle>AI phát hiện nhiều giao dịch</DialogTitle>
        <DialogContent>
          <Stack spacing={1} sx={{ mt: 1 }}>
            {aiSuggestions.map((s, idx) => {
              const t = (s.transactionType ?? '').toString().toUpperCase();
              const label = t === 'INCOME' ? 'Thu nhập' : 'Chi tiêu';
              const amt = s.amount != null ? Math.round(s.amount) : null;
              return (
                <Card key={idx} variant="outlined">
                  <CardContent sx={{ py: 1.5, '&:last-child': { pb: 1.5 } }}>
                    <Stack spacing={0.5}>
                      <Stack direction="row" alignItems="center" justifyContent="space-between">
                        <Typography fontWeight={800}>
                          {label}{amt != null ? ` • ${amt}` : ''}
                        </Typography>
                        <IconButton
                          aria-label="Xóa giao dịch"
                          onClick={() =>
                            setAiSuggestions((prev) =>
                              prev.filter((_, i) => i !== idx),
                            )
                          }
                          size="small"
                        >
                          <DeleteOutlineIcon />
                        </IconButton>
                      </Stack>
                      <Typography variant="body2" color="text.secondary">
                        {s.categoryName}
                      </Typography>
                      {s.description ? (
                        <Typography variant="body2">{s.description}</Typography>
                      ) : null}
                    </Stack>
                  </CardContent>
                </Card>
              );
            })}
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button
            variant="contained"
            onClick={() => saveBatchMut.mutate()}
            disabled={saveBatchMut.isPending || aiSuggestions.length === 0}
          >
            {saveBatchMut.isPending ? 'Đang lưu…' : 'Xác nhận tất cả'}
          </Button>
          <Button onClick={() => setAiDialogOpen(false)}>Đóng</Button>
        </DialogActions>
      </Dialog>
    </GradientBackground>
  );
}
