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
import { CategoryRounded, DeleteOutlineRounded } from '@mui/icons-material';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { GradientBackground } from '@/components/common/GradientBackground';
import { extractApiError } from '@/lib/api';
import * as categoryService from '@/services/categoryService';
import { palette } from '@/theme';

function CategorySection({
  title,
  subtitle,
  accentColor,
  categories,
  isLoading,
  onAdd,
  onDelete,
}: {
  title: string;
  subtitle: string;
  accentColor: string;
  categories: { id: number; name: string; icon?: string | null }[];
  isLoading: boolean;
  onAdd: () => void;
  onDelete: (id: number) => void;
}) {
  return (
    <Box sx={{ mb: 4 }}>
      <Stack
        direction="row"
        justifyContent="space-between"
        alignItems="flex-start"
        spacing={2}
        sx={{ mb: 2 }}
      >
        <Stack direction="row" spacing={1.5} alignItems="center">
          <Box
            sx={{
              width: 44,
              height: 44,
              borderRadius: 2,
              bgcolor: `${accentColor}22`,
              color: accentColor,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <CategoryRounded />
          </Box>
          <Box>
            <Typography variant="h6" fontWeight={800}>
              {title}
            </Typography>
            <Typography variant="body2" color="text.secondary">
              {subtitle}
            </Typography>
          </Box>
        </Stack>
        <Button variant="contained" size="medium" onClick={onAdd}>
          Thêm
        </Button>
      </Stack>

      {isLoading ? (
        <Typography color="text.secondary">Đang tải…</Typography>
      ) : categories.length === 0 ? (
        <Card variant="outlined" sx={{ p: 3, textAlign: 'center' }}>
          <Typography color="text.secondary">Chưa có danh mục</Typography>
          <Button sx={{ mt: 1 }} onClick={onAdd}>
            Thêm danh mục
          </Button>
        </Card>
      ) : (
        <Stack spacing={1}>
          {categories.map((c) => (
            <Card key={c.id} elevation={0}>
              <CardContent sx={{ py: 1.5, '&:last-child': { pb: 1.5 } }}>
                <Stack direction="row" alignItems="center" spacing={1}>
                  <Typography fontSize={20} component="span" sx={{ lineHeight: 1 }}>
                    {c.icon ?? '📁'}
                  </Typography>
                  <Typography fontWeight={700} flex={1}>
                    {c.name}
                  </Typography>
                  <IconButton
                    color="error"
                    size="small"
                    aria-label="Xóa"
                    onClick={() => {
                      if (confirm('Xóa danh mục này?')) onDelete(c.id);
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
    </Box>
  );
}

export function CategoriesPage() {
  const qc = useQueryClient();
  const [open, setOpen] = useState(false);
  const [name, setName] = useState('');
  const [type, setType] = useState<'EXPENSE' | 'INCOME'>('EXPENSE');

  const { data: expenseCategories = [], isLoading: loadingExp } = useQuery({
    queryKey: ['categories', 'EXPENSE'],
    queryFn: () => categoryService.fetchCategories('EXPENSE'),
  });

  const { data: incomeCategories = [], isLoading: loadingInc } = useQuery({
    queryKey: ['categories', 'INCOME'],
    queryFn: () => categoryService.fetchCategories('INCOME'),
  });

  const createMut = useMutation({
    mutationFn: () =>
      categoryService.createCategory({
        name: name.trim(),
        type,
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['categories'] });
      setOpen(false);
      setName('');
    },
  });

  const delMut = useMutation({
    mutationFn: (id: number) => categoryService.deleteCategory(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['categories'] }),
  });

  function openAdd(forType: 'EXPENSE' | 'INCOME') {
    setType(forType);
    setName('');
    setOpen(true);
  }

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
        <Typography variant="h5" fontWeight={800} sx={{ mb: 3 }}>
          Danh mục
        </Typography>

        <CategorySection
          title="Chi tiêu"
          subtitle="Danh mục cho khoản chi"
          accentColor={palette.expense}
          categories={expenseCategories}
          isLoading={loadingExp}
          onAdd={() => openAdd('EXPENSE')}
          onDelete={(id) => delMut.mutate(id)}
        />

        <CategorySection
          title="Thu nhập"
          subtitle="Danh mục cho khoản thu"
          accentColor={palette.income}
          categories={incomeCategories}
          isLoading={loadingInc}
          onAdd={() => openAdd('INCOME')}
          onDelete={(id) => delMut.mutate(id)}
        />

        <Dialog open={open} onClose={() => setOpen(false)} fullWidth>
          <DialogTitle>
            {type === 'EXPENSE' ? 'Thêm danh mục chi tiêu' : 'Thêm danh mục thu nhập'}
          </DialogTitle>
          <DialogContent>
            <TextField
              autoFocus
              fullWidth
              label="Tên"
              value={name}
              onChange={(e) => setName(e.target.value)}
              margin="normal"
            />
            <TextField
              select
              fullWidth
              label="Loại"
              value={type}
              onChange={(e) =>
                setType(e.target.value as 'EXPENSE' | 'INCOME')
              }
              margin="normal"
            >
              <MenuItem value="EXPENSE">Chi tiêu</MenuItem>
              <MenuItem value="INCOME">Thu nhập</MenuItem>
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
              disabled={!name.trim()}
            >
              Tạo
            </Button>
          </DialogActions>
        </Dialog>
      </Box>
    </GradientBackground>
  );
}
