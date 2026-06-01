package com.expense.dto.recurring;

import com.expense.dto.category.CategoryDto;
import com.expense.entity.enums.TransactionType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RecurringTransactionDto {

    private Long id;
    private TransactionType type;
    private BigDecimal amount;
    private String description;
    private Integer dayOfMonth;
    private LocalDate startDate;
    private LocalDate endDate;
    private Boolean isActive;
    private CategoryDto category;
}
