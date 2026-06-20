import {
  Box,
  Card,
  CardContent,
  IconButton,
  LinearProgress,
  Stack,
  Typography,
} from "@mui/material";
import {
  AccountBalanceWalletRounded,
  AddRounded,
  EditRounded,
  SavingsRounded,
  TrendingFlatRounded,
} from "@mui/icons-material";
import type { Wallet } from "@/types/models";
import { formatMoney } from "@/lib/format";
import { palette } from "@/theme";

type Props = {
  wallets: Wallet[];
  selectedWalletId: number | null;
  totalSaved: number;
  periodBalance: number;
  periodLabel: string;
  onSelect: (id: number) => void;
  onEdit: (e: React.MouseEvent, walletId: number) => void;
  onAdd: () => void;
};

function walletMainBalance(w: Wallet): number {
  return w.currentBalance ?? w.initialBalance ?? 0;
}

function WalletSplitChip({
  label,
  amount,
  icon,
  accent,
  bg,
  border,
}: {
  label: string;
  amount: number;
  icon: React.ReactNode;
  accent: string;
  bg: string;
  border: string;
}) {
  return (
    <Box
      sx={{
        flex: 1,
        minWidth: 0,
        px: 1.5,
        py: 1.25,
        borderRadius: 2.5,
        bgcolor: bg,
        border: `1px solid ${border}`,
      }}
    >
      <Stack direction="row" alignItems="center" spacing={0.5} mb={0.5}>
        <Box sx={{ color: accent, display: "flex", "& svg": { fontSize: 15 } }}>
          {icon}
        </Box>
        <Typography
          variant="caption"
          color="text.secondary"
          fontWeight={700}
          noWrap
        >
          {label}
        </Typography>
      </Stack>
      <Typography
        variant="body2"
        fontWeight={800}
        sx={{ color: accent }}
        noWrap
      >
        {formatMoney(amount)}
      </Typography>
    </Box>
  );
}

function WalletBalanceBreakdown({
  mainBalance,
  totalSaved,
  periodBalance,
  periodLabel,
  showPeriod,
}: {
  mainBalance: number;
  totalSaved: number;
  periodBalance?: number;
  periodLabel?: string;
  showPeriod?: boolean;
}) {
  const total = mainBalance + totalSaved;
  const savedPct = total > 0 ? Math.min(100, (totalSaved / total) * 100) : 0;

  return (
    <>
      <Typography
        variant="h5"
        fontWeight={800}
        letterSpacing="-0.03em"
        sx={{
          fontSize: { xs: "1.35rem", sm: "1.55rem" },
          lineHeight: 1.15,
          background: `linear-gradient(135deg, ${palette.primary.dark} 0%, ${palette.primary.main} 100%)`,
          WebkitBackgroundClip: "text",
          WebkitTextFillColor: "transparent",
        }}
      >
        {formatMoney(total)}
      </Typography>
      <Typography
        variant="caption"
        color="text.secondary"
        fontWeight={700}
        display="block"
        sx={{
          letterSpacing: "0.06em",
          textTransform: "uppercase",
          fontSize: 10,
          mt: 0.25,
          mb: 1.25,
        }}
      >
        Tổng tài sản
      </Typography>

      {total > 0 && (
        <Box sx={{ mb: 1.25 }}>
          <Stack direction="row" justifyContent="space-between" mb={0.5}>
            <Typography
              variant="caption"
              fontWeight={600}
              color="text.secondary"
              fontSize={10}
            >
              Phân bổ
            </Typography>
            <Typography
              variant="caption"
              fontWeight={700}
              sx={{ color: palette.income, fontSize: 10 }}
            >
              Tiết kiệm {savedPct.toFixed(0)}%
            </Typography>
          </Stack>
          <LinearProgress
            variant="determinate"
            value={savedPct}
            sx={{
              height: 5,
              borderRadius: 99,
              bgcolor: `${palette.primary.main}18`,
              "& .MuiLinearProgress-bar": {
                borderRadius: 99,
                background: `linear-gradient(90deg, ${palette.income}, #66BB6A)`,
              },
            }}
          />
        </Box>
      )}

      <Stack direction="row" spacing={1.25} sx={{ width: "100%" }}>
        <WalletSplitChip
          label="Ví chính"
          amount={mainBalance}
          icon={<AccountBalanceWalletRounded />}
          accent={palette.primary.main}
          bg={`${palette.primary.main}0A`}
          border={`${palette.primary.main}22`}
        />
        <WalletSplitChip
          label="Tiết kiệm"
          amount={totalSaved}
          icon={<SavingsRounded />}
          accent="#2E7D32"
          bg="#E8F5E914"
          border="#A5D6A766"
        />
      </Stack>

      {showPeriod && periodLabel != null && periodBalance != null && (
        <Stack
          direction="row"
          alignItems="center"
          spacing={0.75}
          sx={{
            mt: 1.25,
            pt: 1.25,
            borderTop: `1px dashed ${palette.outline}`,
          }}
        >
          <TrendingFlatRounded
            sx={{ fontSize: 16, color: palette.textMuted }}
          />
          <Typography
            variant="caption"
            color="text.secondary"
            fontWeight={600}
            lineHeight={1.35}
          >
            Chênh lệch · {periodLabel}:{" "}
            <Box
              component="span"
              fontWeight={800}
              color={periodBalance >= 0 ? "primary.main" : "error.main"}
            >
              {formatMoney(periodBalance)}
            </Box>
          </Typography>
        </Stack>
      )}
    </>
  );
}

export function WalletCarousel({
  wallets,
  selectedWalletId,
  totalSaved,
  periodBalance,
  periodLabel,
  onSelect,
  onEdit,
  onAdd,
}: Props) {
  return (
    <Stack
      direction="row"
      spacing={1.5}
      alignItems="stretch"
      sx={{ overflowX: "auto", pb: 1, mx: -0.5, px: 0.5 }}
    >
      {wallets.map((w) => {
        const selected = selectedWalletId === w.id;
        const mainBalance = walletMainBalance(w);
        return (
          <Card
            key={w.id}
            onClick={() => onSelect(w.id)}
            sx={{
              position: "relative",
              overflow: "hidden",
              minWidth: selected ? { xs: 300, sm: 380 } : { xs: 220, sm: 260 },
              flex: selected ? "1 1 380px" : "0 0 auto",
              maxWidth: selected ? { sm: "calc(100% - 148px)" } : undefined,
              cursor: "pointer",
              flexShrink: 0,
              transition:
                "transform 0.22s ease, box-shadow 0.22s ease, border-color 0.22s ease",
              borderRadius: 3,
              border: selected
                ? `2px solid ${palette.primary.main}`
                : `1px solid ${palette.outline}`,
              boxShadow: selected ? palette.shadowLift : palette.shadowSoft,
              background: selected
                ? `linear-gradient(155deg, ${palette.primary.main}16 0%, #FFFFFF 42%, ${palette.surface} 100%)`
                : "#FFFFFF",
              "&:hover": {
                transform: "translateY(-4px)",
                boxShadow: palette.shadowLift,
              },
              "&::before": selected
                ? {
                    content: '""',
                    position: "absolute",
                    top: -28,
                    right: -28,
                    width: 88,
                    height: 88,
                    borderRadius: "50%",
                    bgcolor: `${palette.primary.main}12`,
                    pointerEvents: "none",
                  }
                : undefined,
            }}
          >
            <CardContent
              sx={{
                py: 2.5,
                px: 2.5,
                position: "relative",
                "&:last-child": { pb: 2.5 },
              }}
            >
              <Stack direction="row" alignItems="center" spacing={1} mb={1.75}>
                <Box
                  sx={{
                    width: 38,
                    height: 38,
                    borderRadius: 2.5,
                    display: "grid",
                    placeItems: "center",
                    background: selected
                      ? `linear-gradient(135deg, ${palette.primary.main}, ${palette.primary.light})`
                      : `${palette.primary.main}14`,
                    color: selected ? "#fff" : palette.primary.main,
                    boxShadow: selected
                      ? `0 4px 12px ${palette.primary.main}40`
                      : "none",
                  }}
                >
                  <AccountBalanceWalletRounded fontSize="small" />
                </Box>
                <Typography
                  fontWeight={800}
                  noWrap
                  flex={1}
                  fontSize={15}
                  color="text.primary"
                >
                  {w.name}
                </Typography>
                <IconButton
                  size="small"
                  onClick={(e) => {
                    e.stopPropagation();
                    onEdit(e, w.id);
                  }}
                  sx={{
                    color: palette.textMuted,
                    bgcolor: `${palette.primary.main}08`,
                    "&:hover": {
                      bgcolor: `${palette.primary.main}16`,
                      color: palette.primary.main,
                    },
                  }}
                >
                  <EditRounded sx={{ fontSize: 16 }} />
                </IconButton>
              </Stack>

              {selected ? (
                <WalletBalanceBreakdown
                  mainBalance={mainBalance}
                  totalSaved={totalSaved}
                  periodBalance={periodBalance}
                  periodLabel={periodLabel}
                  showPeriod
                />
              ) : (
                <>
                  <Typography
                    variant="h6"
                    fontWeight={800}
                    letterSpacing="-0.02em"
                    color="primary.main"
                  >
                    {formatMoney(mainBalance + totalSaved)}
                  </Typography>
                  <Typography
                    variant="caption"
                    color="text.secondary"
                    fontWeight={600}
                    display="block"
                    mt={0.25}
                  >
                    Tổng tài sản
                  </Typography>
                  <Typography
                    variant="caption"
                    color="text.secondary"
                    fontWeight={600}
                    display="block"
                    mt={0.75}
                  >
                    Ví chính · {formatMoney(mainBalance)}
                  </Typography>
                </>
              )}
            </CardContent>
          </Card>
        );
      })}
      <Card
        onClick={onAdd}
        sx={{
          minWidth: { xs: 108, sm: 132 },
          width: { xs: 108, sm: 132 },
          flexShrink: 0,
          alignSelf: "stretch",
          cursor: "pointer",
          borderRadius: 3,
          bgcolor: palette.surface,
          border: `1px dashed ${palette.textMuted}`,
          display: "flex",
          alignItems: "stretch",
          justifyContent: "center",
          transition: "all 0.2s ease",
          "&:hover": {
            bgcolor: `${palette.primary.main}08`,
            borderColor: palette.primary.light,
            transform: "translateY(-2px)",
          },
        }}
      >
        <CardContent
          sx={{
            flex: 1,
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            textAlign: "center",
            py: 3,
            px: 1.5,
          }}
        >
          <Box
            sx={{
              width: 40,
              height: 40,
              mx: "auto",
              mb: 0.75,
              borderRadius: "50%",
              display: "grid",
              placeItems: "center",
              bgcolor: `${palette.primary.main}12`,
            }}
          >
            <AddRounded sx={{ color: palette.primary.main }} />
          </Box>
          <Typography color="text.secondary" fontWeight={700} fontSize={13}>
            Ví mới
          </Typography>
        </CardContent>
      </Card>
    </Stack>
  );
}
