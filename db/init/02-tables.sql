-- ============================================================
-- Family Finance - Table Definitions
-- Generated from design doc v1.0 (2026-07-15)
-- ============================================================

-- ===================== 1. 用户与家庭 =====================

CREATE TABLE families (
    id              BIGSERIAL PRIMARY KEY,
    name            VARCHAR(50) NOT NULL,
    invite_code     VARCHAR(20) UNIQUE,
    created_by      BIGINT,
    settings        JSONB DEFAULT '{
        "member_can_import": false,
        "member_can_export": false,
        "member_can_delete_others": false,
        "member_can_view_all_accounts": true,
        "member_can_manage_budget": false,
        "member_can_manage_categories": false
    }'::jsonb,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE users (
    id              BIGSERIAL PRIMARY KEY,
    family_id       BIGINT REFERENCES families(id),
    nickname        VARCHAR(50) NOT NULL,
    avatar_url      VARCHAR(500),
    phone           VARCHAR(20) UNIQUE,
    password_hash   VARCHAR(255),
    role            VARCHAR(20) DEFAULT 'member',
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_user_role CHECK (role IN ('owner', 'admin', 'member'))
);

-- Back-fill families.created_by
ALTER TABLE families ADD CONSTRAINT fk_families_created_by
    FOREIGN KEY (created_by) REFERENCES users(id);

CREATE TABLE refresh_tokens (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash      VARCHAR(255) NOT NULL UNIQUE,
    expires_at      TIMESTAMPTZ NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ===================== 2. 账本 =====================

CREATE TABLE account_books (
    id              BIGSERIAL PRIMARY KEY,
    family_id       BIGINT NOT NULL REFERENCES families(id),
    name            VARCHAR(50) NOT NULL,
    icon            VARCHAR(50),
    color           VARCHAR(20),
    description     VARCHAR(200),
    is_default      BOOLEAN DEFAULT FALSE,
    is_archived     BOOLEAN DEFAULT FALSE,
    created_by      BIGINT REFERENCES users(id),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ===================== 3. 分类 =====================

CREATE TABLE categories (
    id              BIGSERIAL PRIMARY KEY,
    family_id       BIGINT REFERENCES families(id),
    parent_id       BIGINT REFERENCES categories(id),
    level           SMALLINT NOT NULL,
    name            VARCHAR(50) NOT NULL,
    icon            VARCHAR(50),
    color           VARCHAR(20),
    type            VARCHAR(10) DEFAULT 'expense',
    sort_order      SMALLINT DEFAULT 0,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_category_level CHECK (level IN (1, 2, 3)),
    CONSTRAINT chk_category_type CHECK (type IN ('expense', 'income'))
);

-- ===================== 4. 资金来源 =====================

CREATE TABLE account_type_templates (
    id              BIGSERIAL PRIMARY KEY,
    type_code       VARCHAR(30) UNIQUE NOT NULL,
    name            VARCHAR(50) NOT NULL,
    icon            VARCHAR(50),
    group_name      VARCHAR(30) NOT NULL,
    is_credit       BOOLEAN DEFAULT FALSE,
    has_balance     BOOLEAN DEFAULT TRUE,
    has_credit_limit BOOLEAN DEFAULT FALSE,
    has_billing_day  BOOLEAN DEFAULT FALSE,
    has_due_day      BOOLEAN DEFAULT FALSE,
    default_icon    VARCHAR(50),
    default_color   VARCHAR(20),
    sort_order      SMALLINT DEFAULT 0,
    is_active       BOOLEAN DEFAULT TRUE
);

CREATE TABLE banks (
    id              BIGSERIAL PRIMARY KEY,
    name            VARCHAR(50) NOT NULL,
    code            VARCHAR(20) UNIQUE NOT NULL,
    short_name      VARCHAR(20),
    icon            VARCHAR(100),
    color           VARCHAR(20),
    sort_order      SMALLINT DEFAULT 0
);

-- ===================== 5. 支付渠道 & 交易平台 =====================

CREATE TABLE payment_channels (
    id              BIGSERIAL PRIMARY KEY,
    family_id       BIGINT REFERENCES families(id),
    name            VARCHAR(50) NOT NULL,
    icon            VARCHAR(50),
    sort_order      SMALLINT DEFAULT 0,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE platforms (
    id              BIGSERIAL PRIMARY KEY,
    family_id       BIGINT REFERENCES families(id),
    name            VARCHAR(100) NOT NULL,
    type            VARCHAR(20) NOT NULL,
    icon            VARCHAR(50),
    sort_order      SMALLINT DEFAULT 0,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE payment_accounts (
    id              BIGSERIAL PRIMARY KEY,
    family_id       BIGINT NOT NULL REFERENCES families(id),
    user_id         BIGINT NOT NULL REFERENCES users(id),
    template_id     BIGINT REFERENCES account_type_templates(id),
    name            VARCHAR(100) NOT NULL,
    type_code       VARCHAR(30) NOT NULL,
    icon            VARCHAR(50),
    color           VARCHAR(20),
    bank_name       VARCHAR(50),
    bank_code       VARCHAR(20),
    card_tail       VARCHAR(10),
    card_type       VARCHAR(20),
    initial_balance BIGINT DEFAULT 0,
    credit_limit    BIGINT,
    used_amount     BIGINT DEFAULT 0,
    billing_day     SMALLINT,
    due_day         SMALLINT,
    grace_days      SMALLINT,
    is_shared       BOOLEAN DEFAULT FALSE,
    shared_with     BIGINT REFERENCES users(id),
    share_type      VARCHAR(30),
    group_name      VARCHAR(30),
    sort_order      SMALLINT DEFAULT 0,
    is_active       BOOLEAN DEFAULT TRUE,
    is_hidden       BOOLEAN DEFAULT FALSE,

    -- 账户层级和关联字段（v1.1）
    parent_id       BIGINT REFERENCES payment_accounts(id),  -- 父账户ID
    bank_id         BIGINT REFERENCES banks(id),              -- 关联银行
    channel_id      BIGINT REFERENCES payment_channels(id),  -- 关联支付渠道
    linked_account_id BIGINT REFERENCES payment_accounts(id), -- 关联扣款账户（亲情卡/代付）
    linked_user_id  BIGINT REFERENCES users(id),              -- 关联用户（亲情卡使用者）
    platform_id     BIGINT REFERENCES platforms(id),          -- 关联购物平台
    group_label     VARCHAR(50),                              -- 分组标签

    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- (payment_channels & platforms 已移至 payment_accounts 之前)

-- ===================== 6. 交易记录（分区表） =====================

CREATE TABLE transactions (
    id                  BIGSERIAL,
    family_id           BIGINT NOT NULL REFERENCES families(id),
    book_id             BIGINT NOT NULL REFERENCES account_books(id),
    entry_id            BIGINT,
    entry_side          VARCHAR(10) NOT NULL,
    type                VARCHAR(20) NOT NULL,
    amount              BIGINT NOT NULL,
    currency            VARCHAR(3) DEFAULT 'CNY',
    original_amount     BIGINT,
    original_currency   VARCHAR(3),
    exchange_rate       DECIMAL(10,6),
    category_id         BIGINT REFERENCES categories(id),
    sub_category_id     BIGINT REFERENCES categories(id),
    detail_category_id  BIGINT REFERENCES categories(id),
    payment_account_id  BIGINT REFERENCES payment_accounts(id),
    payment_channel_id  BIGINT REFERENCES payment_channels(id),
    platform_id         BIGINT REFERENCES platforms(id),
    merchant_name       VARCHAR(200),
    description         VARCHAR(500),
    transaction_time    TIMESTAMPTZ NOT NULL,
    recorded_at         TIMESTAMPTZ DEFAULT NOW(),
    recorded_by         BIGINT NOT NULL REFERENCES users(id),
    paid_by             BIGINT REFERENCES users(id),
    is_quick_entry      BOOLEAN DEFAULT FALSE,
    completion_status   VARCHAR(20) DEFAULT 'complete',
    recurring_id        BIGINT,
    import_id           BIGINT,
    raw_data            JSONB,
    version             INTEGER NOT NULL DEFAULT 1,
    is_deleted          BOOLEAN DEFAULT FALSE,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (id, transaction_time),
    CONSTRAINT chk_entry_side CHECK (entry_side IN ('debit', 'credit')),
    CONSTRAINT chk_type CHECK (type IN ('expense', 'income', 'transfer')),
    CONSTRAINT chk_amount CHECK (amount > 0),
    CONSTRAINT chk_completion CHECK (completion_status IN ('complete', 'pending', 'partial'))
) PARTITION BY RANGE (transaction_time);

-- ===================== 7. 交易扩展表 =====================

CREATE TABLE transaction_settlements (
    id                  BIGSERIAL PRIMARY KEY,
    transaction_id      BIGINT NOT NULL,
    entry_id            BIGINT NOT NULL,
    settlement_amount   BIGINT NOT NULL,
    settlement_rate     DECIMAL(10,6) NOT NULL,
    settlement_date     DATE NOT NULL,
    status              VARCHAR(20) DEFAULT 'pending',
    version             INTEGER NOT NULL DEFAULT 1,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_settle_status CHECK (status IN ('pending', 'settled')),
    UNIQUE(transaction_id)
);

CREATE TABLE transaction_refunds (
    id                  BIGSERIAL PRIMARY KEY,
    original_txn_id     BIGINT NOT NULL,
    refund_txn_id       BIGINT NOT NULL,
    family_id           BIGINT NOT NULL REFERENCES families(id),
    amount              BIGINT NOT NULL,
    status              VARCHAR(20) DEFAULT 'pending',
    refund_time         TIMESTAMPTZ,
    reason              VARCHAR(200),
    platform_refund_id  VARCHAR(100),
    version             INTEGER NOT NULL DEFAULT 1,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_refund_status CHECK (status IN ('pending', 'approved', 'received'))
);

-- ===================== 8. 标签 =====================

CREATE TABLE tags (
    id              BIGSERIAL PRIMARY KEY,
    family_id       BIGINT NOT NULL REFERENCES families(id),
    name            VARCHAR(50) NOT NULL,
    color           VARCHAR(20),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE transaction_tags (
    transaction_id  BIGINT NOT NULL,
    tag_id          BIGINT NOT NULL REFERENCES tags(id),
    PRIMARY KEY (transaction_id, tag_id)
);

-- ===================== 9. 预算 =====================

CREATE TABLE budgets (
    id              BIGSERIAL PRIMARY KEY,
    family_id       BIGINT NOT NULL REFERENCES families(id),
    book_id         BIGINT REFERENCES account_books(id),
    category_id     BIGINT REFERENCES categories(id),
    amount          BIGINT NOT NULL,
    currency        VARCHAR(3) DEFAULT 'CNY',
    period          VARCHAR(20) NOT NULL,
    year            SMALLINT NOT NULL,
    month           SMALLINT,
    week_start_date DATE,
    rollover        BOOLEAN DEFAULT FALSE,
    rollover_amount BIGINT DEFAULT 0,
    alert_threshold DECIMAL(5,2) DEFAULT 0.8,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ===================== 10. 多币种 =====================

CREATE TABLE currencies (
    code            VARCHAR(3) PRIMARY KEY,
    name            VARCHAR(50) NOT NULL,
    symbol          VARCHAR(10),
    decimal_places  SMALLINT DEFAULT 2,
    is_active       BOOLEAN DEFAULT TRUE
);

CREATE TABLE exchange_rates (
    id              BIGSERIAL PRIMARY KEY,
    base_currency   VARCHAR(3) NOT NULL,
    target_currency VARCHAR(3) NOT NULL,
    rate            DECIMAL(12,6) NOT NULL,
    rate_type       VARCHAR(20) DEFAULT 'market',
    source          VARCHAR(30),
    rate_date       DATE NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(base_currency, target_currency, rate_type, rate_date)
);

-- ===================== 11. 周期性交易 =====================

CREATE TABLE recurring_transactions (
    id              BIGSERIAL PRIMARY KEY,
    family_id       BIGINT NOT NULL REFERENCES families(id),
    book_id         BIGINT NOT NULL REFERENCES account_books(id),
    type            VARCHAR(20) NOT NULL,
    amount          BIGINT NOT NULL,
    currency        VARCHAR(3) DEFAULT 'CNY',
    category_id     BIGINT REFERENCES categories(id),
    sub_category_id BIGINT REFERENCES categories(id),
    payment_account_id BIGINT REFERENCES payment_accounts(id),
    payment_channel_id BIGINT REFERENCES payment_channels(id),
    platform_id     BIGINT REFERENCES platforms(id),
    merchant_name   VARCHAR(200),
    description     VARCHAR(500),
    frequency       VARCHAR(20) NOT NULL,
    day_of_month    SMALLINT,
    day_of_week     SMALLINT,
    month_of_year   SMALLINT,
    interval_value  SMALLINT DEFAULT 1,
    start_date      DATE NOT NULL,
    end_date        DATE,
    remind_days_before SMALLINT DEFAULT 1,
    remind_time     TIME DEFAULT '09:00',
    is_active       BOOLEAN DEFAULT TRUE,
    last_generated  DATE,
    next_generate   DATE,
    total_generated INTEGER DEFAULT 0,
    created_by      BIGINT NOT NULL REFERENCES users(id),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE recurring_transaction_logs (
    id              BIGSERIAL PRIMARY KEY,
    recurring_id    BIGINT NOT NULL REFERENCES recurring_transactions(id),
    transaction_id  BIGINT,
    scheduled_date  DATE NOT NULL,
    actual_date     DATE,
    status          VARCHAR(20) DEFAULT 'pending',
    amount          BIGINT,
    note            VARCHAR(200),
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ===================== 12. 账单导入 =====================

CREATE TABLE bill_imports (
    id              BIGSERIAL PRIMARY KEY,
    family_id       BIGINT NOT NULL REFERENCES families(id),
    book_id         BIGINT NOT NULL REFERENCES account_books(id),
    source          VARCHAR(30) NOT NULL,
    file_url        VARCHAR(500),
    file_format     VARCHAR(10),
    status          VARCHAR(20) DEFAULT 'pending',
    total_rows      INTEGER DEFAULT 0,
    parsed_count    INTEGER DEFAULT 0,
    matched_count   INTEGER DEFAULT 0,
    new_count       INTEGER DEFAULT 0,
    parse_log       JSONB,
    imported_by     BIGINT NOT NULL REFERENCES users(id),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE bill_import_items (
    id              BIGSERIAL PRIMARY KEY,
    import_id       BIGINT NOT NULL REFERENCES bill_imports(id),
    raw_data        JSONB NOT NULL,
    parsed_amount   BIGINT,
    parsed_time     TIMESTAMPTZ,
    parsed_merchant VARCHAR(200),
    parsed_category VARCHAR(50),
    matched_txn_id  BIGINT,
    action          VARCHAR(20) DEFAULT 'pending',
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ===================== 13. 规则引擎 =====================

CREATE TABLE automation_rules (
    id              BIGSERIAL PRIMARY KEY,
    family_id       BIGINT REFERENCES families(id),
    name            VARCHAR(100),
    conditions      JSONB NOT NULL,
    actions         JSONB NOT NULL,
    stage           VARCHAR(20) DEFAULT 'classify',
    priority        SMALLINT DEFAULT 0,
    is_active       BOOLEAN DEFAULT TRUE,
    hit_count       INTEGER DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE automation_rule_logs (
    id              BIGSERIAL PRIMARY KEY,
    rule_id         BIGINT NOT NULL REFERENCES automation_rules(id),
    transaction_id  BIGINT,
    import_item_id  BIGINT REFERENCES bill_import_items(id),
    action_taken    VARCHAR(50),
    before_value    JSONB,
    after_value     JSONB,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ===================== 14. 商户别名 =====================

CREATE TABLE merchant_aliases (
    id              BIGSERIAL PRIMARY KEY,
    family_id       BIGINT REFERENCES families(id),
    original_name   VARCHAR(200) NOT NULL,
    alias_name      VARCHAR(100) NOT NULL,
    category_id     BIGINT REFERENCES categories(id),
    sub_category_id BIGINT REFERENCES categories(id),
    platform_id     BIGINT REFERENCES platforms(id),
    hit_count       INTEGER DEFAULT 0,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ===================== 15. 同步 =====================

CREATE TABLE family_sync_seq (
    family_id       BIGINT PRIMARY KEY REFERENCES families(id),
    current_seq     BIGINT NOT NULL DEFAULT 0
);

CREATE TABLE sync_change_log (
    id              BIGSERIAL PRIMARY KEY,
    family_id       BIGINT NOT NULL REFERENCES families(id),
    seq             BIGINT NOT NULL,
    table_name      VARCHAR(50) NOT NULL,
    record_id       BIGINT NOT NULL,
    operation       VARCHAR(10) NOT NULL,
    version         INTEGER NOT NULL,
    changed_by      BIGINT REFERENCES users(id),
    changed_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    change_data     JSONB,
    family_id_check BIGINT NOT NULL,
    CONSTRAINT chk_sync_op CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE'))
);

CREATE TABLE client_sync_state (
    id              BIGSERIAL PRIMARY KEY,
    client_id       VARCHAR(100) NOT NULL,
    family_id       BIGINT NOT NULL REFERENCES families(id),
    user_id         BIGINT NOT NULL REFERENCES users(id),
    last_pushed_seq BIGINT DEFAULT 0,
    last_pulled_seq BIGINT DEFAULT 0,
    device_type     VARCHAR(20),
    device_name     VARCHAR(100),
    app_version     VARCHAR(20),
    last_active_at  TIMESTAMPTZ DEFAULT NOW(),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(client_id, family_id)
);

CREATE TABLE sync_logs (
    id              BIGSERIAL PRIMARY KEY,
    client_id       VARCHAR(100) NOT NULL,
    family_id       BIGINT NOT NULL REFERENCES families(id),
    sync_type       VARCHAR(20) NOT NULL,
    record_count    INTEGER DEFAULT 0,
    conflict_count  INTEGER DEFAULT 0,
    status          VARCHAR(20) DEFAULT 'success',
    error_message   VARCHAR(500),
    duration_ms     INTEGER,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ===================== 16. 借贷 =====================

CREATE TABLE debts (
    id              BIGSERIAL PRIMARY KEY,
    family_id       BIGINT NOT NULL REFERENCES families(id),
    type            VARCHAR(20) NOT NULL,
    counterparty    VARCHAR(100) NOT NULL,
    amount          BIGINT NOT NULL,
    currency        VARCHAR(3) DEFAULT 'CNY',
    payment_account_id BIGINT REFERENCES payment_accounts(id),
    debt_date       DATE NOT NULL,
    due_date        DATE,
    status          VARCHAR(20) DEFAULT 'pending',
    repaid_amount   BIGINT DEFAULT 0,
    description     VARCHAR(500),
    created_by      BIGINT NOT NULL REFERENCES users(id),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_debt_type CHECK (type IN ('lend', 'borrow')),
    CONSTRAINT chk_debt_amount CHECK (amount > 0),
    CONSTRAINT chk_debt_status CHECK (status IN ('pending', 'partial', 'settled'))
);

CREATE TABLE debt_repayments (
    id              BIGSERIAL PRIMARY KEY,
    debt_id         BIGINT NOT NULL REFERENCES debts(id),
    amount          BIGINT NOT NULL,
    repayment_date  DATE NOT NULL,
    payment_account_id BIGINT REFERENCES payment_accounts(id),
    description     VARCHAR(200),
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ===================== 17. 报销 =====================

CREATE TABLE reimbursements (
    id              BIGSERIAL PRIMARY KEY,
    family_id       BIGINT NOT NULL REFERENCES families(id),
    title           VARCHAR(200) NOT NULL,
    total_amount    BIGINT NOT NULL,
    status          VARCHAR(20) DEFAULT 'draft',
    submitted_at    TIMESTAMPTZ,
    approved_at     TIMESTAMPTZ,
    received_at     TIMESTAMPTZ,
    received_amount BIGINT,
    submitted_by    BIGINT NOT NULL REFERENCES users(id),
    description     VARCHAR(500),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_reimb_status CHECK (status IN ('draft', 'submitted', 'approved', 'received'))
);

CREATE TABLE reimbursement_items (
    id                  BIGSERIAL PRIMARY KEY,
    reimbursement_id    BIGINT NOT NULL REFERENCES reimbursements(id),
    transaction_id      BIGINT NOT NULL,
    amount              BIGINT NOT NULL,
    description         VARCHAR(200)
);

-- ===================== 18. 储蓄目标 =====================

CREATE TABLE savings_goals (
    id              BIGSERIAL PRIMARY KEY,
    family_id       BIGINT NOT NULL REFERENCES families(id),
    name            VARCHAR(100) NOT NULL,
    icon            VARCHAR(50),
    color           VARCHAR(20),
    target_amount   BIGINT NOT NULL,
    current_amount  BIGINT DEFAULT 0,
    account_id      BIGINT REFERENCES payment_accounts(id),
    start_date      DATE NOT NULL,
    target_date     DATE,
    status          VARCHAR(20) DEFAULT 'active',
    achieved_at     TIMESTAMPTZ,
    created_by      BIGINT NOT NULL REFERENCES users(id),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_goal_status CHECK (status IN ('active', 'achieved', 'abandoned'))
);

-- ===================== 19. 附件 =====================

CREATE TABLE attachments (
    id              BIGSERIAL PRIMARY KEY,
    transaction_id  BIGINT,
    family_id       BIGINT NOT NULL REFERENCES families(id),
    uploaded_by     BIGINT NOT NULL REFERENCES users(id),
    file_url        VARCHAR(500) NOT NULL,
    file_type       VARCHAR(20) NOT NULL,
    file_size       INTEGER,
    thumbnail_url   VARCHAR(500),
    image_type      VARCHAR(30),
    ocr_engine      VARCHAR(30),
    ocr_raw_text    TEXT,
    ocr_result      JSONB,
    ocr_confidence  DECIMAL(3,2),
    status          VARCHAR(20) DEFAULT 'pending',
    error_message   VARCHAR(500),
    is_confirmed    BOOLEAN DEFAULT FALSE,
    user_corrections JSONB,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ===================== 20. 通知 =====================

CREATE TABLE notifications (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT NOT NULL REFERENCES users(id),
    family_id       BIGINT NOT NULL REFERENCES families(id),
    type            VARCHAR(30) NOT NULL,
    title           VARCHAR(200) NOT NULL,
    content         VARCHAR(500),
    related_id      BIGINT,
    related_type    VARCHAR(30),
    is_read         BOOLEAN DEFAULT FALSE,
    read_at         TIMESTAMPTZ,
    channel         VARCHAR(20) DEFAULT 'app_push',
    send_status     VARCHAR(20) DEFAULT 'pending',
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ===================== 21. 用户设置 =====================

CREATE TABLE user_settings (
    id                  BIGSERIAL PRIMARY KEY,
    user_id             BIGINT NOT NULL REFERENCES users(id) UNIQUE,
    default_currency    VARCHAR(3) DEFAULT 'CNY',
    month_start_day     SMALLINT DEFAULT 1,
    theme               VARCHAR(20) DEFAULT 'light',
    language            VARCHAR(10) DEFAULT 'zh-CN',
    date_format         VARCHAR(20) DEFAULT 'YYYY-MM-DD',
    number_format       VARCHAR(20) DEFAULT '1,234.56',
    default_book_id     BIGINT REFERENCES account_books(id),
    quick_entry_mode    VARCHAR(20) DEFAULT 'minimal',
    confirm_before_save BOOLEAN DEFAULT TRUE,
    notify_budget_alert BOOLEAN DEFAULT TRUE,
    notify_recurring    BOOLEAN DEFAULT TRUE,
    notify_sync         BOOLEAN DEFAULT FALSE,
    quiet_hours_start   TIME,
    quiet_hours_end     TIME,
    auto_sync           BOOLEAN DEFAULT TRUE,
    sync_on_wifi_only   BOOLEAN DEFAULT FALSE,
    settings_json       JSONB,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- ===================== 22. 备份 =====================

CREATE TABLE backup_configs (
    id              BIGSERIAL PRIMARY KEY,
    family_id       BIGINT NOT NULL REFERENCES families(id),
    backup_type     VARCHAR(30) NOT NULL,
    schedule        VARCHAR(50) NOT NULL,
    is_enabled      BOOLEAN DEFAULT TRUE,
    target          VARCHAR(30) NOT NULL,
    target_config   JSONB,
    retention_days  INTEGER DEFAULT 30,
    max_backups     INTEGER DEFAULT 10,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE backup_logs (
    id              BIGSERIAL PRIMARY KEY,
    backup_type     VARCHAR(30) NOT NULL,
    backup_target   VARCHAR(30) NOT NULL,
    file_path       VARCHAR(500),
    file_size       BIGINT,
    file_format     VARCHAR(20),
    table_counts    JSONB,
    status          VARCHAR(20) DEFAULT 'success',
    error_message   VARCHAR(500),
    duration_ms     INTEGER,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ===================== 23. 监控 =====================

CREATE TABLE app_error_logs (
    id              BIGSERIAL PRIMARY KEY,
    level           VARCHAR(10) NOT NULL,
    endpoint        VARCHAR(200),
    method          VARCHAR(10),
    user_id         BIGINT,
    error_type      VARCHAR(100),
    message         TEXT,
    traceback       TEXT,
    request_data    JSONB,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE app_slow_queries (
    id              BIGSERIAL PRIMARY KEY,
    endpoint        VARCHAR(200),
    query_text      TEXT,
    duration_ms     INTEGER,
    user_id         BIGINT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ===================== 24. 性能优化 =====================

CREATE TABLE account_balance_snapshots (
    id              BIGSERIAL PRIMARY KEY,
    account_id      BIGINT NOT NULL REFERENCES payment_accounts(id),
    family_id       BIGINT NOT NULL REFERENCES families(id),
    snapshot_month  DATE NOT NULL,
    balance         BIGINT NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(account_id, snapshot_month)
);

CREATE TABLE credit_card_bills (
    id              BIGSERIAL PRIMARY KEY,
    account_id      BIGINT NOT NULL REFERENCES payment_accounts(id),
    family_id       BIGINT NOT NULL REFERENCES families(id),
    bill_year       SMALLINT NOT NULL,
    bill_month      SMALLINT NOT NULL,
    billing_date    DATE NOT NULL,
    due_date        DATE NOT NULL,
    total_amount    BIGINT NOT NULL DEFAULT 0,
    paid_amount     BIGINT NOT NULL DEFAULT 0,
    min_payment     BIGINT DEFAULT 0,
    status          VARCHAR(20) DEFAULT 'pending',
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(account_id, bill_year, bill_month),
    CONSTRAINT chk_cc_bill_status CHECK (status IN ('pending', 'partial', 'paid', 'overdue'))
);

-- ===================== 25. 视图 =====================

CREATE VIEW user_transactions AS
SELECT
    entry_id,
    MAX(family_id) AS family_id,
    MAX(CASE WHEN entry_side='debit' THEN id END) AS txn_id,
    MAX(CASE WHEN entry_side='debit' THEN type END) AS type,
    MAX(CASE WHEN entry_side='debit' THEN amount END) AS amount,
    MAX(CASE WHEN entry_side='debit' THEN currency END) AS currency,
    MAX(CASE WHEN entry_side='debit' THEN category_id END) AS category_id,
    MAX(CASE WHEN entry_side='debit' THEN sub_category_id END) AS sub_category_id,
    MAX(CASE WHEN entry_side='debit' THEN detail_category_id END) AS detail_category_id,
    MAX(CASE WHEN entry_side='credit' THEN payment_account_id END) AS payment_account_id,
    MAX(CASE WHEN entry_side='debit' THEN payment_channel_id END) AS payment_channel_id,
    MAX(CASE WHEN entry_side='debit' THEN platform_id END) AS platform_id,
    MAX(CASE WHEN entry_side='debit' THEN merchant_name END) AS merchant_name,
    MAX(CASE WHEN entry_side='debit' THEN description END) AS description,
    MAX(CASE WHEN entry_side='debit' THEN transaction_time END) AS transaction_time,
    MAX(CASE WHEN entry_side='debit' THEN recorded_by END) AS recorded_by,
    MAX(CASE WHEN entry_side='debit' THEN paid_by END) AS paid_by,
    MAX(CASE WHEN entry_side='debit' THEN original_amount END) AS original_amount,
    MAX(CASE WHEN entry_side='debit' THEN original_currency END) AS original_currency,
    MAX(CASE WHEN entry_side='debit' THEN exchange_rate END) AS exchange_rate,
    MAX(CASE WHEN entry_side='debit' THEN book_id END) AS book_id,
    BOOL_OR(CASE WHEN entry_side='debit' THEN is_quick_entry ELSE FALSE END) AS is_quick_entry,
    MAX(CASE WHEN entry_side='debit' THEN completion_status END) AS completion_status
FROM transactions
WHERE is_deleted = FALSE AND entry_id IS NOT NULL
GROUP BY entry_id;

CREATE VIEW category_usage_stats AS
SELECT
    category_id,
    COUNT(*) AS usage_count,
    MAX(transaction_time) AS last_used
FROM transactions
WHERE is_deleted = FALSE
    AND category_id IS NOT NULL
    AND transaction_time >= NOW() - INTERVAL '3 months'
GROUP BY category_id;

-- Add FK constraints that reference transactions (deferred for partitioned tables)
-- Note: partitioned tables cannot be direct FK targets in PostgreSQL.
-- Referential integrity for transaction_id in these tables is enforced at application level:
--   - transaction_settlements.transaction_id
--   - transaction_refunds.original_txn_id / refund_txn_id
--   - transaction_tags.transaction_id
--   - bill_import_items.matched_txn_id
--   - recurring_transaction_logs.transaction_id
--   - reimbursement_items.transaction_id
--   - attachments.transaction_id

-- Add FK for recurring_transactions → transactions.recurring_id (application-level)
-- Add FK for transactions.import_id → bill_imports (application-level)
