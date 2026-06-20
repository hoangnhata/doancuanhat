package com.expense.config;

import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

/**
 * Chạy sau khi JPA sẵn sàng; tạo user demo nếu chưa có (một lần / mỗi DB trống).
 */
@Component
@Order(100)
@ConditionalOnProperty(name = "app.seed.demo-user-enabled", havingValue = "true")
@RequiredArgsConstructor
public class DemoUserDataInitializer implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(DemoUserDataInitializer.class);

    private final DemoUserSeedService demoUserSeedService;

    @Override
    public void run(ApplicationArguments args) {
        try {
            demoUserSeedService.seedDemoUserIfAbsent();
            demoUserSeedService.ensureDemoTransactionsUpToDate();
            demoUserSeedService.ensureDemoBudgetsForCurrentMonth();
        } catch (Exception e) {
            log.error("Demo user seed failed (bỏ qua nếu DB chưa sẵn sàng): {}", e.getMessage());
        }
    }
}
