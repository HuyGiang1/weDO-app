package com.wedo.backend.community;

import com.wedo.backend.common.error.*;
import com.wedo.backend.realtime.RealtimePublisher;
import java.sql.Timestamp;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import static com.wedo.backend.community.ModerationDtos.*;

/** Reports never grant content access. Only explicit global grants or current GROUP_ONLY managers review. */
@Service
@Transactional(readOnly=true)
public class ModerationService {
    private final JdbcTemplate db;
    private final CommunityAccess access;
    private final RealtimePublisher events;
    @org.springframework.beans.factory.annotation.Autowired private com.wedo.backend.media.storage.ObjectStorageService storage;
    public ModerationService(JdbcTemplate db,CommunityAccess access,RealtimePublisher events) {
        this.db=db;this.access=access;this.events=events;
    }
    private BusinessException denied(){return new BusinessException(ErrorCode.ACCESS_DENIED);}
    private BusinessException invalid(){return new BusinessException(ErrorCode.VALIDATION_FAILED);}
    public boolean global(UUID viewer) {
        return Boolean.TRUE.equals(db.queryForObject("SELECT EXISTS(SELECT 1 FROM community_moderators WHERE user_id=? AND revoked_at IS NULL)",Boolean.class,viewer));
    }
    private static final String GROUP_MANAGER="EXISTS(SELECT 1 FROM group_memberships m JOIN groups g ON g.id=m.group_id WHERE m.user_id=? AND m.group_id=p.group_id AND m.status='ACTIVE' AND m.role IN ('OWNER','ADMIN') AND g.status='ACTIVE' AND NOT EXISTS(SELECT 1 FROM group_bans b WHERE b.group_id=g.id AND b.user_id=m.user_id AND b.unbanned_at IS NULL))";
    private String reviewPredicate(){return "(r.target_type<>'USER' AND p.visibility='GROUP_ONLY' AND "+GROUP_MANAGER+")";}
    public Access capabilities(UUID viewer) {
        access.active(viewer);boolean all=global(viewer);
        boolean group=Boolean.TRUE.equals(db.queryForObject("SELECT EXISTS(SELECT 1 FROM group_memberships m JOIN groups g ON g.id=m.group_id WHERE m.user_id=? AND m.status='ACTIVE' AND m.role IN ('OWNER','ADMIN') AND g.status='ACTIVE' AND NOT EXISTS(SELECT 1 FROM group_bans b WHERE b.group_id=g.id AND b.user_id=m.user_id AND b.unbanned_at IS NULL))",Boolean.class,viewer));
        return new Access(all,all||group);
    }
    private void reviewer(UUID viewer){if(!capabilities(viewer).canReview())throw denied();}
    public boolean canReadReport(UUID id,UUID viewer) {
        access.active(viewer);
        if(global(viewer))return Boolean.TRUE.equals(db.queryForObject("SELECT EXISTS(SELECT 1 FROM community_reports WHERE id=?)",Boolean.class,id));
        return Boolean.TRUE.equals(db.queryForObject("SELECT EXISTS(SELECT 1 FROM community_reports r LEFT JOIN community_posts p ON p.id=r.post_id WHERE r.id=? AND "+reviewPredicate()+")",Boolean.class,id,viewer));
    }
    @Transactional public UUID submit(UUID viewer,Target type,UUID target,CommunityDtos.ReportReason reason) {
        access.active(viewer);UUID post=null,user=null,comment=null;String evidence;
        switch(type) {
            case POST -> {access.require(target,viewer);post=target;evidence=db.queryForObject("SELECT caption FROM community_posts WHERE id=?",String.class,target);}
            case COMMENT -> {
                var rows=db.queryForList("SELECT post_id,author_id,content FROM community_comments WHERE id=? AND deleted_at IS NULL AND moderation_status='ACTIVE'",target);
                if(rows.isEmpty())throw new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);
                var row=rows.getFirst();post=(UUID)row.get("post_id");access.require(post,viewer);
                if(!Boolean.TRUE.equals(db.queryForObject("SELECT "+CommunityAccess.unblocked("?::uuid","?::uuid"),Boolean.class,row.get("author_id"),viewer,viewer,row.get("author_id"))))throw denied();
                comment=target;evidence=(String)row.get("content");
            }
            case USER -> {if(viewer.equals(target))throw invalid();access.active(target);user=target;evidence=db.queryForObject("SELECT COALESCE(display_name,username::text) FROM users WHERE id=?",String.class,target);}
            default -> throw invalid();
        }
        UUID id=UUID.randomUUID();String normalized=reason==CommunityDtos.ReportReason.INAPPROPRIATE?"INAPPROPRIATE_CONTENT":reason.name();
        db.update("INSERT INTO community_reports(id,post_id,reporter_id,reason,target_type,target_user_id,target_comment_id,evidence) VALUES (?,?,?,?,?,?,?,?) ON CONFLICT DO NOTHING",id,post,viewer,normalized,type.name(),user,comment,evidence);
        UUID actual=db.queryForObject("SELECT id FROM community_reports WHERE reporter_id=? AND target_type=? AND COALESCE(target_comment_id,target_user_id,post_id)=? AND status='OPEN'",UUID.class,viewer,type.name(),target);
        if(id.equals(actual))notifyReviewers(actual,post);
        return actual;
    }
    private void notifyReviewers(UUID report,UUID post) {
        Set<UUID> reviewers=new HashSet<>(db.queryForList("SELECT user_id FROM community_moderators WHERE revoked_at IS NULL",UUID.class));
        if(post!=null)reviewers.addAll(db.queryForList("SELECT m.user_id FROM group_memberships m JOIN community_posts p ON p.group_id=m.group_id WHERE p.id=? AND p.visibility='GROUP_ONLY' AND m.status='ACTIVE' AND m.role IN ('OWNER','ADMIN')",UUID.class,post));
        for(UUID user:reviewers)events.resource("MODERATION_QUEUE_CHANGED","MODERATION",report,"moderation:"+user,null,null);
    }
    public CommunityDtos.Page<Item> queue(UUID viewer,String status,String reason,Target type,UUID before) {
        reviewer(viewer);
        if(status!=null&&!Set.of("OPEN","REVIEWED","DISMISSED").contains(status))throw invalid();
        if(reason!=null)try{CommunityDtos.ReportReason.valueOf(reason);}catch(IllegalArgumentException e){throw invalid();}
        List<Object> args=new ArrayList<>();String scope=global(viewer)?"TRUE":reviewPredicate();if(!global(viewer))args.add(viewer);
        String filter="";if(status!=null){filter+=" AND r.status=?";args.add(status);}if(reason!=null){filter+=" AND r.reason=?";args.add(reason);}if(type!=null){filter+=" AND r.target_type=?";args.add(type.name());}
        if(before!=null){if(!canReadReport(before,viewer))throw denied();filter+=" AND (r.created_at,r.id)<(SELECT created_at,id FROM community_reports WHERE id=?)";args.add(before);}
        var rows=db.queryForList("SELECT r.* FROM community_reports r LEFT JOIN community_posts p ON p.id=r.post_id WHERE "+scope+filter+" ORDER BY r.created_at DESC,r.id DESC LIMIT 21",args.toArray());
        return new CommunityDtos.Page<>(rows.stream().limit(20).map(this::item).toList(),rows.size()>20?(UUID)rows.get(19).get("id"):null,rows.size()>20);
    }
    private String contentStatus(Map<String,Object> r) {
        if("USER".equals(r.get("target_type")))return "ACTIVE";
        String table="COMMENT".equals(r.get("target_type"))?"community_comments":"community_posts";
        UUID id=(UUID)(table.equals("community_comments")?r.get("target_comment_id"):r.get("post_id"));
        var row=db.queryForMap("SELECT deleted_at,moderation_status FROM "+table+" WHERE id=?",id);
        return row.get("deleted_at")!=null?"DELETED":(String)row.get("moderation_status");
    }
    private Item item(Map<String,Object> r) {
        Target type=Target.valueOf((String)r.get("target_type"));String state=contentStatus(r),status=(String)r.get("status");
        List<Action> allowed=new ArrayList<>();if(status.equals("OPEN")){allowed.add(Action.DISMISS);allowed.add(Action.RESOLVE);}
        if(type!=Target.USER&&!state.equals("DELETED"))allowed.add(state.equals("REMOVED")?Action.RESTORE:Action.REMOVE);
        UUID target=(UUID)(type==Target.USER?r.get("target_user_id"):type==Target.COMMENT?r.get("target_comment_id"):r.get("post_id"));
        return new Item((UUID)r.get("id"),type,target,(UUID)r.get("post_id"),(String)r.get("reason"),status,((Timestamp)r.get("created_at")).toInstant(),(String)r.get("evidence"),state,allowed);
    }
    public Detail detail(UUID id,UUID viewer) {
        if(!canReadReport(id,viewer))throw denied();
        var r=db.queryForMap("SELECT * FROM community_reports WHERE id=?",id);
        var history=db.query("SELECT * FROM community_moderation_actions WHERE report_id=? ORDER BY created_at,id",(rs,n)->new Audit(rs.getObject("id",UUID.class),rs.getObject("moderator_id",UUID.class),Action.valueOf(rs.getString("action")),rs.getString("reason"),rs.getString("before_status"),rs.getString("after_status"),rs.getTimestamp("created_at").toInstant()),id);
        var media="POST".equals(r.get("target_type"))?db.query("SELECT * FROM community_media WHERE post_id=? ORDER BY sort_order,id",(rs,n)->new com.wedo.backend.moment.MomentDtos.Media(rs.getObject("id",UUID.class),rs.getString("content_type"),rs.getString("file_name"),rs.getLong("file_size"),rs.getInt("sort_order")),r.get("post_id")):List.<com.wedo.backend.moment.MomentDtos.Media>of();
        return new Detail(item(r),history,media);
    }
    public com.wedo.backend.media.dto.MediaAccessResponse evidenceMedia(UUID report,UUID media,UUID viewer) {
        if(!canReadReport(report,viewer))throw denied();
        var keys=db.queryForList("SELECT m.storage_key FROM community_media m JOIN community_reports r ON r.post_id=m.post_id JOIN community_posts p ON p.id=m.post_id WHERE r.id=? AND r.target_type='POST' AND m.id=? AND p.deleted_at IS NULL",String.class,report,media);
        if(keys.isEmpty())throw new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);
        var signed=storage.presignGet(keys.getFirst(),java.time.Duration.ofSeconds(60));
        return new com.wedo.backend.media.dto.MediaAccessResponse(signed.url(),signed.expiresAt());
    }
    @Transactional public Detail act(UUID id,UUID viewer,Command command) {
        if(!canReadReport(id,viewer))throw denied();
        var r=db.queryForMap("SELECT * FROM community_reports WHERE id=? FOR UPDATE",id);
        // Permission can have changed while this command waited for another reviewer.
        if(!canReadReport(id,viewer))throw denied();
        var old=db.queryForList("SELECT * FROM community_moderation_actions WHERE id=?",command.clientRequestId());
        if(!old.isEmpty()) {
            var c=old.getFirst();if(!id.equals(c.get("report_id"))||!viewer.equals(c.get("moderator_id"))||!command.action().name().equals(c.get("action"))||!command.reason().trim().equals(c.get("reason")))throw invalid();
            return detail(id,viewer);
        }
        String before=contentStatus(r),after=before;
        if(command.action()==Action.REMOVE||command.action()==Action.RESTORE) {
            if("USER".equals(r.get("target_type")))throw denied();
            String table="COMMENT".equals(r.get("target_type"))?"community_comments":"community_posts";
            UUID target=(UUID)(table.equals("community_comments")?r.get("target_comment_id"):r.get("post_id"));
            db.queryForMap("SELECT id FROM "+table+" WHERE id=? FOR UPDATE",target);
            before=contentStatus(r);if(before.equals("DELETED"))throw invalid();
            after=command.action()==Action.REMOVE?"REMOVED":"ACTIVE";
            db.update("UPDATE "+table+" SET moderation_status=? WHERE id=?",after,target);
            db.update("UPDATE community_reports SET status='REVIEWED' WHERE id=?",id);
            UUID post=(UUID)r.get("post_id"),author=db.queryForObject("SELECT author_id FROM community_posts WHERE id=?",UUID.class,post);
            events.resource(table.equals("community_posts")?"COMMUNITY_POST_UPDATED":"COMMUNITY_COMMENT_CHANGED","COMMUNITY_POST",post,"community:"+author,null,null);
        } else {
            if(!"OPEN".equals(r.get("status")))throw invalid();
            db.update("UPDATE community_reports SET status=? WHERE id=?",command.action()==Action.DISMISS?"DISMISSED":"REVIEWED",id);
        }
        db.update("INSERT INTO community_moderation_actions(id,report_id,moderator_id,action,reason,before_status,after_status) VALUES (?,?,?,?,?,?,?)",command.clientRequestId(),id,viewer,command.action().name(),command.reason().trim(),before,after);
        notifyReviewers(id,(UUID)r.get("post_id"));return detail(id,viewer);
    }
}
