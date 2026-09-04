-- ============================================================================
-- Migration: V8__fund.sql
-- Module: Group Fund, Collections, Contributions, Expenses, Reimbursements,
--         and Append-Only Financial Ledger with Compensating Reversals
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Table: group_funds (One active fund per group)
-- ----------------------------------------------------------------------------
CREATE TABLE group_funds (
    id UUID PRIMARY KEY,
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE RESTRICT,
    name VARCHAR(255) NOT NULL DEFAULT 'Quỹ nhóm',
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
        CONSTRAINT chk_group_funds_status CHECK (status IN ('ACTIVE', 'CLOSED')),
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    closed_at TIMESTAMPTZ,
    closed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT chk_group_funds_name_non_empty CHECK (length(trim(name)) > 0),
    CONSTRAINT chk_group_funds_closed_consistency CHECK (
        (status = 'ACTIVE' AND closed_at IS NULL AND closed_by IS NULL)
        OR
        (status = 'CLOSED' AND closed_at IS NOT NULL)
    )
);

-- At most 1 active fund per group
CREATE UNIQUE INDEX uq_group_funds_active_group 
ON group_funds(group_id) 
WHERE status = 'ACTIVE';

CREATE INDEX idx_group_funds_group_status ON group_funds(group_id, status);

-- ----------------------------------------------------------------------------
-- 2. Table: fund_managers (Explicit treasurer role assignments)
-- ----------------------------------------------------------------------------
CREATE TABLE fund_managers (
    id UUID PRIMARY KEY,
    fund_id UUID NOT NULL REFERENCES group_funds(id) ON DELETE RESTRICT,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    assigned_by UUID REFERENCES users(id) ON DELETE SET NULL,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_fund_managers_fund_user UNIQUE (fund_id, user_id)
);

CREATE INDEX idx_fund_managers_user ON fund_managers(user_id);

-- ----------------------------------------------------------------------------
-- 3. Table: fund_collections (Fundraising campaigns/drives)
-- ----------------------------------------------------------------------------
CREATE TABLE fund_collections (
    id UUID PRIMARY KEY,
    fund_id UUID NOT NULL REFERENCES group_funds(id) ON DELETE RESTRICT,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    deadline_at TIMESTAMPTZ,
    status VARCHAR(20) NOT NULL DEFAULT 'OPEN'
        CONSTRAINT chk_fund_collections_status CHECK (status IN ('OPEN', 'CLOSED', 'CANCELLED')),
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_fund_collections_title_non_empty CHECK (length(trim(title)) > 0)
);

CREATE INDEX idx_fund_collections_fund_status ON fund_collections(fund_id, status, deadline_at);

-- ----------------------------------------------------------------------------
-- 4. Table: fund_collection_obligations (Per-member required payment amounts)
-- ----------------------------------------------------------------------------
CREATE TABLE fund_collection_obligations (
    id UUID PRIMARY KEY,
    collection_id UUID NOT NULL REFERENCES fund_collections(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    amount_due NUMERIC(19,2) NOT NULL
        CONSTRAINT chk_fund_obligations_amount CHECK (amount_due > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_fund_collection_obligations_user UNIQUE (collection_id, user_id)
);

CREATE INDEX idx_fund_obligations_user ON fund_collection_obligations(user_id);

-- ----------------------------------------------------------------------------
-- 5. Table: fund_contributions (Member payments toward fund collection)
-- ----------------------------------------------------------------------------
CREATE TABLE fund_contributions (
    id UUID PRIMARY KEY,
    fund_id UUID NOT NULL REFERENCES group_funds(id) ON DELETE RESTRICT,
    collection_id UUID NOT NULL REFERENCES fund_collections(id) ON DELETE RESTRICT,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    amount NUMERIC(19,2) NOT NULL
        CONSTRAINT chk_fund_contributions_amount CHECK (amount > 0),
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING'
        CONSTRAINT chk_fund_contributions_status CHECK (status IN ('PENDING', 'CONFIRMED', 'REJECTED', 'CANCELLED')),
    proof_storage_key VARCHAR(255),
    note TEXT,
    payment_time TIMESTAMPTZ NOT NULL,
    confirmed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    confirmed_at TIMESTAMPTZ,
    rejection_reason VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_fund_contributions_confirmed_consistency CHECK (
        (status = 'CONFIRMED' AND confirmed_at IS NOT NULL)
        OR
        (status <> 'CONFIRMED' AND confirmed_at IS NULL)
    )
);

CREATE INDEX idx_fund_contributions_fund_status ON fund_contributions(fund_id, status);
CREATE INDEX idx_fund_contributions_collection ON fund_contributions(collection_id, user_id, status);
CREATE INDEX idx_fund_contributions_user ON fund_contributions(user_id, status);

-- ----------------------------------------------------------------------------
-- 6. Table: fund_expenses (Direct fund spend/outflow by Owner/Manager)
-- ----------------------------------------------------------------------------
CREATE TABLE fund_expenses (
    id UUID PRIMARY KEY,
    fund_id UUID NOT NULL REFERENCES group_funds(id) ON DELETE RESTRICT,
    activity_id UUID REFERENCES activities(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    amount NUMERIC(19,2) NOT NULL
        CONSTRAINT chk_fund_expenses_amount CHECK (amount > 0),
    occurred_at TIMESTAMPTZ NOT NULL,
    receipt_storage_key VARCHAR(255),
    note TEXT,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_fund_expenses_title_non_empty CHECK (length(trim(title)) > 0)
);

CREATE INDEX idx_fund_expenses_fund_time ON fund_expenses(fund_id, occurred_at DESC);
CREATE INDEX idx_fund_expenses_activity ON fund_expenses(activity_id) WHERE activity_id IS NOT NULL;

-- ----------------------------------------------------------------------------
-- 7. Table: fund_reimbursements (Claims by members who spent personal money)
-- ----------------------------------------------------------------------------
CREATE TABLE fund_reimbursements (
    id UUID PRIMARY KEY,
    fund_id UUID NOT NULL REFERENCES group_funds(id) ON DELETE RESTRICT,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    amount NUMERIC(19,2) NOT NULL
        CONSTRAINT chk_fund_reimbursements_amount CHECK (amount > 0),
    reason TEXT NOT NULL,
    receipt_storage_key VARCHAR(255),
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING'
        CONSTRAINT chk_fund_reimbursements_status CHECK (status IN ('PENDING', 'COMPLETED', 'REJECTED', 'CANCELLED')),
    resolved_by UUID REFERENCES users(id) ON DELETE SET NULL,
    resolved_at TIMESTAMPTZ,
    rejection_reason VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_fund_reimbursements_reason_non_empty CHECK (length(trim(reason)) > 0),
    CONSTRAINT chk_fund_reimbursements_resolved_consistency CHECK (
        (status = 'PENDING' AND resolved_at IS NULL)
        OR
        (status IN ('COMPLETED', 'REJECTED', 'CANCELLED') AND resolved_at IS NOT NULL)
    )
);

CREATE INDEX idx_fund_reimbursements_fund_status ON fund_reimbursements(fund_id, status);
CREATE INDEX idx_fund_reimbursements_user ON fund_reimbursements(user_id);

-- ----------------------------------------------------------------------------
-- 8. Table: fund_transactions (Append-only authoritative accounting ledger)
-- ----------------------------------------------------------------------------
CREATE TABLE fund_transactions (
    id UUID PRIMARY KEY,
    fund_id UUID NOT NULL REFERENCES group_funds(id) ON DELETE RESTRICT,
    transaction_type VARCHAR(30) NOT NULL
        CONSTRAINT chk_fund_transactions_type CHECK (
            transaction_type IN ('CONTRIBUTION', 'FUND_EXPENSE', 'REIMBURSEMENT', 'REVERSAL')
        ),
    direction VARCHAR(10) NOT NULL
        CONSTRAINT chk_fund_transactions_direction CHECK (direction IN ('IN', 'OUT')),
    amount NUMERIC(19,2) NOT NULL
        CONSTRAINT chk_fund_transactions_amount CHECK (amount > 0),
    reference_type VARCHAR(50),
    reference_id UUID,
    note TEXT,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_fund_transactions_type_direction CHECK (
        (transaction_type = 'CONTRIBUTION' AND direction = 'IN') OR
        (transaction_type = 'FUND_EXPENSE' AND direction = 'OUT') OR
        (transaction_type = 'REIMBURSEMENT' AND direction = 'OUT') OR
        (transaction_type = 'REVERSAL' AND direction IN ('IN', 'OUT'))
    ),
    CONSTRAINT chk_fund_transactions_reference_consistency CHECK (
        (transaction_type IN ('CONTRIBUTION', 'FUND_EXPENSE', 'REIMBURSEMENT') 
         AND reference_type IS NOT NULL AND reference_id IS NOT NULL)
        OR
        (transaction_type = 'REVERSAL' 
         AND reference_type IS NULL AND reference_id IS NULL)
    ),
    CONSTRAINT chk_fund_transactions_ref_type_match CHECK (
        (transaction_type = 'CONTRIBUTION' AND reference_type = 'FUND_CONTRIBUTION') OR
        (transaction_type = 'FUND_EXPENSE' AND reference_type = 'FUND_EXPENSE') OR
        (transaction_type = 'REIMBURSEMENT' AND reference_type = 'FUND_REIMBURSEMENT') OR
        (transaction_type = 'REVERSAL' AND reference_type IS NULL)
    )
);

-- Idempotency protection: Each domain event can only post once to ledger
CREATE UNIQUE INDEX uq_fund_transactions_domain_ref 
ON fund_transactions(reference_type, reference_id)
WHERE transaction_type IN ('CONTRIBUTION', 'FUND_EXPENSE', 'REIMBURSEMENT');

CREATE INDEX idx_fund_transactions_fund_timeline ON fund_transactions(fund_id, created_at DESC);
CREATE INDEX idx_fund_transactions_type ON fund_transactions(fund_id, transaction_type);

-- ----------------------------------------------------------------------------
-- 9. Table: fund_transaction_reversals (Strict 1-to-1 compensation)
-- ----------------------------------------------------------------------------
CREATE TABLE fund_transaction_reversals (
    id UUID PRIMARY KEY,
    fund_id UUID NOT NULL REFERENCES group_funds(id) ON DELETE RESTRICT,
    original_transaction_id UUID NOT NULL UNIQUE REFERENCES fund_transactions(id) ON DELETE RESTRICT,
    reversal_transaction_id UUID NOT NULL UNIQUE REFERENCES fund_transactions(id) ON DELETE RESTRICT,
    reason TEXT NOT NULL,
    reversed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_fund_tx_reversals_not_self CHECK (original_transaction_id != reversal_transaction_id),
    CONSTRAINT chk_fund_tx_reversals_reason_non_empty CHECK (length(trim(reason)) > 0)
);

CREATE INDEX idx_fund_tx_reversals_fund ON fund_transaction_reversals(fund_id);
