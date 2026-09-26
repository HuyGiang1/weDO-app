-- ============================================================================
-- Migration: V12__unscheduled_activities.sql
-- Module: Activity & RSVP
-- Description: Allow unscheduled activities where start_at, end_at, and timezone
--              are null, while maintaining end_at > start_at when scheduled.
-- ============================================================================

ALTER TABLE activities ALTER COLUMN start_at DROP NOT NULL;
ALTER TABLE activities ALTER COLUMN timezone DROP NOT NULL;

ALTER TABLE activities DROP CONSTRAINT IF EXISTS chk_activities_time_order;

ALTER TABLE activities ADD CONSTRAINT chk_activities_schedule_consistency CHECK (
    (start_at IS NULL AND end_at IS NULL AND timezone IS NULL)
    OR
    (start_at IS NOT NULL AND timezone IS NOT NULL AND (end_at IS NULL OR end_at > start_at))
);
