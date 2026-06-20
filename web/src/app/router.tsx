import { Navigate, createBrowserRouter } from 'react-router-dom';
import { RootLayout } from '@/app/RootLayout';
import { AppShell } from '@/components/layout/AppShell';
import { OnboardingOnly } from '@/components/layout/OnboardingOnly';
import { ProtectedRoute } from '@/components/layout/ProtectedRoute';
import { RequireOnboardingComplete } from '@/components/layout/RequireOnboardingComplete';
import { LoginPage } from '@/pages/auth/LoginPage';
import { RegisterPage } from '@/pages/auth/RegisterPage';
import { VerifyRegistrationPage } from '@/pages/auth/VerifyRegistrationPage';
import { ForgotPasswordPage } from '@/pages/auth/ForgotPasswordPage';
import { ResetPasswordPage } from '@/pages/auth/ResetPasswordPage';
import { OnboardingPage } from '@/pages/onboarding/OnboardingPage';
import { DashboardPage } from '@/pages/dashboard/DashboardPage';
import { TransactionsPage } from '@/pages/transactions/TransactionsPage';
import { ChatPage } from '@/pages/chat/ChatPage';
import { SettingsPage } from '@/pages/settings/SettingsPage';
import { CategoriesPage } from '@/pages/categories/CategoriesPage';
import { BudgetPage } from '@/pages/budget/BudgetPage';
import { WalletsPage } from '@/pages/wallets/WalletsPage';
import { RecurringPage } from '@/pages/recurring/RecurringPage';
import { AddTransactionPage } from '@/pages/transaction/AddTransactionPage';
import { AnalyticsPage } from '@/pages/analytics/AnalyticsPage';
import { SavingGoalsPage } from '@/pages/saving-goals/SavingGoalsPage';
import { SpendingForecastPage } from '@/pages/forecast/SpendingForecastPage';
import { ProfilePage } from '@/pages/profile/ProfilePage';

export const router = createBrowserRouter([
  {
    element: <RootLayout />,
    children: [
      { path: '/', element: <Navigate to="/login" replace /> },
      { path: '/login', element: <LoginPage /> },
      { path: '/register', element: <RegisterPage /> },
      { path: '/register/verify', element: <VerifyRegistrationPage /> },
      { path: '/forgot-password', element: <ForgotPasswordPage /> },
      { path: '/reset-password', element: <ResetPasswordPage /> },
      {
        path: '/onboarding',
        element: (
          <ProtectedRoute>
            <OnboardingOnly>
              <OnboardingPage />
            </OnboardingOnly>
          </ProtectedRoute>
        ),
      },
      {
        path: '/app',
        element: (
          <ProtectedRoute>
            <RequireOnboardingComplete />
          </ProtectedRoute>
        ),
        children: [
          {
            element: <AppShell />,
            children: [
              { index: true, element: <Navigate to="dashboard" replace /> },
              { path: 'dashboard', element: <DashboardPage /> },
              { path: 'transactions', element: <TransactionsPage /> },
              { path: 'chat', element: <ChatPage /> },
              { path: 'settings', element: <SettingsPage /> },
              { path: 'categories', element: <CategoriesPage /> },
              { path: 'budget', element: <BudgetPage /> },
              { path: 'wallets', element: <WalletsPage /> },
              { path: 'recurring', element: <RecurringPage /> },
              { path: 'transactions/add', element: <AddTransactionPage /> },
              { path: 'transactions/:id/edit', element: <AddTransactionPage /> },
              { path: 'analytics', element: <AnalyticsPage /> },
              { path: 'spending-forecast', element: <SpendingForecastPage /> },
              { path: 'saving-goals', element: <SavingGoalsPage /> },
              { path: 'profile', element: <ProfilePage /> },
            ],
          },
        ],
      },
      { path: '*', element: <Navigate to="/login" replace /> },
    ],
  },
]);
