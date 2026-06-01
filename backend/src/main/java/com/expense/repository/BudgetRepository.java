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
           "AND :date BETWEEN b.startDate AND b.endDate")
    List<Budget> findActiveBudgetsByUserIdAndDate(@Param("userId") Long userId, @Param("date") LocalDate date);

    Optional<Budget> findByUserIdAndCategoryIdAndStartDateLessThanEqualAndEndDateGreaterThanEqual(
            Long userId, Long categoryId, LocalDate date, LocalDate date2);
}
