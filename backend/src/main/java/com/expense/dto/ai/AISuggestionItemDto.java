package com.expense.dto.ai;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AISuggestionItemDto {
    private String categoryName;
    private BigDecimal amount;
    private String suggestion;
    private Integer percentPossible;
}
