package com.wedo.backend.community;

import static com.wedo.backend.community.CommunityDtos.*;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import java.sql.Timestamp;
import java.time.*;
import java.util.*;
import java.util.function.Function;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/** Bounded ranking windows and opaque, viewer-bound, expiring UUID cursors.
 * Snapshots contain IDs/order only. Every page rechecks current R7 eligibility.
 * Local ephemeral cache: restart/eviction/another instance requires explicit refresh.
 */
@Component
public final class CommunityFeedRanking {
    static final int VERSION = 1;
    private final CommunityAccess access;
    private final FeedRankingPolicy policy;
    private final Clock clock;
    private final int windowSize, maxCursors;
    private final Duration ttl;
    private final Map<UUID, Cursor> cursors = new LinkedHashMap<>();
    record Boundary(Instant created, UUID id) {}
    record Candidate(UUID id, Instant created, long score) {}
    record Window(List<Candidate> ordered, Boundary end, boolean more) {}
    record Cursor(int version, UUID viewer, Instant reference, Instant expires, Window window, int offset) {}

    public CommunityFeedRanking(CommunityAccess access, FeedRankingPolicy policy, Clock clock,
            @Value("${wedo.community.ranking.window-size:200}") int windowSize,
            @Value("${wedo.community.ranking.max-cursors:2048}") int maxCursors,
            @Value("${wedo.community.ranking.cursor-ttl-seconds:900}") int ttlSeconds) {
        if (windowSize < 20 || windowSize > 500 || maxCursors < 1 || maxCursors > 10000 || ttlSeconds < 1 || ttlSeconds > 3600)
            throw new IllegalArgumentException("Invalid Community ranking limits");
        this.access = access; this.policy = policy; this.clock = clock;
        this.windowSize = windowSize; this.maxCursors = maxCursors; this.ttl = Duration.ofSeconds(ttlSeconds);
    }

    // Reports affect only this viewer's discovery; detail/media authorization remains R7.
    static final String DISCOVERABLE = CommunityAccess.ELIGIBLE + """
        AND NOT EXISTS(SELECT 1 FROM community_reports report WHERE report.reporter_id=:viewer
          AND report.target_type='POST' AND report.post_id=p.id)
        """;
    private static final String OPEN_RECRUITMENT = """
        r.closed_at IS NULL AND r.expires_at>:reference
        AND (r.planned_at IS NULL OR r.planned_at>=:reference)
        AND EXISTS(SELECT 1 FROM groups g JOIN group_settings s ON s.group_id=g.id
          JOIN group_memberships manager ON manager.group_id=g.id
          WHERE g.id=r.group_id AND g.status='ACTIVE' AND s.join_policy='APPROVAL_REQUIRED'
          AND manager.user_id=p.author_id AND manager.status='ACTIVE' AND manager.role IN ('OWNER','ADMIN')
          AND NOT EXISTS(SELECT 1 FROM group_bans ban WHERE ban.group_id=g.id AND ban.user_id=manager.user_id AND ban.unbanned_at IS NULL))
        AND NOT EXISTS(SELECT 1 FROM activities a WHERE a.id=r.activity_id AND
          (a.status IN ('CANCELLED','COMPLETED') OR a.end_at<=:reference))
        AND (SELECT count(DISTINCT q.user_id) FROM recruitment_applications ra
          JOIN group_join_requests q ON q.id=ra.request_id WHERE ra.post_id=p.id AND q.status='APPROVED')<r.requested_count
        AND (SELECT count(*) FROM group_memberships gm WHERE gm.group_id=r.group_id AND gm.status='ACTIVE')<100
        """;

    private Map<String,Object> args(UUID viewer, Instant reference) {
        var result = new HashMap<String,Object>(); result.put("viewer", viewer);
        result.put("reference", Timestamp.from(reference)); return result;
    }

    private Window window(UUID viewer, Instant reference, Boundary before) {
        var args = args(viewer, reference);
        args.put("beforeTime", before == null ? null : Timestamp.from(before.created()));
        args.put("beforeId", before == null ? null : before.id()); args.put("limit", windowSize + 1);
        // LIMIT uses existing idx_community_feed. Expensive counts run only for this bounded window.
        String sql = CommunityAccess.GRAPH + """
            , candidates AS MATERIALIZED (
              SELECT p.* FROM community_posts p WHERE
            """ + DISCOVERABLE + """
              AND p.created_at<=:reference
              AND (CAST(:beforeId AS uuid) IS NULL OR (p.created_at,p.id)<(CAST(:beforeTime AS timestamptz),CAST(:beforeId AS uuid)))
              ORDER BY p.created_at DESC,p.id DESC LIMIT :limit
            ) SELECT p.id,p.created_at,
            """ + CommunityAccess.FRIEND + " AS friend, (r.post_id IS NOT NULL AND " + OPEN_RECRUITMENT + """
            ) AS open_recruitment,
            (SELECT count(*) FROM (SELECT actor FROM (
              SELECT cr.user_id actor FROM community_reactions cr WHERE cr.post_id=p.id
              UNION SELECT cc.author_id FROM community_comments cc WHERE cc.post_id=p.id
                AND cc.deleted_at IS NULL AND cc.moderation_status='ACTIVE'
            ) actors WHERE actor<>p.author_id AND EXISTS(SELECT 1 FROM users u WHERE u.id=actor AND u.status='ACTIVE') AND
            """ + CommunityAccess.unblocked("actor", ":viewer") + """
              LIMIT :actorCap) bounded_actors) AS actors
            FROM candidates p LEFT JOIN community_recruitment r ON r.post_id=p.id
            ORDER BY p.created_at DESC,p.id DESC
            """;
        args.put("actorCap", policy.actorCap);
        var rows = access.db.query(sql, args, (r,n) -> new Candidate(r.getObject("id",UUID.class),
                r.getTimestamp("created_at").toInstant(), policy.score(r.getTimestamp("created_at").toInstant(), reference,
                r.getLong("actors"), r.getBoolean("friend"), r.getBoolean("open_recruitment"))));
        boolean more = rows.size() > windowSize;
        var selected = rows.stream().limit(windowSize).toList();
        Boundary end = selected.isEmpty() ? before : new Boundary(selected.getLast().created(), selected.getLast().id());
        var ordered = new ArrayList<>(selected);
        // UUID SQL ordering is unsigned byte order; canonical strings preserve that order in Java.
        ordered.sort(Comparator.comparingLong(Candidate::score).reversed()
                .thenComparing(Candidate::created, Comparator.reverseOrder())
                .thenComparing(c -> c.id().toString(), Comparator.reverseOrder()));
        return new Window(List.copyOf(ordered), end, more);
    }

    private synchronized Cursor lookup(UUID token, UUID viewer) {
        Cursor c = cursors.get(token);
        if (c == null || c.version()!=VERSION || !c.viewer().equals(viewer) || !c.expires().isAfter(clock.instant()))
            throw new BusinessException(ErrorCode.COMMUNITY_FEED_CURSOR_INVALID);
        return c;
    }
    private synchronized UUID remember(Cursor cursor) {
        cursors.values().removeIf(c -> !c.expires().isAfter(clock.instant()));
        while (cursors.size() >= maxCursors) cursors.remove(cursors.keySet().iterator().next());
        UUID token = UUID.randomUUID(); cursors.put(token, cursor); return token;
    }

    public Page<Post> page(UUID viewer,UUID token,Function<UUID,Post> hydrate) {
        return pageBatch(viewer,token,ids->{
            var posts=new ArrayList<Post>();
            for(UUID id:ids)try{posts.add(hydrate.apply(id));}catch(BusinessException e){if(e.errorCode()!=ErrorCode.RESOURCE_NOT_FOUND)throw e;}
            return posts;
        });
    }
    public Page<Post> pageBatch(UUID viewer,UUID token,Function<List<UUID>,List<Post>> hydrate) {
        access.active(viewer);
        Instant now = clock.instant();
        Cursor cursor = token == null ? new Cursor(VERSION, viewer, now, now.plus(ttl), window(viewer, now, null), 0) : lookup(token,viewer);
        var selected = new ArrayList<UUID>();
        Window batch = cursor.window(); int offset = cursor.offset();
        // At most one bounded window per HTTP request; older windows remain reachable.
        List<UUID> remaining = batch.ordered().subList(offset,batch.ordered().size()).stream().map(Candidate::id).toList();
        Set<UUID> allowed = new HashSet<>();
        if (!remaining.isEmpty()) {
            var args = args(viewer, now); args.put("ids",remaining);
            allowed.addAll(access.db.queryForList(CommunityAccess.GRAPH+"SELECT p.id FROM community_posts p WHERE p.id IN (:ids) AND "+DISCOVERABLE,args,UUID.class));
        }
        while (offset < batch.ordered().size() && selected.size()<20) {
            UUID id = batch.ordered().get(offset++).id();
            if (allowed.contains(id)) selected.add(id);
        }
        var hydrated = new HashMap<UUID,Post>();
        if(!selected.isEmpty())for(Post post:hydrate.apply(List.copyOf(selected)))hydrated.put(post.id(),post);
        // Hydration rechecks current authorization; never add IDs outside selection.
        var items=selected.stream().map(hydrated::get).filter(Objects::nonNull).toList();
        while (offset<batch.ordered().size() && !allowed.contains(batch.ordered().get(offset).id())) offset++;
        UUID next = null;
        if (offset<batch.ordered().size()) {
            next=remember(new Cursor(VERSION,viewer,cursor.reference(),cursor.expires(),batch,offset));
        } else if (batch.more()) {
            Window older=window(viewer,cursor.reference(),batch.end());
            if (!older.ordered().isEmpty()) next=remember(new Cursor(VERSION,viewer,cursor.reference(),cursor.expires(),older,0));
        }
        return new Page<>(List.copyOf(items),next,next!=null);
    }
}
