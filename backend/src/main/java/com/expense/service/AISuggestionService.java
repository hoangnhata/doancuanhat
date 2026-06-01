package com.expense.service;

import com.expense.dto.ai.AISuggestionItemDto;
import com.expense.entity.User;
import com.expense.entity.enums.TransactionType;
import com.expense.repository.CategoryRepository;
import com.expense.repository.TransactionRepository;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class AISuggestionService {

    private static final Logger log = LoggerFactory.getLogger(AISuggestionService.class);

    private final TransactionRepository transactionRepository;
    private final CategoryRepository categoryRepository;
    private final UserService userService;

    private static final Map<String, String> SUGGESTION_TEMPLATES = Map.ofEntries(
            Map.entry("ăn uống", "Nấu ăn tại nhà nhiều hơn, hạn chế ăn ngoài và giao đồ ăn"),
            Map.entry("ăn", "Giảm chi tiêu ăn ngoài, meal prep cuối tuần để tiết kiệm"),
            Map.entry("di chuyển", "Đi xe bus/MRT hoặc đi chung xe để giảm chi phí"),
            Map.entry("grab", "Đặt giao hàng ít hơn, mua sắm định kỳ thay vì đặt lẻ"),
            Map.entry("mua sắm", "Lên danh sách trước khi mua, tránh mua sắm theo cảm hứng"),
            Map.entry("giải trí", "Giảm subscription không dùng, tìm giải trí miễn phí"),
            Map.entry("sức khỏe", "Tập thể dục tại nhà, mua thuốc theo toa để tiết kiệm")
    );

    public List<AISuggestionItemDto> getSuggestions() {
        User user = userService.getCurrentUserEntity();
        LocalDate endDate = LocalDate.now();
        LocalDate startDate = endDate.minusDays(30);

        List<Object[]> categorySums = transactionRepository.sumAmountByCategoryAndDateRange(
                user.getId(), TransactionType.EXPENSE, startDate, endDate);

        if (categorySums == null || categorySums.isEmpty()) {
            log.info("No expense data for suggestions for user {}", user.getId());
            return List.of(AISuggestionItemDto.builder()
                    .categoryName("Chưa có dữ liệu")
                    .amount(BigDecimal.ZERO)
                    .suggestion("Hãy ghi chép chi tiêu ít nhất 30 ngày để nhận gợi ý tiết kiệm từ AI.")
                    .percentPossible(0)
                    .build());
        }

        categorySums.sort(Comparator.comparing(row -> (BigDecimal) row[1], Comparator.reverseOrder()));

        BigDecimal totalExpense = categorySums.stream()
                .map(row -> (BigDecimal) row[1])
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        List<AISuggestionItemDto> suggestions = new ArrayList<>();
        int maxSuggestions = Math.min(5, categorySums.size());

        for (int i = 0; i < maxSuggestions; i++) {
            Object[] row = categorySums.get(i);
            Long categoryId = (Long) row[0];
            BigDecimal amount = (BigDecimal) row[1];
            if (amount == null) amount = BigDecimal.ZERO;

            String categoryName = categoryRepository.findById(categoryId)
                    .map(c -> c.getName())
                    .orElse("Khác");

            String suggestion = findSuggestionForCategory(categoryName);
            int percentPossible = totalExpense.compareTo(BigDecimal.ZERO) > 0
                    ? amount.multiply(BigDecimal.valueOf(100)).divide(totalExpense, 0, RoundingMode.HALF_UP).intValue()
                    : 10;
            percentPossible = Math.min(30, Math.max(5, percentPossible));

            suggestions.add(AISuggestionItemDto.builder()
                    .categoryName(categoryName)
                    .amount(amount)
                    .suggestion(suggestion)
                    .percentPossible(percentPossible)
                    .build());
        }

        log.info("Generated {} AI suggestions for user {}", suggestions.size(), user.getId());
        return suggestions;
    }

    private String findSuggestionForCategory(String categoryName) {
        String lower = categoryName.toLowerCase();
        for (Map.Entry<String, String> e : SUGGESTION_TEMPLATES.entrySet()) {
            if (lower.contains(e.getKey())) {
                return e.getValue();
            }
        }
        return "Xem xét giảm chi tiêu trong danh mục này, mục tiêu 10-20%.";
    }
}
