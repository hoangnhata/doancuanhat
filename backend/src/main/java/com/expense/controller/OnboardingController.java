package com.expense.controller;

import com.expense.dto.common.ApiResponse;
import com.expense.dto.user.OnboardingStatusDto;
import com.expense.dto.user.UserDto;
import com.expense.service.OnboardingService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/onboarding")
@RequiredArgsConstructor
public class OnboardingController {

    private final OnboardingService onboardingService;

    @GetMapping("/status")
    public ResponseEntity<ApiResponse<OnboardingStatusDto>> getStatus() {
        return ResponseEntity.ok(ApiResponse.success(onboardingService.getStatus()));
    }

    @PostMapping("/skip-saving-goal")
    public ResponseEntity<ApiResponse<UserDto>> skipSavingGoal() {
        return ResponseEntity.ok(ApiResponse.success("Đã bỏ qua thiết lập mục tiêu tiết kiệm",
                onboardingService.skipSavingGoal()));
    }

    @PostMapping("/complete-saving-goal")
    public ResponseEntity<ApiResponse<UserDto>> completeSavingGoal() {
        return ResponseEntity.ok(ApiResponse.success("Đã hoàn tất thiết lập mục tiêu tiết kiệm",
                onboardingService.completeSavingGoal()));
    }

    @PostMapping("/skip-spending-limit")
    public ResponseEntity<ApiResponse<UserDto>> skipSpendingLimit() {
        return ResponseEntity.ok(ApiResponse.success("Đã bỏ qua thiết lập hạn mức chi tiêu",
                onboardingService.skipSpendingLimit()));
    }

    @PostMapping("/complete-spending-limit")
    public ResponseEntity<ApiResponse<UserDto>> completeSpendingLimit() {
        return ResponseEntity.ok(ApiResponse.success("Đã hoàn tất thiết lập hạn mức chi tiêu",
                onboardingService.completeSpendingLimit()));
    }
}
