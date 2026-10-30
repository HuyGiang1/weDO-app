CREATE TABLE group_moments (
 id UUID PRIMARY KEY, group_id UUID NOT NULL REFERENCES groups(id),
 activity_id UUID REFERENCES activities(id), created_by UUID NOT NULL REFERENCES users(id),
 caption VARCHAR(5000) NOT NULL DEFAULT '', created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), deleted_at TIMESTAMPTZ, deleted_by UUID REFERENCES users(id)
);
CREATE INDEX idx_moments_feed ON group_moments(group_id,created_at DESC,id DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_moments_activity ON group_moments(activity_id,created_at DESC,id DESC) WHERE deleted_at IS NULL;
CREATE TABLE moment_media (
 id UUID PRIMARY KEY, moment_id UUID NOT NULL REFERENCES group_moments(id),
 storage_key VARCHAR(512) NOT NULL UNIQUE, content_type VARCHAR(100) NOT NULL,
 file_name VARCHAR(255) NOT NULL, file_size BIGINT NOT NULL CHECK(file_size>0),
 sort_order INT NOT NULL CHECK(sort_order>=0), UNIQUE(moment_id,sort_order)
);
CREATE TABLE moment_reactions (
 moment_id UUID NOT NULL REFERENCES group_moments(id), user_id UUID NOT NULL REFERENCES users(id),
 emoji VARCHAR(16) NOT NULL CHECK(emoji IN ('👍','❤️','😂','😮','😢','😡')),
 PRIMARY KEY(moment_id,user_id)
);
CREATE TABLE moment_comments (
 id UUID PRIMARY KEY, moment_id UUID NOT NULL REFERENCES group_moments(id),
 created_by UUID NOT NULL REFERENCES users(id), content VARCHAR(2000) NOT NULL CHECK(length(trim(content))>0),
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), deleted_at TIMESTAMPTZ, deleted_by UUID REFERENCES users(id)
);
CREATE INDEX idx_moment_comments_cursor ON moment_comments(moment_id,created_at DESC,id DESC) WHERE deleted_at IS NULL;
CREATE TABLE group_albums (
 id UUID PRIMARY KEY, group_id UUID NOT NULL REFERENCES groups(id), activity_id UUID REFERENCES activities(id),
 created_by UUID NOT NULL REFERENCES users(id), name VARCHAR(160) NOT NULL CHECK(length(trim(name))>0),
 description VARCHAR(2000) NOT NULL DEFAULT '', created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), deleted_at TIMESTAMPTZ, deleted_by UUID REFERENCES users(id)
);
CREATE INDEX idx_group_albums_cursor ON group_albums(group_id,created_at DESC,id DESC) WHERE deleted_at IS NULL;
CREATE TABLE album_items (
 album_id UUID NOT NULL REFERENCES group_albums(id), media_id UUID NOT NULL REFERENCES moment_media(id),
 added_by UUID NOT NULL REFERENCES users(id), added_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 PRIMARY KEY(album_id,media_id)
);
-- Cross-group links are invalid even for direct SQL writers.
CREATE FUNCTION enforce_memory_links() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_TABLE_NAME='album_items' THEN
  IF (SELECT a.group_id FROM group_albums a WHERE a.id=NEW.album_id) IS DISTINCT FROM
     (SELECT m.group_id FROM moment_media mm JOIN group_moments m ON m.id=mm.moment_id WHERE mm.id=NEW.media_id)
  THEN RAISE EXCEPTION 'Album media group mismatch' USING ERRCODE='23514'; END IF;
 ELSIF NEW.activity_id IS NOT NULL AND NEW.group_id IS DISTINCT FROM
     (SELECT group_id FROM activities WHERE id=NEW.activity_id)
 THEN RAISE EXCEPTION 'Memory Activity group mismatch' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END; $$;
CREATE TRIGGER trg_moment_activity BEFORE INSERT OR UPDATE ON group_moments FOR EACH ROW EXECUTE FUNCTION enforce_memory_links();
CREATE TRIGGER trg_album_activity BEFORE INSERT OR UPDATE ON group_albums FOR EACH ROW EXECUTE FUNCTION enforce_memory_links();
CREATE TRIGGER trg_album_item_group BEFORE INSERT OR UPDATE ON album_items FOR EACH ROW EXECUTE FUNCTION enforce_memory_links();
