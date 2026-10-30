CREATE TABLE community_posts (
 id UUID PRIMARY KEY, author_id UUID NOT NULL REFERENCES users(id),
 post_type VARCHAR(32) NOT NULL DEFAULT 'GENERAL' CHECK(post_type='GENERAL'),
 caption VARCHAR(5000) NOT NULL DEFAULT '',
 visibility VARCHAR(32) NOT NULL CHECK(visibility IN ('PUBLIC','FRIENDS_OF_FRIENDS','FRIENDS','GROUP_ONLY')),
 group_id UUID REFERENCES groups(id),
 moderation_status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK(moderation_status IN ('ACTIVE','REMOVED')),
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 deleted_at TIMESTAMPTZ, deleted_by UUID REFERENCES users(id),
 CHECK((visibility='GROUP_ONLY')=(group_id IS NOT NULL))
);
CREATE INDEX idx_community_feed ON community_posts(created_at DESC,id DESC) WHERE deleted_at IS NULL AND moderation_status='ACTIVE';
CREATE INDEX idx_community_author ON community_posts(author_id,created_at DESC,id DESC);
CREATE INDEX idx_community_group ON community_posts(group_id) WHERE group_id IS NOT NULL;
CREATE TABLE community_media (
 id UUID PRIMARY KEY, post_id UUID NOT NULL REFERENCES community_posts(id),
 storage_key VARCHAR(512) NOT NULL UNIQUE, content_type VARCHAR(100) NOT NULL,
 file_name VARCHAR(255) NOT NULL, file_size BIGINT NOT NULL CHECK(file_size>0),
 sort_order INT NOT NULL CHECK(sort_order>=0), UNIQUE(post_id,sort_order)
);
CREATE TABLE community_reactions (
 post_id UUID NOT NULL REFERENCES community_posts(id), user_id UUID NOT NULL REFERENCES users(id),
 emoji VARCHAR(16) NOT NULL CHECK(emoji IN ('👍','❤️','😂','😮','😢','😡')), PRIMARY KEY(post_id,user_id)
);
CREATE TABLE community_comments (
 id UUID PRIMARY KEY, post_id UUID NOT NULL REFERENCES community_posts(id),
 author_id UUID NOT NULL REFERENCES users(id), content VARCHAR(2000) NOT NULL CHECK(length(trim(content))>0),
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), deleted_at TIMESTAMPTZ, deleted_by UUID REFERENCES users(id)
);
CREATE INDEX idx_community_comments ON community_comments(post_id,created_at DESC,id DESC) WHERE deleted_at IS NULL;
CREATE TABLE community_hidden_posts (
 post_id UUID NOT NULL REFERENCES community_posts(id), user_id UUID NOT NULL REFERENCES users(id),
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), PRIMARY KEY(post_id,user_id)
);
CREATE TABLE community_reports (
 id UUID PRIMARY KEY, post_id UUID NOT NULL REFERENCES community_posts(id),
 reporter_id UUID NOT NULL REFERENCES users(id),
 reason VARCHAR(32) NOT NULL CHECK(reason IN ('SPAM','HARASSMENT','INAPPROPRIATE','OTHER')),
 status VARCHAR(20) NOT NULL DEFAULT 'OPEN' CHECK(status IN ('OPEN','REVIEWED','DISMISSED')),
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), UNIQUE(post_id,reporter_id)
);
