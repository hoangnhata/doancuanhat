import { Box, CircularProgress } from '@mui/material';
import { Navigate } from 'react-router-dom';
import { useAuth } from '@/contexts/AuthContext';
import type { ReactNode } from 'react';

/** Đã xong onboarding thì không cho vào /onboarding nữa. */
export function OnboardingOnly({ children }: { children: ReactNode }) {
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
  if (user?.onboardingCompleted) {
    return <Navigate to="/app/dashboard" replace />;
  }
  return <>{children}</>;
}
