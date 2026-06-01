import {
  Alert,
  Box,
  Button,
  Container,
  Link,
  Paper,
  TextField,
  Typography,
} from '@mui/material';
import { useState } from 'react';
import { Link as RouterLink, Navigate, useNavigate } from 'react-router-dom';
import { GradientBackground } from '@/components/common/GradientBackground';
import { RobotAvatar } from '@/components/robot';
import { useAuth } from '@/contexts/AuthContext';
import { extractApiError } from '@/lib/api';
import { palette } from '@/theme';
import * as authService from '@/services/authService';

export function RegisterPage() {
  const { user, loading } = useAuth();
  const navigate = useNavigate();
  const [fullName, setFullName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [phone, setPhone] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  if (!loading && user) {
    return (
      <Navigate
        to={user.onboardingCompleted ? '/app/dashboard' : '/onboarding'}
        replace
      />
    );
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    if (!fullName.trim() || !email.trim() || password.length < 6) {
      setError('Họ tên, email và mật khẩu (≥6 ký tự) là bắt buộc');
      return;
    }
    setSubmitting(true);
    try {
      // Bước 1: gửi OTP, CHƯA tạo user thật.
      await authService.requestRegistration(
        fullName.trim(),
        email.trim(),
        password,
        phone.trim() || undefined,
      );
      navigate('/register/verify', { state: { email: email.trim() } });
    } catch (err) {
      setError(extractApiError(err));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <GradientBackground>
      <Container maxWidth="sm" sx={{ py: 6 }}>
        <Box display="flex" justifyContent="center" mb={3}>
          <Box
            sx={{
              p: 1.5,
              borderRadius: 3,
              bgcolor: 'background.paper',
              boxShadow: 2,
            }}
          >
            <RobotAvatar size={72} animated />
          </Box>
        </Box>
        <Typography variant="h4" color="text.primary" gutterBottom fontWeight={800} textAlign="center">
          Đăng ký
        </Typography>
        <Typography color="text.secondary" sx={{ mb: 3, textAlign: 'center' }}>
          Chúng tôi sẽ gửi mã OTP về email để xác minh trước khi tạo tài khoản.
        </Typography>
        <Paper
          elevation={0}
          component="form"
          onSubmit={handleSubmit}
          sx={{
            p: { xs: 2.5, sm: 4 },
            borderRadius: 3,
            border: '1px solid',
            borderColor: 'divider',
            bgcolor: 'background.paper',
            boxShadow: palette.shadowLift,
          }}
        >
          <TextField
            fullWidth
            label="Họ và tên"
            value={fullName}
            onChange={(e) => setFullName(e.target.value)}
            margin="normal"
          />
          <TextField
            fullWidth
            label="Email"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            margin="normal"
            autoComplete="email"
          />
          <TextField
            fullWidth
            label="Mật khẩu"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            margin="normal"
            helperText="Tối thiểu 6 ký tự"
            autoComplete="new-password"
          />
          <TextField
            fullWidth
            label="Số điện thoại (tuỳ chọn)"
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            margin="normal"
          />
          {error && (
            <Alert severity="error" sx={{ mt: 2 }} icon={false}>
              {error}
            </Alert>
          )}
          <Button
            fullWidth
            type="submit"
            variant="contained"
            size="large"
            disabled={submitting}
            sx={{ mt: 3 }}
          >
            {submitting ? 'Đang gửi OTP…' : 'Tiếp tục → Nhận OTP qua email'}
          </Button>
          <Box textAlign="center" mt={2}>
            <Typography variant="body2" color="text.secondary">
              Đã có tài khoản?{' '}
              <Link
                component={RouterLink}
                to="/login"
                fontWeight={700}
                color={palette.primary.main}
                underline="hover"
              >
                Đăng nhập
              </Link>
            </Typography>
          </Box>
        </Paper>
      </Container>
    </GradientBackground>
  );
}
