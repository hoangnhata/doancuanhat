import {
  Accordion,
  AccordionDetails,
  AccordionSummary,
  Box,
  Button,
  Card,
  CardActionArea,
  CardContent,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Stack,
  Switch,
  TextField,
  ToggleButton,
  ToggleButtonGroup,
  Typography,
} from '@mui/material';
import {
  AccountBalanceWalletRounded,
  CategoryRounded,
  PersonRounded,
  DarkModeRounded,
  LightModeRounded,
  SettingsBrightnessRounded,
  LockRounded,
  LogoutRounded,
  NotificationsRounded,
  RepeatRounded,
  SmartToyRounded,
  ExpandMoreRounded,
} from '@mui/icons-material';
import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { GradientBackground } from '@/components/common/GradientBackground';
import { NattaAvatar } from '@/components/robot';
import { useAuth } from '@/contexts/AuthContext';
import { useThemeMode } from '@/contexts/ThemeModeContext';
import { extractApiError } from '@/lib/api';
import * as userService from '@/services/userService';
import { palette } from '@/theme';

export function SettingsPage() {
  const navigate = useNavigate();
  const { user, logout, refreshUser } = useAuth();
  const { mode, setMode } = useThemeMode();
  const [pwdOpen, setPwdOpen] = useState(false);
  const [botOpen, setBotOpen] = useState(false);
  const [currentPwd, setCurrentPwd] = useState('');
  const [newPwd, setNewPwd] = useState('');
  const [pwdErr, setPwdErr] = useState<string | null>(null);
  const [personality, setPersonality] = useState<'HAPPY' | 'SAD' | 'ANGRY'>(
    'HAPPY',
  );
  const [reminder, setReminder] = useState(false);

  const currentPersonality = user?.botPersonality?.toUpperCase() ?? 'HAPPY';
  const personalityLabel =
    currentPersonality === 'SAD'
      ? 'SAD'
      : currentPersonality === 'ANGRY'
        ? 'ANGRY'
        : 'HAPPY';
  const personalityColor = personalityLabel === 'HAPPY' ? '#0288D1' : '#E64A19';
  const personalityDesc =
    personalityLabel === 'SAD'
      ? 'Nhẹ nhàng, phân tích và đưa ra lời khuyên hợp lý.'
      : personalityLabel === 'ANGRY'
        ? 'Mạnh mẽ, nhắc nhở để bạn kiểm soát chi tiêu tốt hơn.'
        : 'Tràn đầy năng lượng, đồng hành cùng bạn trong hành trình tài chính.';

  async function savePassword() {
    setPwdErr(null);
    try {
      await userService.changePassword(currentPwd, newPwd);
      setPwdOpen(false);
      setCurrentPwd('');
      setNewPwd('');
    } catch (e) {
      setPwdErr(extractApiError(e));
    }
  }

  async function savePersonality() {
    if (!personality) return;
    await userService.patchProfile({ botPersonality: personality });
    await refreshUser();
    setBotOpen(false);
  }

  return (
    <GradientBackground>
      <Box
        sx={{
          width: '100%',
          maxWidth: { xs: '100%', sm: 800, md: 1000, lg: 1280, xl: 1440 },
          mx: 'auto',
          px: { xs: 2, sm: 3, md: 4, lg: 5 },
          py: { xs: 2, md: 3 },
          pb: 10,
        }}
      >
        <Stack direction="row" alignItems="center" spacing={2} sx={{ mb: 1 }}>
          <Box
            sx={{
              p: 1,
              borderRadius: 2,
              bgcolor: 'background.paper',
              boxShadow: 1,
            }}
          >
            <NattaAvatar size={56} animated={false} />
          </Box>
          <Box sx={{ flex: 1, minWidth: 0 }}>
            <Typography variant="h5" fontWeight={900}>
              Cài đặt
            </Typography>
            <Typography variant="body2" color="text.secondary" noWrap>
              {user?.fullName ?? user?.email}
            </Typography>
            <Box sx={{ mt: 1, display: 'flex', gap: 1, flexWrap: 'wrap' }}>
              <Box
                sx={{
                  px: 1.1,
                  py: 0.55,
                  borderRadius: 999,
                  bgcolor: `${personalityColor}22`,
                  color: personalityColor,
                  border: `1px solid ${personalityColor}33`,
                  fontWeight: 800,
                  fontSize: 13,
                  whiteSpace: 'nowrap',
                }}
              >
                Trợ lý: {personalityLabel}
              </Box>
            </Box>
            <Typography variant="body2" color="text.secondary" sx={{ mt: 0.75 }}>
              {personalityDesc}
            </Typography>
          </Box>
        </Stack>

        <Stack spacing={1.5} mt={2}>
          <SettingsAccordion
            title="Trợ lý Natta"
            icon={<SmartToyRounded color="primary" />}
          >
            <SettingsCard
              icon={<SmartToyRounded />}
              title="Đổi nhân vật Natta"
              subtitle="Thay đổi tính cách trợ lý AI"
              onClick={() => {
                const p = user?.botPersonality?.toUpperCase();
                if (p === 'SAD' || p === 'ANGRY' || p === 'HAPPY') {
                  setPersonality(p);
                } else {
                  setPersonality('HAPPY');
                }
                setBotOpen(true);
              }}
            />
          </SettingsAccordion>

          <SettingsAccordion title="Tài khoản" icon={<PersonRounded color="primary" />}>
            <SettingsCard
              icon={<PersonRounded />}
              title="Thông tin cá nhân"
              subtitle="Quản lý họ tên, SĐT và mục tiêu tiết kiệm"
              onClick={() => navigate('/app/profile')}
            />
          </SettingsAccordion>

          <SettingsAccordion
            title="Tài chính"
            icon={<AccountBalanceWalletRounded color="primary" />}
          >
            <SettingsCard
              icon={<AccountBalanceWalletRounded />}
              title="Ngân sách"
              subtitle="Quản lý ngân sách theo danh mục"
              onClick={() => navigate('/app/budget')}
            />
            <SettingsCard
              icon={<CategoryRounded />}
              title="Danh mục"
              subtitle="Quản lý danh mục chi tiêu"
              onClick={() => navigate('/app/categories')}
            />
            <SettingsCard
              icon={<AccountBalanceWalletRounded />}
              title="Quản lý ví"
              subtitle="Thêm, sửa, xóa ví"
              onClick={() => navigate('/app/wallets')}
            />
            <SettingsCard
              icon={<RepeatRounded />}
              title="Giao dịch định kỳ"
              subtitle="Tạo giao dịch lặp mỗi tháng"
              onClick={() => navigate('/app/recurring')}
            />
          </SettingsAccordion>

          <SettingsAccordion title="Giao diện & nhắc nhở" icon={<DarkModeRounded color="primary" />}>
            <Card elevation={2}>
              <CardContent>
                <Stack direction="row" alignItems="center" spacing={2} sx={{ mb: 2 }}>
                  <Box
                    sx={{
                      p: 1.5,
                      borderRadius: 2,
                      bgcolor: `${palette.primary.main}22`,
                      color: 'primary.main',
                      display: 'flex',
                    }}
                  >
                    <DarkModeRounded />
                  </Box>
                  <Box flex={1}>
                    <Typography fontWeight={700}>Chế độ màu</Typography>
                    <Typography variant="body2" color="text.secondary">
                      Sáng / Tối / Theo hệ thống
                    </Typography>
                  </Box>
                </Stack>
                <ToggleButtonGroup
                  value={mode}
                  exclusive
                  onChange={(_, v) => {
                    if (v) setMode(v);
                  }}
                  size="small"
                  fullWidth
                  color="primary"
                >
                  <ToggleButton value="light">
                    <LightModeRounded sx={{ mr: 1, fontSize: 18 }} /> Sáng
                  </ToggleButton>
                  <ToggleButton value="dark">
                    <DarkModeRounded sx={{ mr: 1, fontSize: 18 }} /> Tối
                  </ToggleButton>
                  <ToggleButton value="system">
                    <SettingsBrightnessRounded sx={{ mr: 1, fontSize: 18 }} /> Hệ thống
                  </ToggleButton>
                </ToggleButtonGroup>
              </CardContent>
            </Card>

            <Card elevation={2}>
              <CardContent>
                <Stack direction="row" alignItems="center" spacing={2}>
                  <Box
                    sx={{
                      p: 1.5,
                      borderRadius: 2,
                      bgcolor: `${palette.primary.main}22`,
                      color: 'primary.main',
                      display: 'flex',
                    }}
                  >
                    <NotificationsRounded />
                  </Box>
                  <Box flex={1}>
                    <Typography fontWeight={700}>Nhắc ghi chép chi tiêu</Typography>
                    <Typography variant="body2" color="text.secondary">
                      (Web) lưu tùy chọn cục bộ — tích hợp thông báo trình duyệt sau
                    </Typography>
                  </Box>
                  <Switch
                    checked={reminder}
                    onChange={(_, v) => setReminder(v)}
                    color="primary"
                  />
                </Stack>
              </CardContent>
            </Card>
          </SettingsAccordion>

          <SettingsAccordion title="Bảo mật" icon={<LockRounded color="primary" />}>
            <SettingsCard
              icon={<LockRounded />}
              title="Đổi mật khẩu"
              subtitle="Thay đổi mật khẩu tài khoản"
              onClick={() => setPwdOpen(true)}
            />
          </SettingsAccordion>

          <SettingsAccordion title="Khác" icon={<LogoutRounded color="error" />}>
            <Card elevation={2}>
              <CardActionArea onClick={() => logout()}>
                <CardContent>
                  <Stack direction="row" alignItems="center" spacing={2}>
                    <Box sx={{ color: 'error.main', display: 'flex' }}>
                      <LogoutRounded />
                    </Box>
                    <Box>
                      <Typography fontWeight={700} color="error">
                        Đăng xuất
                      </Typography>
                      <Typography variant="body2" color="text.secondary">
                        Đăng xuất khỏi tài khoản
                      </Typography>
                    </Box>
                  </Stack>
                </CardContent>
              </CardActionArea>
            </Card>
          </SettingsAccordion>
        </Stack>
      </Box>

      <Dialog open={pwdOpen} onClose={() => setPwdOpen(false)} fullWidth>
        <DialogTitle>Đổi mật khẩu</DialogTitle>
        <DialogContent>
          <TextField
            fullWidth
            type="password"
            label="Mật khẩu hiện tại"
            value={currentPwd}
            onChange={(e) => setCurrentPwd(e.target.value)}
            margin="normal"
          />
          <TextField
            fullWidth
            type="password"
            label="Mật khẩu mới"
            value={newPwd}
            onChange={(e) => setNewPwd(e.target.value)}
            margin="normal"
          />
          {pwdErr && (
            <Typography color="error" variant="body2">
              {pwdErr}
            </Typography>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setPwdOpen(false)}>Hủy</Button>
          <Button variant="contained" onClick={savePassword}>
            Lưu
          </Button>
        </DialogActions>
      </Dialog>

      <Dialog open={botOpen} onClose={() => setBotOpen(false)} fullWidth>
        <DialogTitle>Tính cách Natta</DialogTitle>
        <DialogContent>
          <TextField
            select
            fullWidth
            label="Personality"
            value={personality}
            onChange={(e) =>
              setPersonality(e.target.value as 'HAPPY' | 'SAD' | 'ANGRY')
            }
            margin="normal"
            SelectProps={{ native: true }}
          >
            <option value="HAPPY">Vui vẻ (HAPPY)</option>
            <option value="SAD">Buồn (SAD)</option>
            <option value="ANGRY">Nóng tính (ANGRY)</option>
          </TextField>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setBotOpen(false)}>Hủy</Button>
          <Button variant="contained" onClick={savePersonality}>
            Lưu
          </Button>
        </DialogActions>
      </Dialog>
    </GradientBackground>
  );
}

function SettingsAccordion({
  title,
  icon,
  defaultExpanded,
  children,
}: {
  title: string;
  icon: React.ReactNode;
  defaultExpanded?: boolean;
  children: React.ReactNode;
}) {
  return (
    <Accordion
      defaultExpanded={defaultExpanded}
      elevation={0}
      disableGutters
      sx={{
        bgcolor: 'transparent',
        '&:before': { display: 'none' },
        '&.MuiPaper-root': { bgcolor: 'transparent' },
      }}
    >
      <AccordionSummary
        expandIcon={<ExpandMoreRounded />}
        sx={{
          px: 0,
          minHeight: 62,
          py: 0.5,
          bgcolor: 'transparent',
          '&.Mui-expanded': { bgcolor: 'transparent' },
          '& .MuiAccordionSummary-content': { my: 0 },
        }}
      >
        <Stack direction="row" spacing={1.5} alignItems="center">
          <Box
            sx={{
              color: 'primary.main',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              width: 44,
              height: 44,
              borderRadius: 2.5,
              bgcolor: `${palette.primary.main}12`,
              border: `1px solid ${palette.primary.main}22`,
            }}
          >
            {icon}
          </Box>
          <Typography fontWeight={900} sx={{ fontSize: 16 }}>
            {title}
          </Typography>
        </Stack>
      </AccordionSummary>
      <AccordionDetails sx={{ px: 0, pt: 0.5, pb: 2 }}>
        <Stack spacing={1.5} sx={{ px: 0 }}>
          {children}
        </Stack>
      </AccordionDetails>
    </Accordion>
  );
}

function SettingsCard({
  icon,
  title,
  subtitle,
  onClick,
}: {
  icon: React.ReactNode;
  title: string;
  subtitle: string;
  onClick: () => void;
}) {
  return (
    <Card elevation={2} sx={{ borderRadius: 3, minHeight: 86 }}>
      <CardActionArea onClick={onClick}>
        <CardContent sx={{ py: 2, '&:last-child': { pb: 2 } }}>
          <Stack direction="row" alignItems="center" spacing={2}>
            <Box
              sx={{
                p: 2,
                borderRadius: 3,
                bgcolor: `${palette.primary.main}22`,
                color: 'primary.main',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              {icon}
            </Box>
            <Box flex={1}>
              <Typography fontWeight={800} sx={{ fontSize: 15 }}>
                {title}
              </Typography>
              <Typography variant="body2" color="text.secondary" sx={{ mt: 0.25 }}>
                {subtitle}
              </Typography>
            </Box>
            <Typography color="text.secondary">›</Typography>
          </Stack>
        </CardContent>
      </CardActionArea>
    </Card>
  );
}
