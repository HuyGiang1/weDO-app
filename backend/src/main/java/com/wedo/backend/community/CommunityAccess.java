package com.wedo.backend.community;

import com.wedo.backend.common.error.*;
import com.wedo.backend.user.service.UserService;
import java.util.*;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Component;

/** One SQL eligibility predicate for feeds, detail, media, interaction and socket delivery. */
@Component
public class CommunityAccess {
    public final NamedParameterJdbcTemplate db;
    private final UserService users;
    public CommunityAccess(NamedParameterJdbcTemplate db, UserService users) { this.db=db; this.users=users; }
    public static final String GRAPH = """
        WITH edges AS (
          SELECT user_id_1 a,user_id_2 b FROM friendships WHERE status='ACTIVE'
          UNION ALL SELECT user_id_2,user_id_1 FROM friendships WHERE status='ACTIVE'
        )
        """;
    public static String unblocked(String a,String b) {
        return "NOT EXISTS(SELECT 1 FROM user_blocks ub WHERE (ub.blocker_id="+a+" AND ub.blocked_id="+b+") OR (ub.blocker_id="+b+" AND ub.blocked_id="+a+"))";
    }
    public static final String FRIEND = "EXISTS(SELECT 1 FROM edges e WHERE e.a=p.author_id AND e.b=:viewer)";
    public static final String GROUP = """
        EXISTS(SELECT 1 FROM group_memberships gm JOIN groups g ON g.id=gm.group_id
          WHERE gm.group_id=p.group_id AND gm.user_id=:viewer AND gm.status='ACTIVE' AND g.status<>'DELETED'
          AND NOT EXISTS(SELECT 1 FROM group_bans gb WHERE gb.group_id=p.group_id AND gb.user_id=:viewer AND gb.unbanned_at IS NULL))
        """;
    public static final String ELIGIBLE = """
        p.deleted_at IS NULL AND p.moderation_status='ACTIVE'
        AND EXISTS(SELECT 1 FROM users u WHERE u.id=p.author_id AND u.status='ACTIVE')
        AND NOT EXISTS(SELECT 1 FROM community_hidden_posts h WHERE h.post_id=p.id AND h.user_id=:viewer)
        AND\s""" + unblocked("p.author_id",":viewer") + """
        AND (
          (p.visibility='GROUP_ONLY' AND\s""" + GROUP + ") OR (p.visibility<>'GROUP_ONLY' AND (p.author_id=:viewer OR p.visibility='PUBLIC' OR "
        + "(p.visibility IN ('FRIENDS','FRIENDS_OF_FRIENDS') AND " + FRIEND + ") OR "
        + "(p.visibility='FRIENDS_OF_FRIENDS' AND EXISTS(SELECT 1 FROM edges e JOIN edges f ON e.b=f.a JOIN users bridge ON bridge.id=e.b AND bridge.status='ACTIVE' WHERE e.a=p.author_id AND f.b=:viewer AND "
        + unblocked("e.b",":viewer") + " AND " + unblocked("e.b","p.author_id") + ")))))";
    public void active(UUID viewer) { users.requireActiveUser(viewer); }
    public boolean canRead(UUID post, UUID viewer) {
        active(viewer);
        return Boolean.TRUE.equals(db.queryForObject(GRAPH+"SELECT EXISTS(SELECT 1 FROM community_posts p WHERE p.id=:post AND "+ELIGIBLE+")",Map.of("viewer",viewer,"post",post),Boolean.class));
    }
    public void require(UUID post, UUID viewer) {
        if(!canRead(post,viewer)) throw new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);
    }
}
