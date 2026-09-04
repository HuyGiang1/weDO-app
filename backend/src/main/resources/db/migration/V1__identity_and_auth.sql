-- V1__identity_and_auth.sql
-- Module: Identity & Authentication
-- Tables: users, user_credentials, user_privacy_settings, auth_tokens, refresh_sessions, user_devices

CREATE EXTENSION IF NOT EXISTS citext;

-- 1. Table: users
CREATE TABLE users (
    id UUID PRIMARY KEY,
    email CITEXT NOT NULL UNIQUE,
    username CITEXT UNIQUE,
    display_name VARCHAR(100),
    avatar_storage_key VARCHAR(255),
    bio VARCHAR(500),
    phone VARCHAR(20),
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING_VERIFICATION'
        CONSTRAINT chk_users_status CHECK (status IN ('PENDING_VERIFICATION', 'ACTIVE', 'SUSPENDED', 'DEACTIVATED')),
    email_verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_status ON users(status);

-- 2. Table: user_credentials
CREATE TABLE user_credentials (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    password_hash VARCHAR(255) NOT NULL,
    failed_attempts INT NOT NULL DEFAULT 0
        CONSTRAINT chk_user_credentials_failed_attempts CHECK (failed_attempts >= 0),
    locked_until TIMESTAMPTZ,
    password_changed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 3. Table: user_privacy_settings
CREATE TABLE user_privacy_settings (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    discover_by_username BOOLEAN NOT NULL DEFAULT TRUE,
    discover_by_qr BOOLEAN NOT NULL DEFAULT TRUE,
    discover_by_email BOOLEAN NOT NULL DEFAULT FALSE,
    discover_by_phone BOOLEAN NOT NULL DEFAULT FALSE,
    dm_policy VARCHAR(30) NOT NULL DEFAULT 'EVERYONE'
        CONSTRAINT chk_user_privacy_dm_policy CHECK (dm_policy IN ('EVERYONE', 'MUTUAL_GROUPS', 'FRIENDS_ONLY')),
    friend_request_policy VARCHAR(30) NOT NULL DEFAULT 'EVERYONE'
        CONSTRAINT chk_user_privacy_friend_policy CHECK (friend_request_policy IN ('EVERYONE', 'MUTUAL_GROUPS', 'NONE')),
    show_online_status BOOLEAN NOT NULL DEFAULT TRUE,
    show_last_seen BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 4. Table: auth_tokens
CREATE TABLE auth_tokens (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_type VARCHAR(30) NOT NULL
        CONSTRAINT chk_auth_tokens_type CHECK (token_type IN ('EMAIL_VERIFICATION', 'PASSWORD_RESET')),
    token_hash VARCHAR(255) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    attempts INT NOT NULL DEFAULT 0
        CONSTRAINT chk_auth_tokens_attempts CHECK (attempts >= 0),
    consumed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_auth_tokens_user_type ON auth_tokens(user_id, token_type);
CREATE INDEX idx_auth_tokens_token_hash ON auth_tokens(token_hash);

-- 5. Table: refresh_sessions
CREATE TABLE refresh_sessions (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    replaced_by_session_id UUID REFERENCES refresh_sessions(id) ON DELETE SET NULL,
    device_name VARCHAR(100),
    ip_address VARCHAR(45),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_refresh_sessions_user_id ON refresh_sessions(user_id);

-- 6. Table: user_devices
CREATE TABLE user_devices (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    platform VARCHAR(20) NOT NULL
        CONSTRAINT chk_user_devices_platform CHECK (platform IN ('IOS', 'ANDROID', 'WEB')),
    push_token TEXT NOT NULL,
    device_id VARCHAR(100) NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_user_devices_user_device UNIQUE (user_id, device_id)
);

CREATE INDEX idx_user_devices_user_active ON user_devices(user_id, active);
CREATE INDEX idx_user_devices_push_token ON user_devices(push_token);
