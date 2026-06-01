package com.expense.service;

import com.expense.dto.budget.BudgetDto;
import com.expense.dto.statistics.ForecastBudgetAlertDto;
import com.expense.dto.statistics.ForecastEligibilityResponse;
import com.expense.dto.statistics.ForecastInsightDto;
import com.expense.dto.statistics.SpendingForecastResponse;
import com.expense.entity.User;
import com.expense.entity.enums.CategoryType;
import com.expense.entity.enums.TransactionType;
import com.expense.exception.BadRequestException;
import com.expense.repository.TransactionRepository;
import com.expense.repository.WalletRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.WebClientResponseException;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class SpendingForecastService {

    private static final Logger log = LoggerFactory.getLogger(SpendingForecastService.class);

    private final TransactionRepository transactionRepository;
    private final WalletRepository walletRepository;
    private final UserService userService;
    private final BudgetService budgetService;
    private final WebClient.Builder webClientBuilder;
    private final ObjectMapper objectMapper;

    @Value("${ai.forecast.enabled:true}")
    private boolean forecastEnabled;

    @Value("${ai.categorization.python-api.base-url:http://localhost:8000}")
    private String pythonApiBaseUrl;

    @Value("${ai.forecast.endpoint:/api/forecast}")
    private String forecastEndpoint;

    @Value("${ai.forecast.window-days:30}")
    private int windowDays;

    /**
     * Tối thiểu số ngày có chi trong cửa sổ để cho phép dự báo AI (đồng bộ với ngưỡng sparse/fallback).
     */
    public static final int MIN_DAYS_WITH_EXPENSE_FOR_AI_FORECAST = 4;

    public ForecastEligibilityResponse getForecastEligibility(Long walletId, LocalDate lastObservationDate) {
        User user = userService.getCurrentUserEntity();
        ExpenseWindowContext ctx = buildExpenseWindow(user, walletId, lastObservationDate);
        if (!forecastEnabled) {
            return ForecastEligibilityResponse.builder()
                    .eligible(false)
                    .requiredDaysWithExpense(MIN_DAYS_WITH_EXPENSE_FOR_AI_FORECAST)
                    .daysWithExpenseInWindow(ctx.daysWithExpense())
                    .windowDays(ctx.windowDays())
                    .messageVi("Dự báo chi tiêu AI đang tắt trên máy chủ (ai.forecast.enabled=false).")
                    .build();
        }
        boolean eligible = ctx.daysWithExpense() >= MIN_DAYS_WITH_EXPENSE_FOR_AI_FORECAST;
        return ForecastEligibilityResponse.builder()
                .eligible(eligible)
                .requiredDaysWithExpense(MIN_DAYS_WITH_EXPENSE_FOR_AI_FORECAST)
                .daysWithExpenseInWindow(ctx.daysWithExpense())
                .windowDays(ctx.windowDays())
                .messageVi(eligible ? null : eligibilityDeniedMessage(ctx.daysWithExpense(), ctx.windowDays()))
                .build();
    }

    public SpendingForecastResponse forecastSpending(Long walletId, LocalDate lastObservationDate) {
        if (!forecastEnabled) {
            throw new BadRequestException("Dự báo chi tiêu AI đang tắt (ai.forecast.enabled=false).");
        }
        User user = userService.getCurrentUserEntity();
        ExpenseWindowContext ctx = buildExpenseWindow(user, walletId, lastObservationDate);
        if (ctx.daysWithExpense() < MIN_DAYS_WITH_EXPENSE_FOR_AI_FORECAST) {
            throw new BadRequestException(eligibilityDeniedMessage(ctx.daysWithExpense(), ctx.windowDays()));
        }

        List<Double> series = ctx.series();
        LocalDate end = ctx.end();
        boolean includeLegacy = ctx.includeLegacy();
        int effectiveWindow = ctx.windowDays();

        String url = pythonApiBaseUrl + forecastEndpoint;
        Map<String, Object> body = new HashMap<>();
        body.put("daily_expenses_vnd", series);
        body.put("last_observation_date", end.toString());

        String requestJson;
        try {
            requestJson = objectMapper.writeValueAsString(body);
        } catch (Exception e) {
            throw new BadRequestException("Không tạo được payload dự báo.");
        }

        try {
            String response = webClientBuilder.build()
                    .post()
                    .uri(url)
                    .contentType(MediaType.APPLICATION_JSON)
                    .bodyValue(requestJson)
                    .retrieve()
                    .bodyToMono(String.class)
                    .block();

            if (response == null) {
                throw new BadRequestException("API dự báo không trả dữ liệu.");
            }
            JsonNode root = objectMapper.readTree(response);
            JsonNode preds = root.path("predicted_next_days_vnd");
            if (!preds.isArray() || preds.isEmpty()) {
                throw new BadRequestException("Phản hồi dự báo không hợp lệ.");
            }
            List<Long> out = new ArrayList<>();
            for (JsonNode n : preds) {
                out.add(n.asLong());
            }
            int horizon = root.path("horizon").asInt(out.size());
            int window = root.path("window").asInt(effectiveWindow);

            out = applySparseHistoryForecastFallback(series, out);

            ForecastInsightDto insight = buildInsight(
                    user, walletId, includeLegacy, end, out, series);

            return SpendingForecastResponse.builder()
                    .predictedNextDaysVnd(out)
                    .horizon(horizon)
                    .window(window)
                    .lastObservationDate(end.toString())
                    .insight(insight)
                    .build();
        } catch (WebClientResponseException e) {
            String detail = e.getResponseBodyAsString();
            log.warn("Forecast API HTTP {}: {}", e.getStatusCode().value(), detail);
            if (e.getStatusCode().value() == 503) {
                throw new BadRequestException(
                        "Chưa load được model dự báo. Hãy chạy ai_service (uvicorn) và đặt forecast_model.pt trong models/.");
            }
            throw new BadRequestException(
                    detail != null && !detail.isBlank() ? detail : "Gọi dịch vụ dự báo thất bại: " + e.getMessage());
        } catch (BadRequestException e) {
            throw e;
        } catch (Exception e) {
            log.warn("Forecast call failed", e);
            throw new BadRequestException(
                    "Không kết nối được AI dự báo (" + pythonApiBaseUrl + "). Đảm bảo đã bật ai_service.");
        }
    }

    /**
     * Chuỗi nhiều ngày 0 + vài ngày có chi làm mô hình deep learning thường dự báo gần 0 VND (OOD).
     * Khi đó dùng trung bình chi/ngày trong cửa sổ ({@code sum/windowDays}) làm dự báo phẳng cho horizon.
     */
    private List<Long> applySparseHistoryForecastFallback(List<Double> series, List<Long> aiPreds) {
        if (aiPreds == null || aiPreds.isEmpty() || series == null || series.isEmpty()) {
            return aiPreds;
        }
        int daysWithSpend = 0;
        double sumWindow = 0.0;
        for (Double v : series) {
            double x = v != null ? v : 0.0;
            sumWindow += x;
            if (x > 1.0) {
                daysWithSpend++;
            }
        }
        if (sumWindow < 1.0) {
            return aiPreds;
        }
        double dailyMeanWindow = sumWindow / series.size();
        long aiWeekTotal = aiPreds.stream().mapToLong(Long::longValue).sum();
        boolean sparse = daysWithSpend < MIN_DAYS_WITH_EXPENSE_FOR_AI_FORECAST;
        long floorSuspicious = Math.max(1000L, Math.round(dailyMeanWindow * 7.0 * 0.05));
        boolean aiSuspicious = aiWeekTotal < floorSuspicious;
        if (!sparse && !aiSuspicious) {
            return aiPreds;
        }
        long daily = Math.round(dailyMeanWindow);
        if (daily < 0) {
            daily = 0;
        }
        log.info(
                "Forecast fallback (sparse={}, aiSuspicious={}): daysWithSpend={} sumWindow={} aiWeekTotal={} -> {} VND/day flat",
                sparse, aiSuspicious, daysWithSpend, sumWindow, aiWeekTotal, daily);
        List<Long> fallback = new ArrayList<>(aiPreds.size());
        for (int i = 0; i < aiPreds.size(); i++) {
            fallback.add(daily);
        }
        return fallback;
    }

    private ForecastInsightDto buildInsight(
            User user,
            Long walletId,
            boolean includeLegacy,
            LocalDate end,
            List<Long> preds,
            List<Double> series) {

        long total7 = preds.stream().mapToLong(Long::longValue).sum();
        int h = preds.size();
        long avgPerDay = h > 0 ? total7 / h : 0L;

        double sumWindow = series.stream().mapToDouble(Double::doubleValue).sum();
        long baseline7 = series.isEmpty() ? 0L : Math.round(sumWindow / series.size() * 7.0);

        Integer pacePct = null;
        if (baseline7 > 0) {
            pacePct = (int) Math.round((total7 - baseline7) * 100.0 / baseline7);
        }

        String level = "OK";
        if (pacePct != null && pacePct >= 25) {
            level = "ALERT";
        } else if (pacePct != null && pacePct >= 10) {
            level = "WATCH";
        }

        LocalDate monthStart = end.withDayOfMonth(1);
        BigDecimal mtdBd = transactionRepository.sumAmountByUserIdAndTypeAndDateRangeWithWallet(
                user.getId(),
                TransactionType.EXPENSE,
                monthStart,
                end,
                walletId,
                includeLegacy);
        long mtd = mtdBd != null ? mtdBd.longValue() : 0L;

        long overlapMonth = 0L;
        for (int i = 0; i < preds.size(); i++) {
            LocalDate pd = end.plusDays(i + 1L);
            if (pd.getYear() == end.getYear() && pd.getMonthValue() == end.getMonthValue()) {
                overlapMonth += preds.get(i);
            }
        }
        long projectedFloor = mtd + overlapMonth;

        List<ForecastBudgetAlertDto> budgetAlerts = buildBudgetAlerts(end);
        boolean anyOver = budgetAlerts.stream().anyMatch(a -> "OVER".equals(a.getSeverity()));
        if (anyOver) {
            level = "ALERT";
        } else if (budgetAlerts.stream().anyMatch(a -> "WARN".equals(a.getSeverity())) && "OK".equals(level)) {
            level = "WATCH";
        }

        List<String> tips = new ArrayList<>();
        if (overlapMonth > 0) {
            tips.add(String.format(
                    "Tháng %d/%d: đã chi %,d VND (đến %s). Các ngày dự báo còn trong tháng cộng thêm ~%,d VND — ước tính tối thiểu %,d VND (đã chi + phần dự báo trong tháng).",
                    end.getMonthValue(), end.getYear(), mtd, end, overlapMonth, projectedFloor));
        }

        long sumPositiveRem = budgetAlerts.stream()
                .mapToLong(a -> Math.max(0L, a.getRemainingVnd()))
                .sum();
        if (sumPositiveRem > 0 && total7 > sumPositiveRem) {
            tips.add(String.format(
                    "Tổng dự báo tuần tới (%,d VND) lớn hơn phần còn lại của các ngân sách đang bật (%,d VND). Nên giảm chi hoặc điều chỉnh ngân sách.",
                    total7, sumPositiveRem));
        }

        String headline;
        if ("ALERT".equals(level)) {
            headline = String.format(
                    "Tuần tới dự báo %,d VND (~%,d VND/ngày) — cao khoảng %d%% so với trung bình %d ngày vừa qua.",
                    total7,
                    avgPerDay,
                    pacePct != null ? pacePct : 0,
                    series.size());
            tips.add("Ưu tiên khoản bắt buộc; hoãn mua sắm không cần thiết.");
            tips.add("Mở mục Ngân sách để xem mục nào sắp hết hoặc đã vượt.");
        } else if ("WATCH".equals(level)) {
            headline = String.format(
                    "Tuần tới dự báo %,d VND — nhích cao hơn bình thường (+%d%%). Theo dõi vài ngày đầu tuần.",
                    total7,
                    pacePct != null ? pacePct : 0);
            tips.add("Đặt giới hạn chi cho nhóm ăn uống / giải trí trong tuần.");
        } else {
            headline = String.format(
                    "Tuần tới dự báo khoảng %,d VND (~%,d VND/ngày), gần mức bạn đang chi trung bình.",
                    total7,
                    avgPerDay);
            tips.add("Giữ nhịp chi hiện tại để so sánh với dự báo lần sau.");
        }
        tips.add("Ghi giao dịch đúng ngày để dự báo và ngân sách luôn khớp.");

        return ForecastInsightDto.builder()
                .totalNext7DaysVnd(total7)
                .avgPerDayVnd(avgPerDay)
                .baseline7DaysVnd(baseline7)
                .paceVsBaselinePercent(pacePct)
                .level(level)
                .headlineVi(headline)
                .tipsVi(tips.stream().distinct().collect(Collectors.toList()))
                .expenseMonthToDateVnd(mtd)
                .forecastOverlapSameMonthVnd(overlapMonth)
                .projectedMonthFloorVnd(projectedFloor)
                .budgetAlerts(budgetAlerts)
                .build();
    }

    private List<ForecastBudgetAlertDto> buildBudgetAlerts(LocalDate end) {
        List<BudgetDto> budgets = budgetService.getActiveBudgets(end);
        List<ForecastBudgetAlertDto> out = new ArrayList<>();
        for (BudgetDto b : budgets) {
            if (b.getCategory() == null || b.getCategory().getType() != CategoryType.EXPENSE) {
                continue;
            }
            long amount = b.getAmount() != null ? b.getAmount().longValue() : 0L;
            long spent = b.getSpentAmount() != null ? b.getSpentAmount().longValue() : 0L;
            long rem = b.getRemainingAmount() != null ? b.getRemainingAmount().longValue() : amount - spent;
            int pct = amount > 0 ? (int) Math.min(999L, Math.round(spent * 100.0 / amount)) : 0;
            String sev = "OK";
            if (rem < 0) {
                sev = "OVER";
            } else if (pct >= 75) {
                sev = "WARN";
            }
            out.add(ForecastBudgetAlertDto.builder()
                    .categoryName(b.getCategory().getName())
                    .budgetAmountVnd(amount)
                    .spentVnd(spent)
                    .remainingVnd(rem)
                    .percentUsed(pct)
                    .severity(sev)
                    .build());
        }
        out.sort(Comparator
                .comparingInt((ForecastBudgetAlertDto a) -> severityRank(a.getSeverity()))
                .thenComparing(a -> a.getCategoryName(), String.CASE_INSENSITIVE_ORDER));
        return out;
    }

    private static int severityRank(String s) {
        if ("OVER".equals(s)) {
            return 0;
        }
        if ("WARN".equals(s)) {
            return 1;
        }
        return 2;
    }

    private String eligibilityDeniedMessage(int daysWithExpense, int windowLen) {
        return String.format(
                "Để dự báo chi tiêu AI đáng tin cậy, bạn cần ít nhất %d ngày có chi tiêu trong %d ngày gần nhất (theo ví đang chọn). Hiện có %d ngày — vui lòng ghi thêm giao dịch chi vào các ngày khác nhau rồi thử lại.",
                MIN_DAYS_WITH_EXPENSE_FOR_AI_FORECAST,
                windowLen,
                daysWithExpense);
    }

    private ExpenseWindowContext buildExpenseWindow(User user, Long walletId, LocalDate lastObservationDate) {
        LocalDate end = lastObservationDate != null ? lastObservationDate : LocalDate.now();
        int wd = windowDays < 1 ? 30 : windowDays;
        LocalDate start = end.minusDays((long) wd - 1);

        boolean includeLegacy = false;
        if (walletId != null) {
            includeLegacy = walletRepository.findByUserIdAndIsDefaultTrue(user.getId())
                    .map(w -> w.getId().equals(walletId))
                    .orElse(false);
        }

        List<Object[]> rows = transactionRepository.sumExpenseAmountByDayWithWallet(
                user.getId(),
                TransactionType.EXPENSE,
                start,
                end,
                walletId,
                includeLegacy);

        Map<LocalDate, BigDecimal> byDay = new HashMap<>();
        for (Object[] row : rows) {
            LocalDate d = (LocalDate) row[0];
            BigDecimal sum = (BigDecimal) row[1];
            byDay.put(d, sum != null ? sum : BigDecimal.ZERO);
        }

        List<Double> series = new ArrayList<>(wd);
        for (LocalDate d = start; !d.isAfter(end); d = d.plusDays(1)) {
            series.add(byDay.getOrDefault(d, BigDecimal.ZERO).doubleValue());
        }

        if (series.size() != wd) {
            throw new BadRequestException(
                    "Lỗi nội bộ: chuỗi ngày không khớp cỡ sổ " + wd);
        }

        int daysWithExpense = 0;
        for (Double v : series) {
            if (v != null && v > 1.0) {
                daysWithExpense++;
            }
        }
        return new ExpenseWindowContext(series, daysWithExpense, end, start, wd, includeLegacy);
    }

    private record ExpenseWindowContext(
            List<Double> series,
            int daysWithExpense,
            LocalDate end,
            LocalDate start,
            int windowDays,
            boolean includeLegacy) {}
}
