import {
  Alert,
  Box,
  Button,
  Container,
  Link,
  Paper,
  Snackbar,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { MarkEmailReadRounded, RefreshRounded } from '@mui/icons-material';
import { useState } from 'react';
import { Link as RouterLink, Navigate, useLocation, useNavigate } from 'react-router-dom';
import { GradientBackground } from '@/components/common/GradientBackground';
import { useAuth } from '@/contexts/AuthContext';
import { extractApiError } from '@/lib/api';
import { palette } from '@/theme';
import * as authService from '@/services/authService';

export function VerifyRegistrationPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const initialEmail = (location.state as { email?: string } | null)?.email ?? '';
  const { setAuthUser } = useAuth();

  const [email, setEmail] = useState(initialEmail);
  const [otp, setOtp] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [resending, setResending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);

  // Nếu user vào trực tiếp /register/verify mà không có email từ state → quay về register.
  if (!initialEmail && !email) {
    return <Navigate to="/register" replace />;
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    if (!/^\d{6}$/.test(otp)) {
      setError('OTP gồm 6 chữ số');
      return;
    }
    if (!email.trim()) {
      setError('Email không hợp lệ');
      return;
    }
    setSubmitting(true);
    try {
      const payload = await authService.verifyRegistration(email.trim(), otp.trim());
      setAuthUser(payload.user);
      navigate(
        payload.user.onboardingCompleted ? '/app/dashboard' : '/onboarding',
        { replace: true },
      );
    } catch (err) {
      setError(extractApiError(err));
    } finally {
      setSubmitting(false);
    }
  }

  async function handleResend() {
    if (!email.trim()) {
      setError('Nhập email để gửi lại OTP');
      return;
    }
    setResending(true);
    setError(null);
    try {
      await authService.resendRegistrationOtp(email.trim());
      setInfo('Đã gửi lại OTP. Vui lòng kiểm tra email.');
    } catch (err) {
      setError(extractApiError(err));
    } finally {
      setResending(false);
    }
  }

  return (
    <GradientBackground>
      <Container maxWidth="sm" sx={{ py: 6 }}>
        <Box display="flex" justifyContent="center" mb={2}>
          <Box
            sx={{
              p: 2,
              borderRadius: 3,
              bgcolor: 'background.paper',
              boxShadow: 2,
              color: 'primary.main',
            }}
          >
            <MarkEmailReadRounded sx={{ fontSize: 56 }} />
          </Box>
        </Box>
        <Typography variant="h4" fontWeight={800} textAlign="center" gutterBottom>
          Xác minh email
        </Typography>
        <Typography color="text.secondary" textAlign="center">
          Mã OTP 6 chữ số đã được gửi đến:
        </Typography>
        <Typography
          textAlign="center"
          fontWeight={800}
          color={palette.primary.main}
          sx={{ mb: 3 }}
        >
          {email}
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
            label="Email"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            margin="normal"
            autoComplete="email"
          />
          <TextField
            fullWidth
            label="Mã OTP (6 chữ số)"
            value={otp}
            onChange={(e) => setOtp(e.target.value.replace(/\D/g, '').slice(0, 6))}
            margin="normal"
            inputProps={{ inputMode: 'numeric', maxLength: 6 }}
            autoFocus
          />
          {error && (
            <Alert severity="error" sx={{ mt: 2 }} icon={false}>
              {error}
            </Alert>
          )}
          <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5} sx={{ mt: 3 }}>
            <Button
              fullWidth
              type="submit"
              variant="contained"
              size="large"
              disabled={submitting}
            >
              {submitting ? 'Đang xác minh…' : 'Xác minh & Tạo tài khoản'}
            </Button>
            <Button
              fullWidth
              variant="outlined"
              size="large"
              startIcon={<RefreshRounded />}
              disabled={resending}
              onClick={handleResend}
            >
              {resending ? 'Đang gửi…' : 'Gửi lại OTP'}
            </Button>
          </Stack>
          <Box textAlign="center" mt={2}>
            <Typography variant="body2" color="text.secondary">
              <Link component={RouterLink} to="/register" underline="hover">
                ← Quay lại form đăng ký
              </Link>
            </Typography>
          </Box>
        </Paper>
      </Container>
      <Snackbar
        open={!!info}
        autoHideDuration={4000}
        onClose={() => setInfo(null)}
        message={info ?? ''}
      />
    </GradientBackground>
  );
}
