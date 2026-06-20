package com.expense.service;

import com.expense.dto.ai.OcrReceiptResponse;
import com.expense.exception.BadRequestException;
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
import org.springframework.web.reactive.function.client.WebClientResponseException;

import java.io.IOException;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;

/**
 * Proxy upload ảnh bill chuyển khoản lên FastAPI OCR.
 * Chỉ lấy số tiền + ngày — phân loại danh mục do client gọi /transactions/ai/categorize.
 */
@Service
@RequiredArgsConstructor
public class ReceiptOcrService {

    private static final Logger log = LoggerFactory.getLogger(ReceiptOcrService.class);

    private final WebClient.Builder webClientBuilder;
    private final ObjectMapper objectMapper;

    @Value("${ai.categorization.python-api.base-url:http://localhost:8000}")
    private String pythonApiBaseUrl;

    @Value("${ai.ocr.parse-endpoint:/api/ocr/transfer/parse}")
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
        String filename = file.getOriginalFilename() != null ? file.getOriginalFilename() : "transfer.jpg";
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
        } catch (WebClientResponseException ex) {
            String detail = extractFastApiDetail(ex.getResponseBodyAsString());
            log.warn("OCR API HTTP {}: {}", ex.getStatusCode().value(), detail);
            if (ex.getStatusCode().value() == 503) {
                throw new BadRequestException(
                        detail != null && !detail.isBlank()
                                ? detail
                                : "Model OCR chưa sẵn sàng. Hãy chạy ai_service và đặt ocr_reco_* trong models/.");
            }
            throw new BadRequestException(
                    detail != null && !detail.isBlank()
                            ? detail
                            : "Không phân tích được bill chuyển khoản.");
        } catch (BadRequestException ex) {
            throw ex;
        } catch (Exception ex) {
            log.warn("OCR service không phản hồi: {}", ex.getMessage());
            throw new BadRequestException(
                    "AI OCR service chưa sẵn sàng. Hãy đảm bảo FastAPI đang chạy ở " + pythonApiBaseUrl);
        }

        if (response == null) {
            throw new BadRequestException("AI OCR service trả về rỗng");
        }

        JsonNode root;
        try {
            root = objectMapper.readTree(response);
        } catch (Exception e) {
            throw new BadRequestException("Không parse được response OCR", e);
        }

        BigDecimal amount = root.path("amount_vnd").isNumber()
                ? BigDecimal.valueOf(root.path("amount_vnd").asLong())
                : null;
        LocalDate date = parseDate(root.path("transaction_date").asText(null));
        Double confidence = root.path("confidence").isNumber()
                ? root.path("confidence").asDouble()
                : null;
        String engine = optString(root.path("ocr_engine"));
        boolean needsReview = root.path("needs_review").asBoolean(false);

        if (amount == null || amount.signum() <= 0) {
            needsReview = true;
        }

        return OcrReceiptResponse.builder()
                .transactionType("EXPENSE")
                .amount(amount)
                .transactionDate(date)
                .confidence(confidence)
                .needsReview(needsReview)
                .ocrEngine(engine)
                .bankTransfer(true)
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

    private String extractFastApiDetail(String body) {
        if (body == null || body.isBlank()) {
            return null;
        }
        try {
            JsonNode root = objectMapper.readTree(body);
            JsonNode detail = root.path("detail");
            if (detail.isTextual()) {
                return detail.asText();
            }
            if (detail.isArray() && !detail.isEmpty()) {
                StringBuilder sb = new StringBuilder();
                for (JsonNode item : detail) {
                    if (!sb.isEmpty()) {
                        sb.append("; ");
                    }
                    sb.append(item.path("msg").asText(item.asText("")));
                }
                return sb.toString();
            }
        } catch (Exception ignored) {
            // body không phải JSON FastAPI
        }
        return body.length() > 300 ? body.substring(0, 300) : body;
    }
}
