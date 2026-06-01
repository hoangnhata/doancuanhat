package com.expense.dto.statistics;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * Tom tat du bao cho nguoi dung: tong tuan, so voi muc co so, goi y kiem soat chi.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ForecastInsightDto {

    private long totalNext7DaysVnd;
    private long avgPerDayVnd;
    /** Trung binh 30 ngay * 7 — chuan so sanh */
    private long baseline7DaysVnd;
    /** % chenh so voi baseline; am = thap hon */
    private Integer paceVsBaselinePercent;

    /** OK | WATCH | ALERT */
    private String level;

    private String headlineVi;
    private List<String> tipsVi;

    private Long expenseMonthToDateVnd;
    private Long forecastOverlapSameMonthVnd;
    private Long projectedMonthFloorVnd;

    private List<ForecastBudgetAlertDto> budgetAlerts;
}
