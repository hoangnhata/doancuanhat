package com.expense.repository;

import com.expense.entity.PendingRegistration;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.Optional;

@Repository
public interface PendingRegistrationRepository extends JpaRepository<PendingRegistration, Long> {

    Optional<PendingRegistration> findFirstByEmailOrderByCreatedAtDesc(String email);

    @Modifying
    @Query("DELETE FROM PendingRegistration p WHERE p.email = :email")
    void deleteAllByEmail(@Param("email") String email);

    @Modifying
    @Query("DELETE FROM PendingRegistration p WHERE p.expiresAt < :now")
    int deleteExpired(@Param("now") LocalDateTime now);
}
