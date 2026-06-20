package com.expense.repository;

import com.expense.entity.SavingTransaction;
import com.expense.entity.enums.SavingTransactionType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.List;

@Repository
public interface SavingTransactionRepository extends JpaRepository<SavingTransaction, Long> {

    List<SavingTransaction> findBySavingGoalIdOrderByCreatedAtDesc(Long savingGoalId);

    @Query("SELECT COALESCE(SUM(st.amount), 0) FROM SavingTransaction st " +
           "WHERE st.wallet.id = :walletId AND st.user.id = :userId AND st.type = :type")
    BigDecimal sumAmountByWalletAndType(
            @Param("walletId") Long walletId,
            @Param("userId") Long userId,
            @Param("type") SavingTransactionType type);
}
