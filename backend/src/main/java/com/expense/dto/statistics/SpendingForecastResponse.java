package com.expense.dto.statistics;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SpendingForecastResponse {

    private List<Long> predictedNextDaysVnd;
    private int horizon;
    private int window;
    /** Ngày cuối của chuỗi đầu vào (YYYY-MM-DD) */
    private String lastObservationDate;

    private ForecastInsightDto insight;
}
