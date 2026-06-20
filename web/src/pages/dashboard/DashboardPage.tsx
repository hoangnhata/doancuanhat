import {
  Box,
  Button,
  Card,
  CardContent,
  CircularProgress,
  Stack,
  ToggleButton,
  ToggleButtonGroup,
  Typography,
} from "@mui/material";
import { useQuery } from "@tanstack/react-query";
import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { Cell, Pie, PieChart, ResponsiveContainer, Tooltip } from "recharts";
import { GradientBackground } from "@/components/common/GradientBackground";
import { PeriodFilterBar } from "@/components/common/PeriodFilterBar";
import { DashboardHero } from "@/components/dashboard/DashboardHero";
import { ForecastPromoCard } from "@/components/dashboard/ForecastPromoCard";
import { SpendingLimitAlertsCard } from "@/components/dashboard/SpendingLimitAlertsCard";
import { SavingGoalsHomeSection } from "@/components/dashboard/SavingGoalsHomeSection";
import { NetChangeSummaryCard } from "@/components/dashboard/NetChangeSummaryCard";
import { SectionLabel } from "@/components/dashboard/SectionLabel";
import { WalletCarousel } from "@/components/dashboard/WalletCarousel";
import { useAuth } from "@/contexts/AuthContext";
import { useSelectedWallet } from "@/contexts/SelectedWalletContext";
import { formatMoney } from "@/lib/format";
import * as statisticsService from "@/services/statisticsService";
import * as savingGoalService from "@/services/savingGoalService";
import * as walletService from "@/services/walletService";
import { chartCategoryColor, palette } from "@/theme";

export function DashboardPage() {
  const navigate = useNavigate();
  const { user } = useAuth();
  const { selectedWalletId, setSelectedWalletId } = useSelectedWallet();

  const now = new Date();
  const [period, setPeriod] = useState<"month" | "year">("month");
  const [year, setYear] = useState(now.getFullYear());
  const [month, setMonth] = useState(now.getMonth() + 1);
  const [showExpense, setShowExpense] = useState(true);
  const periodLabel =
    period === "month" ? `Tháng ${month}/${year}` : `Năm ${year}`;

  const { data: wallets = [], isLoading: walletsLoading } = useQuery({
    queryKey: ['wallets'],
    queryFn: walletService.fetchWallets,
    refetchOnWindowFocus: true,
  });

  const { data: savingGoals = [] } = useQuery({
    queryKey: ["saving-goals"],
    queryFn: savingGoalService.fetchSavingGoals,
  });

  const totalSaved = useMemo(
    () => savingGoals.reduce((sum, g) => sum + g.currentAmount, 0),
    [savingGoals],
  );

  useEffect(() => {
    if (!wallets.length) return;
    const valid =
      selectedWalletId != null &&
      wallets.some((w) => w.id === selectedWalletId);
    if (!valid) {
      const def = wallets.find((w) => w.isDefault) ?? wallets[0];
      setSelectedWalletId(def.id);
    }
  }, [wallets, selectedWalletId, setSelectedWalletId]);

  const walletId = selectedWalletId ?? undefined;

  const { data: expenseStats, isLoading: loadingExp } = useQuery({
    queryKey: ["stats", period, year, month, walletId, "EXPENSE"],
    queryFn: () =>
      period === "month"
        ? statisticsService.getStatsByMonth(year, month, "EXPENSE", walletId)
        : statisticsService.getStatsByYear(year, "EXPENSE", walletId),
    enabled: walletId != null,
  });

  const { data: incomeStats, isLoading: loadingInc } = useQuery({
    queryKey: ["stats", period, year, month, walletId, "INCOME"],
    queryFn: () =>
      period === "month"
        ? statisticsService.getStatsByMonth(year, month, "INCOME", walletId)
        : statisticsService.getStatsByYear(year, "INCOME", walletId),
    enabled: walletId != null,
  });

  const loading =
    walletsLoading || loadingExp || loadingInc || walletId == null;

  const totalIncome = incomeStats?.totalIncome ?? 0;
  const totalExpense = expenseStats?.totalExpense ?? 0;
  const balance = totalIncome - totalExpense;

  const chartData = useMemo(() => {
    const src = showExpense
      ? expenseStats?.byCategory
      : incomeStats?.byCategory;
    return (src ?? []).map((c) => ({
      name: c.categoryName,
      amount: c.amount,
    }));
  }, [showExpense, expenseStats, incomeStats]);

  return (
    <GradientBackground>
      <Box sx={{ p: { xs: 2, md: 3 }, pb: 10, maxWidth: 900, mx: "auto" }}>
        <DashboardHero
          userName={user?.fullName}
          periodLabel={periodLabel}
          onSavingGoals={() => navigate("/app/saving-goals")}
          onAnalytics={() => navigate("/app/analytics")}
          onForecast={() => navigate("/app/spending-forecast")}
        />

        <SectionLabel>Ví của bạn</SectionLabel>
        <WalletCarousel
          wallets={wallets}
          selectedWalletId={selectedWalletId}
          totalSaved={totalSaved}
          periodBalance={balance}
          periodLabel={periodLabel}
          onSelect={setSelectedWalletId}
          onEdit={(_, id) => {
            setSelectedWalletId(id);
            navigate("/app/wallets");
          }}
          onAdd={() => navigate("/app/wallets")}
        />

        <SpendingLimitAlertsCard />

        <SavingGoalsHomeSection />

        <Box sx={{ mt: 2.5 }}>
          <PeriodFilterBar
            period={period}
            onPeriodChange={setPeriod}
            year={year}
            month={month}
            onMonthYearChange={(y, m) => {
              setYear(y);
              setMonth(m);
            }}
            onYearChange={setYear}
            maxYear={now.getFullYear() + 1}
          />
        </Box>

        {loading ? (
          <Box display="flex" justifyContent="center" py={6}>
            <CircularProgress />
          </Box>
        ) : totalIncome === 0 && totalExpense === 0 ? (
          <Card sx={{ p: 4, textAlign: "center", borderRadius: 4 }}>
            <Typography gutterBottom fontWeight={700}>
              Chưa có giao dịch trong {periodLabel.toLowerCase()}
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
              {period === "month"
                ? "Thử chọn tháng khác hoặc chuyển sang xem theo năm để thấy dữ liệu tổng hợp."
                : "Thử chọn năm khác hoặc thêm giao dịch mới."}
            </Typography>
            <Stack
              direction={{ xs: "column", sm: "row" }}
              spacing={1}
              justifyContent="center"
            >
              {period === "month" && (
                <Button variant="outlined" onClick={() => setPeriod("year")}>
                  Xem theo năm {year}
                </Button>
              )}
              <Button
                variant="contained"
                onClick={() => navigate("/app/transactions/add")}
              >
                Thêm giao dịch
              </Button>
            </Stack>
          </Card>
        ) : (
          <>
            <NetChangeSummaryCard
              periodLabel={periodLabel}
              balance={balance}
              totalIncome={totalIncome}
              totalExpense={totalExpense}
            />

            <ForecastPromoCard
              onClick={() => navigate("/app/spending-forecast")}
            />

            <SectionLabel>Phân bổ theo danh mục</SectionLabel>
            <Stack direction="row" spacing={1} mb={2}>
              <ToggleButtonGroup
                fullWidth
                value={showExpense ? "exp" : "inc"}
                exclusive
                onChange={(_, v) => {
                  if (v) setShowExpense(v === "exp");
                }}
              >
                <ToggleButton value="exp">Chi phí</ToggleButton>
                <ToggleButton value="inc">Thu nhập</ToggleButton>
              </ToggleButtonGroup>
            </Stack>

            <Card sx={{ borderRadius: 4, boxShadow: palette.shadowSoft }}>
              <CardContent sx={{ p: { xs: 2, sm: 3 } }}>
                <Typography fontWeight={800} gutterBottom fontSize={16}>
                  {showExpense
                    ? "Chi tiêu theo danh mục"
                    : "Thu nhập theo danh mục"}
                </Typography>
                {chartData.length === 0 ? (
                  <Typography color="text.secondary" py={2}>
                    Chưa có dữ liệu danh mục trong kỳ này.
                  </Typography>
                ) : (
                  <>
                    <Box height={220}>
                      <ResponsiveContainer width="100%" height="100%">
                        <PieChart>
                          <Pie
                            data={chartData}
                            dataKey="amount"
                            nameKey="name"
                            cx="50%"
                            cy="50%"
                            innerRadius={52}
                            outerRadius={78}
                            paddingAngle={3}
                            stroke="none"
                          >
                            {chartData.map((_, i) => (
                              <Cell key={i} fill={chartCategoryColor(i)} />
                            ))}
                          </Pie>
                          <Tooltip formatter={(v: number) => formatMoney(v)} />
                        </PieChart>
                      </ResponsiveContainer>
                    </Box>
                    <Stack spacing={1.25} mt={2}>
                      {chartData.map((row, i) => (
                        <Stack
                          key={row.name}
                          direction="row"
                          alignItems="center"
                          spacing={1.25}
                          sx={{
                            p: 1.25,
                            borderRadius: 2,
                            bgcolor: `${chartCategoryColor(i)}12`,
                          }}
                        >
                          <Box
                            width={12}
                            height={12}
                            borderRadius={1}
                            bgcolor={chartCategoryColor(i)}
                          />
                          <Typography flex={1} fontWeight={600} fontSize={14}>
                            {row.name}
                          </Typography>
                          <Typography fontWeight={800} fontSize={14}>
                            {formatMoney(row.amount)}
                          </Typography>
                        </Stack>
                      ))}
                    </Stack>
                  </>
                )}
              </CardContent>
            </Card>
          </>
        )}
      </Box>
    </GradientBackground>
  );
}
