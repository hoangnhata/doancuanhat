package com.expense.repository;

import com.expense.entity.RecurringTransaction;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface RecurringTransactionRepository extends JpaRepository<RecurringTransaction, Long> {

    List<RecurringTransaction> findByUserIdAndIsActiveTrueOrderByDayOfMonthAsc(Long userId);

    List<RecurringTransaction> findByUserIdOrderByDayOfMonthAsc(Long userId);

    List<RecurringTransaction> findByIsActiveTrueAndDayOfMonth(Integer dayOfMonth);
}
