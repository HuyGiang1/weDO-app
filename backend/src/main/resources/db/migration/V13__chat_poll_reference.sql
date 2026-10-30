-- R3: canonical group-owned Poll; Activity association is optional.
ALTER TABLE polls ADD COLUMN group_id UUID REFERENCES groups(id) ON DELETE CASCADE;
UPDATE polls p SET group_id=a.group_id FROM activities a WHERE a.id=p.activity_id;
ALTER TABLE polls ALTER COLUMN activity_id DROP NOT NULL;
ALTER TABLE polls ALTER COLUMN group_id SET NOT NULL;
CREATE INDEX idx_polls_group_created_at ON polls(group_id,created_at DESC);

-- Preserve old Activity-only inserts while enforcing same-group ownership.
CREATE FUNCTION enforce_poll_group() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE activity_group UUID;
BEGIN
  IF NEW.activity_id IS NOT NULL THEN
    SELECT group_id INTO activity_group FROM activities WHERE id=NEW.activity_id;
    IF NEW.group_id IS NULL THEN NEW.group_id=activity_group;
    ELSIF NEW.group_id IS DISTINCT FROM activity_group THEN
      RAISE EXCEPTION 'Poll Activity must belong to its group' USING ERRCODE='23514';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_polls_group BEFORE INSERT OR UPDATE OF activity_id,group_id ON polls
FOR EACH ROW EXECUTE FUNCTION enforce_poll_group();

-- One durable Chat reference; TEXT/IMAGE and all historical ballots unchanged.
ALTER TABLE messages DROP CONSTRAINT chk_messages_type;
ALTER TABLE messages ADD CONSTRAINT chk_messages_type CHECK (type IN ('TEXT','IMAGE','POLL'));
ALTER TABLE messages ADD COLUMN poll_id UUID REFERENCES polls(id) ON DELETE RESTRICT;
ALTER TABLE messages ADD CONSTRAINT uq_messages_poll UNIQUE (poll_id);
ALTER TABLE messages ADD CONSTRAINT chk_messages_poll_reference CHECK (
    (type = 'POLL' AND poll_id IS NOT NULL) OR (type <> 'POLL' AND poll_id IS NULL)
);
