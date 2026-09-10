-- V11: Session Family Hardening - Add absolute family expiration timestamp
ALTER TABLE refresh_sessions
    ADD COLUMN absolute_expires_at TIMESTAMPTZ;
