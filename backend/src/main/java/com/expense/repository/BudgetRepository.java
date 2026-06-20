package com.expense.repository;

import com.expense.entity.Budget;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Repository
public interface BudgetRepository extends JpaRepository<Budget, Long> {

    Page<Budget> findByUserId(Long userId, Pageable pageable);

    List<Budget> findByUserIdAndStartDateLessThanEqualAndEndDateGreaterThanEqual(
            Long userId, LocalDate date, LocalDate date2);

    @Query("SELECT b FROM Budget b WHERE b.user.id = :userId " +
           "AND :date BETWEEN b.startDate AND b.endDate " +
           "AND (b.isActive IS NULL OR b.isActive = true)")
    List<Budget> findActiveBudgetsByUserIdAndDate(@Param("userId") Long userId, @Param("date") LocalDate date);

    @Query("SELECT b FROM Budget b WHERE b.user.id = :userId " +
           "AND b.category.id = :categoryId " +
           "AND :date BETWEEN b.startDate AND b.endDate " +
           "AND (b.isActive IS NULL OR b.isActive = true)")
    List<Budget> findActiveByUserIdAndCategoryIdAndDate(
            @Param("userId") Long userId,
            @Param("categoryId") Long categoryId,
            @Param("date") LocalDate date);
}
