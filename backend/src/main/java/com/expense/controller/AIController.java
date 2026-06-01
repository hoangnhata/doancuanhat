package com.expense.controller;

import com.expense.dto.ai.AISuggestionItemDto;
import com.expense.dto.ai.ChatRequest;
import com.expense.dto.ai.ChatResponse;
import com.expense.dto.common.ApiResponse;
import com.expense.service.AISuggestionService;
import com.expense.service.ChatAssistantService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/ai")
@RequiredArgsConstructor
public class AIController {

    private final AISuggestionService aiSuggestionService;
    private final ChatAssistantService chatAssistantService;

    @GetMapping("/suggestions")
    public ResponseEntity<ApiResponse<List<AISuggestionItemDto>>> getSuggestions() {
        List<AISuggestionItemDto> suggestions = aiSuggestionService.getSuggestions();
        return ResponseEntity.ok(ApiResponse.success(suggestions));
    }

    /**
     * Chatbot Q&A: hỏi về chi tiêu tháng này, ngân sách, lời khuyên tiết kiệm.
     * Server tự đính kèm context (giao dịch 45 ngày + ngân sách) trước khi gửi sang AI.
     */
    @PostMapping("/chat")
    public ResponseEntity<ApiResponse<ChatResponse>> chat(@Valid @RequestBody ChatRequest request) {
        return ResponseEntity.ok(ApiResponse.success(chatAssistantService.ask(request.getMessage())));
    }
}
