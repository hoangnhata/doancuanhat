import {
  Box,
  Button,
  Card,
  CardContent,
  Collapse,
  IconButton,
  LinearProgress,
  Stack,
  Typography,
} from '@mui/material';
import { ExpandMoreRounded, SavingsRounded, TrendingUpRounded } from '@mui/icons-material';
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { formatMoneyFull } from '@/lib/format';
import * as savingGoalService from '@/services/savingGoalService';
import { palette } from '@/theme';

export function SavingGoalsHomeSection() {
  const navigate = useNavigate();
  const [expanded, setExpanded] = useState(false);

  const { data: goals = [], isLoading } = useQuery({
    queryKey: ['saving-goals'],
    queryFn: savingGoalService.fetchSavingGoals,
  });

  if (isLoading) return null;

  const active = goals.filter((g) => g.status === 'ACTIVE' || g.status === 'COMPLETED');
  const preview = active.slice(0, 3);
  const completedCount = goals.filter((g) => g.isCompleted).length;
  const totalSaved = goals.reduce((sum, g) => sum + g.currentAmount, 0);
  const showExpandToggle = preview.length > 0;

  return (
    <Card
      elevation={0}
      sx={{
        mb: 2,
        borderRadius: 3,
        border: '1px solid',
        borderColor: 'divider',
        boxShadow: '0 4px 20px rgba(46, 125, 50, 0.08)',
        overflow: 'hidden',
      }}
    >
      <CardContent sx={{ p: 0, '&:last-child': { pb: 0 } }}>
        <Box
          onClick={() => showExpandToggle && setExpanded((v) => !v)}
          sx={{
            p: 2.5,
            cursor: showExpandToggle ? 'pointer' : 'default',
            transition: 'background 0.15s ease',
            '&:hover': showExpandToggle ? { bgcolor: 'action.hover' } : undefined,
          }}
        >
          <Stack direction="row" spacing={1.5} alignItems="center">
            <Box
              sx={{
                width: 44,
                height: 44,
                borderRadius: 2,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                bgcolor: '#E8F5E914',
                color: '#2E7D32',
                flexShrink: 0,
              }}
            >
              <SavingsRounded />
            </Box>
            <Box flex={1} minWidth={0}>
              <Typography fontWeight={800}>
                {goals.length === 0
                  ? 'Mục tiêu tiết kiệm'
                  : `${goals.length} mục tiêu · ${formatMoneyFull(totalSaved)} đã tiết kiệm`}
              </Typography>
              <Typography variant="body2" color="text.secondary" noWrap>
                {goals.length === 0
                  ? 'Tạo ví tiết kiệm nội bộ cho kế hoạch lớn'
                  : expanded
                    ? completedCount > 0
                      ? `${completedCount} mục tiêu đã hoàn thành`
                      : 'Theo dõi tiến độ nạp/rút từng mục tiêu'
                    : 'Nhấn để xem chi tiết mục tiêu'}
              </Typography>
            </Box>
            {showExpandToggle ? (
              <IconButton
                size="small"
                aria-label={expanded ? 'Thu gọn' : 'Mở rộng'}
                onClick={(e) => {
                  e.stopPropagation();
                  setExpanded((v) => !v);
                }}
                sx={{
                  transform: expanded ? 'rotate(180deg)' : 'rotate(0deg)',
                  transition: 'transform 0.25s ease',
                  bgcolor: '#2E7D320A',
                }}
              >
                <ExpandMoreRounded />
              </IconButton>
            ) : null}
          </Stack>
        </Box>

        <Collapse in={expanded} timeout="auto" unmountOnExit>
          <Box sx={{ px: 2.5, pb: 2.5, pt: 0 }}>
            {preview.length > 0 && (
              <Stack spacing={1.5}>
                {preview.map((g) => {
                  const color = g.isCompleted ? '#2E7D32' : palette.primary.main;
                  return (
                    <Box key={g.id}>
                      <Stack direction="row" spacing={1.25} alignItems="center" mb={0.75}>
                        <Box
                          sx={{
                            width: 32,
                            height: 32,
                            borderRadius: 1.5,
                            display: 'grid',
                            placeItems: 'center',
                            bgcolor: `${color}14`,
                            color,
                          }}
                        >
                          {g.isCompleted ? (
                            <TrendingUpRounded sx={{ fontSize: 18 }} />
                          ) : (
                            <SavingsRounded sx={{ fontSize: 18 }} />
                          )}
                        </Box>
                        <Typography variant="body2" fontWeight={700} flex={1} noWrap>
                          {g.name}
                        </Typography>
                        <Typography variant="body2" fontWeight={800} sx={{ color }}>
                          {g.progressPercent.toFixed(0)}%
                        </Typography>
                      </Stack>
                      <LinearProgress
                        variant="determinate"
                        value={Math.min(100, g.progressPercent)}
                        sx={{
                          height: 6,
                          borderRadius: 999,
                          bgcolor: `${color}18`,
                          '& .MuiLinearProgress-bar': { bgcolor: color, borderRadius: 999 },
                        }}
                      />
                      <Typography variant="caption" color="text.secondary" display="block" mt={0.25}>
                        {formatMoneyFull(g.currentAmount)} / {formatMoneyFull(g.targetAmount)}
                      </Typography>
                    </Box>
                  );
                })}
              </Stack>
            )}

            <Stack direction="row" spacing={1} mt={2}>
              <Button size="small" variant="contained" onClick={() => navigate('/app/saving-goals')}>
                {goals.length === 0 ? 'Tạo mục tiêu' : 'Quản lý tiết kiệm'}
              </Button>
            </Stack>
          </Box>
        </Collapse>

        {!showExpandToggle && goals.length === 0 && (
          <Box sx={{ px: 2.5, pb: 2.5 }}>
            <Button size="small" variant="contained" onClick={() => navigate('/app/saving-goals')}>
              Tạo mục tiêu
            </Button>
          </Box>
        )}
      </CardContent>
    </Card>
  );
}
