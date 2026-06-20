import { Box, Card, CardActionArea, Chip, Stack, Typography } from '@mui/material';
import {
  ArrowDownwardRounded,
  ArrowUpwardRounded,
  ChevronRightRounded,
} from '@mui/icons-material';
import { formatMoney } from '@/lib/format';
import { chartCategoryColor } from '@/theme';
import { palette } from '@/theme';
import type { Transaction } from '@/types/models';

type Props = {
  t: Transaction;
  onOpen: () => void;
  categoryIndex?: number;
};

export function TransactionListItem({ t, onOpen, categoryIndex = 0 }: Props) {
  const inc = t.type === 'INCOME';
  const accent = inc ? palette.income : palette.expense;
  const catColor = chartCategoryColor(categoryIndex);
  const title = t.description?.trim() || t.category.name;

  return (
    <Card
      elevation={0}
      sx={{
        borderRadius: 3,
        border: `1px solid ${palette.outline}`,
        boxShadow: palette.shadowSoft,
        transition: 'box-shadow 0.2s, transform 0.15s, border-color 0.2s',
        '&:hover': {
          boxShadow: palette.shadowLift,
          transform: 'translateY(-1px)',
          borderColor: `${accent}44`,
        },
      }}
    >
      <CardActionArea onClick={onOpen} sx={{ borderRadius: 3 }}>
        <Box sx={{ display: 'flex', alignItems: 'stretch' }}>
          <Box
            sx={{
              width: 4,
              bgcolor: catColor,
              borderRadius: '12px 0 0 12px',
              flexShrink: 0,
            }}
          />
          <Stack
            direction="row"
            spacing={1.5}
            alignItems="center"
            sx={{ flex: 1, minWidth: 0, px: 2, py: 1.75 }}
          >
            <Box
              sx={{
                width: 46,
                height: 46,
                borderRadius: 2.5,
                bgcolor: `${accent}14`,
                border: `1px solid ${accent}33`,
                display: 'grid',
                placeItems: 'center',
                flexShrink: 0,
              }}
            >
              {inc ? (
                <ArrowDownwardRounded sx={{ color: accent, fontSize: 22 }} />
              ) : (
                <ArrowUpwardRounded sx={{ color: accent, fontSize: 22 }} />
              )}
            </Box>

            <Box flex={1} minWidth={0}>
              <Stack direction="row" alignItems="center" spacing={0.75} mb={0.25}>
                <Typography fontWeight={700} noWrap sx={{ flex: 1 }}>
                  {title}
                </Typography>
                <Chip
                  size="small"
                  label={inc ? 'Thu' : 'Chi'}
                  sx={{
                    height: 22,
                    fontSize: 11,
                    fontWeight: 800,
                    bgcolor: `${accent}18`,
                    color: accent,
                    flexShrink: 0,
                  }}
                />
              </Stack>
              <Typography variant="caption" color="text.secondary" fontWeight={600} noWrap>
                {t.category.name}
              </Typography>
            </Box>

            <Stack direction="row" alignItems="center" spacing={0.5} flexShrink={0}>
              <Typography fontWeight={800} fontSize={15} color={inc ? palette.income : 'error.main'}>
                {inc ? '+' : '−'}
                {formatMoney(t.amount)}
              </Typography>
              <ChevronRightRounded sx={{ color: palette.textMuted, fontSize: 20 }} />
            </Stack>
          </Stack>
        </Box>
      </CardActionArea>
    </Card>
  );
}

export function TransactionDateHeader({
  label,
  count,
  dayTotal,
}: {
  label: string;
  count: number;
  dayTotal: number;
}) {
  return (
    <Stack
      direction="row"
      alignItems="center"
      justifyContent="space-between"
      sx={{ px: 0.5, py: 1.25, mt: 1 }}
    >
      <Box>
        <Typography
          variant="overline"
          sx={{ fontWeight: 800, letterSpacing: '0.08em', color: 'text.secondary', lineHeight: 1.2 }}
        >
          {label}
        </Typography>
        <Typography variant="caption" color="text.secondary" fontWeight={600}>
          {count} giao dịch
        </Typography>
      </Box>
      <Typography variant="caption" fontWeight={800} color="text.secondary">
        {dayTotal >= 0 ? '+' : ''}
        {formatMoney(dayTotal)}
      </Typography>
    </Stack>
  );
}
