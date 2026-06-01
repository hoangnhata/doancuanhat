package com.expense.repository;

import com.expense.entity.Wallet;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface WalletRepository extends JpaRepository<Wallet, Long> {

    List<Wallet> findByUserIdOrderByIsDefaultDescNameAsc(Long userId);

    Optional<Wallet> findByUserIdAndId(Long userId, Long id);

    Optional<Wallet> findByUserIdAndIsDefaultTrue(Long userId);

    boolean existsByUserId(Long userId);
}
