package com.expense.service;

import com.expense.dto.transaction.AICategorizeResponse;
import com.expense.entity.Category;
import com.expense.entity.User;
import com.expense.entity.enums.CategoryType;
import com.expense.entity.enums.TransactionType;
import com.expense.repository.CategoryRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Service
public class AICategorizationService {

    private static final Logger log = LoggerFactory.getLogger(AICategorizationService.class);
    private static final Pattern AMOUNT_PATTERN = Pattern.compile(
            "(\\d{1,3}(?:[.,]\\d{3})*(?:[.,]\\d+)?)\\s*(k|nghìn|ngàn|tr|triệu|trăm|đ|vnđ|vnd)?",
            Pattern.CASE_INSENSITIVE);
    private static final Pattern DATE_IN_TEXT = Pattern.compile(
            "(?:\\bngày\\s+)?(\\d{1,2})[/\\-.](\\d{1,2})[/\\-.](\\d{2,4})\\b",
            Pattern.CASE_INSENSITIVE);
    // Split items by separators.
    // Important: comma can be written like "50k ,lương..." (no space after),
    // but we should NOT split commas inside numbers like "1,200".
    // So: split on comma only when it is NOT directly adjacent to digits.
    private static final Pattern BATCH_SPLIT_PATTERN = Pattern.compile(
            "(?<!\\d)\\s*,\\s*(?!\\d)|;|\\n|\\+|&|\\s+và\\s+",
            Pattern.CASE_INSENSITIVE
    );

    private final UserService userService;
    private final CategoryRepository categoryRepository;
    private final WebClient.Builder webClientBuilder;
    private final ObjectMapper objectMapper;

    @Value("${ai.categorization.enabled:true}")
    private boolean enabled;

    @Value("${ai.categorization.provider:openai}")
    private String provider;

    @Value("${ai.categorization.openai.api-key:}")
    private String openaiApiKey;

    @Value("${ai.categorization.openai.model:gpt-3.5-turbo}")
    private String openaiModel;

    @Value("${ai.categorization.openai.endpoint:https://api.openai.com/v1/chat/completions}")
    private String openaiEndpoint;

    @Value("${ai.categorization.python-api.base-url:http://localhost:8000}")
    private String pythonApiBaseUrl;

    @Value("${ai.categorization.python-api.categorize-endpoint:/api/categorize}")
    private String pythonCategorizeEndpoint;

    public AICategorizationService(UserService userService, CategoryRepository categoryRepository,
                                    WebClient.Builder webClientBuilder, ObjectMapper objectMapper) {
        this.userService = userService;
        this.categoryRepository = categoryRepository;
        this.webClientBuilder = webClientBuilder;
        this.objectMapper = objectMapper;
    }

    public AICategorizeResponse categorize(String text, String personality) {
        if (!enabled) {
            return fallbackCategorize(text, personality);
        }

        User user = userService.getCurrentUserEntity();
        BigDecimal amount = extractAmount(text);
        String description = text.trim();
        String effectivePersonality = (personality != null && !personality.isEmpty())
                ? personality : (user.getBotPersonality() != null ? user.getBotPersonality() : "HAPPY");

        AICategorizeResponse result;
        try {
            if ("openai".equalsIgnoreCase(provider) && openaiApiKey != null && !openaiApiKey.isEmpty()) {
                result = categorizeWithOpenAI(text, user, amount, description);
            } else if ("python-api".equalsIgnoreCase(provider)) {
                result = categorizeWithPythonAPI(text, user, amount, description);
            } else {
                result = fallbackCategorize(text, effectivePersonality);
            }
        } catch (Exception e) {
            log.warn("AI categorization failed, using fallback: {}", e.getMessage());
            result = fallbackCategorize(text, effectivePersonality);
        }

        if (result.getAmount() != null && result.getAmount().compareTo(BigDecimal.ZERO) > 0) {
            String rollyResponse = generateRollyResponse(effectivePersonality, description, result.getAmount());
            result.setRollyResponse(rollyResponse);
        }

        // Luôn ưu tiên ngày trong câu nhập (tránh fallback LocalDate.now() sai 1 ngày)
        LocalDate fromText = extractDateFromText(text);
        if (fromText != null) {
            result.setTransactionDate(fromText);
        } else if (result.getTransactionDate() == null) {
            result.setTransactionDate(LocalDate.now());
        }
        return result;
    }

    /**
     * Split a single input into multiple items and categorize each one.
     * Separators supported: comma (,), semicolon (;), newline.
     */
    public List<AICategorizeResponse> categorizeBatch(String rawText, String personality) {
        String t = rawText == null ? "" : rawText.trim();
        if (t.isEmpty()) return List.of();

        String[] parts = BATCH_SPLIT_PATTERN.split(t);
        List<AICategorizeResponse> out = new ArrayList<>();
        for (String p : parts) {
            String item = p == null ? "" : p.trim();
            if (item.isEmpty()) continue;
            out.add(categorize(item, personality));
        }
        return out;
    }

    private AICategorizeResponse categorizeWithOpenAI(String text, User user, BigDecimal amount, String description) {
        String systemPrompt = """
        Bạn là trợ lý phân loại chi tiêu. Phân tích text tiếng Việt và trả về JSON với format:
        {"category": "Tên danh mục", "description": "Mô tả ngắn"}
        Chỉ trả về JSON, không thêm text khác.
        Các danh mục phổ biến: Ăn uống, Di chuyển, Mua sắm, Giải trí, Sức khỏe, Hóa đơn, Giáo dục, Khác.
        """;

        String userPrompt = "Phân loại: \"" + text + "\"";

        String requestBody;
        try {
            requestBody = objectMapper.writeValueAsString(java.util.Map.of(
                    "model", openaiModel,
                    "messages", java.util.List.of(
                            java.util.Map.of("role", "system", "content", systemPrompt),
                            java.util.Map.of("role", "user", "content", userPrompt)
                    ),
                    "temperature", 0.3
            ));
        } catch (Exception e) {
            throw new RuntimeException("Failed to build request", e);
        }

        String response = webClientBuilder.build()
                .post()
                .uri(openaiEndpoint)
                .header("Authorization", "Bearer " + openaiApiKey)
                .contentType(MediaType.APPLICATION_JSON)
                .bodyValue(requestBody)
                .retrieve()
                .bodyToMono(String.class)
                .block();

        if (response != null) {
            try {
                JsonNode root = objectMapper.readTree(response);
                JsonNode choices = root.path("choices");
                if (choices.isArray() && choices.size() > 0) {
                    String content = choices.get(0).path("message").path("content").asText();
                    String categoryName = extractCategoryFromJson(content);
                    if (categoryName != null) {
                        CategoryType inferredType = inferCategoryType(text, user.getId(), categoryName, null);
                        Optional<Category> match = findBestMatchingCategory(user.getId(), categoryName, inferredType);
                        return AICategorizeResponse.builder()
                                .transactionType(inferredType == CategoryType.INCOME ? TransactionType.INCOME.name() : TransactionType.EXPENSE.name())
                                .categoryName(categoryName)
                                .categoryId(match.map(Category::getId).orElse(null))
                                .amount(amount)
                                .description(description)
                                .transactionDate(null)
                                .suggestedCategoryName(categoryName)
                                .rollyResponse(null)
                                .build();
                    }
                }
            } catch (com.fasterxml.jackson.core.JsonProcessingException e) {
                log.warn("Failed to parse OpenAI response", e);
            }
        }

        return fallbackCategorize(text, "HAPPY");
    }

    private AICategorizeResponse categorizeWithPythonAPI(String text, User user, BigDecimal amount, String description) {
        String url = pythonApiBaseUrl + pythonCategorizeEndpoint;
        String requestBody;
        try {
            requestBody = objectMapper.writeValueAsString(java.util.Map.of("text", text));
        } catch (Exception e) {
            throw new RuntimeException("Failed to build request", e);
        }
        String response = webClientBuilder.build()
                .post()
                .uri(url)
                .contentType(MediaType.APPLICATION_JSON)
                .bodyValue(requestBody)
                .retrieve()
                .bodyToMono(String.class)
                .block();

        if (response != null) {
            try {
                JsonNode root = objectMapper.readTree(response);
                String categoryName = root.path("category").asText(null);
                if (categoryName != null) {
                    String typeStr = root.path("type").asText(null); // optional
                    CategoryType inferredType = inferCategoryType(text, user.getId(), categoryName, typeStr);
                    Optional<Category> match = findBestMatchingCategory(user.getId(), categoryName, inferredType);
                    BigDecimal pyAmount = root.hasNonNull("amount")
                            ? root.path("amount").decimalValue() : null;
                    String pyDesc = root.path("description").asText(null);
                    LocalDate pyDate = parseTransactionDate(root.path("transaction_date").asText(null));
                    if (pyDate == null) {
                        pyDate = parseTransactionDate(root.path("transactionDate").asText(null));
                    }
                    if (pyDate == null) {
                        pyDate = extractDateFromText(text);
                    }

                    return AICategorizeResponse.builder()
                            .transactionType(inferredType == CategoryType.INCOME ? TransactionType.INCOME.name() : TransactionType.EXPENSE.name())
                            .categoryName(categoryName)
                            .categoryId(match.map(Category::getId).orElse(null))
                            .amount(pickAmount(pyAmount, amount))
                            .description(pyDesc != null && !pyDesc.isBlank() ? pyDesc : description)
                            .transactionDate(pyDate != null ? pyDate : LocalDate.now())
                            .suggestedCategoryName(categoryName)
                            .rollyResponse(null)
                            .build();
                }
            } catch (com.fasterxml.jackson.core.JsonProcessingException e) {
                log.warn("Failed to parse Python API response", e);
            }
        }

        return fallbackCategorize(text, "HAPPY");
    }

    private AICategorizeResponse fallbackCategorize(String text, String personality) {
        User user = userService.getCurrentUserEntity();
        BigDecimal amount = extractAmount(text);
        String description = text.trim();

        CategoryType inferredType = inferCategoryType(text, user.getId(), null, null);
        String suggestedCategory = inferredType == CategoryType.INCOME ? "Thu nhập khác" : "Khác";
        if (inferredType == CategoryType.INCOME) {
            if (text.matches("(?i).*(lương|luong|salary).*")) {
                suggestedCategory = "Lương";
            } else if (text.matches("(?i).*(thưởng|thuong|bonus).*")) {
                suggestedCategory = "Thưởng";
            } else if (text.matches("(?i).*(freelance|job|làm thêm|lam them).*")) {
                suggestedCategory = "Freelance";
            } else if (text.matches("(?i).*(đầu tư|dau tu|cổ tức|lai|lãi).*")) {
                suggestedCategory = "Đầu tư";
            } else if (text.matches("(?i).*(bán|ban|doanh thu).*")) {
                suggestedCategory = "Bán hàng";
            }
        } else {
            if (text.matches("(?i).*(ăn|uống|cơm|phở|bún|quán|cafe|trà|coca).*")) {
                suggestedCategory = "Ăn uống";
            } else if (text.matches("(?i).*(xăng|grab|uber|xe|taxi|di chuyển).*")) {
                suggestedCategory = "Di chuyển";
            } else if (text.matches("(?i).*(mua|sắm|shop|laptop|lap top|máy tính|may tinh|điện thoại|dien thoai).*")) {
                suggestedCategory = "Mua sắm";
            } else if (text.matches("(?i).*(điện|nước|internet|wifi|hóa đơn|hoa don).*")) {
                suggestedCategory = "Hóa đơn";
            }
        }

        Optional<Category> match = findBestMatchingCategory(user.getId(), suggestedCategory, inferredType);

        LocalDate txDate = extractDateFromText(text);

        return AICategorizeResponse.builder()
                .transactionType(inferredType == CategoryType.INCOME ? TransactionType.INCOME.name() : TransactionType.EXPENSE.name())
                .categoryName(suggestedCategory)
                .categoryId(match.map(Category::getId).orElse(null))
                .amount(amount)
                .description(description)
                .transactionDate(txDate != null ? txDate : LocalDate.now())
                .suggestedCategoryName(suggestedCategory)
                .rollyResponse(null)
                .build();
    }

    private String generateRollyResponse(String personality, String description, BigDecimal amount) {
        String amtStr = String.format("%,d", amount.longValue());
        String desc = (description != null && !description.isEmpty()) ? description : "Chi tiêu";

        if ("SAD".equalsIgnoreCase(personality)) {
            return String.format("Ôi không! Bạn đã chi %s₫ cho %s. Tim tôi đau quá! Hãy kiểm soát chi tiêu nhé... 😢", amtStr, desc);
        } else if ("ANGRY".equalsIgnoreCase(personality)) {
            return String.format("Gì vậy?! %s₫ cho %s à? Cẩn thận với thói quen chi tiêu đấy! 💢", amtStr, desc);
        } else {
            return String.format("Wow, bạn đã chi %s₫ cho %s! Thật tuyệt khi tận hưởng cuộc sống. Hãy tiếp tục nuông chiều bản thân nhé! 😊", amtStr, desc);
        }
    }

    private static BigDecimal pickAmount(BigDecimal pythonAmount, BigDecimal fallback) {
        if (pythonAmount != null && pythonAmount.signum() > 0) {
            return pythonAmount;
        }
        return fallback;
    }

    private BigDecimal extractAmount(String text) {
        if (text == null || text.isBlank()) {
            return null;
        }
        String withoutDates = DATE_IN_TEXT.matcher(text).replaceAll(" ");
        BigDecimal best = scanAmounts(withoutDates);
        if (best != null) {
            return best;
        }
        return scanAmounts(text);
    }

    private BigDecimal scanAmounts(String text) {
        Matcher matcher = AMOUNT_PATTERN.matcher(text);
        BigDecimal best = null;
        int bestScore = -1;
        while (matcher.find()) {
            String numStr = matcher.group(1).replaceAll("[.,]", "");
            String unit = matcher.group(2);
            boolean hasUnit = unit != null && !unit.isBlank();
            if (hasUnit) {
                unit = unit.toLowerCase();
                if (unit.matches("k|nghìn|ngàn")) {
                    numStr = numStr + "000";
                } else if (unit.matches("tr|triệu")) {
                    numStr = numStr + "000000";
                } else if (unit.matches("trăm")) {
                    numStr = numStr + "00";
                }
            }
            try {
                BigDecimal val = new BigDecimal(numStr);
                int score = 0;
                if (hasUnit) {
                    score += 100;
                }
                if (val.compareTo(BigDecimal.valueOf(10_000)) >= 0) {
                    score += 20;
                } else if (val.compareTo(BigDecimal.valueOf(1_000)) >= 0) {
                    score += 10;
                } else if (val.compareTo(BigDecimal.valueOf(100)) < 0 && !hasUnit) {
                    continue;
                }
                score += Math.min(numStr.length(), 8);
                if (score > bestScore) {
                    bestScore = score;
                    best = val;
                }
            } catch (NumberFormatException e) {
                log.debug("Could not parse amount from: {}", text);
            }
        }
        return best;
    }

    private String extractCategoryFromJson(String content) {
        try {
            content = content.trim().replaceAll("^```json\\s*|^```\\s*|\\s*```$", "");
            JsonNode node = objectMapper.readTree(content);
            return node.path("category").asText(null);
        } catch (Exception e) {
            return null;
        }
    }

    private Optional<Category> findBestMatchingCategory(Long userId, String categoryName, CategoryType type) {
        List<Category> categories = categoryRepository.findByUserIdAndType(userId, type);
        return categories.stream()
                .filter(c -> c.getName().equalsIgnoreCase(categoryName) ||
                        c.getName().toLowerCase().contains(categoryName.toLowerCase()) ||
                        categoryName.toLowerCase().contains(c.getName().toLowerCase()))
                .findFirst();
    }

    private CategoryType inferCategoryType(String text, Long userId, String categoryName, String typeHint) {
        if (typeHint != null) {
            if ("INCOME".equalsIgnoreCase(typeHint)) return CategoryType.INCOME;
            if ("EXPENSE".equalsIgnoreCase(typeHint)) return CategoryType.EXPENSE;
        }
        if (categoryName != null && !categoryName.isBlank()) {
            List<Category> incomeCategories = categoryRepository.findByUserIdAndType(userId, CategoryType.INCOME);
            boolean isIncomeName = incomeCategories.stream().anyMatch(c ->
                    c.getName().equalsIgnoreCase(categoryName) ||
                            c.getName().toLowerCase().contains(categoryName.toLowerCase()) ||
                            categoryName.toLowerCase().contains(c.getName().toLowerCase()));
            if (isIncomeName) return CategoryType.INCOME;
        }
        String t = text == null ? "" : text.toLowerCase();
        if (t.matches(".*\\b(lương|luong|salary|thưởng|thuong|bonus|thu nhập|thu nhap|bán|ban|doanh thu|freelance|job|hoàn tiền|hoan tien|refund|cashback|lãi|lai|cổ tức|co tuc|đầu tư|dau tu|nhận|nhan|được nhận|duoc nhan|được tặng|duoc tang|thu về|thu ve)\\b.*")) {
            boolean giving = t.matches(".*\\b(cho|tặng|tang|biếu|bieu|mừng|mung|gửi quà|gui qua)\\b.*");
            boolean receiving = t.matches(".*\\b(nhận|nhan|được|duoc|thu về|thu ve|hoàn|hoan|refund|cashback)\\b.*");
            if (!giving || receiving) {
                return CategoryType.INCOME;
            }
        }
        return CategoryType.EXPENSE;
    }

    private static LocalDate parseTransactionDate(String raw) {
        if (raw == null || raw.isBlank()) return null;
        String s = raw.trim();
        if (s.length() >= 10) {
            s = s.substring(0, 10);
        }
        try {
            return LocalDate.parse(s);
        } catch (DateTimeParseException ignored) {
            return null;
        }
    }

    /** Trích ngày từ câu nhập (dd/mm/yyyy) khi Python/API không trả field. */
    private static LocalDate extractDateFromText(String text) {
        if (text == null || text.isBlank()) {
            return null;
        }
        Matcher m = DATE_IN_TEXT.matcher(text);
        if (!m.find()) {
            return null;
        }
        int d = Integer.parseInt(m.group(1));
        int mo = Integer.parseInt(m.group(2));
        int y = Integer.parseInt(m.group(3));
        if (y < 100) {
            y += 2000;
        }
        try {
            return LocalDate.of(y, mo, d);
        } catch (Exception e) {
            return null;
        }
    }
}
