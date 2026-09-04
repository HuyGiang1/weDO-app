-- ============================================================================
-- Migration: V4__chat.sql
-- Module: Chat & Messaging
-- Tables: conversations, direct_conversations, group_conversations, 
--         message_requests, conversation_sequences, messages, 
--         message_attachments, message_edit_history, message_hidden_users, 
--         message_reactions, conversation_read_states, message_pins
-- ============================================================================

-- 1. Table: conversations (Root)
CREATE TABLE conversations (
    id UUID PRIMARY KEY,
    type VARCHAR(20) NOT NULL
        CONSTRAINT chk_conversations_type CHECK (type IN ('DIRECT', 'GROUP')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2. Table: direct_conversations (Subtype)
CREATE TABLE direct_conversations (
    conversation_id UUID PRIMARY KEY REFERENCES conversations(id) ON DELETE CASCADE,
    user_id_1 UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    user_id_2 UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT chk_direct_conversations_canonical_order CHECK (user_id_1 < user_id_2),
    CONSTRAINT uq_direct_conversations_pair UNIQUE (user_id_1, user_id_2)
);

CREATE INDEX idx_direct_conversations_user2 ON direct_conversations(user_id_2);

-- 3. Table: group_conversations (Subtype)
CREATE TABLE group_conversations (
    conversation_id UUID PRIMARY KEY REFERENCES conversations(id) ON DELETE CASCADE,
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_group_conversations_group UNIQUE (group_id)
);

-- 4. Table: conversation_sequences
CREATE TABLE conversation_sequences (
    conversation_id UUID PRIMARY KEY REFERENCES conversations(id) ON DELETE CASCADE,
    current_sequence BIGINT NOT NULL DEFAULT 0
        CONSTRAINT chk_conversation_sequences_non_negative CHECK (current_sequence >= 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 5. Table: message_requests
CREATE TABLE message_requests (
    id UUID PRIMARY KEY,
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING'
        CONSTRAINT chk_message_requests_status CHECK (status IN ('PENDING', 'ACCEPTED', 'DECLINED', 'CANCELLED')),
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_message_requests_not_self CHECK (sender_id != receiver_id),
    CONSTRAINT chk_message_requests_consistency CHECK (
        (status = 'PENDING' AND resolved_at IS NULL)
        OR
        (status <> 'PENDING' AND resolved_at IS NOT NULL)
    )
);

-- Mỗi conversation chỉ có tối đa 1 Message Request PENDING
CREATE UNIQUE INDEX uq_message_requests_pending 
    ON message_requests (conversation_id) 
    WHERE status = 'PENDING';

CREATE INDEX idx_message_requests_receiver_status ON message_requests(receiver_id, status);
CREATE INDEX idx_message_requests_conversation ON message_requests(conversation_id);

-- 6. Table: messages
CREATE TABLE messages (
    id UUID PRIMARY KEY,
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE RESTRICT,
    sender_id UUID REFERENCES users(id) ON DELETE SET NULL,
    sequence BIGINT NOT NULL,
    type VARCHAR(20) NOT NULL DEFAULT 'TEXT'
        CONSTRAINT chk_messages_type CHECK (type IN ('TEXT', 'IMAGE')),
    content TEXT,
    reply_to_message_id UUID REFERENCES messages(id) ON DELETE SET NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
        CONSTRAINT chk_messages_status CHECK (status IN ('ACTIVE', 'UNSENT')),
    edited_at TIMESTAMPTZ,
    unsent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_messages_conversation_sequence UNIQUE (conversation_id, sequence),
    CONSTRAINT chk_messages_sequence_positive CHECK (sequence > 0),
    CONSTRAINT chk_messages_active_content CHECK (
        status = 'UNSENT'
        OR type <> 'TEXT'
        OR content IS NOT NULL
    ),
    CONSTRAINT chk_messages_unsent CHECK (
        (status = 'ACTIVE' AND unsent_at IS NULL)
        OR
        (status = 'UNSENT' AND unsent_at IS NOT NULL)
    ),
    CONSTRAINT chk_messages_edited CHECK (edited_at IS NULL OR edited_at >= created_at)
);

CREATE INDEX idx_messages_sender ON messages(sender_id);

-- 7. Table: message_attachments
CREATE TABLE message_attachments (
    id UUID PRIMARY KEY,
    message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    storage_key VARCHAR(500) NOT NULL,
    file_name VARCHAR(255),
    content_type VARCHAR(100) NOT NULL,
    file_size_bytes BIGINT NOT NULL
        CONSTRAINT chk_message_attachments_size CHECK (file_size_bytes > 0),
    sort_order INT NOT NULL DEFAULT 0
        CONSTRAINT chk_message_attachments_order CHECK (sort_order >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_message_attachments_message_order ON message_attachments(message_id, sort_order);

-- 8. Table: message_edit_history
CREATE TABLE message_edit_history (
    id UUID PRIMARY KEY,
    message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    previous_content TEXT,
    edited_by UUID REFERENCES users(id) ON DELETE SET NULL,
    edited_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_message_edit_history_message ON message_edit_history(message_id, edited_at DESC);

-- 9. Table: message_hidden_users (Delete For Me)
CREATE TABLE message_hidden_users (
    message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    hidden_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (message_id, user_id)
);

CREATE INDEX idx_message_hidden_users_user ON message_hidden_users(user_id);

-- 10. Table: message_reactions
CREATE TABLE message_reactions (
    id UUID PRIMARY KEY,
    message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    emoji VARCHAR(32) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_message_reactions_message_user UNIQUE (message_id, user_id)
);

-- 11. Table: conversation_read_states
CREATE TABLE conversation_read_states (
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    last_read_sequence BIGINT NOT NULL DEFAULT 0
        CONSTRAINT chk_conversation_read_states_sequence CHECK (last_read_sequence >= 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (conversation_id, user_id)
);

CREATE INDEX idx_conversation_read_states_user ON conversation_read_states(user_id);

-- 12. Table: message_pins
CREATE TABLE message_pins (
    id UUID PRIMARY KEY,
    message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    pinned_by UUID REFERENCES users(id) ON DELETE SET NULL,
    pinned_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_message_pins_message UNIQUE (message_id)
);
