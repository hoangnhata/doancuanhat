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
} from "@mui/material";
import {
  AddRounded,
  AccountBalanceWalletRounded,
  AutoGraphRounded,
  ChevronLeftRounded,
  HomeRounded,
  SavingsRounded,
  SettingsRounded,
  SmartToyRounded,
  SpeedOutlined,
} from "@mui/icons-material";
import { Outlet, useLocation, useNavigate } from "react-router-dom";
import { useMemo } from "react";
import { WalletStorageSync } from "@/contexts/SelectedWalletContext";
import { RobotAvatar } from "@/components/robot";
import { palette } from "@/theme";

const drawerWidth = 272;

const navItems = [
  { to: "/app/dashboard", label: "Trang chủ", icon: <HomeRounded /> },
  {
    to: "/app/transactions",
    label: "Giao dịch",
    icon: <AccountBalanceWalletRounded />,
  },
  { to: "/app/budget", label: "Hạn mức chi tiêu", icon: <SpeedOutlined /> },
  {
    to: "/app/saving-goals",
    label: "Mục tiêu tiết kiệm",
    icon: <SavingsRounded />,
  },
  { to: "/app/spending-forecast", label: "Dự báo", icon: <AutoGraphRounded /> },
  { to: "/app/chat", label: "Trợ lý AI", icon: <SmartToyRounded /> },
  { to: "/app/settings", label: "Cài đặt", icon: <SettingsRounded /> },
];

function isNavRoute(pathname: string, to: string): boolean {
  return pathname === to || pathname.startsWith(`${to}/`);
}

function tabIndex(pathname: string): number {
  const i = navItems.findIndex((n) => isNavRoute(pathname, n.to));
  return i >= 0 ? i : 0;
}

export function AppShell() {
  const theme = useTheme();
  const isDesktop = useMediaQuery(theme.breakpoints.up("md"));
  const { pathname } = useLocation();
  const navigate = useNavigate();

  const isMainTab = navItems.some((n) => isNavRoute(pathname, n.to));

  const title = useMemo(() => {
    if (pathname.includes("/categories")) return "Danh mục";
    if (pathname.includes("/budget")) return "Hạn mức chi tiêu";
    if (pathname.includes("/wallets")) return "Quản lý ví";
    if (pathname.includes("/recurring")) return "Giao dịch định kỳ";
    if (pathname.includes("/analytics")) return "Phân tích";
    if (pathname.includes("/saving-goals")) return "Mục tiêu tiết kiệm";
    if (pathname.includes("/transactions/add")) return "Thêm giao dịch";
    if (pathname.includes("/edit")) return "Sửa giao dịch";
    return "";
  }, [pathname]);

  const showSubShell = !isMainTab;
  const isChatPage = pathname.startsWith("/app/chat");
  const bottomValue = tabIndex(pathname);

  return (
    <Box
      sx={{
        display: "flex",
        minHeight: "100vh",
        bgcolor: "background.default",
      }}
    >
      <WalletStorageSync />
      {isDesktop && isMainTab && (
        <Drawer
          variant="permanent"
          sx={{
            width: drawerWidth,
            flexShrink: 0,
            "& .MuiDrawer-paper": {
              width: drawerWidth,
              boxSizing: "border-box",
              borderRight: "none",
              background: (t) =>
                t.palette.mode === "dark"
                  ? `linear-gradient(180deg, ${palette.primary.dark}22 0%, ${t.palette.background.paper} 40%)`
                  : `linear-gradient(180deg, ${palette.gradientStart} 0%, #fff 38%, #fff 100%)`,
              boxShadow: "4px 0 40px rgba(2, 136, 209, 0.07)",
            },
          }}
        >
          <Box
            sx={{
              mx: 2,
              mt: 2.5,
              mb: 2,
              p: 2,
              borderRadius: 3,
              background: `linear-gradient(135deg, ${palette.primary.main} 0%, ${palette.primary.light} 100%)`,
              color: "#fff",
              boxShadow: "0 10px 32px rgba(2, 136, 209, 0.28)",
            }}
          >
            <Box display="flex" alignItems="center" gap={1.5}>
              <Box
                sx={{
                  p: 0.75,
                  borderRadius: 2.5,
                  bgcolor: "rgba(255,255,255,0.95)",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  flexShrink: 0,
                }}
              >
                <RobotAvatar size={38} animated={false} />
              </Box>
              <Box minWidth={0}>
                <Typography
                  fontWeight={800}
                  fontSize={17}
                  letterSpacing="-0.02em"
                  lineHeight={1.2}
                >
                  Natta
                </Typography>
                <Typography
                  variant="caption"
                  sx={{ opacity: 0.88, fontWeight: 600 }}
                >
                  Quản lý chi tiêu
                </Typography>
              </Box>
            </Box>
          </Box>

          <Typography
            variant="caption"
            fontWeight={700}
            color="text.secondary"
            sx={{
              px: 3,
              mb: 1,
              letterSpacing: 1,
              textTransform: "uppercase",
              fontSize: 10,
            }}
          >
            Menu
          </Typography>

          <List sx={{ px: 1.5, pb: 2 }}>
            {navItems.map((item) => {
              const selected = isNavRoute(pathname, item.to);
              return (
                <ListItemButton
                  key={item.to}
                  selected={selected}
                  onClick={() => navigate(item.to)}
                  sx={{
                    borderRadius: 2.5,
                    mb: 0.5,
                    py: 1.1,
                    px: 1.5,
                    gap: 0.5,
                    transition: "all 0.18s ease",
                    "&:hover": {
                      bgcolor: selected
                        ? undefined
                        : `${palette.primary.main}0A`,
                    },
                    "&.Mui-selected": {
                      bgcolor: `${palette.primary.main}14`,
                      color: palette.primary.dark,
                      "&:hover": { bgcolor: `${palette.primary.main}1A` },
                    },
                  }}
                >
                  <ListItemIcon sx={{ minWidth: 0, mr: 0 }}>
                    <Box
                      sx={{
                        width: 38,
                        height: 38,
                        borderRadius: 2,
                        display: "grid",
                        placeItems: "center",
                        transition: "all 0.18s ease",
                        bgcolor: selected
                          ? palette.primary.main
                          : `${palette.primary.main}10`,
                        color: selected ? "#fff" : palette.primary.main,
                        boxShadow: selected
                          ? "0 4px 14px rgba(2, 136, 209, 0.35)"
                          : "none",
                        "& svg": { fontSize: 21 },
                      }}
                    >
                      {item.icon}
                    </Box>
                  </ListItemIcon>
                  <ListItemText
                    primary={item.label}
                    primaryTypographyProps={{
                      fontWeight: selected ? 800 : 600,
                      fontSize: 14,
                      letterSpacing: "-0.01em",
                    }}
                  />
                  {selected && (
                    <Box
                      sx={{
                        width: 4,
                        height: 22,
                        borderRadius: 99,
                        bgcolor: palette.primary.main,
                        flexShrink: 0,
                      }}
                    />
                  )}
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
          display: "flex",
          flexDirection: "column",
          minHeight: "100vh",
          width: { md: isMainTab ? `calc(100% - ${drawerWidth}px)` : "100%" },
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
              borderColor: "divider",
            }}
          >
            <Toolbar>
              <IconButton
                edge="start"
                onClick={() => navigate(-1)}
                sx={{ mr: 1 }}
              >
                <ChevronLeftRounded />
              </IconButton>
              <Typography variant="h6" fontWeight={700} color="text.primary">
                {title}
              </Typography>
            </Toolbar>
          </AppBar>
        )}

        <Box sx={{ flex: 1, position: "relative" }}>
          <Outlet />
        </Box>

        {!isDesktop && isMainTab && (
          <BottomNavigation
            value={bottomValue}
            showLabels
            onChange={(_, v) => navigate(navItems[v].to)}
            sx={{
              position: "fixed",
              bottom: 0,
              left: 0,
              right: 0,
              borderTop: 1,
              borderColor: "divider",
              borderRadius: "20px 20px 0 0",
              bgcolor: (t) =>
                t.palette.mode === "dark"
                  ? "rgba(30, 41, 59, 0.92)"
                  : "rgba(255, 255, 255, 0.92)",
              backdropFilter: "saturate(180%) blur(16px)",
              boxShadow: "0 -8px 32px rgba(15, 23, 42, 0.08)",
              zIndex: (t) => t.zIndex.appBar,
              py: 0.5,
              "& .MuiBottomNavigationAction-root": {
                minWidth: 0,
                px: 0.5,
              },
              "& .MuiBottomNavigationAction-label": {
                fontSize: 10,
              },
              "& .Mui-selected": {
                color: "primary.main",
                "& .MuiBottomNavigationAction-label": { fontWeight: 700 },
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

        {isMainTab && !isChatPage && (
          <Fab
            color="primary"
            aria-label="add"
            onClick={() => navigate("/app/transactions/add")}
            sx={{
              position: "fixed",
              right: 24,
              bottom: !isDesktop ? 88 : 24,
              zIndex: (t) => t.zIndex.fab,
              boxShadow: "0 8px 28px rgba(2, 136, 209, 0.38)",
            }}
          >
            <AddRounded />
          </Fab>
        )}
      </Box>
    </Box>
  );
}
