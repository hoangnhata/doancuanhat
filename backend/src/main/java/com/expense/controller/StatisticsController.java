package com.expense.controller;

import com.expense.dto.common.ApiResponse;
import com.expense.dto.statistics.DailyBreakdownResponse;
import com.expense.dto.statistics.ForecastEligibilityResponse;
import com.expense.dto.statistics.SpendingForecastResponse;
import com.expense.dto.statistics.StatisticsResponse;
import com.expense.entity.enums.TransactionType;
import com.expense.service.SpendingForecastService;
import com.expense.service.StatisticsService;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;

@RestController
@RequestMapping("/statistics")
@RequiredArgsConstructor
public class StatisticsController {

    private final StatisticsService statisticsService;
    private final SpendingForecastService spendingForecastService;

    @GetMapping("/day")
    public ResponseEntity<ApiResponse<StatisticsResponse>> getByDay(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
            @RequestParam(required = false) Long walletId) {
        StatisticsResponse stats = statisticsService.getStatisticsByDay(date, walletId);
        return ResponseEntity.ok(ApiResponse.success(stats));
    }

    @GetMapping("/month")
    public ResponseEntity<ApiResponse<StatisticsResponse>> getByMonth(
            @RequestParam int year,
            @RequestParam int month,
            @RequestParam(required = false) TransactionType categoryType,
            @RequestParam(required = false) Long walletId) {
        StatisticsResponse stats = statisticsService.getStatisticsByMonth(year, month, categoryType, walletId);
        return ResponseEntity.ok(ApiResponse.success(stats));
    }

    @GetMapping("/year")
    public ResponseEntity<ApiResponse<StatisticsResponse>> getByYear(
            @RequestParam int year,
            @RequestParam(required = false) TransactionType categoryType,
            @RequestParam(required = false) Long walletId) {
        StatisticsResponse stats = statisticsService.getStatisticsByYear(year, categoryType, walletId);
        return ResponseEntity.ok(ApiResponse.success(stats));
    }

    @GetMapping("/range")
    public ResponseEntity<ApiResponse<StatisticsResponse>> getByDateRange(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate,
            @RequestParam(required = false) TransactionType categoryType,
            @RequestParam(required = false) Long walletId) {
        StatisticsResponse stats = statisticsService.getStatisticsByDateRange(startDate, endDate, categoryType, walletId);
        return ResponseEntity.ok(ApiResponse.success(stats));
    }

    @GetMapping("/daily-breakdown")
    public ResponseEntity<ApiResponse<DailyBreakdownResponse>> getDailyBreakdown(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate) {
        DailyBreakdownResponse response = statisticsService.getDailyBreakdown(startDate, endDate);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    /**
     * Kiểm tra đã đủ ngày có chi trong cửa sổ để dùng dự báo AI hay chưa.
     */
    @GetMapping("/spending-forecast/eligibility")
    public ResponseEntity<ApiResponse<ForecastEligibilityResponse>> getForecastEligibility(
            @RequestParam(required = false) Long walletId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate lastObservationDate) {
        ForecastEligibilityResponse response = spendingForecastService.getForecastEligibility(walletId, lastObservationDate);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    /**
     * Dự báo tổng chi tiêu 7 ngày tới (Transformer trong ai_service). Cần ai_service chạy và có forecast_model.pt.
     */
    @GetMapping("/spending-forecast")
    public ResponseEntity<ApiResponse<SpendingForecastResponse>> getSpendingForecast(
            @RequestParam(required = false) Long walletId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate lastObservationDate) {
        SpendingForecastResponse response = spendingForecastService.forecastSpending(walletId, lastObservationDate);
        return ResponseEntity.ok(ApiResponse.success(response));
    }
}
