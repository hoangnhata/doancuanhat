package com.expense.dto.statistics;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DailyBreakdownResponse {

    private List<DaySummary> days;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class DaySummary {
        private LocalDate date;
        private BigDecimal income;
        private BigDecimal expense;
    }
}
