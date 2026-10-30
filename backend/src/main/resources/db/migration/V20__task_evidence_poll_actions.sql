CREATE TABLE task_execution (
 task_id UUID PRIMARY KEY REFERENCES tasks(id) ON DELETE CASCADE,
 stop_id UUID REFERENCES activity_stops(id),
 evidence_mode VARCHAR(24) NOT NULL DEFAULT 'NONE' CHECK(evidence_mode IN ('NONE','DIRECT_COMPLETE','REQUIRE_REVIEW'))
);
CREATE INDEX idx_task_stop ON task_execution(stop_id) WHERE stop_id IS NOT NULL;
CREATE TABLE task_evidence (
 id UUID PRIMARY KEY, task_id UUID NOT NULL REFERENCES tasks(id), author_id UUID NOT NULL REFERENCES users(id),
 source VARCHAR(32) NOT NULL CHECK(source IN ('CAMERA_CLIENT_DECLARED','GALLERY_UPLOAD')),
 caption VARCHAR(2000) NOT NULL DEFAULT '', task_snapshot TIMESTAMPTZ NOT NULL,
 status VARCHAR(20) NOT NULL CHECK(status IN ('PENDING','APPROVED','REJECTED','SUPERSEDED')),
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_task_evidence ON task_evidence(task_id,created_at DESC,id DESC);
CREATE UNIQUE INDEX uq_task_pending_evidence ON task_evidence(task_id) WHERE status='PENDING';
CREATE TABLE task_evidence_media (
 id UUID PRIMARY KEY, evidence_id UUID NOT NULL REFERENCES task_evidence(id),
 storage_key VARCHAR(512) NOT NULL UNIQUE, content_type VARCHAR(100) NOT NULL,
 file_name VARCHAR(255) NOT NULL, file_size BIGINT NOT NULL CHECK(file_size>0),
 sort_order INT NOT NULL CHECK(sort_order>=0), UNIQUE(evidence_id,sort_order)
);
CREATE TABLE task_evidence_reviews (
 id UUID PRIMARY KEY, evidence_id UUID NOT NULL UNIQUE REFERENCES task_evidence(id),
 reviewer_id UUID NOT NULL REFERENCES users(id), decision VARCHAR(12) NOT NULL CHECK(decision IN ('APPROVE','REJECT')),
 reason VARCHAR(1000) NOT NULL DEFAULT '', created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE poll_conversion_links (
 id UUID PRIMARY KEY, poll_id UUID REFERENCES polls(id) ON DELETE SET NULL,
 option_id UUID REFERENCES poll_options(id) ON DELETE SET NULL,
 group_id UUID NOT NULL REFERENCES groups(id), activity_id UUID NOT NULL REFERENCES activities(id),
 target_kind VARCHAR(12) NOT NULL CHECK(target_kind IN ('TASK','STOP')),
 task_id UUID REFERENCES tasks(id) ON DELETE SET NULL, stop_id UUID REFERENCES activity_stops(id),
 source_question VARCHAR(5000) NOT NULL, source_option VARCHAR(1000) NOT NULL,
 created_by UUID NOT NULL REFERENCES users(id), created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 CHECK((target_kind='TASK' AND stop_id IS NULL) OR (target_kind='STOP' AND task_id IS NULL)),
 UNIQUE(option_id,target_kind,activity_id)
);
CREATE FUNCTION enforce_journey_target_context() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_TABLE_NAME='task_execution' THEN
  IF NEW.stop_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM activity_stops s JOIN tasks t ON t.activity_id=s.activity_id WHERE s.id=NEW.stop_id AND t.id=NEW.task_id)
  THEN RAISE EXCEPTION 'Task stop context mismatch' USING ERRCODE='23514'; END IF;
 ELSE
  IF NOT EXISTS(SELECT 1 FROM activities a WHERE a.id=NEW.activity_id AND a.group_id=NEW.group_id)
   OR (NEW.poll_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM polls p WHERE p.id=NEW.poll_id AND p.group_id=NEW.group_id))
   OR (NEW.option_id IS NOT NULL AND NEW.poll_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM poll_options o WHERE o.id=NEW.option_id AND o.poll_id=NEW.poll_id))
   OR (NEW.task_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM tasks t WHERE t.id=NEW.task_id AND t.activity_id=NEW.activity_id))
   OR (NEW.stop_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM activity_stops s WHERE s.id=NEW.stop_id AND s.activity_id=NEW.activity_id))
  THEN RAISE EXCEPTION 'Poll conversion context mismatch' USING ERRCODE='23514'; END IF;
 END IF;
 RETURN NEW;
END; $$;
CREATE TRIGGER trg_task_stop_context BEFORE INSERT OR UPDATE ON task_execution FOR EACH ROW EXECUTE FUNCTION enforce_journey_target_context();
CREATE TRIGGER trg_poll_conversion_context BEFORE INSERT OR UPDATE ON poll_conversion_links FOR EACH ROW EXECUTE FUNCTION enforce_journey_target_context();
