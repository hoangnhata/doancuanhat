package com.expense.repository;

import com.expense.entity.SavingGoal;
import com.expense.entity.enums.SavingGoalStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface SavingGoalRepository extends JpaRepository<SavingGoal, Long> {

    List<SavingGoal> findByUserIdOrderByCreatedAtDesc(Long userId);

    Optional<SavingGoal> findByUserIdAndId(Long userId, Long id);

    long countByUserIdAndStatusNot(Long userId, SavingGoalStatus status);
}
