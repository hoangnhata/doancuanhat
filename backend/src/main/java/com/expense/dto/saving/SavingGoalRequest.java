package com.expense.dto.saving;

import com.expense.entity.enums.SavingGoalStatus;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;

@Data
public class SavingGoalRequest {

    @NotBlank
    @Size(max = 150)
    private String name;

    @NotNull
    @DecimalMin(value = "0.01", message = "Target amount must be greater than 0")
    private BigDecimal targetAmount;

    private BigDecimal initialAmount;

    private LocalDate targetDate;

    @Size(max = 500)
    private String note;

    private SavingGoalStatus status;
}
