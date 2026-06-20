import { Alert, Box, Link, Snackbar, Typography } from '@mui/material';
import { EmailRounded, LockRounded } from '@mui/icons-material';
import { useState } from 'react';
import { Link as RouterLink, Navigate, useLocation, useNavigate } from 'react-router-dom';
import { AuthPrimaryButton } from '@/components/auth/AuthPrimaryButton';
import { AuthShell } from '@/components/auth/AuthShell';
import { AuthTextField } from '@/components/auth/AuthTextField';
import { useAuth } from '@/contexts/AuthContext';
import { extractApiError } from '@/lib/api';
import { palette } from '@/theme';

export function LoginPage() {
  const { user, loading, login } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const resetSuccess = (location.state as { resetSuccess?: boolean } | null)?.resetSuccess;
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [info, setInfo] = useState<string | null>(
    resetSuccess ? 'Đặt lại mật khẩu thành công. Hãy đăng nhập với mật khẩu mới.' : null,
  );

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
    if (!email.trim() || !password) {
      setError('Vui lòng nhập đủ thông tin');
      return;
    }
    setSubmitting(true);
    try {
      const u = await login(email.trim(), password);
      navigate(
        u.onboardingCompleted ? '/app/dashboard' : '/onboarding',
        { replace: true },
      );
    } catch (err) {
      setError(extractApiError(err));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <>
      <AuthShell
        title="Đăng nhập"
        subtitle="Chào mừng trở lại! Tiếp tục theo dõi chi tiêu và trò chuyện với trợ lý AI."
        showDemoHint
        footer={
          <Typography variant="body2" color="text.secondary">
            Bạn chưa có tài khoản?{' '}
            <Link
              component={RouterLink}
              to="/register"
              fontWeight={700}
              color={palette.primary.main}
              underline="hover"
            >
              Đăng ký miễn phí
            </Link>
          </Typography>
        }
      >
        <Box component="form" onSubmit={handleSubmit}>
          <AuthTextField
            label="Email"
            type="email"
            placeholder="email@example.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            autoComplete="email"
            startIcon={<EmailRounded />}
          />
          <AuthTextField
            label="Mật khẩu"
            type="password"
            placeholder="••••••••"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="current-password"
            startIcon={<LockRounded />}
          />
          {error && (
            <Alert severity="error" sx={{ mt: 2, borderRadius: 2 }} icon={false}>
              {error}
            </Alert>
          )}
          <Box display="flex" justifyContent="flex-end" mt={0.5}>
            <Link
              component={RouterLink}
              to="/forgot-password"
              state={{ email: email.trim() || undefined }}
              fontWeight={600}
              color={palette.primary.main}
              underline="hover"
              variant="body2"
            >
              Quên mật khẩu?
            </Link>
          </Box>
          <AuthPrimaryButton type="submit" loading={submitting} loadingLabel="Đang đăng nhập…">
            Đăng nhập
          </AuthPrimaryButton>
        </Box>
      </AuthShell>
      <Snackbar
        open={!!info}
        autoHideDuration={5000}
        onClose={() => setInfo(null)}
        message={info ?? ''}
      />
    </>
  );
}
