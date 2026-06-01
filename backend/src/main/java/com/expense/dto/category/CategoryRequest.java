package com.expense.dto.category;

import com.expense.entity.enums.CategoryType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class CategoryRequest {

    @NotBlank(message = "Category name is required")
    @Size(min = 1, max = 100)
    private String name;

    @Size(max = 255)
    private String description;

    @Size(max = 50)
    private String icon;

    @NotNull(message = "Category type is required")
    private CategoryType type;
}
