package com.expense.dto.wallet;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class WalletDto {

    private Long id;
    private String name;
    private String currencyCode;
    private BigDecimal initialBalance;
    private Boolean isDefault;
    private LocalDateTime createdAt;
}
