package com.wedo.backend.community;

import static com.wedo.backend.community.CommunityDtos.*;
import com.wedo.backend.common.error.*;
import com.wedo.backend.moment.MomentDtos.Author;
import com.wedo.backend.moment.MomentDtos.Media;
import java.sql.Timestamp;
import java.util.*;
import org.springframework.stereotype.Component;

/** Bounded list hydration. Reuses the exact R7 predicate, never trusts cached IDs. */
@Component
public class CommunityPostReader {
    private final CommunityAccess access;
    private final RecruitmentProjection recruitment;
    public CommunityPostReader(CommunityAccess access, RecruitmentProjection recruitment) {
        this.access=access; this.recruitment=recruitment;
    }

    public List<Post> read(List<UUID> requested, UUID viewer) {
        access.active(viewer);
        if(requested.size()>100)throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        if(requested.isEmpty())return List.of();
        var args=new HashMap<String,Object>();args.put("viewer",viewer);args.put("ids",requested);
        var rows=access.db.queryForList(CommunityAccess.GRAPH+"""
            SELECT p.*,COALESCE(author.display_name,author.username::text) author_name,
                   author.avatar_storage_key author_avatar,viewer_member.role viewer_role,g.status group_status
            FROM community_posts p JOIN users author ON author.id=p.author_id
            LEFT JOIN groups g ON g.id=p.group_id
            LEFT JOIN group_memberships viewer_member ON viewer_member.group_id=p.group_id
                AND viewer_member.user_id=:viewer AND viewer_member.status='ACTIVE'
            WHERE p.id IN (:ids) AND
            """+CommunityAccess.ELIGIBLE,args);
        if(rows.isEmpty())return List.of();
        var byId=new HashMap<UUID,Map<String,Object>>();
        for(var row:rows)byId.put((UUID)row.get("id"),row);
        args.put("ids",new ArrayList<>(byId.keySet()));
        var media=new HashMap<UUID,List<Media>>();
        access.db.query("SELECT * FROM community_media WHERE post_id IN (:ids) ORDER BY post_id,sort_order,id",args,r->{
            UUID id=r.getObject("post_id",UUID.class);
            media.computeIfAbsent(id,k->new ArrayList<>()).add(new Media(r.getObject("id",UUID.class),r.getString("content_type"),
                r.getString("file_name"),r.getLong("file_size"),r.getInt("sort_order")));
        });
        String visibleReaction=CommunityAccess.unblocked("cr.user_id",":viewer")+" AND EXISTS(SELECT 1 FROM users u WHERE u.id=cr.user_id AND u.status='ACTIVE')";
        var reactions=access.db.queryForList("SELECT cr.post_id,count(*) n,max(cr.emoji) FILTER(WHERE cr.user_id=:viewer) mine FROM community_reactions cr WHERE cr.post_id IN (:ids) AND "+visibleReaction+" GROUP BY cr.post_id",args);
        var reactionCounts=new HashMap<UUID,Long>();var ownReactions=new HashMap<UUID,String>();
        for(var row:reactions){UUID id=(UUID)row.get("post_id");reactionCounts.put(id,((Number)row.get("n")).longValue());ownReactions.put(id,(String)row.get("mine"));}
        String visibleComment=CommunityAccess.unblocked("cc.author_id",":viewer")+" AND EXISTS(SELECT 1 FROM users u WHERE u.id=cc.author_id AND u.status='ACTIVE')";
        var comments=access.db.queryForList("SELECT cc.post_id,count(*) n FROM community_comments cc WHERE cc.post_id IN (:ids) AND cc.deleted_at IS NULL AND cc.moderation_status='ACTIVE' AND "+visibleComment+" GROUP BY cc.post_id",args);
        var commentCounts=new HashMap<UUID,Long>();
        for(var row:comments)commentCounts.put((UUID)row.get("post_id"),((Number)row.get("n")).longValue());
        var recruitmentIds=rows.stream().filter(r->"LOOKING_FOR_MEMBERS".equals(r.get("post_type"))).map(r->(UUID)r.get("id")).toList();
        var recruits=recruitment.views(recruitmentIds,viewer);
        var result=new ArrayList<Post>();
        for(UUID id:new LinkedHashSet<>(requested)) {
            var row=byId.get(id);if(row==null)continue;
            UUID author=(UUID)row.get("author_id"),group=(UUID)row.get("group_id");
            boolean own=viewer.equals(author)||"OWNER".equals(row.get("viewer_role"))||"ADMIN".equals(row.get("viewer_role"));
            boolean mutable=group==null||"ACTIVE".equals(row.get("group_status"));
            var recruit=recruits.get(id);
            result.add(new Post(id,new Author(author,(String)row.get("author_name"),(String)row.get("author_avatar")),
                (String)row.get("post_type"),(String)row.get("caption"),Visibility.valueOf((String)row.get("visibility")),group,
                ((Timestamp)row.get("created_at")).toInstant(),((Timestamp)row.get("updated_at")).toInstant(),
                List.copyOf(media.getOrDefault(id,List.of())),reactionCounts.getOrDefault(id,0L),ownReactions.get(id),
                commentCounts.getOrDefault(id,0L),(String)row.get("moderation_status"),
                new Permissions(own&&mutable&&(recruit==null||recruit.canManage()),own&&mutable,mutable),recruit));
        }
        return List.copyOf(result);
    }
}
