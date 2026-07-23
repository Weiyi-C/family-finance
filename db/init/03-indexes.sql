-- ============================================================
-- Family Finance - Indexes
-- ============================================================

-- Users
CREATE INDEX idx_users_family ON users(family_id);

-- Refresh tokens
CREATE INDEX idx_refresh_token_user ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_token_expires ON refresh_tokens(expires_at);

-- Account books
CREATE UNIQUE INDEX idx_one_default_book ON account_books(family_id) WHERE is_default = TRUE;

-- Categories
CREATE UNIQUE INDEX idx_cat_unique_name ON categories(family_id, parent_id, name)
    WHERE family_id IS NOT NULL;

-- Payment accounts
CREATE INDEX idx_pa_family ON payment_accounts(family_id);
CREATE INDEX idx_pa_user ON payment_accounts(user_id);
CREATE INDEX idx_pa_parent ON payment_accounts(parent_id);
CREATE INDEX idx_pa_bank ON payment_accounts(bank_id);
CREATE INDEX idx_pa_channel ON payment_accounts(channel_id);
CREATE INDEX idx_pa_platform ON payment_accounts(platform_id);

-- Transactions (partitioned - indexes auto-apply to all partitions)
CREATE INDEX idx_txn_family ON transactions(family_id);
CREATE INDEX idx_txn_book ON transactions(book_id);
CREATE INDEX idx_txn_time ON transactions(transaction_time);
CREATE INDEX idx_txn_category ON transactions(category_id);
CREATE INDEX idx_txn_status ON transactions(completion_status);
CREATE INDEX idx_txn_entry ON transactions(entry_id);
CREATE INDEX idx_txn_account ON transactions(payment_account_id);
CREATE INDEX idx_txn_recorded_by ON transactions(recorded_by);
CREATE INDEX idx_txn_paid_by ON transactions(paid_by);
CREATE INDEX idx_txn_import ON transactions(import_id);
CREATE INDEX idx_txn_recurring ON transactions(recurring_id);
CREATE INDEX idx_txn_book_time ON transactions(book_id, transaction_time);

-- Transaction settlements
CREATE INDEX idx_settle_entry ON transaction_settlements(entry_id);

-- Transaction refunds
CREATE INDEX idx_refund_original ON transaction_refunds(original_txn_id);
CREATE INDEX idx_refund_family ON transaction_refunds(family_id);

-- Tags
CREATE UNIQUE INDEX idx_tag_unique_name ON tags(family_id, name);

-- Sync
CREATE INDEX idx_sync_log_family_seq ON sync_change_log(family_id, seq);
CREATE INDEX idx_sync_log_table ON sync_change_log(family_id, table_name, seq);

-- Debts
CREATE INDEX idx_debts_family ON debts(family_id);
CREATE INDEX idx_debts_status ON debts(family_id, status);
CREATE INDEX idx_debts_due ON debts(due_date) WHERE status != 'settled';

-- Reimbursements
CREATE INDEX idx_reimb_family ON reimbursements(family_id);
CREATE INDEX idx_reimb_status ON reimbursements(family_id, status);

-- Savings goals
CREATE INDEX idx_goals_family ON savings_goals(family_id);
CREATE INDEX idx_goals_status ON savings_goals(family_id, status);

-- Notifications
CREATE INDEX idx_notifications_user ON notifications(user_id, is_read, created_at DESC);

-- Monitoring
CREATE INDEX idx_error_log_time ON app_error_logs(created_at DESC);
CREATE INDEX idx_slow_query_time ON app_slow_queries(created_at DESC);

-- Automation rules (GIN for JSONB)
CREATE INDEX idx_rules_conditions ON automation_rules USING GIN (conditions);
CREATE INDEX idx_rules_actions ON automation_rules USING GIN (actions);

-- Attachments (GIN for OCR results)
CREATE INDEX idx_attachments_ocr ON attachments USING GIN (ocr_result);

-- Transactions (GIN for raw_data)
CREATE INDEX idx_transactions_raw ON transactions USING GIN (raw_data);

-- Merchant aliases
CREATE INDEX idx_alias_original ON merchant_aliases(original_name);
CREATE INDEX idx_alias_family ON merchant_aliases(family_id);
CREATE INDEX idx_alias_alias ON merchant_aliases(alias_name);

-- Account balance snapshots
CREATE INDEX idx_snapshots_account ON account_balance_snapshots(account_id, snapshot_month);

-- Credit card bills
CREATE INDEX idx_ccbills_account ON credit_card_bills(account_id, bill_year, bill_month);
