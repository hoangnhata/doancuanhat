package com.expense.service;

import com.expense.dto.category.CategoryDto;
import com.expense.dto.category.CategoryRequest;
import com.expense.dto.common.PageResponse;
import com.expense.entity.Category;
import com.expense.entity.User;
import com.expense.entity.enums.CategoryType;
import com.expense.exception.BadRequestException;
import com.expense.exception.ResourceNotFoundException;
import com.expense.repository.CategoryRepository;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class CategoryService {

    private static final Logger log = LoggerFactory.getLogger(CategoryService.class);

    /** Danh mục chi tiêu gợi ý (giống onboarding app). */
    private static final String[][] DEFAULT_EXPENSE = {
            {"Ăn uống", "🍔"},
            {"Di chuyển", "🚗"},
            {"Nhà ở", "🏠"},
            {"Hóa đơn", "📄"},
            {"Mua sắm", "🛍️"},
            {"Giải trí", "🎬"},
            {"Du lịch", "🧳"},
            {"Giáo dục", "📚"},
            {"Sức khỏe", "💊"},
            {"Gia đình", "👨‍👩‍👧‍👦"},
            {"Thú cưng", "🐾"},
            {"Quà tặng", "🎁"},
            {"Từ thiện", "🤝"},
            {"Khác", "📌"}
    };
    /** Danh mục thu nhập gợi ý. */
    private static final String[][] DEFAULT_INCOME = {
            {"Lương", "💰"},
            {"Thưởng", "🎁"},
            {"Freelance", "💻"},
            {"Đầu tư", "📈"},
            {"Bán hàng", "🛒"},
            {"Thu nhập khác", "📌"}
    };

    private final CategoryRepository categoryRepository;
    private final UserService userService;

    /**
     * Tạo danh mục mặc định cho loại còn thiếu (user mới hoặc chỉ có chi tiêu / chỉ có thu nhập).
     */
    @Transactional
    public void seedDefaultCategoriesIfEmpty(User user) {
        Long uid = user.getId();
        boolean needExpense = categoryRepository.findByUserIdAndType(uid, CategoryType.EXPENSE).isEmpty();
        boolean needIncome = categoryRepository.findByUserIdAndType(uid, CategoryType.INCOME).isEmpty();
        if (!needExpense && !needIncome) {
            return;
        }
        log.info("Seeding default categories for user id={} (needExpense={}, needIncome={})", uid, needExpense, needIncome);
        if (needExpense) {
            for (String[] row : DEFAULT_EXPENSE) {
                categoryRepository.save(Category.builder()
                        .name(row[0])
                        .icon(row[1])
                        .type(CategoryType.EXPENSE)
                        .user(user)
                        .build());
            }
        }
        if (needIncome) {
            for (String[] row : DEFAULT_INCOME) {
                categoryRepository.save(Category.builder()
                        .name(row[0])
                        .icon(row[1])
                        .type(CategoryType.INCOME)
                        .user(user)
                        .build());
            }
        }
    }

    @Transactional
    public CategoryDto create(CategoryRequest request) {
        User user = userService.getCurrentUserEntity();

        if (categoryRepository.existsByUserIdAndNameAndType(user.getId(), request.getName(), request.getType())) {
            throw new BadRequestException("Category with this name and type already exists");
        }

        Category category = Category.builder()
                .name(request.getName())
                .description(request.getDescription())
                .icon(request.getIcon())
                .type(request.getType())
                .user(user)
                .build();

        category = categoryRepository.save(category);
        log.info("Category created: {} for user {}", category.getName(), user.getId());

        return mapToDto(category);
    }

    public CategoryDto getById(Long id) {
        User user = userService.getCurrentUserEntity();
        Category category = categoryRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Category", "id", id));

        if (!category.getUser().getId().equals(user.getId())) {
            throw new ResourceNotFoundException("Category", "id", id);
        }

        return mapToDto(category);
    }

    public PageResponse<CategoryDto> getAll(Pageable pageable, CategoryType type) {
        User user = userService.getCurrentUserEntity();
        Page<Category> page = type != null
                ? categoryRepository.findByUserIdAndType(user.getId(), type, pageable)
                : categoryRepository.findByUserId(user.getId(), pageable);

        return buildPageResponse(page);
    }

    public List<CategoryDto> getByType(CategoryType type) {
        User user = userService.getCurrentUserEntity();
        return categoryRepository.findByUserIdAndType(user.getId(), type).stream()
                .map(this::mapToDto)
                .collect(Collectors.toList());
    }

    @Transactional
    public CategoryDto update(Long id, CategoryRequest request) {
        User user = userService.getCurrentUserEntity();
        Category category = categoryRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Category", "id", id));

        if (!category.getUser().getId().equals(user.getId())) {
            throw new ResourceNotFoundException("Category", "id", id);
        }

        category.setName(request.getName());
        category.setDescription(request.getDescription());
        category.setIcon(request.getIcon());
        category.setType(request.getType());

        category = categoryRepository.save(category);
        log.info("Category updated: {}", category.getId());

        return mapToDto(category);
    }

    @Transactional
    public void delete(Long id) {
        User user = userService.getCurrentUserEntity();
        Category category = categoryRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Category", "id", id));

        if (!category.getUser().getId().equals(user.getId())) {
            throw new ResourceNotFoundException("Category", "id", id);
        }

        categoryRepository.delete(category);
        log.info("Category deleted: {}", id);
    }

    public Category getCategoryEntity(Long id, Long userId) {
        return categoryRepository.findById(id)
                .filter(c -> c.getUser().getId().equals(userId))
                .orElseThrow(() -> new ResourceNotFoundException("Category", "id", id));
    }

    private CategoryDto mapToDto(Category category) {
        return CategoryDto.builder()
                .id(category.getId())
                .name(category.getName())
                .description(category.getDescription())
                .icon(category.getIcon())
                .type(category.getType())
                .createdAt(category.getCreatedAt())
                .build();
    }

    private PageResponse<CategoryDto> buildPageResponse(Page<Category> page) {
        return PageResponse.<CategoryDto>builder()
                .content(page.getContent().stream().map(this::mapToDto).collect(Collectors.toList()))
                .page(page.getNumber())
                .size(page.getSize())
                .totalElements(page.getTotalElements())
                .totalPages(page.getTotalPages())
                .first(page.isFirst())
                .last(page.isLast())
                .build();
    }
}
