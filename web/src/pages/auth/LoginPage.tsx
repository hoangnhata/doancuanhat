import {
  Alert,
  Box,
  Button,
  Container,
  Link,
  Paper,
  Snackbar,
  TextField,
  Typography,
} from '@mui/material';
import { useState } from 'react';
import { Link as RouterLink, Navigate, useLocation, useNavigate } from 'react-router-dom';
import { GradientBackground } from '@/components/common/GradientBackground';
import { RobotAvatar } from '@/components/robot';
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
    <GradientBackground>
      <Container maxWidth="sm" sx={{ py: 6 }}>
        <Box
          sx={{
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            mb: 3,
          }}
        >
          <Box
            sx={{
              p: 2,
              borderRadius: 4,
              bgcolor: 'background.paper',
              boxShadow: 3,
            }}
          >
            <RobotAvatar size={88} animated />
          </Box>
        </Box>
        <Typography
          variant="h4"
          color="text.primary"
          gutterBottom
          fontWeight={800}
          textAlign="center"
        >
          Đăng nhập
        </Typography>
        <Typography color="text.secondary" sx={{ mb: 1, textAlign: 'center' }}>
          Chào mừng trở lại!
        </Typography>
        <Typography
          variant="caption"
          color="text.disabled"
          sx={{ mb: 2, textAlign: 'center', display: 'block', px: 1 }}
        >
          Test AI: ai.demo@local.test / Demo@123456
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
            placeholder="email@example.com"
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
            autoComplete="current-password"
          />
          {error && (
            <Alert severity="error" sx={{ mt: 2 }} icon={false}>
              {error}
            </Alert>
          )}
          <Box display="flex" justifyContent="flex-end" mt={1}>
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
          <Button
            fullWidth
            type="submit"
            variant="contained"
            size="large"
            disabled={submitting}
            sx={{ mt: 2 }}
          >
            {submitting ? 'Đang đăng nhập…' : 'Đăng nhập'}
          </Button>
          <Box textAlign="center" mt={2}>
            <Typography variant="body2" color="text.secondary">
              Bạn chưa có tài khoản?{' '}
              <Link
                component={RouterLink}
                to="/register"
                fontWeight={700}
                color={palette.primary.main}
                underline="hover"
              >
                Đăng ký tại đây
              </Link>
            </Typography>
          </Box>
        </Paper>
      </Container>
      <Snackbar
        open={!!info}
        autoHideDuration={5000}
        onClose={() => setInfo(null)}
        message={info ?? ''}
      />
    </GradientBackground>
  );
}
