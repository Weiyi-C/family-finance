-- ============================================================
-- Family Finance - Transaction Partitions
-- ============================================================

-- Quarterly partitions for transactions (2026-2027)
CREATE TABLE transactions_2026q1 PARTITION OF transactions
    FOR VALUES FROM ('2026-01-01') TO ('2026-04-01');
CREATE TABLE transactions_2026q2 PARTITION OF transactions
    FOR VALUES FROM ('2026-04-01') TO ('2026-07-01');
CREATE TABLE transactions_2026q3 PARTITION OF transactions
    FOR VALUES FROM ('2026-07-01') TO ('2026-10-01');
CREATE TABLE transactions_2026q4 PARTITION OF transactions
    FOR VALUES FROM ('2026-10-01') TO ('2027-01-01');
CREATE TABLE transactions_2027q1 PARTITION OF transactions
    FOR VALUES FROM ('2027-01-01') TO ('2027-04-01');
CREATE TABLE transactions_2027q2 PARTITION OF transactions
    FOR VALUES FROM ('2027-04-01') TO ('2027-07-01');
