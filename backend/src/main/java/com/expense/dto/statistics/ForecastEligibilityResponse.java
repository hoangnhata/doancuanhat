package com.expense.dto.statistics;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ForecastEligibilityResponse {

    private boolean eligible;

    /** Số ngày có chi tối thiểu để bật dự báo AI (khớp logic kiểm tra phía server). */
    private int requiredDaysWithExpense;

    /** Số ngày trong cửa sổ hiện có giao dịch chi (ước lượng trên 1 VND). */
    private int daysWithExpenseInWindow;

    private int windowDays;

    /** Khi eligible=false: thông báo gợi ý cho người dùng (tiếng Việt). */
    private String messageVi;
}
