package com.expense.dto.wallet;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.math.BigDecimal;

@Data
public class WalletRequest {

    @NotBlank(message = "Wallet name is required")
    @Size(min = 1, max = 100)
    private String name;

    @NotBlank(message = "Currency code is required")
    @Size(min = 1, max = 10)
    private String currencyCode;

    @NotNull(message = "Initial balance is required")
    @DecimalMin(value = "0", message = "Initial balance must be >= 0")
    private BigDecimal initialBalance;

    private Boolean isDefault;
}
