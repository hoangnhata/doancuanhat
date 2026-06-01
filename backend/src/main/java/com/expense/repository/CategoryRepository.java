package com.expense.repository;

import com.expense.entity.Category;
import com.expense.entity.enums.CategoryType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CategoryRepository extends JpaRepository<Category, Long> {

    List<Category> findByUserIdAndType(Long userId, CategoryType type);

    Page<Category> findByUserId(Long userId, Pageable pageable);

    Page<Category> findByUserIdAndType(Long userId, CategoryType type, Pageable pageable);

    boolean existsByUserIdAndNameAndType(Long userId, String name, CategoryType type);
}
