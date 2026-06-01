package com.expense.repository;

import com.expense.entity.Transaction;
import com.expense.entity.enums.TransactionType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

@Repository
public interface TransactionRepository extends JpaRepository<Transaction, Long> {

    Page<Transaction> findByUserId(Long userId, Pageable pageable);

    Page<Transaction> findByUserIdAndType(Long userId, TransactionType type, Pageable pageable);

    Page<Transaction> findByUserIdAndCategoryId(Long userId, Long categoryId, Pageable pageable);

    Page<Transaction> findByUserIdAndTransactionDateBetween(Long userId, LocalDate start, LocalDate end, Pageable pageable);

    @Query("SELECT t FROM Transaction t WHERE t.user.id = :userId " +
           "AND (:walletId IS NULL OR t.wallet.id = :walletId OR (:includeLegacy = true AND t.wallet IS NULL)) " +
           "AND (:type IS NULL OR t.type = :type) " +
           "AND (:categoryId IS NULL OR t.category.id = :categoryId) " +
           "AND (:startDate IS NULL OR t.transactionDate >= :startDate) " +
           "AND (:endDate IS NULL OR t.transactionDate <= :endDate)")
    Page<Transaction> findByUserIdWithFilters(
            @Param("userId") Long userId,
            @Param("walletId") Long walletId,
            @Param("includeLegacy") boolean includeLegacy,
            @Param("type") TransactionType type,
            @Param("categoryId") Long categoryId,
            @Param("startDate") LocalDate startDate,
            @Param("endDate") LocalDate endDate,
            Pageable pageable);

    @Query("SELECT COALESCE(SUM(t.amount), 0) FROM Transaction t WHERE t.user.id = :userId " +
           "AND t.type = :type AND t.transactionDate BETWEEN :startDate AND :endDate")
    BigDecimal sumAmountByUserIdAndTypeAndDateRange(
            @Param("userId") Long userId,
            @Param("type") TransactionType type,
            @Param("startDate") LocalDate startDate,
            @Param("endDate") LocalDate endDate);

    @Query("SELECT COALESCE(SUM(t.amount), 0) FROM Transaction t WHERE t.user.id = :userId " +
           "AND t.type = :type AND t.transactionDate BETWEEN :startDate AND :endDate " +
           "AND (:walletId IS NULL OR t.wallet.id = :walletId OR (:includeLegacy = true AND t.wallet IS NULL))")
    BigDecimal sumAmountByUserIdAndTypeAndDateRangeWithWallet(
            @Param("userId") Long userId,
            @Param("type") TransactionType type,
            @Param("startDate") LocalDate startDate,
            @Param("endDate") LocalDate endDate,
            @Param("walletId") Long walletId,
            @Param("includeLegacy") boolean includeLegacy);

    @Query("SELECT t.category.id, COALESCE(SUM(t.amount), 0) FROM Transaction t " +
           "WHERE t.user.id = :userId AND t.type = :type " +
           "AND t.transactionDate BETWEEN :startDate AND :endDate " +
           "GROUP BY t.category.id")
    List<Object[]> sumAmountByCategoryAndDateRange(
            @Param("userId") Long userId,
            @Param("type") TransactionType type,
            @Param("startDate") LocalDate startDate,
            @Param("endDate") LocalDate endDate);

    @Query("SELECT t.category.id, COALESCE(SUM(t.amount), 0) FROM Transaction t " +
           "WHERE t.user.id = :userId AND t.type = :type " +
           "AND t.transactionDate BETWEEN :startDate AND :endDate " +
           "AND (:walletId IS NULL OR t.wallet.id = :walletId OR (:includeLegacy = true AND t.wallet IS NULL)) " +
           "GROUP BY t.category.id")
    List<Object[]> sumAmountByCategoryAndDateRangeWithWallet(
            @Param("userId") Long userId,
            @Param("type") TransactionType type,
            @Param("startDate") LocalDate startDate,
            @Param("endDate") LocalDate endDate,
            @Param("walletId") Long walletId,
            @Param("includeLegacy") boolean includeLegacy);

    @Query("SELECT t FROM Transaction t WHERE t.user.id = :userId " +
           "AND t.transactionDate BETWEEN :startDate AND :endDate ORDER BY t.transactionDate DESC")
    List<Transaction> findByUserIdAndTransactionDateBetweenAll(
            @Param("userId") Long userId,
            @Param("startDate") LocalDate startDate,
            @Param("endDate") LocalDate endDate);

    boolean existsByRecurringTransactionIdAndTransactionDate(Long recurringTransactionId, LocalDate transactionDate);

    @Query("SELECT t.transactionDate, t.type, SUM(t.amount) FROM Transaction t " +
           "WHERE t.user.id = :userId AND t.transactionDate BETWEEN :startDate AND :endDate " +
           "GROUP BY t.transactionDate, t.type")
    List<Object[]> sumAmountByDateAndType(
            @Param("userId") Long userId,
            @Param("startDate") LocalDate startDate,
            @Param("endDate") LocalDate endDate);

    /**
     * Tổng chi (EXPENSE) theo danh mục trong khoảng ngày — dùng cho ngân sách.
     */
    @Query("SELECT COALESCE(SUM(t.amount), 0) FROM Transaction t WHERE t.user.id = :userId " +
           "AND t.type = :type AND t.category.id = :categoryId " +
           "AND t.transactionDate BETWEEN :startDate AND :endDate")
    BigDecimal sumAmountByUserCategoryTypeAndDateRange(
            @Param("userId") Long userId,
            @Param("categoryId") Long categoryId,
            @Param("type") TransactionType type,
            @Param("startDate") LocalDate startDate,
            @Param("endDate") LocalDate endDate);

    /**
     * Tổng chi (EXPENSE) theo từng ngày — dùng cho dự báo AI (cửa sổ 30 ngày).
     */
    @Query("SELECT t.transactionDate, COALESCE(SUM(t.amount), 0) FROM Transaction t " +
           "WHERE t.user.id = :userId AND t.type = :expenseType " +
           "AND t.transactionDate BETWEEN :startDate AND :endDate " +
           "AND (:walletId IS NULL OR t.wallet.id = :walletId OR (:includeLegacy = true AND t.wallet IS NULL)) " +
           "GROUP BY t.transactionDate ORDER BY t.transactionDate")
    List<Object[]> sumExpenseAmountByDayWithWallet(
            @Param("userId") Long userId,
            @Param("expenseType") TransactionType expenseType,
            @Param("startDate") LocalDate startDate,
            @Param("endDate") LocalDate endDate,
            @Param("walletId") Long walletId,
            @Param("includeLegacy") boolean includeLegacy);
}
