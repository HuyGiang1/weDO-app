package com.wedo.backend.community;

import com.wedo.backend.common.error.*;
import com.wedo.backend.group.service.GroupAdmissionService;
import com.wedo.backend.realtime.RealtimePublisher;
import java.sql.Timestamp;
import java.time.*;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service @Transactional(readOnly=true)
public class RecruitmentService {
 private final JdbcTemplate db;private final CommunityService community;private final CommunityAccess access;
 private final RecruitmentProjection projection;private final GroupAdmissionService admission;private final RealtimePublisher events;private final Clock clock;
 @jakarta.persistence.PersistenceContext private jakarta.persistence.EntityManager entities;
 public RecruitmentService(JdbcTemplate db,CommunityService community,CommunityAccess access,RecruitmentProjection projection,GroupAdmissionService admission,RealtimePublisher events,Clock clock){this.db=db;this.community=community;this.access=access;this.projection=projection;this.admission=admission;this.events=events;this.clock=clock;}
 private BusinessException denied(){return new BusinessException(ErrorCode.ACCESS_DENIED);}
 private BusinessException invalid(){return new BusinessException(ErrorCode.VALIDATION_FAILED);}
 private void emit(UUID post){events.resource("COMMUNITY_RECRUITMENT_CHANGED","COMMUNITY_POST",post,"post:"+post,null,null);}
 private void lockGroup(UUID group){db.queryForObject("SELECT id FROM groups WHERE id=? FOR UPDATE",UUID.class,group);}
 private RecruitmentDtos.View view(UUID post,UUID actor){access.require(post,actor);var v=projection.view(post,actor);if(v==null)throw new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);return v;}
 public List<RecruitmentDtos.Option> options(UUID actor){access.active(actor);return db.queryForList("SELECT g.id,g.name FROM groups g JOIN group_settings s ON s.group_id=g.id JOIN group_memberships m ON m.group_id=g.id WHERE m.user_id=? AND m.status='ACTIVE' AND m.role IN ('OWNER','ADMIN') AND g.status='ACTIVE' AND s.join_policy='APPROVAL_REQUIRED' ORDER BY g.name,g.id",actor).stream().map(r->new RecruitmentDtos.Option((UUID)r.get("id"),(String)r.get("name"))).filter(r->projection.recruiter(r.groupId(),actor)).toList();}
 @Transactional public CommunityDtos.Post create(UUID actor,RecruitmentDtos.Create r){
  access.active(actor);lockGroup(r.groupId());projection.requireRecruiter(r.groupId(),actor);
  var existing=db.queryForList("SELECT post_type,author_id FROM community_posts WHERE id=?",r.clientRequestId());
  if(!existing.isEmpty()) {var old=existing.getFirst();if(!actor.equals(old.get("author_id"))||!"LOOKING_FOR_MEMBERS".equals(old.get("post_type")))throw invalid();return community.get(r.clientRequestId(),actor);}
  Instant now=clock.instant(),expiry=r.expiresAt()!=null?r.expiresAt():r.plannedAt()!=null?r.plannedAt():now.plus(Duration.ofDays(30));
  if(r.requestedCount()<1||r.requestedCount()>100||!expiry.isAfter(now)||r.plannedAt()!=null&&!r.plannedAt().isAfter(now)||r.tags().size()>6)throw invalid();
  List<String> tags=r.tags().stream().map(t->t.trim().toLowerCase(Locale.ROOT)).distinct().toList();
  if(tags.stream().anyMatch(t->!t.matches("[\\p{L}\\p{N} _-]{1,32}")))throw invalid();
  Map<String,Object> activity=null;
  if(r.activityId()!=null){var rows=db.queryForList("SELECT title,start_at,status FROM activities WHERE id=? AND group_id=?",r.activityId(),r.groupId());if(rows.isEmpty())throw invalid();activity=rows.getFirst();if(Set.of("CANCELLED","COMPLETED").contains(activity.get("status")))throw invalid();}
  community.create(actor,new CommunityDtos.Create(r.clientRequestId(),r.caption(),r.visibility(),r.visibility()==CommunityDtos.Visibility.GROUP_ONLY?r.groupId():null,r.mediaKeys()));
  db.update("UPDATE community_posts SET post_type='LOOKING_FOR_MEMBERS' WHERE id=?",r.clientRequestId());
  String name=db.queryForObject("SELECT name FROM groups WHERE id=?",String.class,r.groupId());
  db.update("INSERT INTO community_recruitment(post_id,group_id,activity_id,requested_count,broad_location,tags,planned_at,expires_at,public_group_name,public_activity_title,public_activity_start) VALUES (?,?,?,?,?,string_to_array(?,','),?,?,?,?,?)",
   r.clientRequestId(),r.groupId(),r.activityId(),r.requestedCount(),r.broadLocation().trim(),String.join(",",tags),r.plannedAt()==null?null:Timestamp.from(r.plannedAt()),Timestamp.from(expiry),name,activity==null?null:activity.get("title"),activity==null?null:activity.get("start_at"));
  events.resource("COMMUNITY_RECRUITMENT_CREATED","COMMUNITY_POST",r.clientRequestId(),"community:"+actor,null,null);
  return community.get(r.clientRequestId(),actor);
 }
 public RecruitmentDtos.View preview(UUID post,UUID actor){return view(post,actor);}
 @Transactional public RecruitmentDtos.View request(UUID post,UUID actor){
  var first=view(post,actor);lockGroup(first.groupId());db.queryForObject("SELECT post_id FROM community_recruitment WHERE post_id=? FOR UPDATE",UUID.class,post);
  var v=view(post,actor);if(v.requestState().equals("MEMBER")||v.requestState().equals("PENDING"))return v;
  if(!v.canRequest())throw denied();
  var request=admission.requestForRecruitment(v.groupId(),actor);
  db.update("INSERT INTO recruitment_applications(request_id,post_id) VALUES (?,?) ON CONFLICT(request_id) DO NOTHING",request.getId(),post);
  emit(post);return view(post,actor);
 }
 @Transactional public RecruitmentDtos.View cancel(UUID post,UUID actor){var v=view(post,actor);if(v.canCancel())admission.cancelJoinRequest(v.requestId(),actor);entities.flush();return view(post,actor);}
 @Transactional public RecruitmentDtos.View close(UUID post,UUID actor){var v=view(post,actor);lockGroup(v.groupId());projection.requireRecruiter(v.groupId(),actor);if(db.update("UPDATE community_recruitment SET closed_at=now(),closed_by=? WHERE post_id=? AND closed_at IS NULL",actor,post)>0)emit(post);return view(post,actor);}
 public List<com.wedo.backend.group.dto.JoinRequestResponse> requests(UUID post,UUID actor){var v=view(post,actor);projection.requireRecruiter(v.groupId(),actor);var source=db.queryForList("SELECT request_id FROM recruitment_applications WHERE post_id=?",UUID.class,post);var result=new ArrayList<com.wedo.backend.group.dto.JoinRequestResponse>();int page=0;com.wedo.backend.common.dto.PagedResponse<com.wedo.backend.group.dto.JoinRequestResponse> batch;
  do {batch=admission.getJoinRequests(v.groupId(),actor,page++,100);batch.items().stream().filter(r->source.contains(r.id())).forEach(result::add);}while(batch.hasNext());return result;}
 @Transactional public RecruitmentDtos.View resolve(UUID post,UUID request,UUID actor,boolean approve){var v=view(post,actor);lockGroup(v.groupId());projection.requireRecruiter(v.groupId(),actor);
  if(!Boolean.TRUE.equals(db.queryForObject("SELECT EXISTS(SELECT 1 FROM recruitment_applications WHERE post_id=? AND request_id=?)",Boolean.class,post,request)))throw denied();
  String state=db.queryForObject("SELECT status FROM group_join_requests WHERE id=?",String.class,request);
  if(state.equals("PENDING")){if(approve)admission.approveJoinRequest(request,actor);else admission.rejectJoinRequest(request,actor);entities.flush();}
  return view(post,actor);
 }
 public CommunityDtos.Page<CommunityDtos.Post> discover(UUID viewer,RecruitmentDtos.Filter f){
  access.active(viewer);if(f.from()!=null&&f.to()!=null&&f.from().isAfter(f.to()))throw invalid();
  String eligibleRecruiter="EXISTS(SELECT 1 FROM groups g JOIN group_settings s ON s.group_id=g.id JOIN group_memberships m ON m.group_id=g.id WHERE g.id=r.group_id AND g.status='ACTIVE' AND s.join_policy='APPROVAL_REQUIRED' AND m.user_id=p.author_id AND m.status='ACTIVE' AND m.role IN ('OWNER','ADMIN'))";
  String open="r.closed_at IS NULL AND r.expires_at>:now AND "+eligibleRecruiter+" AND NOT EXISTS(SELECT 1 FROM activities a WHERE a.id=r.activity_id AND a.status IN ('CANCELLED','COMPLETED')) AND (SELECT count(DISTINCT q.user_id) FROM recruitment_applications ra JOIN group_join_requests q ON q.id=ra.request_id WHERE ra.post_id=p.id AND q.status='APPROVED')<r.requested_count AND (SELECT count(*) FROM group_memberships gm WHERE gm.group_id=r.group_id AND gm.status='ACTIVE')<100";
  Map<String,Object> args=new HashMap<>();args.put("viewer",viewer);args.put("now",Timestamp.from(clock.instant()));args.put("keyword",pattern(f.keyword()));args.put("location",pattern(f.location()));args.put("tag",f.tag()==null?"":f.tag().trim());args.put("from",f.from()==null?null:Timestamp.from(f.from()));args.put("to",f.to()==null?null:Timestamp.from(f.to()));args.put("before",f.before());
  var ids=access.db.queryForList(CommunityAccess.GRAPH+"SELECT p.id FROM community_posts p JOIN community_recruitment r ON r.post_id=p.id WHERE "+CommunityAccess.ELIGIBLE+" AND "+open+" AND (p.caption ILIKE :keyword OR r.broad_location ILIKE :keyword OR EXISTS(SELECT 1 FROM unnest(r.tags) t WHERE t ILIKE :keyword)) AND r.broad_location ILIKE :location AND (:tag='' OR EXISTS(SELECT 1 FROM unnest(r.tags) t WHERE lower(t)=lower(:tag))) AND (CAST(:from AS timestamptz) IS NULL OR r.planned_at>=:from) AND (CAST(:to AS timestamptz) IS NULL OR r.planned_at<=:to) AND (CAST(:before AS uuid) IS NULL OR (p.created_at,p.id)<(SELECT c.created_at,c.id FROM community_posts c WHERE c.id=:before AND "+CommunityAccess.ELIGIBLE.replace("p.","c.")+")) ORDER BY p.created_at DESC,p.id DESC LIMIT 21",args,UUID.class);
  return new CommunityDtos.Page<>(ids.stream().limit(20).map(id->community.get(id,viewer)).toList(),ids.size()>20?ids.get(19):null,ids.size()>20);
 }
 private String pattern(String value){return "%"+(value==null?"":value.trim().replace("\\","\\\\").replace("%","\\%").replace("_","\\_"))+"%";}
}
