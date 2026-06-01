import {
  AppBar,
  BottomNavigation,
  BottomNavigationAction,
  Box,
  Drawer,
  Fab,
  IconButton,
  List,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  Toolbar,
  Typography,
  useMediaQuery,
  useTheme,
} from '@mui/material';
import {
  AddRounded,
  AccountBalanceWalletRounded,
  AutoGraphRounded,
  ChevronLeftRounded,
  HomeRounded,
  SettingsRounded,
  SmartToyRounded,
} from '@mui/icons-material';
import { Outlet, useLocation, useNavigate } from 'react-router-dom';
import { useMemo } from 'react';
import { WalletStorageSync } from '@/contexts/SelectedWalletContext';
import { RobotAvatar } from '@/components/robot';
import { palette } from '@/theme';

const MAIN_TAB_PATHS = [
  '/app/dashboard',
  '/app/transactions',
  '/app/spending-forecast',
  '/app/chat',
  '/app/settings',
];

const drawerWidth = 280;

const navItems = [
  { to: '/app/dashboard', label: 'Trang chủ', icon: <HomeRounded /> },
  {
    to: '/app/transactions',
    label: 'Giao dịch',
    icon: <AccountBalanceWalletRounded />,
  },
  { to: '/app/spending-forecast', label: 'Dự báo', icon: <AutoGraphRounded /> },
  { to: '/app/chat', label: 'Trợ lý AI', icon: <SmartToyRounded /> },
  { to: '/app/settings', label: 'Cài đặt', icon: <SettingsRounded /> },
];

function tabIndex(pathname: string): number {
  const i = navItems.findIndex((n) => pathname.startsWith(n.to));
  return i >= 0 ? i : 0;
}

export function AppShell() {
  const theme = useTheme();
  const isDesktop = useMediaQuery(theme.breakpoints.up('md'));
  const { pathname } = useLocation();
  const navigate = useNavigate();

  const isMainTab = MAIN_TAB_PATHS.some((p) => pathname === p || pathname === `${p}/`);

  const title = useMemo(() => {
    if (pathname.includes('/categories')) return 'Danh mục';
    if (pathname.includes('/budget')) return 'Ngân sách';
    if (pathname.includes('/wallets')) return 'Quản lý ví';
    if (pathname.includes('/recurring')) return 'Giao dịch định kỳ';
    if (pathname.includes('/analytics')) return 'Phân tích';
    if (pathname.includes('/milestones')) return 'Cột mốc';
    if (pathname.includes('/transactions/add')) return 'Thêm giao dịch';
    if (pathname.includes('/edit')) return 'Sửa giao dịch';
    return '';
  }, [pathname]);

  const showSubShell = !isMainTab;

  const bottomValue = tabIndex(pathname);

  return (
    <Box sx={{ display: 'flex', minHeight: '100vh', bgcolor: 'background.default' }}>
      <WalletStorageSync />
      {isDesktop && isMainTab && (
        <Drawer
          variant="permanent"
          sx={{
            width: drawerWidth,
            flexShrink: 0,
            '& .MuiDrawer-paper': {
              width: drawerWidth,
              boxSizing: 'border-box',
              borderRight: '1px solid',
              borderColor: 'divider',
              background: (t) =>
                `linear-gradient(180deg, ${palette.gradientStart} 0%, ${t.palette.background.paper} 52%, ${t.palette.background.paper} 100%)`,
              boxShadow: (t) =>
                t.palette.mode === 'dark'
                  ? '4px 0 24px rgba(0,0,0,0.25)'
                  : '4px 0 32px rgba(15, 23, 42, 0.06)',
            },
          }}
        >
          <Toolbar sx={{ py: 2.5, flexDirection: 'column', alignItems: 'flex-start', gap: 1 }}>
            <Box display="flex" alignItems="center" gap={1.5} px={1}>
              <Box
                sx={{
                  p: 0.75,
                  borderRadius: 2.5,
                  bgcolor: 'background.paper',
                  border: '1px solid',
                  borderColor: 'divider',
                  boxShadow: palette.shadowSoft,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <RobotAvatar size={40} animated={false} />
              </Box>
              <Box>
                <Typography fontWeight={800} color="text.primary" fontSize={18} letterSpacing="-0.02em">
                  Natta
                </Typography>
                <Typography variant="caption" color="text.secondary" fontWeight={500}>
                  Quản lý chi tiêu
                </Typography>
              </Box>
            </Box>
          </Toolbar>
          <List sx={{ px: 2 }}>
            {navItems.map((item) => {
              const selected =
                pathname === item.to || pathname.startsWith(`${item.to}/`);
              return (
                <ListItemButton
                  key={item.to}
                  selected={selected}
                  onClick={() => navigate(item.to)}
                  sx={{
                    borderRadius: 2,
                    mb: 0.5,
                    py: 1.25,
                    transition: 'transform 0.15s ease, box-shadow 0.2s ease',
                    '&:hover': { transform: 'translateX(2px)' },
                    '&.Mui-selected': {
                      bgcolor: 'primary.main',
                      color: 'white',
                      boxShadow: '0 6px 20px rgba(2, 136, 209, 0.38)',
                      '& .MuiListItemIcon-root': { color: 'white' },
                    },
                  }}
                >
                  <ListItemIcon sx={{ minWidth: 40, color: 'inherit' }}>
                    {item.icon}
                  </ListItemIcon>
                  <ListItemText primary={item.label} />
                </ListItemButton>
              );
            })}
          </List>
        </Drawer>
      )}

      <Box
        component="main"
        sx={{
          flexGrow: 1,
          display: 'flex',
          flexDirection: 'column',
          minHeight: '100vh',
          width: { md: `calc(100% - ${drawerWidth}px)` },
          pb: !isDesktop && isMainTab ? 10 : 0,
        }}
      >
        {showSubShell && (
          <AppBar
            position="sticky"
            color="inherit"
            elevation={0}
            sx={{
              borderBottom: 1,
              borderColor: 'divider',
            }}
          >
            <Toolbar>
              <IconButton edge="start" onClick={() => navigate(-1)} sx={{ mr: 1 }}>
                <ChevronLeftRounded />
              </IconButton>
              <Typography variant="h6" fontWeight={700} color="text.primary">
                {title}
              </Typography>
            </Toolbar>
          </AppBar>
        )}

        <Box sx={{ flex: 1, position: 'relative' }}>
          <Outlet />
        </Box>

        {!isDesktop && isMainTab && (
          <BottomNavigation
            value={bottomValue}
            showLabels
            onChange={(_, v) => navigate(navItems[v].to)}
            sx={{
              position: 'fixed',
              bottom: 0,
              left: 0,
              right: 0,
              borderTop: 1,
              borderColor: 'divider',
              borderRadius: '20px 20px 0 0',
              bgcolor: (t) =>
                t.palette.mode === 'dark' ? 'rgba(30, 41, 59, 0.92)' : 'rgba(255, 255, 255, 0.92)',
              backdropFilter: 'saturate(180%) blur(16px)',
              boxShadow: '0 -8px 32px rgba(15, 23, 42, 0.08)',
              zIndex: (t) => t.zIndex.appBar,
              py: 0.5,
              '& .Mui-selected': {
                color: 'primary.main',
                '& .MuiBottomNavigationAction-label': { fontWeight: 700 },
              },
            }}
          >
            {navItems.map((item, i) => (
              <BottomNavigationAction
                key={item.to}
                label={item.label}
                icon={item.icon}
                value={i}
              />
            ))}
          </BottomNavigation>
        )}

        {isMainTab && (
          <Fab
            color="primary"
            aria-label="add"
            onClick={() => navigate('/app/transactions/add')}
            sx={{
              position: 'fixed',
              right: 24,
              bottom: !isDesktop ? 88 : 24,
              zIndex: (t) => t.zIndex.fab,
            }}
          >
            <AddRounded />
          </Fab>
        )}
      </Box>
    </Box>
  );
}
