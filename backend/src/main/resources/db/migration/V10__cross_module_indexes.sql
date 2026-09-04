-- ============================================================================
-- Migration: V10__cross_module_indexes.sql
-- Module: Cross-Module Indexes, Constraints & Hardening
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Security & Privacy Hardening: Active Push Token Uniqueness
-- Đảm bảo tại một thời điểm mỗi push_token chỉ gắn với tối đa một tài khoản ACTIVE,
-- ngăn ngừa rò rỉ thông báo đẩy khi nhiều người dùng đăng nhập trên cùng một thiết bị.
-- ----------------------------------------------------------------------------
CREATE UNIQUE INDEX uq_user_devices_active_push_token
    ON user_devices (push_token)
    WHERE active = TRUE;
