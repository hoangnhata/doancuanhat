package com.expense.service;

import com.expense.dto.ai.ChatResponse;
import com.expense.entity.Budget;
import com.expense.entity.Transaction;
import com.expense.entity.User;
import com.expense.entity.enums.TransactionType;
import com.expense.repository.BudgetRepository;
import com.expense.repository.TransactionRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.reactive.function.client.WebClient;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Lấy context giao dịch của user → gửi sang FastAPI /api/chat (Gemini hoặc rule-based).
 */
@Service
@RequiredArgsConstructor
public class ChatAssistantService {

    private static final Logger log = LoggerFactory.getLogger(ChatAssistantService.class);

    private final UserService userService;
    private final TransactionRepository transactionRepository;
    private final BudgetRepository budgetRepository;
    private final WebClient.Builder webClientBuilder;
    private final ObjectMapper objectMapper;

    @Value("${ai.categorization.python-api.base-url:http://localhost:8000}")
    private String pythonApiBaseUrl;

    @Value("${ai.chat.endpoint:/api/chat}")
    private String chatEndpoint;

    @Value("${ai.chat.history-days:45}")
    private int historyDays;

    @Transactional(readOnly = true)
    public ChatResponse ask(String message) {
        User user = userService.getCurrentUserEntity();

        LocalDate today = LocalDate.now();
        LocalDate from = today.minusDays(Math.max(7, historyDays));
        LocalDate monthStart = today.withDayOfMonth(1);

        List<Transaction> recent = transactionRepository.findByUserIdAndTransactionDateBetweenAll(
                user.getId(), from, today);

        // Tổng tháng hiện tại
        long monthExpense = 0;
        long monthIncome = 0;
        Map<String, Long> byCategory = new HashMap<>();
        for (Transaction t : recent) {
            if (t.getTransactionDate().isBefore(monthStart)) continue;
            long amt = t.getAmount().longValue();
            if (t.getType() == TransactionType.EXPENSE) {
                monthExpense += amt;
                byCategory.merge(safeCategoryName(t), amt, Long::sum);
            } else if (t.getType() == TransactionType.INCOME) {
                monthIncome += amt;
            }
        }

        // 15 giao dịch gần nhất gửi đi (đã đảo theo desc)
        List<Map<String, Object>> recentForAi = new ArrayList<>();
        int max = Math.min(recent.size(), 15);
        for (int i = 0; i < max; i++) {
            Transaction t = recent.get(i);
            Map<String, Object> row = new HashMap<>();
            row.put("date", t.getTransactionDate().toString());
            row.put("amount", t.getAmount().longValue());
            row.put("description", t.getDescription());
            row.put("category", safeCategoryName(t));
            row.put("type", t.getType().name());
            recentForAi.add(row);
        }

        List<Map<String, Object>> byCategoryList = new ArrayList<>();
        byCategory.forEach((name, amt) -> {
            Map<String, Object> row = new HashMap<>();
            row.put("name", name);
            row.put("amount", amt);
            byCategoryList.add(row);
        });

        List<Budget> activeBudgets = budgetRepository.findActiveBudgetsByUserIdAndDate(user.getId(), today);
        List<Map<String, Object>> budgetsForAi = new ArrayList<>();
        for (Budget b : activeBudgets) {
            BigDecimal used = transactionRepository.sumAmountByUserCategoryTypeAndDateRange(
                    user.getId(), b.getCategory().getId(), TransactionType.EXPENSE,
                    b.getStartDate(), b.getEndDate());
            Map<String, Object> row = new HashMap<>();
            row.put("category", b.getCategory().getName());
            row.put("limit", b.getAmount().longValue());
            row.put("used", used == null ? 0 : used.longValue());
            budgetsForAi.add(row);
        }

        Map<String, Object> context = new HashMap<>();
        context.put("currency", user.getCurrencyCode() != null ? user.getCurrencyCode() : "VND");
        context.put("month_total_expense", monthExpense);
        context.put("month_total_income", monthIncome);
        context.put("by_category", byCategoryList);
        context.put("recent_transactions", recentForAi);
        context.put("budgets", budgetsForAi);

        Map<String, Object> body = new HashMap<>();
        body.put("message", message);
        body.put("personality", user.getBotPersonality() != null ? user.getBotPersonality() : "HAPPY");
        body.put("context", context);

        String requestBody;
        try {
            requestBody = objectMapper.writeValueAsString(body);
        } catch (Exception e) {
            throw new IllegalStateException("Không build được request chat", e);
        }

        try {
            String response = webClientBuilder.build()
                    .post()
                    .uri(pythonApiBaseUrl + chatEndpoint)
                    .contentType(MediaType.APPLICATION_JSON)
                    .bodyValue(requestBody)
                    .retrieve()
                    .bodyToMono(String.class)
                    .block();
            if (response == null) throw new IllegalStateException("AI chat trả về rỗng");
            JsonNode root = objectMapper.readTree(response);
            return ChatResponse.builder()
                    .reply(root.path("reply").asText("Xin lỗi, tôi chưa trả lời được câu hỏi này."))
                    .engine(root.path("engine").asText("unknown"))
                    .build();
        } catch (Exception ex) {
            log.warn("Chat AI service lỗi: {}", ex.getMessage());
            return ChatResponse.builder()
                    .reply("AI chưa sẵn sàng. Vui lòng đảm bảo FastAPI đang chạy ở "
                            + pythonApiBaseUrl + " và thử lại.")
                    .engine("error")
                    .build();
        }
    }

    private static String safeCategoryName(Transaction t) {
        return t.getCategory() != null ? t.getCategory().getName() : "Khác";
    }
}
