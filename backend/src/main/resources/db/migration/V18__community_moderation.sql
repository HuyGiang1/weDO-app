-- Extend canonical reports; no duplicate post/report store or automatic role grant.
ALTER TABLE community_reports DROP CONSTRAINT community_reports_post_id_reporter_id_key;
ALTER TABLE community_reports DROP CONSTRAINT community_reports_reason_check;
ALTER TABLE community_reports ALTER COLUMN post_id DROP NOT NULL;
ALTER TABLE community_reports ADD COLUMN target_type VARCHAR(12) NOT NULL DEFAULT 'POST'
 CHECK(target_type IN ('POST','COMMENT','USER'));
ALTER TABLE community_reports ADD COLUMN target_user_id UUID REFERENCES users(id);
ALTER TABLE community_reports ADD COLUMN target_comment_id UUID REFERENCES community_comments(id);
ALTER TABLE community_reports ADD COLUMN evidence VARCHAR(5000) NOT NULL DEFAULT '';
ALTER TABLE community_reports ADD CONSTRAINT community_reports_reason_check
 CHECK(reason IN ('SPAM','HARASSMENT','INAPPROPRIATE','INAPPROPRIATE_CONTENT','SCAM','OTHER'));
ALTER TABLE community_reports ADD CONSTRAINT community_reports_target_check CHECK(
 (target_type='POST' AND post_id IS NOT NULL AND target_user_id IS NULL AND target_comment_id IS NULL) OR
 (target_type='COMMENT' AND post_id IS NOT NULL AND target_comment_id IS NOT NULL AND target_user_id IS NULL) OR
 (target_type='USER' AND post_id IS NULL AND target_user_id IS NOT NULL AND target_comment_id IS NULL));
CREATE UNIQUE INDEX uq_community_report_active ON community_reports
 (reporter_id,target_type,(COALESCE(target_comment_id,target_user_id,post_id))) WHERE status='OPEN';
CREATE INDEX idx_community_report_queue ON community_reports(status,reason,target_type,created_at DESC,id DESC);
CREATE TABLE community_moderators (
 user_id UUID PRIMARY KEY REFERENCES users(id), granted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 granted_by UUID REFERENCES users(id), revoked_at TIMESTAMPTZ
);
CREATE TABLE community_moderation_actions (
 id UUID PRIMARY KEY, report_id UUID NOT NULL REFERENCES community_reports(id),
 moderator_id UUID NOT NULL REFERENCES users(id),
 action VARCHAR(16) NOT NULL CHECK(action IN ('DISMISS','RESOLVE','REMOVE','RESTORE')),
 reason VARCHAR(1000) NOT NULL CHECK(length(trim(reason))>0),
 before_status VARCHAR(20) NOT NULL, after_status VARCHAR(20) NOT NULL,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_community_moderation_history ON community_moderation_actions(report_id,created_at,id);
ALTER TABLE community_comments ADD COLUMN moderation_status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
 CHECK(moderation_status IN ('ACTIVE','REMOVED'));

-- Populate only minimal existing report evidence; no media keys or reporter disclosure.
UPDATE community_reports r SET evidence=p.caption FROM community_posts p WHERE p.id=r.post_id;
UPDATE community_reports SET reason='INAPPROPRIATE_CONTENT' WHERE reason='INAPPROPRIATE';
CREATE FUNCTION enforce_community_report_comment() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF NEW.target_type='COMMENT' AND NOT EXISTS(SELECT 1 FROM community_comments c WHERE c.id=NEW.target_comment_id AND c.post_id=NEW.post_id)
 THEN RAISE EXCEPTION 'Comment report context mismatch' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END; $$;
CREATE TRIGGER trg_community_report_comment BEFORE INSERT OR UPDATE ON community_reports FOR EACH ROW EXECUTE FUNCTION enforce_community_report_comment();
