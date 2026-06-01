package com.expense.service;

import com.expense.dto.ai.OcrReceiptResponse;
import com.expense.entity.Category;
import com.expense.entity.User;
import com.expense.entity.enums.CategoryType;
import com.expense.repository.CategoryRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.MediaType;
import org.springframework.http.client.MultipartBodyBuilder;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.reactive.function.BodyInserters;
import org.springframework.web.reactive.function.client.WebClient;

import java.io.IOException;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.List;
import java.util.Optional;

/**
 * Proxy upload ảnh hóa đơn lên FastAPI OCR (EasyOCR + CRNN), sau đó map category về
 * id của user hiện hành để frontend có thể pre-fill form thêm giao dịch.
 */
@Service
@RequiredArgsConstructor
public class ReceiptOcrService {

    private static final Logger log = LoggerFactory.getLogger(ReceiptOcrService.class);

    private final UserService userService;
    private final CategoryRepository categoryRepository;
    private final WebClient.Builder webClientBuilder;
    private final ObjectMapper objectMapper;

    @Value("${ai.categorization.python-api.base-url:http://localhost:8000}")
    private String pythonApiBaseUrl;

    @Value("${ai.ocr.parse-endpoint:/api/ocr/receipt/parse}")
    private String parseEndpoint;

    public OcrReceiptResponse parseReceipt(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new IllegalArgumentException("File rỗng");
        }

        byte[] bytes;
        try {
            bytes = file.getBytes();
        } catch (IOException e) {
            throw new IllegalArgumentException("Không đọc được file ảnh", e);
        }

        MultipartBodyBuilder builder = new MultipartBodyBuilder();
        String filename = file.getOriginalFilename() != null ? file.getOriginalFilename() : "receipt.jpg";
        builder.part("file", new ByteArrayResource(bytes) {
            @Override
            public String getFilename() {
                return filename;
            }
        }).contentType(MediaType.parseMediaType(
                file.getContentType() != null ? file.getContentType() : MediaType.IMAGE_JPEG_VALUE));

        String response;
        try {
            response = webClientBuilder.build()
                    .post()
                    .uri(pythonApiBaseUrl + parseEndpoint)
                    .contentType(MediaType.MULTIPART_FORM_DATA)
                    .body(BodyInserters.fromMultipartData(builder.build()))
                    .retrieve()
                    .bodyToMono(String.class)
                    .block();
        } catch (Exception ex) {
            log.warn("OCR service không phản hồi: {}", ex.getMessage());
            throw new IllegalStateException(
                    "AI OCR service chưa sẵn sàng. Hãy đảm bảo FastAPI đang chạy ở " + pythonApiBaseUrl);
        }

        if (response == null) {
            throw new IllegalStateException("AI OCR service trả về rỗng");
        }

        JsonNode root;
        try {
            root = objectMapper.readTree(response);
        } catch (Exception e) {
            throw new IllegalStateException("Không parse được response OCR", e);
        }

        BigDecimal amount = root.path("amount_vnd").isNumber()
                ? BigDecimal.valueOf(root.path("amount_vnd").asLong())
                : null;
        LocalDate date = parseDate(root.path("transaction_date").asText(null));
        String merchant = optString(root.path("merchant"));
        String description = optString(root.path("description"));
        String categoryName = optString(root.path("category"));
        String typeRaw = optString(root.path("type"));
        Double confidence = root.path("category_confidence").isNumber()
                ? root.path("category_confidence").asDouble() : null;
        String engine = optString(root.path("ocr_engine"));
        boolean needsReview = root.path("needs_review").asBoolean(false);

        if (amount == null || amount.signum() <= 0) {
            needsReview = true;
        }

        // Map category name → id của user (nếu user đã có category cùng tên)
        User user = userService.getCurrentUserEntity();
        CategoryType type = "INCOME".equalsIgnoreCase(typeRaw) ? CategoryType.INCOME : CategoryType.EXPENSE;
        Long categoryId = null;
        if (categoryName != null && !categoryName.isBlank()) {
            categoryId = findBestMatch(user.getId(), categoryName, type)
                    .map(Category::getId)
                    .orElse(null);
        }
        if (categoryId == null) needsReview = true;

        // Description ưu tiên merchant nếu có
        String finalDescription = (description != null && !description.isBlank())
                ? description
                : (merchant != null && !merchant.isBlank() ? merchant : null);

        return OcrReceiptResponse.builder()
                .transactionType(type.name())
                .amount(amount)
                .transactionDate(date)
                .merchant(merchant)
                .description(finalDescription)
                .categoryName(categoryName)
                .categoryId(categoryId)
                .confidence(confidence)
                .needsReview(needsReview)
                .ocrEngine(engine)
                .build();
    }

    private static String optString(JsonNode node) {
        if (node == null || node.isNull() || node.isMissingNode()) return null;
        String s = node.asText("").trim();
        return s.isEmpty() ? null : s;
    }

    private static LocalDate parseDate(String raw) {
        if (raw == null || raw.isBlank()) return null;
        try {
            return LocalDate.parse(raw);
        } catch (DateTimeParseException ignored) {
            return null;
        }
    }

    private Optional<Category> findBestMatch(Long userId, String categoryName, CategoryType type) {
        List<Category> list = categoryRepository.findByUserIdAndType(userId, type);
        String want = categoryName.toLowerCase().trim();
        return list.stream()
                .filter(c -> c.getName().equalsIgnoreCase(categoryName)
                        || c.getName().toLowerCase().contains(want)
                        || want.contains(c.getName().toLowerCase()))
                .findFirst();
    }
}
