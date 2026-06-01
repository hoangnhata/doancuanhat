import {
  Box,
  Button,
  Card,
  CardActionArea,
  CardContent,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  IconButton,
  InputAdornment,
  MenuItem,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import {
  FilterListRounded,
  ReceiptLongRounded,
  SearchRounded,
} from '@mui/icons-material';
import { useInfiniteQuery, useQuery } from '@tanstack/react-query';
import { format } from 'date-fns';
import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { GradientBackground } from '@/components/common/GradientBackground';
import { useSelectedWallet } from '@/contexts/SelectedWalletContext';
import { extractApiError } from '@/lib/api';
import { formatMoney } from '@/lib/format';
import * as categoryService from '@/services/categoryService';
import * as transactionService from '@/services/transactionService';
import { palette } from '@/theme';
import type { Transaction } from '@/types/models';

export function TransactionsPage() {
  const navigate = useNavigate();
  const { selectedWalletId } = useSelectedWallet();
  const [search, setSearch] = useState('');
  const [filterOpen, setFilterOpen] = useState(false);
  const [filterType, setFilterType] = useState<'EXPENSE' | 'INCOME' | ''>('');
  const [filterCategoryId, setFilterCategoryId] = useState<number | ''>('');
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');

  const { data: categories = [] } = useQuery({
    queryKey: ['categories', 'all'],
    queryFn: () => categoryService.fetchCategories(),
  });

  const filters = useMemo(
    () => ({
      type: filterType || undefined,
      categoryId:
        filterCategoryId === '' ? undefined : Number(filterCategoryId),
      walletId: selectedWalletId ?? undefined,
      startDate: startDate || undefined,
      endDate: endDate || undefined,
    }),
    [filterType, filterCategoryId, selectedWalletId, startDate, endDate],
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

  return (
    <GradientBackground>
      <Box
        sx={{
          width: '100%',
          maxWidth: { xs: '100%', sm: 800, md: 1000, lg: 1280, xl: 1440 },
          mx: 'auto',
          px: { xs: 2, sm: 3, md: 4, lg: 5 },
          py: { xs: 2, md: 3 },
          pb: 10,
        }}
      >
        <Stack direction="row" spacing={2} alignItems="center" mb={2.5}>
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
            <ReceiptLongRounded sx={{ fontSize: 26, display: 'block' }} />
          </Box>
          <Box>
            <Typography variant="h5" fontWeight={800} color="text.primary">
              Giao dịch
            </Typography>
            <Typography variant="body2" color="text.secondary">
              Lịch sử thu chi
            </Typography>
          </Box>
        </Stack>

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
          sx={{ mb: 1, bgcolor: 'background.paper', borderRadius: 2 }}
        />

        <Stack direction="row" alignItems="center" spacing={1} mb={2}>
          <IconButton
            color={filterType || filterCategoryId || startDate ? 'primary' : 'default'}
            onClick={() => setFilterOpen(true)}
          >
            <FilterListRounded />
          </IconButton>
          {(filterType || filterCategoryId || startDate || endDate) && (
            <Button
              size="small"
              onClick={() => {
                setFilterType('');
                setFilterCategoryId('');
                setStartDate('');
                setEndDate('');
              }}
            >
              Xóa lọc
            </Button>
          )}
        </Stack>

        {infinite.isError && (
          <Typography color="error">{extractApiError(infinite.error)}</Typography>
        )}

        {filtered.length === 0 && !infinite.isLoading ? (
          <Box textAlign="center" py={6}>
            <Typography color="text.secondary">
              {search ? 'Không tìm thấy kết quả' : 'Chưa có giao dịch'}
            </Typography>
            <Button sx={{ mt: 1 }} onClick={() => navigate('/app/transactions/add')}>
              Thêm giao dịch đầu tiên
            </Button>
          </Box>
        ) : (
          <Stack spacing={1}>
            {filtered.map((t) => (
              <TransactionRow
                key={t.id}
                t={t}
                onOpen={() => navigate(`/app/transactions/${t.id}/edit`)}
              />
            ))}
            {infinite.hasNextPage && (
              <Button
                fullWidth
                onClick={() => infinite.fetchNextPage()}
                disabled={infinite.isFetchingNextPage}
              >
                {infinite.isFetchingNextPage ? 'Đang tải…' : 'Tải thêm'}
              </Button>
            )}
          </Stack>
        )}
      </Box>

      <Dialog open={filterOpen} onClose={() => setFilterOpen(false)} fullWidth>
        <DialogTitle>Lọc giao dịch</DialogTitle>
        <DialogContent>
          <TextField
            select
            fullWidth
            label="Loại"
            value={filterType}
            onChange={(e) =>
              setFilterType(e.target.value as 'EXPENSE' | 'INCOME' | '')
            }
            margin="normal"
          >
            <MenuItem value="">Tất cả</MenuItem>
            <MenuItem value="EXPENSE">Chi tiêu</MenuItem>
            <MenuItem value="INCOME">Thu nhập</MenuItem>
          </TextField>
          <TextField
            select
            fullWidth
            label="Danh mục"
            value={filterCategoryId}
            onChange={(e) =>
              setFilterCategoryId(
                e.target.value === '' ? '' : Number(e.target.value),
              )
            }
            margin="normal"
          >
            <MenuItem value="">Tất cả</MenuItem>
            {categories.map((c) => (
              <MenuItem key={c.id} value={c.id}>
                {c.name}
              </MenuItem>
            ))}
          </TextField>
          <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2} mt={1}>
            <TextField
              fullWidth
              type="date"
              label="Từ ngày"
              InputLabelProps={{ shrink: true }}
              value={startDate}
              onChange={(e) => setStartDate(e.target.value)}
            />
            <TextField
              fullWidth
              type="date"
              label="Đến ngày"
              InputLabelProps={{ shrink: true }}
              value={endDate}
              onChange={(e) => setEndDate(e.target.value)}
            />
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setFilterOpen(false)}>Đóng</Button>
          <Button variant="contained" onClick={() => setFilterOpen(false)}>
            Áp dụng
          </Button>
        </DialogActions>
      </Dialog>
    </GradientBackground>
  );
}

function TransactionRow({
  t,
  onOpen,
}: {
  t: Transaction;
  onOpen: () => void;
}) {
  const inc = t.type === 'INCOME';
  return (
    <Card elevation={2}>
      <CardActionArea onClick={onOpen}>
        <CardContent>
          <Stack direction="row" spacing={2} alignItems="center">
            <Box
              sx={{
                width: 48,
                height: 48,
                borderRadius: 2,
                bgcolor: inc ? `${palette.income}33` : `${palette.expense}33`,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: inc ? palette.income : palette.expense,
              }}
            >
              {inc ? '↓' : '↑'}
            </Box>
            <Box flex={1} minWidth={0}>
              <Typography fontWeight={700} noWrap>
                {t.description || t.category.name}
              </Typography>
              <Typography variant="caption" color="text.secondary">
                {t.category.name} • {format(new Date(t.transactionDate), 'dd/MM/yyyy')}
              </Typography>
            </Box>
            <Typography
              fontWeight={800}
              color={inc ? palette.income : 'error.main'}
            >
              {inc ? '+' : '-'}
              {formatMoney(t.amount)}
            </Typography>
          </Stack>
        </CardContent>
      </CardActionArea>
    </Card>
  );
}
