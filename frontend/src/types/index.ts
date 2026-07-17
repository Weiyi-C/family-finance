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
  user_id: number
  name: string
  type_code: string
  template_id: number | null
  icon: string | null
  color: string | null
  currency: string
  balance: number
  initial_balance: number
  available_balance: number | null
  credit_limit: number | null
  used_amount: number | null
  billing_day: number | null
  due_day: number | null
  grace_days: number | null
  bank_name: string | null
  bank_code: string | null
  bank_id: number | null
  card_tail: string | null
  card_type: string | null
  is_shared: boolean
  shared_with: number | null
  share_type: string | null
  is_active: boolean
  is_hidden: boolean
  include_in_total: boolean
  notes: string | null
  parent_id: number | null
  channel_id: number | null
  linked_account_id: number | null
  linked_user_id: number | null
  platform_id: number | null
  group_label: string | null
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
  book_id: number | null
  category_id: number | null
  amount: number
  currency: string
  period: string
  year: number
  month: number | null
  week_start_date: string | null
  rollover: boolean
  rollover_amount: number
  alert_threshold: number
}

export interface BudgetCreate {
  book_id?: number
  category_id?: number
  amount: number
  currency?: string
  period: string
  year: number
  month?: number
  week_start_date?: string
  rollover?: boolean
  alert_threshold?: number
}

export interface BudgetUpdate {
  amount?: number
  rollover?: boolean
  alert_threshold?: number
}

export interface BudgetUsage {
  budget_id: number
  amount: number
  spent: number
  remaining: number
  usage_rate: number
  is_over: boolean
  period_start: string
  period_end: string
}

// ---- Debt ----
export interface Debt {
  id: number
  family_id: number
  type: string
  counterparty: string
  amount: number
  currency: string
  payment_account_id: number | null
  debt_date: string
  due_date: string | null
  status: string
  repaid_amount: number
  description: string | null
  created_by: number
  repayments: RepaymentResponse[]
}

export interface DebtCreate {
  type: string
  counterparty: string
  amount: number
  currency?: string
  payment_account_id?: number
  debt_date: string
  due_date?: string
  description?: string
}

export interface DebtUpdate {
  counterparty?: string
  due_date?: string
  description?: string
}

export interface RepaymentCreate {
  amount: number
  repayment_date: string
  payment_account_id?: number
  description?: string
}

export interface RepaymentResponse {
  id: number
  debt_id: number
  amount: number
  repayment_date: string
  payment_account_id: number | null
  description: string | null
}

// ---- Recurring ----
export interface RecurringTransaction {
  id: number
  family_id: number
  book_id: number
  type: string
  amount: number
  currency: string
  category_id: number | null
  sub_category_id: number | null
  payment_account_id: number | null
  payment_channel_id: number | null
  platform_id: number | null
  merchant_name: string | null
  description: string | null
  frequency: string
  day_of_month: number | null
  day_of_week: number | null
  month_of_year: number | null
  interval_value: number
  start_date: string
  end_date: string | null
  next_generate: string | null
  is_active: boolean
  remind_days_before: number
  remind_time: string | null
  created_by: number
}

export interface RecurringCreate {
  book_id: number
  type: string
  amount: number
  currency?: string
  category_id?: number
  sub_category_id?: number
  payment_account_id?: number
  payment_channel_id?: number
  platform_id?: number
  merchant_name?: string
  description?: string
  frequency: string
  day_of_month?: number
  day_of_week?: number
  month_of_year?: number
  interval_value?: number
  start_date: string
  end_date?: string
  remind_days_before?: number
  remind_time?: string
}

export interface RecurringUpdate {
  amount?: number
  category_id?: number
  sub_category_id?: number
  payment_account_id?: number
  merchant_name?: string
  description?: string
  frequency?: string
  day_of_month?: number
  is_active?: boolean
}

export interface RecurringLog {
  id: number
  recurring_id: number
  transaction_id: number | null
  scheduled_date: string
  actual_date: string | null
  status: string
  amount: number | null
  note: string | null
}

// ---- Reimbursement ----
export interface Reimbursement {
  id: number
  family_id: number
  title: string
  total_amount: number
  status: string
  submitted_at: string | null
  approved_at: string | null
  received_at: string | null
  received_amount: number | null
  submitted_by: number
  description: string | null
  items: ReimbursementItem[]
}

export interface ReimbursementItem {
  id: number
  reimbursement_id: number
  transaction_id: number
  amount: number
  description: string | null
}

export interface ReimbursementCreate {
  title: string
  total_amount: number
  description?: string
  items: ReimbursementItemCreate[]
}

export interface ReimbursementItemCreate {
  transaction_id: number
  amount: number
  description?: string
}

export interface ReimbursementUpdate {
  title?: string
  total_amount?: number
  description?: string
}

export interface ReceiveRequest {
  received_amount: number
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
  icon: string | null
  color: string | null
  target_amount: number
  current_amount: number
  account_id: number | null
  start_date: string
  target_date: string | null
  status: string
  achieved_at: string | null
  created_by: number
  progress: number
}

export interface SavingsGoalCreate {
  name: string
  icon?: string
  color?: string
  target_amount: number
  account_id?: number
  start_date: string
  target_date?: string
}

export interface SavingsGoalUpdate {
  name?: string
  icon?: string
  color?: string
  target_amount?: number
  target_date?: string
}

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
