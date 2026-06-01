import {
  Box,
  Button,
  Card,
  CardActionArea,
  Chip,
  Divider,
  Grid,
  LinearProgress,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { InfoOutlined, LockOutlined } from '@mui/icons-material';
import { useMutation } from '@tanstack/react-query';
import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { GradientBackground } from '@/components/common/GradientBackground';
import { PersonalityRobotAvatar } from '@/components/robot/PersonalityRobotAvatar';
import { useAuth } from '@/contexts/AuthContext';
import { extractApiError } from '@/lib/api';
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

export function OnboardingPage() {
  const navigate = useNavigate();
  const { refreshUser } = useAuth();
  const [step, setStep] = useState(0);
  const [personality, setPersonality] = useState<'HAPPY' | 'SAD' | 'ANGRY'>('HAPPY');
  const [walletName, setWalletName] = useState('Ví của tôi');
  const [currency, setCurrency] = useState<'VND' | 'USD'>('VND');
  const [initialBalance, setInitialBalance] = useState('0');
  const [error, setError] = useState<string | null>(null);

  const progress = ((step + 1) / 2) * 100;

  const botMut = useMutation({
    mutationFn: () => userService.patchProfile({ botPersonality: personality }),
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
        onboardingCompleted: true,
      }),
    onSuccess: async () => {
      await refreshUser();
      setError(null);
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
          Bước {step + 1}/2 — đồng bộ với app mobile
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
              Thiết lập ví
            </Typography>
            <Typography color="text.secondary" sx={{ mb: 3 }}>
              Giống bước ví trên app — lưu vào hồ sơ người dùng (backend). Danh mục chi tiêu/thu nhập mặc định đã được tạo khi đăng ký.
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
            <Stack direction="row" spacing={2} sx={{ mt: 3 }}>
              <Button onClick={() => setStep(0)}>Quay lại</Button>
              <Button
                fullWidth
                variant="contained"
                size="large"
                onClick={() => walletMut.mutate()}
                disabled={walletMut.isPending}
              >
                {walletMut.isPending ? 'Đang lưu…' : 'Hoàn tất'}
              </Button>
            </Stack>
          </>
        )}
      </Box>
    </GradientBackground>
  );
}
