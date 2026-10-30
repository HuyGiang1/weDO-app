package com.wedo.backend.community;
import com.wedo.backend.common.error.*;
import com.wedo.backend.group.service.GroupPermissionService;
import java.sql.Timestamp;
import java.time.*;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/** Safe external projection: approved preview snapshots, never member-only DTOs. */
@Component
public class RecruitmentProjection {
 final JdbcTemplate db;final GroupPermissionService groups;final CommunityAccess access;final Clock clock;
 public RecruitmentProjection(JdbcTemplate db,GroupPermissionService groups,CommunityAccess access,Clock clock){this.db=db;this.groups=groups;this.access=access;this.clock=clock;}
 public boolean recruiter(UUID group,UUID actor){return Boolean.TRUE.equals(db.queryForObject("SELECT EXISTS(SELECT 1 FROM group_memberships m JOIN groups g ON g.id=m.group_id JOIN group_settings s ON s.group_id=g.id WHERE m.group_id=? AND m.user_id=? AND m.status='ACTIVE' AND m.role IN ('OWNER','ADMIN') AND g.status='ACTIVE' AND s.join_policy='APPROVAL_REQUIRED' AND NOT EXISTS(SELECT 1 FROM group_bans b WHERE b.group_id=g.id AND b.user_id=m.user_id AND b.unbanned_at IS NULL))",Boolean.class,group,actor));}
 public void requireRecruiter(UUID group,UUID actor){access.active(actor);if(!recruiter(group,actor))throw new BusinessException(ErrorCode.ACCESS_DENIED);}
 public boolean blockedFromManagers(UUID group,UUID actor){return Boolean.TRUE.equals(db.queryForObject("SELECT EXISTS(SELECT 1 FROM group_memberships m JOIN user_blocks b ON (b.blocker_id=m.user_id AND b.blocked_id=?) OR (b.blocked_id=m.user_id AND b.blocker_id=?) WHERE m.group_id=? AND m.status='ACTIVE' AND m.role IN ('OWNER','ADMIN'))",Boolean.class,actor,actor,group));}
 public RecruitmentDtos.View view(UUID post,UUID viewer){
  var rows=db.queryForList("SELECT r.*,p.author_id,p.deleted_at FROM community_recruitment r JOIN community_posts p ON p.id=r.post_id WHERE r.post_id=?",post);if(rows.isEmpty())return null;
  var r=rows.getFirst();UUID group=(UUID)r.get("group_id"),author=(UUID)r.get("author_id");
  long approved=db.queryForObject("SELECT count(DISTINCT q.user_id) FROM recruitment_applications a JOIN group_join_requests q ON q.id=a.request_id WHERE a.post_id=? AND q.status='APPROVED'",Long.class,post);
  int members=db.queryForObject("SELECT count(*) FROM group_memberships WHERE group_id=? AND status='ACTIVE'",Integer.class,group),target=(Integer)r.get("requested_count");
  boolean member=Boolean.TRUE.equals(db.queryForObject("SELECT EXISTS(SELECT 1 FROM group_memberships WHERE group_id=? AND user_id=? AND status='ACTIVE')",Boolean.class,group,viewer));
  boolean banned=Boolean.TRUE.equals(db.queryForObject("SELECT EXISTS(SELECT 1 FROM group_bans WHERE group_id=? AND user_id=? AND unbanned_at IS NULL)",Boolean.class,group,viewer));
  boolean cancelled=r.get("activity_id")!=null&&Boolean.TRUE.equals(db.queryForObject("SELECT EXISTS(SELECT 1 FROM activities WHERE id=? AND status IN ('CANCELLED','COMPLETED'))",Boolean.class,r.get("activity_id")));
  Instant expires=((Timestamp)r.get("expires_at")).toInstant();
  String status=r.get("closed_at")!=null||r.get("deleted_at")!=null||!recruiter(group,author)||cancelled?"CLOSED":!expires.isAfter(clock.instant())?"EXPIRED":approved>=target||members>=100?"FILLED":"OPEN";
  var requests=db.queryForList("SELECT q.id,q.status FROM group_join_requests q LEFT JOIN recruitment_applications a ON a.request_id=q.id WHERE q.group_id=? AND q.user_id=? ORDER BY (q.status='PENDING') DESC,COALESCE(a.created_at,q.created_at) DESC,q.id DESC LIMIT 1",group,viewer);
  String state=member?"MEMBER":requests.isEmpty()?"NOT_REQUESTED":(String)requests.getFirst().get("status");
  if(!member&&state.equals("APPROVED"))state="NOT_REQUESTED";
  UUID request=requests.isEmpty()?null:(UUID)requests.getFirst().get("id");
  List<String> tags;
  try{tags=Arrays.asList((String[])((java.sql.Array)r.get("tags")).getArray());}catch(java.sql.SQLException e){throw new IllegalStateException(e);}
  return new RecruitmentDtos.View(group,(String)r.get("public_group_name"),(UUID)r.get("activity_id"),(String)r.get("public_activity_title"),instant(r,"public_activity_start"),target,approved,Math.max(0,(int)Math.min(target-approved,100-members)),(String)r.get("broad_location"),tags,instant(r,"planned_at"),expires,status,state,request,
   status.equals("OPEN")&&!member&&!state.equals("PENDING")&&!banned&&!blockedFromManagers(group,viewer),state.equals("PENDING"),recruiter(group,viewer));
 }
 /** Bulk equivalent of view for already-authorized IDs; no per-post round trips. */
 public Map<UUID,RecruitmentDtos.View> views(List<UUID> ids,UUID viewer){
  if(ids.isEmpty())return Map.of();
  if(ids.size()>100)throw new BusinessException(ErrorCode.VALIDATION_FAILED);
  String recruiter="EXISTS(SELECT 1 FROM group_memberships m JOIN groups g ON g.id=m.group_id JOIN group_settings s ON s.group_id=g.id WHERE m.group_id=r.group_id AND m.user_id=%s AND m.status='ACTIVE' AND m.role IN ('OWNER','ADMIN') AND g.status='ACTIVE' AND s.join_policy='APPROVAL_REQUIRED' AND NOT EXISTS(SELECT 1 FROM group_bans b WHERE b.group_id=g.id AND b.user_id=m.user_id AND b.unbanned_at IS NULL))";
  String sql="""
   SELECT r.*,p.author_id,p.deleted_at,
    (SELECT count(DISTINCT q.user_id) FROM recruitment_applications a JOIN group_join_requests q ON q.id=a.request_id WHERE a.post_id=r.post_id AND q.status='APPROVED') approved,
    (SELECT count(*) FROM group_memberships m WHERE m.group_id=r.group_id AND m.status='ACTIVE') members,
    EXISTS(SELECT 1 FROM group_memberships m WHERE m.group_id=r.group_id AND m.user_id=:viewer AND m.status='ACTIVE') member,
    EXISTS(SELECT 1 FROM group_bans b WHERE b.group_id=r.group_id AND b.user_id=:viewer AND b.unbanned_at IS NULL) banned,
    EXISTS(SELECT 1 FROM activities a WHERE a.id=r.activity_id AND a.status IN ('CANCELLED','COMPLETED')) cancelled,
    EXISTS(SELECT 1 FROM group_memberships m JOIN user_blocks b ON (b.blocker_id=m.user_id AND b.blocked_id=:viewer) OR (b.blocked_id=m.user_id AND b.blocker_id=:viewer) WHERE m.group_id=r.group_id AND m.status='ACTIVE' AND m.role IN ('OWNER','ADMIN')) manager_blocked,
   """+recruiter.formatted("p.author_id")+" author_recruiter,"+recruiter.formatted(":viewer")+"""
    viewer_recruiter,req.id request_id,req.status request_status
   FROM community_recruitment r JOIN community_posts p ON p.id=r.post_id
   LEFT JOIN LATERAL (SELECT q.id,q.status FROM group_join_requests q LEFT JOIN recruitment_applications a ON a.request_id=q.id
    WHERE q.group_id=r.group_id AND q.user_id=:viewer ORDER BY (q.status='PENDING') DESC,COALESCE(a.created_at,q.created_at) DESC,q.id DESC LIMIT 1) req ON true
   WHERE r.post_id IN (:ids)
   """;
  var rows=access.db.queryForList(sql,Map.of("viewer",viewer,"ids",ids));
  var result=new HashMap<UUID,RecruitmentDtos.View>();Instant now=clock.instant();
  for(var r:rows){
   UUID post=(UUID)r.get("post_id"),group=(UUID)r.get("group_id");
   long approved=((Number)r.get("approved")).longValue();int members=((Number)r.get("members")).intValue(),target=(Integer)r.get("requested_count");
   boolean member=Boolean.TRUE.equals(r.get("member")),banned=Boolean.TRUE.equals(r.get("banned"));
   Instant expires=instant(r,"expires_at");
   String status=r.get("closed_at")!=null||r.get("deleted_at")!=null||!Boolean.TRUE.equals(r.get("author_recruiter"))||Boolean.TRUE.equals(r.get("cancelled"))?"CLOSED":!expires.isAfter(now)?"EXPIRED":approved>=target||members>=100?"FILLED":"OPEN";
   String state=member?"MEMBER":r.get("request_status")==null?"NOT_REQUESTED":(String)r.get("request_status");
   if(!member&&state.equals("APPROVED"))state="NOT_REQUESTED";
   List<String> tags;try{tags=Arrays.asList((String[])((java.sql.Array)r.get("tags")).getArray());}catch(java.sql.SQLException e){throw new IllegalStateException(e);}
   result.put(post,new RecruitmentDtos.View(group,(String)r.get("public_group_name"),(UUID)r.get("activity_id"),(String)r.get("public_activity_title"),instant(r,"public_activity_start"),target,approved,Math.max(0,(int)Math.min(target-approved,100-members)),(String)r.get("broad_location"),tags,instant(r,"planned_at"),expires,status,state,(UUID)r.get("request_id"),
    status.equals("OPEN")&&!member&&!state.equals("PENDING")&&!banned&&!Boolean.TRUE.equals(r.get("manager_blocked")),state.equals("PENDING"),Boolean.TRUE.equals(r.get("viewer_recruiter"))));
  }
  return result;
 }
 private Instant instant(Map<String,Object> row,String key){return row.get(key)==null?null:((Timestamp)row.get(key)).toInstant();}
}
