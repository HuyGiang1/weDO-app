-- ============================================================================
-- Migration: V7__finance.sql
-- Module: Expense & Peer-to-Peer Settlement (Derived Debt)
-- Tables: expenses, expense_shares, expense_change_logs,
--         settlements, settlement_status_history
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Table: expenses
-- ----------------------------------------------------------------------------
CREATE TABLE expenses (
    id UUID PRIMARY KEY,
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE RESTRICT,
    activity_id UUID REFERENCES activities(id) ON DELETE SET NULL,
    paid_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    total_amount NUMERIC(19,2) NOT NULL
        CONSTRAINT chk_expenses_total_amount CHECK (total_amount > 0),
    split_type VARCHAR(20) NOT NULL
        CONSTRAINT chk_expenses_split_type CHECK (split_type IN ('EQUAL', 'CUSTOM_AMOUNT')),
    occurred_at TIMESTAMPTZ NOT NULL,
    note TEXT,
    receipt_storage_key VARCHAR(255),
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
        CONSTRAINT chk_expenses_status CHECK (status IN ('ACTIVE', 'CANCELLED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_expenses_title_non_empty CHECK (length(trim(title)) > 0)
);

CREATE INDEX idx_expenses_group_occurred ON expenses(group_id, occurred_at DESC);
CREATE INDEX idx_expenses_activity ON expenses(activity_id) WHERE activity_id IS NOT NULL;
CREATE INDEX idx_expenses_paid_by ON expenses(paid_by);

-- ----------------------------------------------------------------------------
-- 2. Table: expense_shares (Obligation breakdown per participant)
-- ----------------------------------------------------------------------------
CREATE TABLE expense_shares (
    id UUID PRIMARY KEY,
    expense_id UUID NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    amount NUMERIC(19,2) NOT NULL
        CONSTRAINT chk_expense_shares_amount CHECK (amount > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_expense_shares_expense_user UNIQUE (expense_id, user_id)
);

CREATE INDEX idx_expense_shares_user ON expense_shares(user_id);

-- ----------------------------------------------------------------------------
-- 3. Table: expense_change_logs (Audit log for expense corrections)
-- ----------------------------------------------------------------------------
CREATE TABLE expense_change_logs (
    id UUID PRIMARY KEY,
    expense_id UUID NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
    actor_id UUID REFERENCES users(id) ON DELETE SET NULL,
    field_name VARCHAR(50) NOT NULL,
    old_value TEXT,
    new_value TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_expense_change_logs_expense ON expense_change_logs(expense_id, created_at ASC);

-- ----------------------------------------------------------------------------
-- 4. Table: settlements (Peer-to-peer debt payments)
-- ----------------------------------------------------------------------------
CREATE TABLE settlements (
    id UUID PRIMARY KEY,
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE RESTRICT,
    from_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    to_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    amount NUMERIC(19,2) NOT NULL
        CONSTRAINT chk_settlements_amount CHECK (amount > 0),
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING'
        CONSTRAINT chk_settlements_status CHECK (status IN ('PENDING', 'COMPLETED', 'REJECTED', 'CANCELLED')),
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    declaration_type VARCHAR(20) NOT NULL
        CONSTRAINT chk_settlements_declaration_type CHECK (declaration_type IN ('I_PAID', 'I_RECEIVED')),
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_settlements_no_self_debt CHECK (from_user_id != to_user_id),
    CONSTRAINT chk_settlements_creator_declaration CHECK (
        (declaration_type = 'I_PAID' AND created_by = from_user_id)
        OR
        (declaration_type = 'I_RECEIVED' AND created_by = to_user_id)
    ),
    CONSTRAINT chk_settlements_completed_consistency CHECK (
        (status != 'COMPLETED' AND completed_at IS NULL)
        OR
        (status = 'COMPLETED' AND completed_at IS NOT NULL)
    )
);

CREATE INDEX idx_settlements_group_status ON settlements(group_id, status);
CREATE INDEX idx_settlements_user_pair ON settlements(from_user_id, to_user_id, status);

-- ----------------------------------------------------------------------------
-- 5. Table: settlement_status_history (Audit status transitions)
-- ----------------------------------------------------------------------------
CREATE TABLE settlement_status_history (
    id UUID PRIMARY KEY,
    settlement_id UUID NOT NULL REFERENCES settlements(id) ON DELETE CASCADE,
    from_status VARCHAR(20)
        CONSTRAINT chk_settlement_status_history_from CHECK (from_status IS NULL OR from_status IN ('PENDING', 'COMPLETED', 'REJECTED', 'CANCELLED')),
    to_status VARCHAR(20) NOT NULL
        CONSTRAINT chk_settlement_status_history_to CHECK (to_status IN ('PENDING', 'COMPLETED', 'REJECTED', 'CANCELLED')),
    changed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_settlement_status_history_created ON settlement_status_history(settlement_id, created_at ASC);
