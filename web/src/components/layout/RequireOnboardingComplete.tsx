import { Box, CircularProgress } from '@mui/material';
import { Navigate, Outlet } from 'react-router-dom';
import { useAuth } from '@/contexts/AuthContext';

/** Chặn vào /app/* nếu chưa hoàn tất onboarding (đồng bộ với app Flutter). */
export function RequireOnboardingComplete() {
  const { user, loading } = useAuth();

  if (loading) {
    return (
      <Box
        display="flex"
        alignItems="center"
        justifyContent="center"
        minHeight="100vh"
      >
        <CircularProgress color="primary" />
      </Box>
    );
  }
  if (user && !user.onboardingCompleted) {
    return <Navigate to="/onboarding" replace />;
  }
  return <Outlet />;
}
