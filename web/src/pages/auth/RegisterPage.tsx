import { Alert, Box, Link, Typography } from '@mui/material';
import {
  EmailRounded,
  LockRounded,
  PersonRounded,
  PhoneRounded,
} from '@mui/icons-material';
import { useState } from 'react';
import { Link as RouterLink, Navigate, useNavigate } from 'react-router-dom';
import { AuthPrimaryButton } from '@/components/auth/AuthPrimaryButton';
import { AuthShell } from '@/components/auth/AuthShell';
import { AuthTextField } from '@/components/auth/AuthTextField';
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
    <AuthShell
      title="Tạo tài khoản"
      subtitle="Điền thông tin cơ bản — chúng tôi sẽ gửi mã OTP qua email để xác minh trước khi kích hoạt."
      footer={
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
      }
    >
      <Box component="form" onSubmit={handleSubmit}>
        <AuthTextField
          label="Họ và tên"
          placeholder="Nguyễn Văn A"
          value={fullName}
          onChange={(e) => setFullName(e.target.value)}
          startIcon={<PersonRounded />}
        />
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
          placeholder="Tối thiểu 6 ký tự"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          helperText="Tối thiểu 6 ký tự"
          autoComplete="new-password"
          startIcon={<LockRounded />}
        />
        <AuthTextField
          label="Số điện thoại (tuỳ chọn)"
          placeholder="0901234567"
          value={phone}
          onChange={(e) => setPhone(e.target.value)}
          startIcon={<PhoneRounded />}
        />
        {error && (
          <Alert severity="error" sx={{ mt: 2, borderRadius: 2 }} icon={false}>
            {error}
          </Alert>
        )}
        <AuthPrimaryButton
          type="submit"
          loading={submitting}
          loadingLabel="Đang gửi OTP…"
          sx={{ mt: 3 }}
        >
          Tiếp tục — Nhận OTP qua email
        </AuthPrimaryButton>
      </Box>
    </AuthShell>
  );
}
