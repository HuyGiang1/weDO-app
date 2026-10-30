CREATE TABLE activity_stops (
 id UUID PRIMARY KEY, activity_id UUID NOT NULL REFERENCES activities(id),
 title VARCHAR(255) NOT NULL CHECK(length(trim(title))>0), notes VARCHAR(5000) NOT NULL DEFAULT '',
 starts_at TIMESTAMPTZ NOT NULL, ends_at TIMESTAMPTZ,
 location_label VARCHAR(160) NOT NULL DEFAULT '', organizer_id UUID REFERENCES users(id),
 estimated_cost NUMERIC(19,2) CHECK(estimated_cost>=0), sort_order INT NOT NULL CHECK(sort_order>=0),
 status VARCHAR(20) NOT NULL DEFAULT 'PLANNED' CHECK(status IN ('PLANNED','IN_PROGRESS','COMPLETED','SKIPPED','CANCELLED')),
 created_by UUID NOT NULL REFERENCES users(id), created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), deleted_at TIMESTAMPTZ,
 CHECK(ends_at IS NULL OR ends_at>starts_at)
);
CREATE UNIQUE INDEX uq_activity_stop_order ON activity_stops(activity_id,sort_order) WHERE deleted_at IS NULL;
CREATE TABLE activity_stop_checkins (
 moment_id UUID PRIMARY KEY REFERENCES group_moments(id), stop_id UUID NOT NULL REFERENCES activity_stops(id),
 source VARCHAR(32) NOT NULL CHECK(source='CAMERA_CLIENT_DECLARED'),
 client_captured_at TIMESTAMPTZ, received_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_stop_checkin_history ON activity_stop_checkins(stop_id,received_at DESC,moment_id DESC);
CREATE FUNCTION enforce_stop_checkin_context() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_TABLE_NAME='activity_stop_checkins' THEN
  IF NOT EXISTS(SELECT 1 FROM activity_stops s JOIN activities a ON a.id=s.activity_id JOIN group_moments m ON m.id=NEW.moment_id WHERE s.id=NEW.stop_id AND m.activity_id=a.id AND m.group_id=a.group_id)
  THEN RAISE EXCEPTION 'Check-in context mismatch' USING ERRCODE='23514'; END IF;
 ELSE
  IF EXISTS(SELECT 1 FROM activity_stop_checkins c JOIN activity_stops s ON s.id=c.stop_id JOIN activities a ON a.id=s.activity_id WHERE c.moment_id=NEW.id AND (NEW.activity_id IS DISTINCT FROM a.id OR NEW.group_id IS DISTINCT FROM a.group_id))
  THEN RAISE EXCEPTION 'Linked check-in context is immutable' USING ERRCODE='23514'; END IF;
 END IF;
 RETURN NEW;
END; $$;
CREATE TRIGGER trg_stop_checkin_context BEFORE INSERT OR UPDATE ON activity_stop_checkins FOR EACH ROW EXECUTE FUNCTION enforce_stop_checkin_context();
CREATE TRIGGER trg_moment_stop_context BEFORE UPDATE ON group_moments FOR EACH ROW EXECUTE FUNCTION enforce_stop_checkin_context();
