-- Conservative staging admission accounting. Pending/failed uploads retain their
-- reservation: releasing unknown outcomes could permit unaccounted R2 objects.
-- Operator-only latch, CLOSED on first migration. Closing this row does not
-- restart the backend or interrupt text Chat/WebSocket connections.
CREATE TABLE staging_media_upload_control (
    id SMALLINT PRIMARY KEY CHECK (id = 1),
    enabled BOOLEAN NOT NULL DEFAULT FALSE
);
INSERT INTO staging_media_upload_control(id, enabled) VALUES (1, FALSE);

CREATE TABLE staging_media_upload_reservations (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    storage_key VARCHAR(512) NOT NULL UNIQUE,
    reserved_bytes BIGINT NOT NULL CHECK (reserved_bytes > 0),
    created_at TIMESTAMPTZ NOT NULL
);
CREATE INDEX idx_staging_media_user_window
    ON staging_media_upload_reservations(user_id, created_at);
