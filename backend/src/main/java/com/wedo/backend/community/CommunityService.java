package com.wedo.backend.community;

import static com.wedo.backend.community.CommunityDtos.*;
import com.wedo.backend.common.error.*;
import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.service.GroupPermissionService;
import com.wedo.backend.media.dto.*;
import com.wedo.backend.media.service.MediaReferenceService;
import com.wedo.backend.media.storage.ObjectStorageService;
import com.wedo.backend.moment.MomentDtos.Author;
import com.wedo.backend.moment.MomentDtos.Media;
import com.wedo.backend.realtime.RealtimePublisher;
import java.sql.*;
import java.time.*;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly=true)
public class CommunityService {
    @org.springframework.beans.factory.annotation.Autowired private ModerationService moderation;
    @org.springframework.beans.factory.annotation.Autowired private RecruitmentProjection recruitment;
    @org.springframework.beans.factory.annotation.Autowired private CommunityFeedRanking ranking;
    @org.springframework.beans.factory.annotation.Autowired private CommunityPostReader postReader;
    private final JdbcTemplate db;
    private final CommunityAccess access;
    private final GroupPermissionService groups;
    private final MediaReferenceService refs;
    private final ObjectStorageService storage;
    private final RealtimePublisher events;
    public CommunityService(JdbcTemplate db,CommunityAccess access,GroupPermissionService groups,
            MediaReferenceService refs,ObjectStorageService storage,RealtimePublisher events) {
        this.db=db; this.access=access; this.groups=groups; this.refs=refs; this.storage=storage; this.events=events;
    }
    private BusinessException invalid(){return new BusinessException(ErrorCode.VALIDATION_FAILED);}
    private BusinessException missing(){return new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);}
    private Map<String,Object> row(UUID id,UUID viewer,boolean lock) {
        access.require(id,viewer);
        return db.queryForMap("SELECT * FROM community_posts WHERE id=?"+(lock?" FOR UPDATE":""),id);
    }
    private void publish(String type,UUID post,UUID author) {
        events.resource(type,"COMMUNITY_POST",post,"community:"+author,null,null);
    }
    private void target(Visibility visibility,UUID group,UUID author) {
        if((visibility==Visibility.GROUP_ONLY)!=(group!=null)) throw invalid();
        if(group!=null) groups.requireMutableMembership(group,author);
    }
    private boolean manage(Map<String,Object> post,UUID viewer) {
        if(viewer.equals(post.get("author_id"))) return true;
        UUID group=(UUID)post.get("group_id");
        if(group==null) return false;
        return groups.requireReadableMembership(group,viewer).membership().getRole()!=GroupRole.MEMBER;
    }
    private void own(Map<String,Object> post,UUID viewer) {
        if(!manage(post,viewer)) throw new BusinessException(ErrorCode.ACCESS_DENIED);
        if(post.get("group_id")!=null) groups.requireMutableMembership((UUID)post.get("group_id"),viewer);
    }
    private Author author(UUID id) {
        return db.queryForObject("SELECT id,COALESCE(display_name,username::text) name,avatar_storage_key FROM users WHERE id=?",
            (r,n)->new Author(id,r.getString("name"),r.getString("avatar_storage_key")),id);
    }
    private Media media(ResultSet r,int n)throws SQLException {
        return new Media(r.getObject("id",UUID.class),r.getString("content_type"),r.getString("file_name"),r.getLong("file_size"),r.getInt("sort_order"));
    }
    private String visibleActor(String column,UUID viewer) {
        // UUID is supplied by the authenticated principal, never user-provided SQL text.
        return CommunityAccess.unblocked(column,"'"+viewer+"'::uuid")+" AND EXISTS(SELECT 1 FROM users u WHERE u.id="+column+" AND u.status='ACTIVE')";
    }
    public Post get(UUID id,UUID viewer) {
        var p=row(id,viewer,false);
        var recruit=recruitment.view(id,viewer);
        boolean own=manage(p,viewer), mutable=true;
        if(p.get("group_id")!=null) mutable=groups.requireReadableMembership((UUID)p.get("group_id"),viewer).group().getStatus()==com.wedo.backend.group.entity.GroupStatus.ACTIVE;
        return new Post(id,author((UUID)p.get("author_id")),(String)p.get("post_type"),(String)p.get("caption"),Visibility.valueOf((String)p.get("visibility")),(UUID)p.get("group_id"),
            ((Timestamp)p.get("created_at")).toInstant(),((Timestamp)p.get("updated_at")).toInstant(),
            db.query("SELECT * FROM community_media WHERE post_id=? ORDER BY sort_order,id",this::media,id),
            db.queryForObject("SELECT count(*) FROM community_reactions WHERE post_id=? AND "+visibleActor("user_id",viewer),Long.class,id),
            db.query("SELECT emoji FROM community_reactions WHERE post_id=? AND user_id=?",r->r.next()?r.getString(1):null,id,viewer),
            db.queryForObject("SELECT count(*) FROM community_comments WHERE post_id=? AND deleted_at IS NULL AND moderation_status='ACTIVE' AND "+visibleActor("author_id",viewer),Long.class,id),
            (String)p.get("moderation_status"),new Permissions(own&&mutable&&(recruit==null||recruit.canManage()),own&&mutable,mutable),recruit);
    }
    public Page<Post> feed(UUID viewer,Feed feed,UUID author,UUID before) {
        access.active(viewer);
        if(feed==Feed.FOR_YOU) return ranking.pageBatch(viewer,before,ids->postReader.read(ids,viewer));
        if(feed==Feed.PROFILE&&author==null) throw invalid();
        String filter=switch(feed) {
            // For You is an eligible mixed feed, not a PUBLIC-only visibility bucket.
            // The shared predicate still enforces all four visibility modes and blocks.
            case FOR_YOU -> "TRUE";
            case FRIENDS -> CommunityAccess.FRIEND;
            case PROFILE -> "p.author_id=:author";
        };
        Map<String,Object> args=new HashMap<>();args.put("viewer",viewer);args.put("author",author);args.put("before",before);
        // Cursor lookup itself must be eligible, so guessed private IDs are not an oracle.
        String sql=CommunityAccess.GRAPH+"SELECT p.id FROM community_posts p WHERE "+CommunityAccess.ELIGIBLE+" AND ("+filter+") AND (CAST(:before AS uuid) IS NULL OR (p.created_at,p.id)<(SELECT c.created_at,c.id FROM community_posts c WHERE c.id=:before AND "+CommunityAccess.ELIGIBLE.replace("p.","c.")+")) ORDER BY p.created_at DESC,p.id DESC LIMIT 21";
        var ids=access.db.queryForList(sql,args,UUID.class);
        return new Page<>(postReader.read(ids.stream().limit(20).toList(),viewer),ids.size()>20?ids.get(19):null,ids.size()>20);
    }
    /** Revalidate only displayed IDs, preserving the accepted feed order. */
    public Page<Post> refreshFeed(UUID viewer,Refresh request) {
        access.active(viewer);
        if(request.ids().size()>100 || (request.feed()==Feed.PROFILE&&request.authorId()==null))throw invalid();
        if(request.ids().isEmpty())return new Page<>(List.of(),null,false);
        String filter=switch(request.feed()) {case FOR_YOU -> CommunityFeedRanking.DISCOVERABLE;
            case FRIENDS -> CommunityAccess.ELIGIBLE+" AND "+CommunityAccess.FRIEND;
            case PROFILE -> CommunityAccess.ELIGIBLE+" AND p.author_id=:author";};
        var args=new HashMap<String,Object>();args.put("viewer",viewer);args.put("author",request.authorId());args.put("ids",request.ids());
        var allowed=new HashSet<>(access.db.queryForList(CommunityAccess.GRAPH+"SELECT p.id FROM community_posts p WHERE p.id IN (:ids) AND "+filter,args,UUID.class));
        return new Page<>(postReader.read(new LinkedHashSet<>(request.ids()).stream().filter(allowed::contains).toList(),viewer),null,false);
    }

    @Transactional public Post create(UUID viewer,Create request) {
        access.active(viewer);target(request.visibility(),request.groupId(),viewer);
        if(request.caption().trim().isEmpty()&&request.mediaKeys().isEmpty())throw invalid();
        if(request.mediaKeys().size()>8||new HashSet<>(request.mediaKeys()).size()!=request.mediaKeys().size())throw invalid();
        int added=db.update("INSERT INTO community_posts(id,author_id,caption,visibility,group_id) VALUES (?,?,?,?,?) ON CONFLICT(id) DO NOTHING",
            request.clientRequestId(),viewer,request.caption().trim(),request.visibility().name(),request.groupId());
        if(added==0) { var p=row(request.clientRequestId(),viewer,false);if(!viewer.equals(p.get("author_id")))throw invalid();return get(request.clientRequestId(),viewer); }
        int order=0;
        for(String key:request.mediaKeys()) {
            refs.validate(key,UploadCategory.COMMUNITY_IMAGE,viewer,viewer);
            var h=storage.head(key);
            db.update("INSERT INTO community_media(id,post_id,storage_key,content_type,file_name,file_size,sort_order) VALUES (?,?,?,?,?,?,?)",
                UUID.randomUUID(),request.clientRequestId(),key,h.contentType(),refs.originalFileName(key),h.size(),order++);
        }
        publish("COMMUNITY_POST_CREATED",request.clientRequestId(),viewer);return get(request.clientRequestId(),viewer);
    }
    @Transactional public Post edit(UUID id,UUID viewer,Edit request) {
        var p=row(id,viewer,true);own(p,viewer);
        if("LOOKING_FOR_MEMBERS".equals(p.get("post_type"))) {
            var linked=recruitment.view(id,viewer);recruitment.requireRecruiter(linked.groupId(),viewer);
            if(request.visibility()==Visibility.GROUP_ONLY&&!Objects.equals(request.groupId(),linked.groupId()))throw invalid();
        }
        // Group moderation may edit caption, but cannot republish someone else's group media publicly.
        if(!viewer.equals(p.get("author_id"))&&(!request.visibility().name().equals(p.get("visibility"))||!Objects.equals(request.groupId(),p.get("group_id"))))throw new BusinessException(ErrorCode.ACCESS_DENIED);
        target(request.visibility(),request.groupId(),viewer);
        if(request.caption().trim().isEmpty()&&db.queryForObject("SELECT count(*) FROM community_media WHERE post_id=?",Integer.class,id)==0)throw invalid();
        db.update("UPDATE community_posts SET caption=?,visibility=?,group_id=?,updated_at=now() WHERE id=?",request.caption().trim(),request.visibility().name(),request.groupId(),id);
        publish("COMMUNITY_POST_UPDATED",id,(UUID)p.get("author_id"));return get(id,viewer);
    }
    @Transactional public void delete(UUID id,UUID viewer) {
        var p=row(id,viewer,true);own(p,viewer);
        db.update("UPDATE community_posts SET deleted_at=now(),deleted_by=? WHERE id=?",viewer,id);
        publish("COMMUNITY_POST_DELETED",id,(UUID)p.get("author_id"));
    }
    private Map<String,Object> interact(UUID id,UUID viewer) {
        var p=row(id,viewer,true);if(p.get("group_id")!=null)groups.requireMutableMembership((UUID)p.get("group_id"),viewer);return p;
    }
    @Transactional public Post react(UUID id,UUID viewer,String emoji) {
        var p=interact(id,viewer);
        if(emoji!=null&&!Set.of("👍","❤️","😂","😮","😢","😡").contains(emoji))throw invalid();
        int n=emoji==null?db.update("DELETE FROM community_reactions WHERE post_id=? AND user_id=?",id,viewer):db.update("INSERT INTO community_reactions(post_id,user_id,emoji) VALUES (?,?,?) ON CONFLICT(post_id,user_id) DO UPDATE SET emoji=excluded.emoji WHERE community_reactions.emoji IS DISTINCT FROM excluded.emoji",id,viewer,emoji);
        if(n>0)publish("COMMUNITY_REACTION_CHANGED",id,(UUID)p.get("author_id"));return get(id,viewer);
    }
    private Comment comment(Map<String,Object> c,Map<String,Object> p,UUID viewer) {
        return new Comment((UUID)c.get("id"),author((UUID)c.get("author_id")),(String)c.get("content"),((Timestamp)c.get("created_at")).toInstant(),viewer.equals(c.get("author_id"))||manage(p,viewer));
    }
    public Page<Comment> comments(UUID id,UUID viewer,UUID before) {
        var p=row(id,viewer,false);
        var rows=db.queryForList("SELECT * FROM community_comments WHERE post_id=? AND deleted_at IS NULL AND moderation_status='ACTIVE' AND "+visibleActor("author_id",viewer)+" AND (?::uuid IS NULL OR (created_at,id)<(SELECT created_at,id FROM community_comments WHERE id=? AND post_id=? AND deleted_at IS NULL AND moderation_status='ACTIVE' AND "+visibleActor("author_id",viewer)+")) ORDER BY created_at DESC,id DESC LIMIT 21",id,before,before,id);
        return new Page<>(rows.stream().limit(20).map(c->comment(c,p,viewer)).toList(),rows.size()>20?(UUID)rows.get(19).get("id"):null,rows.size()>20);
    }
    @Transactional public Comment addComment(UUID id,UUID viewer,AddComment request) {
        var p=interact(id,viewer);
        int n=db.update("INSERT INTO community_comments(id,post_id,author_id,content) VALUES (?,?,?,?) ON CONFLICT(id) DO NOTHING",request.clientRequestId(),id,viewer,request.content().trim());
        var c=db.queryForMap("SELECT * FROM community_comments WHERE id=?",request.clientRequestId());
        if(!id.equals(c.get("post_id"))||!viewer.equals(c.get("author_id"))||c.get("deleted_at")!=null||!"ACTIVE".equals(c.get("moderation_status")))throw invalid();
        if(n>0)publish("COMMUNITY_COMMENT_CHANGED",id,(UUID)p.get("author_id"));return comment(c,p,viewer);
    }
    @Transactional public void deleteComment(UUID id,UUID comment,UUID viewer) {
        var p=interact(id,viewer);var cs=db.queryForList("SELECT * FROM community_comments WHERE id=? AND post_id=? AND deleted_at IS NULL",comment,id);
        if(cs.isEmpty())throw missing();var c=cs.getFirst();if(!viewer.equals(c.get("author_id"))&&!manage(p,viewer))throw new BusinessException(ErrorCode.ACCESS_DENIED);
        db.update("UPDATE community_comments SET deleted_at=now(),deleted_by=? WHERE id=?",viewer,comment);
        publish("COMMUNITY_COMMENT_CHANGED",id,(UUID)p.get("author_id"));
    }
    @Transactional public void hide(UUID id,UUID viewer) {
        access.active(viewer);
        if(Boolean.TRUE.equals(db.queryForObject("SELECT EXISTS(SELECT 1 FROM community_hidden_posts WHERE post_id=? AND user_id=?)",Boolean.class,id,viewer)))return;
        row(id,viewer,false);db.update("INSERT INTO community_hidden_posts(post_id,user_id) VALUES (?,?) ON CONFLICT DO NOTHING",id,viewer);
        events.user("COMMUNITY_POLICY_CHANGED",viewer);
    }
    @Transactional public void report(UUID id,UUID viewer,ReportReason reason) {
        moderation.submit(viewer,ModerationDtos.Target.POST,id,reason);
        events.userRecipientPolicy("COMMUNITY_POLICY_CHANGED",viewer);
    }
    @Transactional public void unhide(UUID id,UUID viewer) {
        access.active(viewer);
        if(db.update("DELETE FROM community_hidden_posts WHERE post_id=? AND user_id=?",id,viewer)>0)events.user("COMMUNITY_POLICY_CHANGED",viewer);
    }
    public Page<ModerationDtos.Hidden> hidden(UUID viewer,UUID before) {
        access.active(viewer);
        String eligible=CommunityAccess.ELIGIBLE.replace("AND NOT EXISTS(SELECT 1 FROM community_hidden_posts h WHERE h.post_id=p.id AND h.user_id=:viewer)","");
        var args=new HashMap<String,Object>();args.put("viewer",viewer);args.put("before",before);
        var rows=access.db.queryForList(CommunityAccess.GRAPH+"SELECT p.id,p.caption FROM community_posts p JOIN community_hidden_posts hidden ON hidden.post_id=p.id AND hidden.user_id=:viewer WHERE "+eligible+" AND (CAST(:before AS uuid) IS NULL OR p.id<:before) ORDER BY p.id DESC LIMIT 21",args);
        return new Page<>(rows.stream().limit(20).map(r->new ModerationDtos.Hidden((UUID)r.get("id"),(String)r.get("caption"))).toList(),rows.size()>20?(UUID)rows.get(19).get("id"):null,rows.size()>20);
    }
    public MediaAccessResponse mediaAccess(UUID media,UUID viewer) {
        var rows=db.queryForList("SELECT post_id,storage_key FROM community_media WHERE id=?",media);
        if(rows.isEmpty())throw missing();var m=rows.getFirst();access.require((UUID)m.get("post_id"),viewer);
        var signed=storage.presignGet((String)m.get("storage_key"),Duration.ofSeconds(60));
        return new MediaAccessResponse(signed.url(),signed.expiresAt());
    }
}
