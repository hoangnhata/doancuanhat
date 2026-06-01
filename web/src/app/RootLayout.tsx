import { Outlet } from 'react-router-dom';
import { AppProviders } from '@/app/AppProviders';

export function RootLayout() {
  return (
    <AppProviders>
      <Outlet />
    </AppProviders>
  );
}
