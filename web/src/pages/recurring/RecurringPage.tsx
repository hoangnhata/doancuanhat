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
import * as categoryService from '@/services/categoryService';
import * as recurringService from '@/services/recurringService';

export function RecurringPage() {
  const qc = useQueryClient();
  const [open, setOpen] = useState(false);
  const [amount, setAmount] = useState('');
  const [type, setType] = useState<'EXPENSE' | 'INCOME'>('EXPENSE');
  const [dayOfMonth, setDayOfMonth] = useState(1);
  const [categoryId, setCategoryId] = useState<number | ''>('');
  const [startDate, setStartDate] = useState(
    () => new Date().toISOString().slice(0, 10),
  );

  const { data: list = [], isLoading } = useQuery({
    queryKey: ['recurring'],
    queryFn: recurringService.fetchRecurring,
  });

  const { data: categories = [] } = useQuery({
    queryKey: ['categories', 'EXPENSE'],
    queryFn: () => categoryService.fetchCategories('EXPENSE'),
  });

  const { data: incomeCats = [] } = useQuery({
    queryKey: ['categories', 'INCOME'],
    queryFn: () => categoryService.fetchCategories('INCOME'),
  });

  const cats = type === 'EXPENSE' ? categories : incomeCats;

  const createMut = useMutation({
    mutationFn: () =>
      recurringService.createRecurring({
        type,
        amount: Number(amount.replace(/\D/g, '')),
        dayOfMonth,
        startDate,
        categoryId: Number(categoryId),
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['recurring'] });
      setOpen(false);
      setAmount('');
    },
  });

  const delMut = useMutation({
    mutationFn: (id: number) => recurringService.deleteRecurring(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['recurring'] }),
  });

  const toggleMut = useMutation({
    mutationFn: (id: number) => recurringService.toggleRecurring(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['recurring'] }),
  });

  return (
    <GradientBackground>
      <Box sx={{ p: 2, pb: 10, maxWidth: 560, mx: 'auto' }}>
        <Stack direction="row" justifyContent="space-between" alignItems="center" mb={2}>
          <Typography variant="h6" fontWeight={800}>
            Giao dịch định kỳ
          </Typography>
          <Button variant="contained" onClick={() => setOpen(true)}>
            Thêm
          </Button>
        </Stack>

        {isLoading ? (
          <Typography>Đang tải…</Typography>
        ) : (
          <Stack spacing={1}>
            {list.map((r) => (
              <Card key={r.id} elevation={2}>
                <CardContent>
                  <Stack direction="row" alignItems="center" spacing={1}>
                    <Box flex={1}>
                      <Typography fontWeight={700}>
                        {r.description || r.category?.name || 'Giao dịch'}
                      </Typography>
                      <Typography variant="body2" color="text.secondary">
                        Ngày {r.dayOfMonth} · {r.type}{' '}
                        {r.active ? '(bật)' : '(tắt)'}
                      </Typography>
                      <Typography fontWeight={800} color="primary">
                        {formatMoney(r.amount)}
                      </Typography>
                      <Button size="small" onClick={() => toggleMut.mutate(r.id)}>
                        Bật/tắt
                      </Button>
                    </Box>
                    <IconButton
                      color="error"
                      onClick={() => {
                        if (confirm('Xóa?')) delMut.mutate(r.id);
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
          <DialogTitle>Giao dịch định kỳ</DialogTitle>
          <DialogContent>
            <TextField
              select
              fullWidth
              label="Loại"
              value={type}
              onChange={(e) => {
                setType(e.target.value as 'EXPENSE' | 'INCOME');
                setCategoryId('');
              }}
              margin="normal"
            >
              <MenuItem value="EXPENSE">Chi tiêu</MenuItem>
              <MenuItem value="INCOME">Thu nhập</MenuItem>
            </TextField>
            <TextField
              fullWidth
              label="Số tiền"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              margin="normal"
            />
            <TextField
              fullWidth
              type="number"
              label="Ngày trong tháng (1–28)"
              value={dayOfMonth}
              onChange={(e) => setDayOfMonth(Number(e.target.value))}
              margin="normal"
              inputProps={{ min: 1, max: 28 }}
            />
            <TextField
              fullWidth
              type="date"
              label="Bắt đầu"
              value={startDate}
              onChange={(e) => setStartDate(e.target.value)}
              margin="normal"
              InputLabelProps={{ shrink: true }}
            />
            <TextField
              select
              fullWidth
              label="Danh mục"
              value={categoryId}
              onChange={(e) => setCategoryId(Number(e.target.value))}
              margin="normal"
            >
              {cats.map((c) => (
                <MenuItem key={c.id} value={c.id}>
                  {c.name}
                </MenuItem>
              ))}
            </TextField>
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
