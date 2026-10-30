-- Forward-only: V13 is already applied. Preserve original cards and ballots.
ALTER TABLE messages DROP CONSTRAINT chk_messages_type;
ALTER TABLE messages ADD CONSTRAINT chk_messages_type CHECK
  (type IN ('TEXT','IMAGE','POLL','POLL_VOTED','POLL_VOTE_CHANGED'));
ALTER TABLE messages DROP CONSTRAINT uq_messages_poll;
CREATE UNIQUE INDEX uq_messages_original_poll ON messages(poll_id) WHERE type='POLL';
ALTER TABLE messages DROP CONSTRAINT chk_messages_poll_reference;
ALTER TABLE messages ADD CONSTRAINT chk_messages_poll_reference CHECK
  ((type IN ('POLL','POLL_VOTED','POLL_VOTE_CHANGED') AND poll_id IS NOT NULL)
   OR (type IN ('TEXT','IMAGE') AND poll_id IS NULL));

-- Command receipts only, never a second ballot store. Prevent delayed retries
-- from applying an old command after another successful vote change.
CREATE TABLE poll_vote_commands (
  poll_id UUID NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  request_id UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (poll_id,user_id,request_id)
);
