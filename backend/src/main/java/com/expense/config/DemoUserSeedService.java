package com.expense.config;

import com.expense.entity.Budget;
import com.expense.entity.Category;
import com.expense.entity.Transaction;
import com.expense.entity.User;
import com.expense.entity.Wallet;
import com.expense.entity.enums.CategoryType;
import com.expense.entity.enums.TransactionType;
import com.expense.repository.BudgetRepository;
import com.expense.repository.CategoryRepository;
import com.expense.repository.TransactionRepository;
import com.expense.repository.UserRepository;
import com.expense.repository.WalletRepository;
import com.expense.service.CategoryService;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;

/**
 * Tạo tài khoản demo: lịch sử giống người dùng thật — thu nhập định kỳ, chi đa dạng,
 * ngày không chi, nhiều giao dịch cùng ngày, cuối tuần / đầu tháng khác nhau.
 */
@Service
@RequiredArgsConstructor
public class DemoUserSeedService {

    private static final Logger log = LoggerFactory.getLogger(DemoUserSeedService.class);

    public static final String DEMO_EMAIL = "ai.demo@local.test";
    private static final String DEMO_PASSWORD = "Demo@123456";

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final CategoryService categoryService;
    private final CategoryRepository categoryRepository;
    private final BudgetRepository budgetRepository;
    private final WalletRepository walletRepository;
    private final TransactionRepository transactionRepository;

    @Value("${app.seed.demo-history-days:45}")
    private int demoHistoryDays;

    @Transactional
    public void seedDemoUserIfAbsent() {
        if (userRepository.findByEmail(DEMO_EMAIL).isPresent()) {
            return;
        }
        log.info("Seeding demo AI user: {}", DEMO_EMAIL);

        User user = User.builder()
                .fullName("Demo AI Test")
                .email(DEMO_EMAIL)
                .password(passwordEncoder.encode(DEMO_PASSWORD))
                .botPersonality("HAPPY")
                .onboardingCompleted(true)
                .currencyCode("VND")
                .walletName("Ví demo AI")
                .build();
        user = userRepository.save(user);

        categoryService.seedDefaultCategoriesIfEmpty(user);

        Wallet wallet = Wallet.builder()
                .name("Ví demo AI")
                .currencyCode("VND")
                .initialBalance(new BigDecimal("50000000"))
                .isDefault(true)
                .user(user)
                .build();
        wallet = walletRepository.save(wallet);

        List<Category> expenseCats = categoryRepository.findByUserIdAndType(user.getId(), CategoryType.EXPENSE);
        List<Category> incomeCats = categoryRepository.findByUserIdAndType(user.getId(), CategoryType.INCOME);
        Category defExp = expenseCats.get(0);
        Category defInc = incomeCats.get(0);

        Category catExpense = findCat(expenseCats, "Ăn uống", defExp);
        Category catTransport = findCat(expenseCats, "Di chuyển", defExp);
        Category catBills = findCat(expenseCats, "Hóa đơn", defExp);
        Category catShop = findCat(expenseCats, "Mua sắm", defExp);
        Category catOther = findCat(expenseCats, "Khác", defExp);
        Category catEnt = findCat(expenseCats, "Giải trí", catExpense);

        Category catSalary = findCat(incomeCats, "Lương", defInc);
        Category catBonus = findCat(incomeCats, "Thưởng", defInc);
        Category catFreelance = findCat(incomeCats, "Freelance", defInc);

        LocalDate today = LocalDate.now(ZoneId.of("Asia/Ho_Chi_Minh"));
        int days = Math.max(demoHistoryDays, 35);

        for (int i = days - 1; i >= 0; i--) {
            LocalDate d = today.minusDays(i);
            long epoch = d.toEpochDay();
            int noise = mix(epoch);

            seedIncomeForDay(d, noise, wallet, user, catSalary, catBonus, catFreelance);
            seedExpensesForDay(d, noise, wallet, user,
                    catExpense, catTransport, catBills, catShop, catOther, catEnt);
        }

        seedDemoBudgetsForMonth(user, expenseCats);
        log.info("Demo user ready: {} — {} days of mixed income/expense + demo budgets (see README / login screen for password)", DEMO_EMAIL, days);
    }

    /**
     * Đảm bảo user demo có ngân sách tháng hiện tại để thẻ “Dự báo chi tiêu” luôn có dữ liệu so sánh.
     * Gọi khi khởi động nếu user demo đã tồn tại nhưng chưa có budget active.
     */
    @Transactional
    public void ensureDemoBudgetsForCurrentMonth() {
        userRepository.findByEmail(DEMO_EMAIL).ifPresent(user -> {
            LocalDate today = LocalDate.now(ZoneId.of("Asia/Ho_Chi_Minh"));
            if (!budgetRepository.findActiveBudgetsByUserIdAndDate(user.getId(), today).isEmpty()) {
                return;
            }
            List<Category> expenseCats = categoryRepository.findByUserIdAndType(user.getId(), CategoryType.EXPENSE);
            if (expenseCats.isEmpty()) {
                return;
            }
            seedDemoBudgetsForMonth(user, expenseCats);
            log.info("Added demo budgets for {} (month {})", DEMO_EMAIL, today.getMonthValue());
        });
    }

    private void seedDemoBudgetsForMonth(User user, List<Category> expenseCats) {
        LocalDate today = LocalDate.now(ZoneId.of("Asia/Ho_Chi_Minh"));
        LocalDate start = today.withDayOfMonth(1);
        LocalDate end = today.withDayOfMonth(today.lengthOfMonth());
        Category defExp = expenseCats.get(0);
        Category catFood = findCat(expenseCats, "Ăn uống", defExp);
        Category catTransport = findCat(expenseCats, "Di chuyển", defExp);
        Category catEnt = findCat(expenseCats, "Giải trí", defExp);

        // Mức thấp cho Ăn uống → demo thường vượt (OVER) hoặc gần trần (WARN)
        saveBudget(user, catFood, vnd(2_200_000L), start, end, "Demo: ăn uống tháng này");
        saveBudget(user, catTransport, vnd(1_000_000L), start, end, "Demo: đi lại");
        saveBudget(user, catEnt, vnd(600_000L), start, end, "Demo: giải trí");
    }

    private void saveBudget(User user, Category category, BigDecimal amount, LocalDate start, LocalDate end, String note) {
        Budget b = Budget.builder()
                .amount(amount)
                .startDate(start)
                .endDate(end)
                .category(category)
                .user(user)
                .note(note)
                .build();
        budgetRepository.save(b);
    }

    private static int mix(long epoch) {
        long x = epoch * 0x9E3779B97F4A7C15L;
        x ^= x >>> 30;
        x *= 0xBF58476D1CE4E5B9L;
        x ^= x >>> 27;
        x *= 0x94D049BB133111EBL;
        x ^= x >>> 31;
        return (int) (x & 0x7FFFFFFF);
    }

    private static BigDecimal vnd(long amount) {
        return BigDecimal.valueOf(amount).setScale(2, RoundingMode.HALF_UP);
    }

    private void seedIncomeForDay(LocalDate d, int noise, Wallet wallet, User user,
                                  Category salary, Category bonus, Category freelance) {
        int dom = d.getDayOfMonth();

        // Lương: ngày 5 hàng tháng (phổ biến)
        if (dom == 5) {
            saveTx(TransactionType.INCOME, 14_200_000L + (noise % 800_000), "Lương tháng " + d.getMonthValue(), d, salary, wallet, user);
        }
        // Thưởng / thêm đợt giữa tháng
        if (dom == 20) {
            saveTx(TransactionType.INCOME, 2_800_000L + (noise % 400_000), "Thưởng KPI tháng", d, bonus, wallet, user);
        }
        // Freelance không đều: ~1–2 lần / tháng (deterministic theo epoch)
        if ((noise % 19 == 0) && d.getDayOfWeek() == DayOfWeek.THURSDAY) {
            saveTx(TransactionType.INCOME, 1_100_000L + (noise % 900_000), "Freelance dự án ngắn", d, freelance, wallet, user);
        }
        // Thu nhập nhỏ: hoàn tiền / bán đồ cũ
        if (noise % 37 == 0 && dom != 5 && dom != 20) {
            saveTx(TransactionType.INCOME, 180_000L + (noise % 120_000), "Hoàn tiền / bán lẻ", d, findIncomeFallback(user), wallet, user);
        }
    }

    private Category findIncomeFallback(User user) {
        return categoryRepository.findByUserIdAndType(user.getId(), CategoryType.INCOME).stream()
                .filter(c -> "Thu nhập khác".equals(c.getName()))
                .findFirst()
                .orElse(categoryRepository.findByUserIdAndType(user.getId(), CategoryType.INCOME).get(0));
    }

    private void seedExpensesForDay(LocalDate d, int noise, Wallet wallet, User user,
                                    Category food, Category transport, Category bills, Category shop,
                                    Category other, Category ent) {
        long epoch = d.toEpochDay();
        DayOfWeek dow = d.getDayOfWeek();
        int dom = d.getDayOfMonth();
        boolean weekend = dow == DayOfWeek.SATURDAY || dow == DayOfWeek.SUNDAY;

        // ~14% ngày không chi gì (ở nhà, đã trả trước…)
        if ((noise & 0xFF) < 36) {
            return;
        }

        double weekendBoost = weekend ? 1.28 : 1.0;
        int base = 85_000 + (noise % 140_000);

        // Đầu tháng: hoá đơn lớn
        if (dom == 1) {
            saveTx(TransactionType.EXPENSE, 2_600_000L + (noise % 600_000), "Tiền nhà + điện nước", d, bills, wallet, user);
            saveTx(TransactionType.EXPENSE, 120_000L + (noise % 40_000), "Internet / di động", d, bills, wallet, user);
            return;
        }
        if (dom == 3) {
            saveTx(TransactionType.EXPENSE, 420_000L + (noise % 80_000), "Bảo hiểm / gói trả góp", d, bills, wallet, user);
            return;
        }

        // Cuối tuần: ăn ngoài + cafe cao hơn
        if (weekend) {
            saveTx(TransactionType.EXPENSE, (long) (base * weekendBoost) + 90_000, "Ăn cuối tuần", d, food, wallet, user);
            if ((noise % 3) == 0) {
                saveTx(TransactionType.EXPENSE, 55_000L + (noise % 25_000), "Cafe / trà sữa", d, food, wallet, user);
            }
            if ((noise % 5) == 0) {
                saveTx(TransactionType.EXPENSE, 180_000L + (noise % 100_000), "Xem phim / Giải trí", d, ent, wallet, user);
            }
            return;
        }

        // Ngày trong tuần: đi làm — grab / xăng xen kỳ
        if (dow == DayOfWeek.FRIDAY && (noise % 2) == 0) {
            saveTx(TransactionType.EXPENSE, 75_000L + (noise % 45_000), "Grab về muộn", d, transport, wallet, user);
        } else if ((noise % 4) == 0) {
            saveTx(TransactionType.EXPENSE, 40_000L + (noise % 20_000), "Xăng / xe máy", d, transport, wallet, user);
        }

        // Thỉnh thoảng 2 giao dịch chi trong ngày (cafe + trưa)
        if ((epoch % 11) == 0) {
            saveTx(TransactionType.EXPENSE, 28_000L + (noise % 12_000), "Cafe sáng", d, food, wallet, user);
            saveTx(TransactionType.EXPENSE, 95_000L + (noise % 35_000), "Cơm trưa văn phòng", d, food, wallet, user);
            return;
        }

        // Mua sắm online đợt giữa tháng (chỉ giao dịch shop, không cộng thêm bữa trưa cùng ngày)
        if (dom == 12 && (noise % 2) == 0) {
            saveTx(TransactionType.EXPENSE, 350_000L + (noise % 200_000), "Đồ dùng / Shopee", d, shop, wallet, user);
            return;
        }

        // Chi tiêu hằng ngày mặc định
        String[] lunch = {"Bún chả", "Cơm tấm", "Phở", "Bánh mì", "Cơm gà"};
        saveTx(TransactionType.EXPENSE, (long) (base * weekendBoost),
                lunch[(int) (epoch % lunch.length)] + " trưa", d, food, wallet, user);

        if ((noise % 7) == 0) {
            saveTx(TransactionType.EXPENSE, 65_000L + (noise % 30_000), "Chi lặt vặt", d, other, wallet, user);
        }
    }

    private void saveTx(TransactionType type, long amountVnd, String desc, LocalDate date,
                        Category category, Wallet wallet, User user) {
        if (amountVnd < 1) {
            return;
        }
        BigDecimal amount = vnd(amountVnd);
        if (amount.compareTo(new BigDecimal("0.01")) < 0) {
            return;
        }
        Transaction tx = Transaction.builder()
                .type(type)
                .amount(amount)
                .description(desc)
                .transactionDate(date)
                .category(category)
                .wallet(wallet)
                .user(user)
                .build();
        transactionRepository.save(tx);
    }

    private static Category findCat(List<Category> cats, String name, Category fallback) {
        return cats.stream()
                .filter(c -> name.equals(c.getName()))
                .findFirst()
                .orElse(fallback);
    }
}
