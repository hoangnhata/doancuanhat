export interface User {
  id: number;
  fullName: string;
  email: string;
  phone?: string | null;
  botPersonality?: string | null;
  botSetupCompleted?: boolean;
  onboardingCompleted: boolean;
  walletSetupCompleted?: boolean;
  savingGoalSetupCompleted?: boolean;
  savingGoalSetupSkipped?: boolean;
  spendingLimitSetupCompleted?: boolean;
  spendingLimitSetupSkipped?: boolean;
  onboardingStep?: string | null;
}

export type SavingGoalStatus = "ACTIVE" | "COMPLETED" | "PAUSED" | "CANCELLED";
export type SavingTransactionType = "DEPOSIT" | "WITHDRAW";

export interface SavingGoal {
  id: number;
  name: string;
  targetAmount: number;
  currentAmount: number;
  targetDate?: string | null;
  status: SavingGoalStatus;
  note?: string | null;
  remainingAmount: number;
  progressPercent: number;
  isCompleted: boolean;
  createdAt?: string;
  updatedAt?: string;
}

export interface SavingTransaction {
  id: number;
  savingGoalId: number;
  wallet?: Wallet;
  amount: number;
  type: SavingTransactionType;
  note?: string | null;
  createdAt: string;
}

export interface AuthPayload {
  accessToken: string;
  refreshToken: string;
  user: User;
}

export interface Category {
  id: number;
  name: string;
  description?: string | null;
  icon?: string | null;
  type: "EXPENSE" | "INCOME";
}

export interface Wallet {
  id: number;
  name: string;
  currencyCode: string;
  initialBalance: number;
  currentBalance?: number;
  isDefault: boolean;
}

export interface Transaction {
  id: number;
  type: "EXPENSE" | "INCOME";
  amount: number;
  description?: string | null;
  transactionDate: string;
  category: Category;
  walletId?: number | null;
  createdAt: string;
}

export interface PageResponse<T> {
  content: T[];
  page: number;
  size: number;
  totalElements: number;
  totalPages: number;
}

export interface Statistics {
  totalIncome: number;
  totalExpense: number;
  balance: number;
  byCategory: { categoryId: number; categoryName: string; amount: number }[];
}

export interface ForecastBudgetAlert {
  categoryName: string;
  budgetAmountVnd: number;
  spentVnd: number;
  remainingVnd: number;
  percentUsed: number;
  severity: "OVER" | "WARN" | "OK";
}

export interface ForecastInsight {
  totalNext7DaysVnd: number;
  avgPerDayVnd: number;
  baseline7DaysVnd: number;
  paceVsBaselinePercent: number | null;
  level: "OK" | "WATCH" | "ALERT";
  headlineVi: string;
  tipsVi: string[];
  expenseMonthToDateVnd?: number | null;
  forecastOverlapSameMonthVnd?: number | null;
  projectedMonthFloorVnd?: number | null;
  budgetAlerts: ForecastBudgetAlert[];
}

/** Dự báo chi tiêu 7 ngày tới (backend → ai_service). */
export interface SpendingForecast {
  predictedNextDaysVnd: number[];
  horizon: number;
  window: number;
  lastObservationDate: string;
  insight?: ForecastInsight | null;
}

/** Đủ điều kiện để gọi dự báo AI hay chưa. */
export interface ForecastEligibility {
  eligible: boolean;
  requiredDaysWithExpense: number;
  daysWithExpenseInWindow: number;
  windowDays: number;
  messageVi?: string | null;
}

export interface AICategorizeResponse {
  /** EXPENSE | INCOME (backend returns this) */
  transactionType?: "EXPENSE" | "INCOME" | string | null;
  categoryName: string;
  categoryId?: number | null;
  amount?: number | null;
  description?: string | null;
  /** YYYY-MM-DD */
  transactionDate?: string | null;
  suggestedCategoryName?: string | null;
  rollyResponse?: string | null;
}

export interface Budget {
  id: number;
  amount: number;
  startDate: string;
  endDate: string;
  categoryId: number;
  category?: Category;
  note?: string | null;
}

export interface RecurringTransaction {
  id: number;
  amount: number;
  description?: string | null;
  type: "EXPENSE" | "INCOME";
  dayOfMonth: number;
  categoryId: number;
  category?: Category;
  walletId?: number | null;
  active: boolean;
}

export interface DaySummary {
  date: string;
  income: number;
  expense: number;
}
