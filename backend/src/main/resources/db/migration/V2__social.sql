-- V2__social.sql
-- Module: Social & Relationships
-- Tables: friend_requests, friendships, user_blocks, user_presence_snapshots

-- 1. Table: friend_requests
CREATE TABLE friend_requests (
    id UUID PRIMARY KEY,
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING'
        CONSTRAINT chk_friend_requests_status CHECK (status IN ('PENDING', 'ACCEPTED', 'DECLINED', 'CANCELLED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    responded_at TIMESTAMPTZ,
    CONSTRAINT chk_friend_requests_not_self CHECK (sender_id != receiver_id),
    CONSTRAINT chk_friend_requests_response_time CHECK (
        (status = 'PENDING' AND responded_at IS NULL)
        OR
        (status <> 'PENDING' AND responded_at IS NOT NULL)
    )
);

-- Chống gửi trùng lặp ở cả hai chiều (A->B và B->A) khi đang PENDING bằng Canonical Pair Expression Index
CREATE UNIQUE INDEX uq_friend_requests_pending_pair 
    ON friend_requests (LEAST(sender_id, receiver_id), GREATEST(sender_id, receiver_id)) 
    WHERE status = 'PENDING';

CREATE INDEX idx_friend_requests_receiver_status ON friend_requests(receiver_id, status);
CREATE INDEX idx_friend_requests_sender_status ON friend_requests(sender_id, status);

-- 2. Table: friendships
CREATE TABLE friendships (
    id UUID PRIMARY KEY,
    user_id_1 UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user_id_2 UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE'
        CONSTRAINT chk_friendships_status CHECK (status IN ('ACTIVE', 'ENDED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMPTZ,
    CONSTRAINT chk_friendships_canonical_pair CHECK (user_id_1 < user_id_2),
    CONSTRAINT chk_friendships_end_time CHECK (
        (status = 'ACTIVE' AND ended_at IS NULL)
        OR
        (status = 'ENDED' AND ended_at IS NOT NULL)
    )
);

-- Chỉ cho phép tối đa 1 quan hệ ACTIVE giữa mỗi cặp user, đồng thời cho phép tạo row mới để bảo toàn lịch sử qua các chu kỳ kết bạn
CREATE UNIQUE INDEX uq_friendships_active_pair 
    ON friendships (user_id_1, user_id_2) 
    WHERE status = 'ACTIVE';

CREATE INDEX idx_friendships_user1_status ON friendships(user_id_1, status);
CREATE INDEX idx_friendships_user2_status ON friendships(user_id_2, status);

-- 3. Table: user_blocks
CREATE TABLE user_blocks (
    id UUID PRIMARY KEY,
    blocker_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_user_blocks_not_self CHECK (blocker_id != blocked_id),
    CONSTRAINT uq_user_blocks_pair UNIQUE (blocker_id, blocked_id)
);

-- Giữ reverse index để tra cứu theo blocked_id; không tạo idx_user_blocks_blocker vì uq_user_blocks_pair đã cover prefix blocker_id
CREATE INDEX idx_user_blocks_blocked ON user_blocks(blocked_id);

-- 4. Table: user_presence_snapshots
CREATE TABLE user_presence_snapshots (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    last_seen_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
