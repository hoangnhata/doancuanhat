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
import { LockResetRounded, RefreshRounded } from '@mui/icons-material';
import { useState } from 'react';
import { Link as RouterLink, useLocation, useNavigate } from 'react-router-dom';
import { GradientBackground } from '@/components/common/GradientBackground';
import { extractApiError } from '@/lib/api';
import { palette } from '@/theme';
import * as authService from '@/services/authService';

export function ResetPasswordPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const initialEmail = (location.state as { email?: string } | null)?.email ?? '';

  const [email, setEmail] = useState(initialEmail);
  const [otp, setOtp] = useState('');
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [resending, setResending] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    if (!email.trim() || !email.includes('@')) {
      setError('Email không hợp lệ');
      return;
    }
    if (!/^\d{6}$/.test(otp)) {
      setError('OTP gồm 6 chữ số');
      return;
    }
    if (password.length < 6) {
      setError('Mật khẩu mới tối thiểu 6 ký tự');
      return;
    }
    if (password !== confirm) {
      setError('Mật khẩu xác nhận không khớp');
      return;
    }
    setSubmitting(true);
    try {
      await authService.resetPassword(email.trim(), otp.trim(), password);
      navigate('/login', { replace: true, state: { resetSuccess: true } });
    } catch (err) {
      setError(extractApiError(err));
    } finally {
      setSubmitting(false);
    }
  }

  async function handleResend() {
    if (!email.trim() || !email.includes('@')) {
      setError('Nhập email trước khi gửi lại OTP');
      return;
    }
    setResending(true);
    setError(null);
    try {
      await authService.forgotPassword(email.trim());
      setInfo('Đã gửi lại OTP, vui lòng kiểm tra email.');
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
            <LockResetRounded sx={{ fontSize: 56 }} />
          </Box>
        </Box>
        <Typography variant="h4" fontWeight={800} textAlign="center" gutterBottom>
          Đặt lại mật khẩu
        </Typography>
        <Typography color="text.secondary" textAlign="center" sx={{ mb: 3 }}>
          Nhập mã OTP đã gửi đến email + mật khẩu mới.
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
          <TextField
            fullWidth
            label="Mật khẩu mới"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            margin="normal"
            helperText="Tối thiểu 6 ký tự"
            autoComplete="new-password"
          />
          <TextField
            fullWidth
            label="Nhập lại mật khẩu mới"
            type="password"
            value={confirm}
            onChange={(e) => setConfirm(e.target.value)}
            margin="normal"
            autoComplete="new-password"
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
              {submitting ? 'Đang xử lý…' : 'Đặt lại mật khẩu'}
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
              <Link component={RouterLink} to="/login" underline="hover">
                ← Quay lại đăng nhập
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
