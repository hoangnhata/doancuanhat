package com.expense.config;

import com.expense.service.RecurringTransactionService;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDate;

@Component
@RequiredArgsConstructor
public class RecurringScheduledJob {

    private static final Logger log = LoggerFactory.getLogger(RecurringScheduledJob.class);

    private final RecurringTransactionService recurringTransactionService;

    @Scheduled(cron = "0 0 0 * * *") // Chạy mỗi ngày lúc 00:00
    public void processRecurringTransactions() {
        LocalDate today = LocalDate.now();
        log.info("Processing recurring transactions for date {}", today);
        try {
            recurringTransactionService.processRecurringForDate(today);
        } catch (Exception e) {
            log.error("Error processing recurring transactions", e);
        }
    }
}
