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
  MenuItem,
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
import * as budgetService from '@/services/budgetService';
import * as categoryService from '@/services/categoryService';

export function BudgetPage() {
  const qc = useQueryClient();
  const [open, setOpen] = useState(false);
  const [amount, setAmount] = useState('');
  const [categoryId, setCategoryId] = useState<number | ''>('');
  const [startDate, setStartDate] = useState(
    () => new Date().toISOString().slice(0, 10),
  );
  const [endDate, setEndDate] = useState(
    () => new Date().toISOString().slice(0, 10),
  );

  const { data: budgets = [], isLoading } = useQuery({
    queryKey: ['budgets'],
    queryFn: budgetService.fetchBudgets,
  });

  const { data: categories = [] } = useQuery({
    queryKey: ['categories', 'EXPENSE'],
    queryFn: () => categoryService.fetchCategories('EXPENSE'),
  });

  const createMut = useMutation({
    mutationFn: () =>
      budgetService.createBudget({
        amount: Number(amount.replace(/\D/g, '')),
        startDate,
        endDate,
        categoryId: Number(categoryId),
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['budgets'] });
      setOpen(false);
    },
  });

  const delMut = useMutation({
    mutationFn: (id: number) => budgetService.deleteBudget(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['budgets'] }),
  });

  return (
    <GradientBackground>
      <Box sx={{ p: 2, pb: 10, maxWidth: 560, mx: 'auto' }}>
        <Stack direction="row" justifyContent="space-between" alignItems="center" mb={2}>
          <Typography variant="h6" fontWeight={800}>
            Ngân sách
          </Typography>
          <Button variant="contained" onClick={() => setOpen(true)}>
            Thêm
          </Button>
        </Stack>

        {isLoading ? (
          <Typography>Đang tải…</Typography>
        ) : (
          <Stack spacing={1}>
            {budgets.map((b) => (
              <Card key={b.id} elevation={2}>
                <CardContent>
                  <Stack direction="row" alignItems="center" spacing={1}>
                    <Box flex={1}>
                      <Typography fontWeight={700}>
                        {b.category?.name ?? `Danh mục #${b.categoryId}`}
                      </Typography>
                      <Typography variant="body2" color="text.secondary">
                        {b.startDate} → {b.endDate}
                      </Typography>
                      <Typography fontWeight={800} color="primary">
                        {formatMoney(b.amount)}
                      </Typography>
                    </Box>
                    <IconButton
                      color="error"
                      onClick={() => {
                        if (confirm('Xóa ngân sách?')) delMut.mutate(b.id);
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
          <DialogTitle>Ngân sách mới</DialogTitle>
          <DialogContent>
            <TextField
              fullWidth
              label="Số tiền"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              margin="normal"
            />
            <TextField
              select
              fullWidth
              label="Danh mục (chi)"
              value={categoryId}
              onChange={(e) => setCategoryId(Number(e.target.value))}
              margin="normal"
            >
              {categories.map((c) => (
                <MenuItem key={c.id} value={c.id}>
                  {c.name}
                </MenuItem>
              ))}
            </TextField>
            <TextField
              fullWidth
              type="date"
              label="Từ ngày"
              value={startDate}
              onChange={(e) => setStartDate(e.target.value)}
              margin="normal"
              InputLabelProps={{ shrink: true }}
            />
            <TextField
              fullWidth
              type="date"
              label="Đến ngày"
              value={endDate}
              onChange={(e) => setEndDate(e.target.value)}
              margin="normal"
              InputLabelProps={{ shrink: true }}
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
              disabled={!amount || categoryId === ''}
            >
              Tạo
            </Button>
          </DialogActions>
        </Dialog>
      </Box>
    </GradientBackground>
  );
}
