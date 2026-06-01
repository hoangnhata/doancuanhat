import {
  Box,
  Button,
  Card,
  CardContent,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Divider,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { useEffect, useState } from 'react';
import { useAuth } from '@/contexts/AuthContext';
import { GradientBackground } from '@/components/common/GradientBackground';
import { NattaAvatar } from '@/components/robot';
import * as userService from '@/services/userService';
import { extractApiError } from '@/lib/api';
import { palette } from '@/theme';

export function ProfilePage() {
  const { user, refreshUser } = useAuth();

  const [fullName, setFullName] = useState(user?.fullName ?? '');
  const [phone, setPhone] = useState(user?.phone ?? '');
  const [goal, setGoal] = useState(
    user?.savingsGoalMonthly != null ? String(user?.savingsGoalMonthly) : '',
  );
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const personality = user?.botPersonality?.toUpperCase() ?? 'HAPPY';
  const personalityColor =
    personality === 'SAD' ? '#E64A19' : personality === 'ANGRY' ? '#E64A19' : '#0288D1';
  const personalityDesc =
    personality === 'SAD'
      ? 'Nhẹ nhàng, phân tích và đưa ra lời khuyên tài chính hợp lý.'
      : personality === 'ANGRY'
        ? 'Mạnh mẽ, nhắc nhở để bạn kiểm soát chi tiêu tốt hơn.'
        : 'Tràn đầy năng lượng, đồng hành cùng bạn trong hành trình tài chính.';

  const [selectedPersonality, setSelectedPersonality] = useState<'HAPPY' | 'SAD' | 'ANGRY'>(
    (personality as 'HAPPY' | 'SAD' | 'ANGRY') ?? 'HAPPY',
  );

  const [pwdOpen, setPwdOpen] = useState(false);
  const [currentPwd, setCurrentPwd] = useState('');
  const [newPwd, setNewPwd] = useState('');
  const [confirmPwd, setConfirmPwd] = useState('');
  const [pwdErr, setPwdErr] = useState<string | null>(null);
  const [pwdSaving, setPwdSaving] = useState(false);

  useEffect(() => {
    setFullName(user?.fullName ?? '');
    setPhone(user?.phone ?? '');
    setGoal(user?.savingsGoalMonthly != null ? String(user.savingsGoalMonthly) : '');
    setSelectedPersonality(
      (user?.botPersonality?.toUpperCase() as 'HAPPY' | 'SAD' | 'ANGRY') ?? 'HAPPY',
    );
  }, [user]);

  async function save() {
    if (!user) return;
    setSaving(true);
    setError(null);
    try {
      const n = goal.trim().length ? Number(goal) : null;
      const safeGoal = n != null && Number.isFinite(n) ? n : null;
      await userService.patchProfile({
        fullName: fullName.trim(),
        phone: phone.trim().length ? phone.trim() : null,
        savingsGoalMonthly: safeGoal,
      });
      await refreshUser();
    } catch (e) {
      setError(extractApiError(e));
    } finally {
      setSaving(false);
    }
  }

  async function savePersonality() {
    if (!user) return;
    setError(null);
    setSaving(true);
    try {
      await userService.patchProfile({
        botPersonality: selectedPersonality,
      });
      await refreshUser();
    } catch (e) {
      setError(extractApiError(e));
    } finally {
      setSaving(false);
    }
  }

  async function submitPassword() {
    if (newPwd.trim().length < 6) {
      setPwdErr('Mật khẩu mới phải có ít nhất 6 ký tự');
      return;
    }
    if (newPwd.trim() !== confirmPwd.trim()) {
      setPwdErr('Xác nhận mật khẩu không khớp');
      return;
    }
    if (!currentPwd.trim()) {
      setPwdErr('Vui lòng nhập mật khẩu hiện tại');
      return;
    }

    setPwdSaving(true);
    setPwdErr(null);
    try {
      await userService.changePassword(currentPwd.trim(), newPwd.trim());
      setPwdOpen(false);
      setCurrentPwd('');
      setNewPwd('');
      setConfirmPwd('');
    } catch (e) {
      setPwdErr(extractApiError(e));
    } finally {
      setPwdSaving(false);
    }
  }

  if (!user) {
    return (
      <GradientBackground>
        <Box sx={{ maxWidth: 720, mx: 'auto', px: 3, py: 6 }}>
          <Typography>Đang tải…</Typography>
        </Box>
      </GradientBackground>
    );
  }

  return (
    <GradientBackground>
      <Box
        sx={{
          width: '100%',
          maxWidth: 720,
          mx: 'auto',
          px: { xs: 2, sm: 3 },
          py: { xs: 3, md: 4 },
          pb: 10,
        }}
      >
        <Box
          sx={{
            mb: 2,
            borderRadius: 4,
            p: 2,
            bgcolor: `${personalityColor}12`,
            border: `1px solid ${personalityColor}22`,
          }}
        >
          <Stack direction="row" alignItems="center" spacing={2}>
            <Box
              sx={{
                p: 1,
                borderRadius: 3,
                bgcolor: 'background.paper',
                boxShadow: 1,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                border: `1px solid ${personalityColor}22`,
              }}
            >
              <NattaAvatar size={72} animated={false} />
            </Box>

            <Box sx={{ flex: 1, minWidth: 0 }}>
              <Stack direction="row" alignItems="center" spacing={1} sx={{ flexWrap: 'wrap' }}>
                <Typography variant="h5" fontWeight={900}>
                  Trang cá nhân
                </Typography>
                <Box
                  sx={{
                    ml: 1,
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
                  Trợ lý: {personality}
                </Box>
              </Stack>

              <Typography variant="body2" color="text.secondary" noWrap>
                {user.fullName} • {user.email}
              </Typography>

              <Typography variant="body2" sx={{ mt: 1, color: 'text.secondary' }}>
                {personalityDesc}
              </Typography>
            </Box>
          </Stack>
        </Box>

        <Card elevation={2} sx={{ mt: 2 }}>
          <CardContent>
            <Stack spacing={2}>
              <Typography fontWeight={800}>Thông tin</Typography>
              <Stack spacing={0.5}>
                <Typography fontWeight={700}>Họ tên</Typography>
                <TextField value={fullName} onChange={(e) => setFullName(e.target.value)} fullWidth />
              </Stack>

              <Stack spacing={0.5}>
                <Typography fontWeight={700}>Số điện thoại</Typography>
                <TextField value={phone ?? ''} onChange={(e) => setPhone(e.target.value)} fullWidth />
              </Stack>

              <Stack spacing={0.5}>
                <Typography fontWeight={700}>Mục tiêu tiết kiệm/tháng</Typography>
                <TextField
                  value={goal}
                  onChange={(e) => setGoal(e.target.value)}
                  fullWidth
                  placeholder="Ví dụ: 5000000"
                  inputMode="numeric"
                />
              </Stack>

              <Divider />

              {error && (
                <Typography color="error" variant="body2">
                  {error}
                </Typography>
              )}

              <Button
                variant="contained"
                onClick={save}
                disabled={saving}
                sx={{
                  borderRadius: 3,
                  py: 1.3,
                  bgcolor: palette.primary.main,
                  '&:hover': { opacity: 0.92 },
                }}
              >
                {saving ? 'Đang lưu…' : 'Lưu thay đổi'}
              </Button>

              <Typography variant="caption" color="text.secondary">
                Ví/currency và danh mục vẫn quản lý trong phần tương ứng.
              </Typography>
            </Stack>
          </CardContent>
        </Card>

        <Card elevation={2} sx={{ mt: 2 }}>
          <CardContent>
            <Stack spacing={2}>
              <Typography fontWeight={800}>Trợ lý Natta</Typography>
              <Typography variant="body2" color="text.secondary">
                Thay đổi tính cách trợ lý AI để gợi ý phù hợp hơn với bạn.
              </Typography>
              <TextField
                select
                fullWidth
                label="Personality"
                value={selectedPersonality}
                onChange={(e) =>
                  setSelectedPersonality(e.target.value as 'HAPPY' | 'SAD' | 'ANGRY')
                }
                margin="normal"
                SelectProps={{ native: true }}
              >
                <option value="HAPPY">Vui vẻ (HAPPY)</option>
                <option value="SAD">Buồn (SAD)</option>
                <option value="ANGRY">Nóng tính (ANGRY)</option>
              </TextField>
              <Button
                variant="contained"
                onClick={savePersonality}
                disabled={saving}
                sx={{
                  borderRadius: 3,
                  py: 1.2,
                  bgcolor: palette.primary.main,
                  '&:hover': { opacity: 0.92 },
                }}
              >
                {saving ? 'Đang lưu…' : 'Lưu personality'}
              </Button>
              {error && (
                <Typography color="error" variant="body2">
                  {error}
                </Typography>
              )}
            </Stack>
          </CardContent>
        </Card>

        <Card elevation={2} sx={{ mt: 2 }}>
          <CardContent>
            <Stack spacing={2}>
              <Typography fontWeight={800}>Bảo mật</Typography>
              <Typography variant="body2" color="text.secondary">
                Đổi mật khẩu tài khoản của bạn.
              </Typography>
              <Button
                variant="outlined"
                onClick={() => {
                  setPwdErr(null);
                  setPwdOpen(true);
                }}
                sx={{ borderRadius: 3, py: 1.2, borderColor: palette.primary.main }}
              >
                Đổi mật khẩu
              </Button>
            </Stack>
          </CardContent>
        </Card>

        <PasswordDialog
          open={pwdOpen}
          onClose={() => setPwdOpen(false)}
          currentPwd={currentPwd}
          setCurrentPwd={setCurrentPwd}
          newPwd={newPwd}
          setNewPwd={setNewPwd}
          confirmPwd={confirmPwd}
          setConfirmPwd={setConfirmPwd}
          error={pwdErr}
          saving={pwdSaving}
          onSubmit={submitPassword}
        />
      </Box>
    </GradientBackground>
  );
}

// Password dialog is kept in same file to avoid routing
function PasswordDialog({
  open,
  onClose,
  currentPwd,
  setCurrentPwd,
  newPwd,
  setNewPwd,
  confirmPwd,
  setConfirmPwd,
  error,
  saving,
  onSubmit,
}: {
  open: boolean;
  onClose: () => void;
  currentPwd: string;
  setCurrentPwd: (v: string) => void;
  newPwd: string;
  setNewPwd: (v: string) => void;
  confirmPwd: string;
  setConfirmPwd: (v: string) => void;
  error: string | null;
  saving: boolean;
  onSubmit: () => void;
}) {
  return (
    <Dialog open={open} onClose={onClose} fullWidth>
      <DialogTitle>Đổi mật khẩu</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ mt: 1 }}>
          <TextField
            fullWidth
            type="password"
            label="Mật khẩu hiện tại"
            value={currentPwd}
            onChange={(e) => setCurrentPwd(e.target.value)}
          />
          <TextField
            fullWidth
            type="password"
            label="Mật khẩu mới"
            value={newPwd}
            onChange={(e) => setNewPwd(e.target.value)}
          />
          <TextField
            fullWidth
            type="password"
            label="Xác nhận mật khẩu mới"
            value={confirmPwd}
            onChange={(e) => setConfirmPwd(e.target.value)}
          />
          {error && (
            <Typography color="error" variant="body2">
              {error}
            </Typography>
          )}
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Hủy</Button>
        <Button variant="contained" onClick={onSubmit} disabled={saving}>
          {saving ? 'Đang đổi…' : 'Đổi mật khẩu'}
        </Button>
      </DialogActions>
    </Dialog>
  );
}

