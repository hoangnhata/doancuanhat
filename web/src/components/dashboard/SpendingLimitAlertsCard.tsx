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
import {
  ExpandMoreRounded,
  SpeedOutlined,
  WarningAmberRounded,
} from '@mui/icons-material';
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { CategoryIconBadge } from '@/lib/categoryIcons';
import { formatMoneyFull } from '@/lib/format';
import * as spendingLimitService from '@/services/spendingLimitService';
import { palette } from '@/theme';

const STATUS_COLOR = {
  SAFE: palette.primary.main,
  WARNING: '#F57C00',
  EXCEEDED: palette.error.main,
} as const;

export function SpendingLimitAlertsCard() {
  const navigate = useNavigate();
  const [expanded, setExpanded] = useState(false);

  const { data: limits = [], isLoading: loadingLimits } = useQuery({
    queryKey: ['spending-limits'],
    queryFn: spendingLimitService.fetchSpendingLimits,
  });
  const { data: alerts = [], isLoading: loadingAlerts } = useQuery({
    queryKey: ['spending-limit-alerts'],
    queryFn: spendingLimitService.fetchSpendingLimitAlerts,
  });

  if (loadingLimits || loadingAlerts) return null;

  const hasAlerts = alerts.length > 0;
  const preview = limits.slice(0, 3);
  const showExpandToggle = preview.length > 0;

  return (
    <Card
      elevation={0}
      sx={{
        mb: 2,
        borderRadius: 3,
        border: '1px solid',
        borderColor: hasAlerts ? '#FFB74D66' : 'divider',
        boxShadow: hasAlerts
          ? '0 8px 28px rgba(245, 124, 0, 0.12)'
          : '0 4px 20px rgba(2, 136, 209, 0.08)',
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
                bgcolor: hasAlerts ? '#FFF3E0' : `${palette.primary.main}14`,
                color: hasAlerts ? '#F57C00' : palette.primary.main,
                flexShrink: 0,
              }}
            >
              {hasAlerts ? <WarningAmberRounded /> : <SpeedOutlined />}
            </Box>
            <Box flex={1} minWidth={0}>
              <Typography fontWeight={800}>
                {hasAlerts ? `${alerts.length} cảnh báo hạn mức` : 'Hạn mức chi tiêu'}
              </Typography>
              <Typography variant="body2" color="text.secondary" noWrap>
                {limits.length === 0
                  ? 'Nhấn để tạo hạn mức theo danh mục'
                  : hasAlerts
                    ? expanded
                      ? 'Một số danh mục sắp hoặc đã vượt hạn mức'
                      : 'Nhấn để xem chi tiết cảnh báo'
                    : expanded
                      ? `${limits.length} hạn mức đang theo dõi`
                      : `${limits.length} hạn mức · Nhấn để xem chi tiết`}
              </Typography>
            </Box>
            {showExpandToggle && (
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
                  bgcolor: `${palette.primary.main}0A`,
                }}
              >
                <ExpandMoreRounded />
              </IconButton>
            )}
          </Stack>

          {hasAlerts && !expanded && preview.length > 0 && (
            <Stack direction="row" spacing={0.75} mt={1.5} flexWrap="wrap" useFlexGap>
              {alerts.slice(0, 3).map((a, i) => {
                const limit = limits.find((l) => l.id === a.limitId);
                const name = limit?.category?.name ?? 'Danh mục';
                return (
                  <Box
                    key={a.limitId}
                    sx={{
                      px: 1.25,
                      py: 0.5,
                      borderRadius: 99,
                      bgcolor: '#FFF3E0',
                      color: '#E65100',
                      fontSize: 12,
                      fontWeight: 700,
                      display: 'flex',
                      alignItems: 'center',
                      gap: 0.5,
                    }}
                  >
                    <CategoryIconBadge
                      name={name}
                      icon={limit?.category?.icon}
                      colorIndex={i}
                      size={20}
                    />
                    {name}
                  </Box>
                );
              })}
            </Stack>
          )}
        </Box>

        <Collapse in={expanded} timeout="auto" unmountOnExit>
          <Box sx={{ px: 2.5, pb: 2.5, pt: 0 }}>
            {preview.length > 0 && (
              <Stack spacing={1.5}>
                {preview.map((l, i) => {
                  const color = STATUS_COLOR[l.status];
                  const name = l.category?.name ?? 'Danh mục';
                  return (
                    <Box key={l.id}>
                      <Stack direction="row" spacing={1.25} alignItems="center" mb={0.75}>
                        <CategoryIconBadge name={name} icon={l.category?.icon} colorIndex={i} size={32} />
                        <Typography variant="body2" fontWeight={700} flex={1} noWrap>
                          {name}
                        </Typography>
                        <Typography variant="body2" fontWeight={800} sx={{ color }}>
                          {l.usagePercent.toFixed(0)}%
                        </Typography>
                      </Stack>
                      <LinearProgress
                        variant="determinate"
                        value={Math.min(100, l.usagePercent)}
                        sx={{
                          height: 6,
                          borderRadius: 999,
                          bgcolor: `${color}18`,
                          '& .MuiLinearProgress-bar': { bgcolor: color, borderRadius: 999 },
                        }}
                      />
                      <Typography variant="caption" color="text.secondary" display="block" mt={0.25}>
                        {formatMoneyFull(l.currentSpent)} / {formatMoneyFull(l.limitAmount)}
                      </Typography>
                    </Box>
                  );
                })}
              </Stack>
            )}

            <Stack direction="row" spacing={1} mt={2}>
              <Button size="small" variant="contained" onClick={() => navigate('/app/budget')}>
                {limits.length === 0 ? 'Tạo hạn mức' : 'Quản lý hạn mức'}
              </Button>
              {hasAlerts && (
                <Button size="small" variant="outlined" onClick={() => navigate('/app/budget')}>
                  Điều chỉnh
                </Button>
              )}
            </Stack>
          </Box>
        </Collapse>

        {!showExpandToggle && limits.length === 0 && (
          <Box sx={{ px: 2.5, pb: 2.5 }}>
            <Button size="small" variant="contained" onClick={() => navigate('/app/budget')}>
              Tạo hạn mức
            </Button>
          </Box>
        )}
      </CardContent>
    </Card>
  );
}
