ALTER TABLE community_posts DROP CONSTRAINT community_posts_post_type_check;
ALTER TABLE community_posts ADD CONSTRAINT community_posts_post_type_check CHECK(post_type IN ('GENERAL','LOOKING_FOR_MEMBERS'));
CREATE TABLE community_recruitment (
 post_id UUID PRIMARY KEY REFERENCES community_posts(id), group_id UUID NOT NULL REFERENCES groups(id),
 activity_id UUID REFERENCES activities(id), requested_count INT NOT NULL CHECK(requested_count BETWEEN 1 AND 100),
 broad_location VARCHAR(160) NOT NULL DEFAULT '', tags TEXT[] NOT NULL DEFAULT '{}',
 planned_at TIMESTAMPTZ, expires_at TIMESTAMPTZ NOT NULL,
 closed_at TIMESTAMPTZ, closed_by UUID REFERENCES users(id),
 public_group_name VARCHAR(160) NOT NULL, public_activity_title VARCHAR(255), public_activity_start TIMESTAMPTZ,
 CHECK(cardinality(tags)<=6)
);
CREATE INDEX idx_recruitment_discovery ON community_recruitment(expires_at,post_id) WHERE closed_at IS NULL;
CREATE INDEX idx_recruitment_group ON community_recruitment(group_id);
CREATE INDEX idx_recruitment_activity ON community_recruitment(activity_id);
-- Provenance only: requests and memberships remain canonical Group admission facts.
CREATE TABLE recruitment_applications (
 request_id UUID PRIMARY KEY REFERENCES group_join_requests(id),
 post_id UUID NOT NULL REFERENCES community_recruitment(post_id), created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_recruitment_applications_post ON recruitment_applications(post_id);
CREATE FUNCTION enforce_recruitment_links() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_TABLE_NAME='recruitment_applications' THEN
  IF (SELECT group_id FROM group_join_requests WHERE id=NEW.request_id) IS DISTINCT FROM
     (SELECT group_id FROM community_recruitment WHERE post_id=NEW.post_id)
  THEN RAISE EXCEPTION 'Recruitment request group mismatch' USING ERRCODE='23514'; END IF;
 ELSE
  IF NOT EXISTS(SELECT 1 FROM community_posts p WHERE p.id=NEW.post_id AND p.post_type='LOOKING_FOR_MEMBERS'
    AND (p.visibility<>'GROUP_ONLY' OR p.group_id=NEW.group_id))
   OR (NEW.activity_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM activities a WHERE a.id=NEW.activity_id AND a.group_id=NEW.group_id))
  THEN RAISE EXCEPTION 'Recruitment ownership mismatch' USING ERRCODE='23514'; END IF;
 END IF;
 RETURN NEW;
END; $$;
CREATE TRIGGER trg_recruitment_links BEFORE INSERT OR UPDATE ON community_recruitment FOR EACH ROW EXECUTE FUNCTION enforce_recruitment_links();
CREATE TRIGGER trg_recruitment_request BEFORE INSERT OR UPDATE ON recruitment_applications FOR EACH ROW EXECUTE FUNCTION enforce_recruitment_links();
