import {
  Alert,
  Box,
  Button,
  Chip,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  IconButton,
  InputAdornment,
  MenuItem,
  Paper,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import {
  AddRounded,
  FilterListRounded,
  ReceiptLongRounded,
  SearchRounded,
  TuneRounded,
} from '@mui/icons-material';
import { useInfiniteQuery, useQuery } from '@tanstack/react-query';
import { parseISO } from 'date-fns';
import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { GradientBackground } from '@/components/common/GradientBackground';
import { DatePickerField } from '@/components/common/DatePickerField';
import { CategorySelectField } from '@/components/category/CategorySelectField';
import {
  TransactionDateHeader,
  TransactionListItem,
} from '@/components/transactions/TransactionListItem';
import {
  TransactionSummaryBar,
  TransactionTypeChips,
} from '@/components/transactions/TransactionSummaryBar';
import { useSelectedWallet } from '@/contexts/SelectedWalletContext';
import { extractApiError } from '@/lib/api';
import {
  groupTransactionsByDate,
  summarizeTransactions,
} from '@/lib/transactionGroups';
import * as categoryService from '@/services/categoryService';
import * as transactionService from '@/services/transactionService';
import * as walletService from '@/services/walletService';
import { palette } from '@/theme';

export function TransactionsPage() {
  const navigate = useNavigate();
  const { selectedWalletId, setSelectedWalletId } = useSelectedWallet();
  const [search, setSearch] = useState('');
  const [filterOpen, setFilterOpen] = useState(false);
  const [filterType, setFilterType] = useState<'EXPENSE' | 'INCOME' | ''>('');
  const [filterCategoryId, setFilterCategoryId] = useState<number | ''>('');
  const [filterWalletId, setFilterWalletId] = useState<number | ''>('');
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');

  const { data: wallets = [] } = useQuery({
    queryKey: ['wallets'],
    queryFn: walletService.fetchWallets,
  });

  useEffect(() => {
    if (!wallets.length) return;
    const valid =
      selectedWalletId != null && wallets.some((w) => w.id === selectedWalletId);
    if (!valid) {
      const def = wallets.find((w) => w.isDefault) ?? wallets[0];
      setSelectedWalletId(def.id);
    }
  }, [wallets, selectedWalletId, setSelectedWalletId]);

  const { data: categories = [] } = useQuery({
    queryKey: ['categories', 'all'],
    queryFn: () => categoryService.fetchCategories(),
  });

  const categoryIndexMap = useMemo(() => {
    const map = new Map<number, number>();
    categories.forEach((c, i) => map.set(c.id, i));
    return map;
  }, [categories]);

  const filters = useMemo(
    () => ({
      type: filterType || undefined,
      categoryId:
        filterCategoryId === '' ? undefined : Number(filterCategoryId),
      walletId: filterWalletId === '' ? undefined : Number(filterWalletId),
      startDate: startDate || undefined,
      endDate: endDate || undefined,
    }),
    [filterType, filterCategoryId, filterWalletId, startDate, endDate],
  );

  const infinite = useInfiniteQuery({
    queryKey: ['transactions', filters],
    queryFn: ({ pageParam }) =>
      transactionService.fetchTransactionsPage(pageParam, 20, filters),
    initialPageParam: 0,
    getNextPageParam: (last) =>
      last.page + 1 < last.totalPages ? last.page + 1 : undefined,
  });

  const items = useMemo(
    () => infinite.data?.pages.flatMap((p) => p.content) ?? [],
    [infinite.data],
  );

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return items;
    return items.filter((t) => {
      const d = (t.description ?? '').toLowerCase();
      const c = t.category.name.toLowerCase();
      return d.includes(q) || c.includes(q);
    });
  }, [items, search]);

  const summary = useMemo(() => summarizeTransactions(filtered), [filtered]);
  const groups = useMemo(() => groupTransactionsByDate(filtered), [filtered]);

  const hasAdvancedFilter =
    filterCategoryId !== '' || filterWalletId !== '' || startDate !== '' || endDate !== '';

  const selectedCategoryName =
    filterCategoryId === ''
      ? null
      : categories.find((c) => c.id === filterCategoryId)?.name;

  const selectedWalletName =
    filterWalletId === ''
      ? null
      : wallets.find((w) => w.id === filterWalletId)?.name;

  return (
    <GradientBackground>
      <Box
        sx={{
          width: '100%',
          maxWidth: { xs: '100%', sm: 800, md: 900 },
          mx: 'auto',
          px: { xs: 2, sm: 3 },
          py: { xs: 2, md: 3 },
          pb: 10,
        }}
      >
        <Stack direction="row" spacing={2} alignItems="center" justifyContent="space-between" mb={2.5}>
          <Stack direction="row" spacing={2} alignItems="center">
            <Box
              aria-hidden
              sx={{
                width: 48,
                height: 48,
                borderRadius: 2.5,
                flexShrink: 0,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                background: `linear-gradient(145deg, ${palette.primary.main}, ${palette.primary.dark})`,
                color: '#fff',
                boxShadow: '0 2px 10px rgba(2, 136, 209, 0.35)',
              }}
            >
              <ReceiptLongRounded sx={{ fontSize: 26 }} />
            </Box>
            <Box>
              <Typography variant="h5" fontWeight={800}>
                Giao dịch
              </Typography>
              <Typography variant="body2" color="text.secondary">
                Lịch sử thu chi · nhóm theo ngày
              </Typography>
            </Box>
          </Stack>
          <Button
            variant="contained"
            size="small"
            startIcon={<AddRounded />}
            onClick={() => navigate('/app/transactions/add')}
            sx={{ borderRadius: 2, flexShrink: 0, display: { xs: 'none', sm: 'inline-flex' } }}
          >
            Thêm
          </Button>
        </Stack>

        {filtered.length > 0 && (
          <TransactionSummaryBar
            totalIncome={summary.totalIncome}
            totalExpense={summary.totalExpense}
            balance={summary.balance}
            count={summary.count}
          />
        )}

        <TextField
          fullWidth
          placeholder="Tìm theo mô tả, danh mục..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          InputProps={{
            startAdornment: (
              <InputAdornment position="start">
                <SearchRounded color="action" />
              </InputAdornment>
            ),
          }}
          sx={{
            mb: 1.5,
            bgcolor: 'background.paper',
            borderRadius: 3,
            '& .MuiOutlinedInput-root': { borderRadius: 3 },
          }}
        />

        <TransactionTypeChips value={filterType} onChange={setFilterType} />

        <Stack direction="row" alignItems="center" spacing={1} flexWrap="wrap" useFlexGap mb={2}>
          <IconButton
            color={hasAdvancedFilter ? 'primary' : 'default'}
            onClick={() => setFilterOpen(true)}
            sx={{
              border: `1px solid ${hasAdvancedFilter ? palette.primary.main : palette.outline}`,
              borderRadius: 2,
            }}
          >
            <FilterListRounded />
          </IconButton>

          {filterCategoryId !== '' && selectedCategoryName && (
            <Chip
              label={selectedCategoryName}
              onDelete={() => setFilterCategoryId('')}
              size="small"
              sx={{ fontWeight: 700 }}
            />
          )}
          {filterWalletId !== '' && selectedWalletName && (
            <Chip
              label={`Ví: ${selectedWalletName}`}
              onDelete={() => setFilterWalletId('')}
              size="small"
              sx={{ fontWeight: 700 }}
            />
          )}
          {startDate && (
            <Chip
              label={`Từ ${startDate.split('-').reverse().join('/')}`}
              onDelete={() => setStartDate('')}
              size="small"
              sx={{ fontWeight: 700 }}
            />
          )}
          {endDate && (
            <Chip
              label={`Đến ${endDate.split('-').reverse().join('/')}`}
              onDelete={() => setEndDate('')}
              size="small"
              sx={{ fontWeight: 700 }}
            />
          )}
          {(filterType || hasAdvancedFilter) && (
            <Button
              size="small"
              onClick={() => {
                setFilterType('');
                setFilterCategoryId('');
                setFilterWalletId('');
                setStartDate('');
                setEndDate('');
              }}
            >
              Xóa lọc
            </Button>
          )}
        </Stack>

        {infinite.isError && (
          <Alert severity="error" sx={{ mb: 2 }}>
            {extractApiError(infinite.error)}
          </Alert>
        )}

        {infinite.isLoading && filtered.length === 0 ? (
          <Box display="flex" justifyContent="center" py={8}>
            <CircularProgress />
          </Box>
        ) : filtered.length === 0 ? (
          <Box
            textAlign="center"
            py={8}
            px={2}
            sx={{
              borderRadius: 4,
              border: `1px dashed ${palette.outline}`,
              bgcolor: `${palette.surface}`,
            }}
          >
            <ReceiptLongRounded sx={{ fontSize: 56, color: palette.textMuted, mb: 1 }} />
            <Typography fontWeight={700} gutterBottom>
              {search || filterType || hasAdvancedFilter
                ? 'Không tìm thấy kết quả'
                : 'Chưa có giao dịch'}
            </Typography>
            <Typography variant="body2" color="text.secondary" mb={2}>
              {search
                ? 'Thử từ khóa khác hoặc xóa bộ lọc'
                : 'Bắt đầu ghi chép thu chi của bạn'}
            </Typography>
            <Button
              variant="contained"
              startIcon={<AddRounded />}
              onClick={() =>
                search || filterType || hasAdvancedFilter
                  ? (() => {
                      setSearch('');
                      setFilterType('');
                      setFilterCategoryId('');
                      setFilterWalletId('');
                      setStartDate('');
                      setEndDate('');
                    })()
                  : navigate('/app/transactions/add')
              }
              sx={{ borderRadius: 2 }}
            >
              {search || filterType || hasAdvancedFilter ? 'Xóa bộ lọc' : 'Thêm giao dịch đầu tiên'}
            </Button>
          </Box>
        ) : (
          <Stack spacing={1}>
            {groups.map((group) => {
              const dayTotal = group.items.reduce(
                (sum, t) => sum + (t.type === 'INCOME' ? t.amount : -t.amount),
                0,
              );
              return (
                <Box key={group.dateKey}>
                  <TransactionDateHeader
                    label={group.label}
                    count={group.items.length}
                    dayTotal={dayTotal}
                  />
                  <Stack spacing={1}>
                    {group.items.map((t) => (
                      <TransactionListItem
                        key={t.id}
                        t={t}
                        onOpen={() => navigate(`/app/transactions/${t.id}/edit`)}
                        categoryIndex={categoryIndexMap.get(t.category.id) ?? 0}
                      />
                    ))}
                  </Stack>
                </Box>
              );
            })}
            {infinite.hasNextPage && (
              <Button
                fullWidth
                variant="outlined"
                onClick={() => infinite.fetchNextPage()}
                disabled={infinite.isFetchingNextPage}
                sx={{ mt: 1, borderRadius: 2 }}
              >
                {infinite.isFetchingNextPage ? 'Đang tải…' : 'Tải thêm giao dịch'}
              </Button>
            )}
          </Stack>
        )}
      </Box>

      <Dialog
        open={filterOpen}
        onClose={() => setFilterOpen(false)}
        fullWidth
        maxWidth="sm"
        PaperProps={{ sx: { borderRadius: 3, overflow: 'hidden' } }}
      >
        <Box
          sx={{
            px: 3,
            py: 2.5,
            background: `linear-gradient(135deg, ${palette.primary.main} 0%, ${palette.primary.light} 100%)`,
            color: '#fff',
          }}
        >
          <Stack direction="row" spacing={1.5} alignItems="center">
            <Box
              sx={{
                width: 44,
                height: 44,
                borderRadius: 2,
                bgcolor: 'rgba(255,255,255,0.2)',
                display: 'grid',
                placeItems: 'center',
              }}
            >
              <TuneRounded />
            </Box>
            <Box>
              <DialogTitle sx={{ p: 0, color: 'inherit', fontWeight: 800, fontSize: '1.25rem' }}>
                Lọc nâng cao
              </DialogTitle>
              <Typography variant="body2" sx={{ opacity: 0.9, mt: 0.25 }}>
                Lọc theo ví, danh mục và khoảng thời gian
              </Typography>
            </Box>
          </Stack>
        </Box>

        <DialogContent sx={{ pt: 2.5 }}>
          <Typography variant="caption" color="text.secondary" display="block" mb={1.5}>
            Loại thu/chi chọn ở thanh phía trên danh sách giao dịch.
          </Typography>

          <CategorySelectField
            categories={categories}
            value={filterCategoryId}
            onChange={setFilterCategoryId}
            label="Danh mục"
            allowEmpty
            emptyLabel="Tất cả danh mục"
            withOnboardingStyle
            margin="normal"
          />

          <TextField
            select
            fullWidth
            label="Ví"
            value={filterWalletId}
            onChange={(e) =>
              setFilterWalletId(e.target.value === '' ? '' : Number(e.target.value))
            }
            margin="normal"
            InputLabelProps={{ shrink: true }}
            sx={{ '& .MuiOutlinedInput-root': { borderRadius: 2.5 } }}
          >
            <MenuItem value="">Tất cả ví</MenuItem>
            {wallets.map((w) => (
              <MenuItem key={w.id} value={w.id}>
                {w.name}
                {w.isDefault ? ' ★' : ''}
              </MenuItem>
            ))}
          </TextField>

          <Paper
            elevation={0}
            sx={{
              mt: 1,
              p: 2,
              borderRadius: 2.5,
              border: '1px solid',
              borderColor: 'divider',
              bgcolor: `${palette.primary.main}06`,
            }}
          >
            <Typography variant="subtitle2" fontWeight={800} gutterBottom>
              Khoảng thời gian
            </Typography>
            <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5}>
              <DatePickerField
                label="Từ ngày"
                value={startDate}
                onChange={setStartDate}
                allowPast
                margin="none"
                placeholder="Chọn ngày bắt đầu"
                maxDate={endDate ? parseISO(endDate) : undefined}
              />
              <DatePickerField
                label="Đến ngày"
                value={endDate}
                onChange={setEndDate}
                allowPast
                margin="none"
                placeholder="Chọn ngày kết thúc"
                minDate={startDate ? parseISO(startDate) : undefined}
              />
            </Stack>
          </Paper>

          {hasAdvancedFilter && (
            <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap mt={2}>
              {selectedCategoryName && (
                <Chip
                  size="small"
                  label={`Danh mục: ${selectedCategoryName}`}
                  onDelete={() => setFilterCategoryId('')}
                />
              )}
              {selectedWalletName && (
                <Chip
                  size="small"
                  label={`Ví: ${selectedWalletName}`}
                  onDelete={() => setFilterWalletId('')}
                />
              )}
              {startDate && (
                <Chip size="small" label={`Từ ${startDate}`} onDelete={() => setStartDate('')} />
              )}
              {endDate && (
                <Chip size="small" label={`Đến ${endDate}`} onDelete={() => setEndDate('')} />
              )}
            </Stack>
          )}
        </DialogContent>

        <DialogActions sx={{ px: 3, pb: 2.5, pt: 0, gap: 1 }}>
          {hasAdvancedFilter && (
            <Button
              color="inherit"
              onClick={() => {
                setFilterCategoryId('');
                setFilterWalletId('');
                setStartDate('');
                setEndDate('');
              }}
              sx={{ mr: 'auto', color: 'text.secondary' }}
            >
              Xóa bộ lọc
            </Button>
          )}
          <Button onClick={() => setFilterOpen(false)}>Đóng</Button>
          <Button variant="contained" onClick={() => setFilterOpen(false)} sx={{ px: 3 }}>
            Áp dụng
          </Button>
        </DialogActions>
      </Dialog>
    </GradientBackground>
  );
}
