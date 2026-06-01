package com.expense.controller;

import com.expense.dto.category.CategoryDto;
import com.expense.dto.category.CategoryRequest;
import com.expense.dto.common.ApiResponse;
import com.expense.dto.common.PageResponse;
import com.expense.entity.enums.CategoryType;
import com.expense.service.CategoryService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/categories")
@RequiredArgsConstructor
public class CategoryController {

    private final CategoryService categoryService;

    @PostMapping
    public ResponseEntity<ApiResponse<CategoryDto>> create(@Valid @RequestBody CategoryRequest request) {
        CategoryDto category = categoryService.create(request);
        return ResponseEntity.ok(ApiResponse.success("Category created", category));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<CategoryDto>> getById(@PathVariable Long id) {
        CategoryDto category = categoryService.getById(id);
        return ResponseEntity.ok(ApiResponse.success(category));
    }

    @GetMapping
    public ResponseEntity<ApiResponse<PageResponse<CategoryDto>>> getAll(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) CategoryType type) {
        Pageable pageable = PageRequest.of(page, size, Sort.by("name"));
        PageResponse<CategoryDto> result = categoryService.getAll(pageable, type);
        return ResponseEntity.ok(ApiResponse.success(result));
    }

    @GetMapping("/by-type/{type}")
    public ResponseEntity<ApiResponse<List<CategoryDto>>> getByType(@PathVariable CategoryType type) {
        List<CategoryDto> categories = categoryService.getByType(type);
        return ResponseEntity.ok(ApiResponse.success(categories));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<CategoryDto>> update(
            @PathVariable Long id,
            @Valid @RequestBody CategoryRequest request) {
        CategoryDto category = categoryService.update(id, request);
        return ResponseEntity.ok(ApiResponse.success("Category updated", category));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable Long id) {
        categoryService.delete(id);
        return ResponseEntity.ok(ApiResponse.success("Category deleted", null));
    }
}
