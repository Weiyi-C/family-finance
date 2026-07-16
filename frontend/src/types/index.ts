// ---- Auth ----
export interface RegisterRequest {
  phone: string
  password: string
  nickname: string
  family_name?: string
}

export interface LoginRequest {
  phone: string
  password: string
}

export interface TokenResponse {
  access_token: string
  refresh_token: string
  token_type: string
}

export interface RegisterResponse {
  user: {
    id: number
    nickname: string
    phone: string
    avatar_url: string | null
    role: string
    family_id: number
  }
  tokens: TokenResponse
}

export interface UserMe {
  id: number
  phone: string
  nickname: string
  avatar_url: string | null
  role: string
  family_id: number
}

// ---- Book ----
export interface AccountBook {
  id: number
  family_id: number
  name: string
  description: string | null
  icon: string | null
  is_default: boolean
  is_archived: boolean
  created_at: string
}

export interface BookCreate {
  name: string
  description?: string
  icon?: string
}

export interface BookUpdate {
  name?: string
  description?: string
  icon?: string
}

// ---- Category ----
export interface Category {
  id: number
  name: string
  type: string
  icon: string | null
  color: string | null
  parent_id: number | null
  level: number
  sort_order: number
  family_id: number | null
  is_active: boolean
  children?: Category[]
}

export interface CategoryCreate {
  name: string
  type: string
  icon?: string
  color?: string
  parent_id?: number
  sort_order?: number
}

export interface CategoryUpdate {
  name?: string
  icon?: string
  color?: string
  sort_order?: number
  is_active?: boolean
}

// ---- Account ----
export interface PaymentAccount {
  id: number
  family_id: number
  name: string
  type_code: string
  template_id: number | null
  icon: string | null
  color: string | null
  currency: string
  balance: number
  available_balance: number | null
  credit_limit: number | null
  billing_day: number | null
  due_day: number | null
  grace_days: number | null
  bank_name: string | null
  bank_code: string | null
  card_tail: string | null
  card_type: string | null
  is_shared: boolean
  is_active: boolean
  include_in_total: boolean
  notes: string | null
  created_at: string
}

export interface AccountCreate {
  name: string
  type_code: string
  template_id?: number
  icon?: string
  color?: string
  currency?: string
  initial_balance?: number
  credit_limit?: number
  billing_day?: number
  due_day?: number
  grace_days?: number
  bank_name?: string
  bank_code?: string
  card_tail?: string
  card_type?: string
  is_shared?: boolean
  include_in_total?: boolean
  notes?: string
}

export interface AccountUpdate extends Partial<AccountCreate> {}

export interface AccountBalance {
  account_id: number
  name: string
  balance: number
  available: number | null
}

// ---- Transaction ----
export interface Transaction {
  id: number
  family_id: number
  book_id: number
  entry_id: number | null
  type: string
  amount: number
  currency: string
  original_amount: number | null
  original_currency: string | null
  exchange_rate: number | null
  category_id: number | null
  sub_category_id: number | null
  detail_category_id: number | null
  payment_account_id: number | null
  payment_channel_id: number | null
  platform_id: number | null
  merchant_name: string | null
  description: string | null
  transaction_time: string
  recorded_by: number
  paid_by: number | null
  is_quick_entry: boolean
  completion_status: string
  version: number
  tag_ids: number[]
}

export interface TransactionCreate {
  type: string
  amount: number
  transaction_time: string
  book_id: number
  category_id?: number
  sub_category_id?: number
  detail_category_id?: number
  payment_account_id?: number
  payment_channel_id?: number
  platform_id?: number
  merchant_name?: string
  description?: string
  tag_ids?: number[]
  is_quick_entry?: boolean
}

export interface TransactionUpdate {
  type?: string
  amount?: number
  transaction_time?: string
  category_id?: number
  sub_category_id?: number
  payment_account_id?: number
  payment_channel_id?: number
  platform_id?: number
  merchant_name?: string
  description?: string
  tag_ids?: number[]
}

export interface TransactionListParams {
  book_id?: number
  type?: string
  category_id?: number
  payment_account_id?: number
  merchant_name?: string
  keyword?: string
  start_date?: string
  end_date?: string
  min_amount?: number
  max_amount?: number
  page?: number
  page_size?: number
}

// ---- Tag ----
export interface Tag {
  id: number
  family_id: number
  name: string
  color: string | null
  usage_count: number
  created_at: string
}

export interface TagCreate {
  name: string
  color?: string
}

export interface TagUpdate {
  name?: string
  color?: string
}

// ---- Budget ----
export interface Budget {
  id: number
  family_id: number
  category_id: number | null
  name: string
  amount: number
  period: string
  year: number
  month: number | null
  week_number: number | null
  rollover: boolean
  alert_threshold: number
  created_at: string
}

export interface BudgetCreate {
  name: string
  amount: number
  period: string
  category_id?: number
  year: number
  month?: number
  week_number?: number
  rollover?: boolean
  alert_threshold?: number
}

export interface BudgetUpdate extends Partial<BudgetCreate> {}

export interface BudgetUsage {
  budget_id: number
  name: string
  amount: number
  spent: number
  remaining: number
  percentage: number
}

// ---- Debt ----
export interface Debt {
  id: number
  family_id: number
  type: string
  person_name: string
  amount: number
  remaining_amount: number
  currency: string
  interest_rate: number | null
  due_date: string | null
  note: string | null
  status: string
  created_at: string
}

export interface DebtCreate {
  type: string
  person_name: string
  amount: number
  currency?: string
  interest_rate?: number
  due_date?: string
  note?: string
}

export interface DebtUpdate extends Partial<DebtCreate> {}

export interface RepaymentCreate {
  amount: number
  note?: string
}

export interface RepaymentResponse {
  id: number
  debt_id: number
  amount: number
  note: string | null
  created_at: string
}

// ---- Recurring ----
export interface RecurringTransaction {
  id: number
  family_id: number
  type: string
  amount: number
  category_id: number | null
  payment_account_id: number | null
  merchant_name: string | null
  note: string | null
  frequency: string
  day_of_month: number | null
  day_of_week: number | null
  start_date: string
  end_date: string | null
  next_generate: string | null
  is_active: boolean
  created_at: string
}

export interface RecurringCreate {
  type: string
  amount: number
  frequency: string
  category_id?: number
  payment_account_id?: number
  merchant_name?: string
  note?: string
  day_of_month?: number
  day_of_week?: number
  start_date: string
  end_date?: string
}

export interface RecurringUpdate extends Partial<RecurringCreate> {
  is_active?: boolean
}

export interface RecurringLog {
  id: number
  recurring_id: number
  transaction_id: number | null
  status: string
  error_message: string | null
  generated_at: string
}

// ---- Reimbursement ----
export interface Reimbursement {
  id: number
  family_id: number
  title: string
  status: string
  total_amount: number
  submitted_at: string | null
  approved_at: string | null
  received_at: string | null
  notes: string | null
  items: ReimbursementItem[]
  created_at: string
}

export interface ReimbursementItem {
  id: number
  reimbursement_id: number
  transaction_id: number | null
  description: string
  amount: number
  category_id: number | null
  note: string | null
}

export interface ReimbursementCreate {
  title: string
  notes?: string
  items: ReimbursementItemCreate[]
}

export interface ReimbursementItemCreate {
  transaction_id?: number
  description: string
  amount: number
  category_id?: number
  note?: string
}

export interface ReimbursementUpdate {
  title?: string
  notes?: string
}

export interface ReceiveRequest {
  account_id: number
}

// ---- Stats ----
export interface StatsSummary {
  total_expense: number
  total_income: number
  net: number
  count: number
}

export interface CategoryStats {
  category_id: number
  total: number
  count: number
}

export interface MonthlyStats {
  month: string
  expense: number
  income: number
}

export interface DailyStats {
  date: string
  total: number
  count: number
}

export interface MerchantRank {
  merchant: string
  total: number
  count: number
}

// ---- Channel & Platform ----
export interface Channel {
  id: number
  name: string
  icon: string | null
  family_id: number | null
  is_active: boolean
}

export interface ChannelCreate {
  name: string
  icon?: string
}

export interface ChannelUpdate {
  name?: string
  icon?: string
}

export interface Platform {
  id: number
  name: string
  type: string
  icon: string | null
  family_id: number | null
  is_active: boolean
}

export interface PlatformCreate {
  name: string
  type: string
  icon?: string
}

export interface PlatformUpdate {
  name?: string
  type?: string
  icon?: string
}

// ---- Savings ----
export interface SavingsGoal {
  id: number
  family_id: number
  name: string
  target_amount: number
  current_amount: number
  currency: string
  deadline: string | null
  icon: string | null
  status: string
  created_at: string
}

export interface SavingsGoalCreate {
  name: string
  target_amount: number
  currency?: string
  deadline?: string
  icon?: string
}

export interface SavingsGoalUpdate extends Partial<SavingsGoalCreate> {}

export interface DepositRequest {
  amount: number
}

// ---- Settings ----
export interface UserSettings {
  id: number
  user_id: number
  default_currency: string
  month_start_day: number
  theme: string
  language: string
  date_format: string
  number_format: string
  default_book_id: number | null
  quick_entry_mode: string
  confirm_before_save: boolean
  notify_budget_alert: boolean
  notify_recurring: boolean
  notify_sync: boolean
  quiet_hours_start: string | null
  quiet_hours_end: string | null
  auto_sync: boolean
  sync_on_wifi_only: boolean
  settings_json: Record<string, unknown> | null
}

export interface SettingsUpdate {
  default_currency?: string
  month_start_day?: number
  theme?: string
  language?: string
  date_format?: string
  number_format?: string
  default_book_id?: number
  quick_entry_mode?: string
  confirm_before_save?: boolean
  notify_budget_alert?: boolean
  notify_recurring?: boolean
  notify_sync?: boolean
  quiet_hours_start?: string
  quiet_hours_end?: string
  auto_sync?: boolean
  sync_on_wifi_only?: boolean
  settings_json?: Record<string, unknown>
}

// ---- Notification ----
export interface Notification {
  id: number
  user_id: number
  family_id: number
  type: string
  title: string
  content: string | null
  related_id: number | null
  related_type: string | null
  is_read: boolean
  read_at: string | null
  channel: string
  send_status: string
  created_at?: string
}
