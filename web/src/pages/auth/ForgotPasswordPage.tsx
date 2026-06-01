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
import { MarkEmailUnreadRounded } from '@mui/icons-material';
import { useState } from 'react';
import { Link as RouterLink, useNavigate, useLocation } from 'react-router-dom';
import { GradientBackground } from '@/components/common/GradientBackground';
import { extractApiError } from '@/lib/api';
import { palette } from '@/theme';
import * as authService from '@/services/authService';

export function ForgotPasswordPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const initialEmail = (location.state as { email?: string } | null)?.email ?? '';
  const [email, setEmail] = useState(initialEmail);
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    if (!email.trim() || !email.includes('@')) {
      setError('Vui lòng nhập email hợp lệ');
      return;
    }
    setSubmitting(true);
    try {
      await authService.forgotPassword(email.trim());
      navigate('/reset-password', { state: { email: email.trim() }, replace: false });
    } catch (err) {
      setError(extractApiError(err));
    } finally {
      setSubmitting(false);
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
            <MarkEmailUnreadRounded sx={{ fontSize: 56 }} />
          </Box>
        </Box>
        <Typography variant="h4" fontWeight={800} textAlign="center" gutterBottom>
          Quên mật khẩu
        </Typography>
        <Typography color="text.secondary" textAlign="center" sx={{ mb: 3 }}>
          Nhập email — chúng tôi sẽ gửi mã OTP 6 chữ số để đặt lại mật khẩu.
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
            {submitting ? 'Đang gửi…' : 'Gửi mã OTP'}
          </Button>
          <Box textAlign="center" mt={2}>
            <Link
              component={RouterLink}
              to="/reset-password"
              state={{ email: email.trim() || undefined }}
              underline="hover"
              fontWeight={600}
              color={palette.primary.main}
            >
              Tôi đã có mã OTP →
            </Link>
          </Box>
          <Box textAlign="center" mt={1.5}>
            <Typography variant="body2" color="text.secondary">
              <Link component={RouterLink} to="/login" underline="hover">
                ← Quay lại đăng nhập
              </Link>
            </Typography>
          </Box>
        </Paper>
      </Container>
    </GradientBackground>
  );
}
