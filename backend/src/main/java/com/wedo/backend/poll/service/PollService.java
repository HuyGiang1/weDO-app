package com.wedo.backend.poll.service;

import com.wedo.backend.activity.service.M8ActivityAccess;
import com.wedo.backend.activity.service.M8ActivityAccessService;
import com.wedo.backend.common.error.*;
import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.repository.GroupMembershipRepository;
import com.wedo.backend.poll.dto.*;
import com.wedo.backend.poll.entity.*;
import com.wedo.backend.poll.repository.*;
import java.time.*;
import java.util.*;
import org.springframework.stereotype.Service;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class PollService { @org.springframework.beans.factory.annotation.Autowired(required=false) private com.wedo.backend.realtime.RealtimePublisher realtime;
 private final M8ActivityAccessService access; private final PollRepository polls; private final PollOptionRepository options; private final PollVoteRepository votes; private final PollVoteChoiceRepository choices; private final Clock clock;
 @Autowired(required=false) private ApplicationEventPublisher eventPublisher;
 @Autowired(required=false) private GroupMembershipRepository memberships;
 @Autowired(required=false) private com.wedo.backend.group.service.GroupPermissionService groupPermissions;
 @Autowired(required=false) private PollChatActivityWriter chatActivity;
 @Autowired private org.springframework.jdbc.core.JdbcTemplate jdbc;
 private com.wedo.backend.group.service.ReadableGroupAccess readableGroup(PollEntity p,UUID actor){return p.getActivityId()==null?groupPermissions.requireReadableMembership(p.getGroupId(),actor):access.requireReadable(p.getActivityId(),actor).groupAccess();}
 private void requireMutable(PollEntity p,UUID actor){if(p.getActivityId()==null)groupPermissions.requireMutableMembership(p.getGroupId(),actor);else access.requireMutable(p.getActivityId(),actor);}
 private void emit(String type,PollEntity p){if(realtime==null)return;if(p.getActivityId()==null)realtime.resource(type,"POLL",p.getId(),"group:"+p.getGroupId(),p.getGroupId(),null);else realtime.activityResource(type,"POLL",p.getId(),p.getActivityId(),p.getGroupId(),null);}
 public PollService(M8ActivityAccessService access,PollRepository polls,PollOptionRepository options,PollVoteRepository votes,PollVoteChoiceRepository choices,Clock clock){this.access=access;this.polls=polls;this.options=options;this.votes=votes;this.choices=choices;this.clock=clock;}
 @Transactional public PollResponse create(UUID activityId,UUID actor,CreatePollRequest request){M8ActivityAccess a=access.requireMutable(activityId,actor);return createOwned(activityId,a.activity().getGroupId(),actor,request);}
 @Transactional public PollResponse createGroup(UUID groupId,UUID actor,CreatePollRequest request){groupPermissions.requireMutableMembership(groupId,actor);return createOwned(null,groupId,actor,request);}
 private PollResponse createOwned(UUID activityId,UUID groupId,UUID actor,CreatePollRequest request){validateCreate(request);Instant now=clock.instant();PollEntity poll=new PollEntity(UUID.randomUUID(),activityId,actor,request.question().trim(),request.pollType(),request.allowMemberAddOption(),request.maxSelections(),request.voteVisibility(),request.resultVisibility(),request.deadlineAt(),now);poll.linkGroup(groupId);polls.save(poll);int order=0;for(String text:request.options())options.save(new PollOptionEntity(UUID.randomUUID(),poll.getId(),text.trim(),order++,actor,now));publishPollEvent(poll,groupId,actor,"POLL_CREATED",now);emit("POLL_CREATED",poll);return response(poll,actor);}
 @Transactional(readOnly=true) public List<PollResponse> list(UUID activityId,UUID actor){access.requireReadable(activityId,actor);return readList(polls.findByActivityIdOrderByCreatedAtDesc(activityId),actor);}
 @Transactional(readOnly=true) public List<PollResponse> listGroup(UUID groupId,UUID actor){groupPermissions.requireReadableMembership(groupId,actor);return readList(polls.findByGroupIdOrderByCreatedAtDesc(groupId),actor);}
 private List<PollResponse> readList(List<PollEntity> rows,UUID actor){return rows.stream().map(p->response(p,actor)).toList();}
 @Transactional public PollResponse get(UUID pollId,UUID actor){PollEntity p=lockedForRead(pollId,actor); closeIfDue(p);return response(p,actor);}
 @Transactional public PollResponse vote(UUID pollId,UUID actor,VotePollRequest request){
  PollEntity p=lockedReadable(pollId,actor);
  if(request.clientRequestId()!=null&&Boolean.TRUE.equals(jdbc.queryForObject("SELECT EXISTS(SELECT 1 FROM poll_vote_commands WHERE poll_id=? AND user_id=? AND request_id=?)",Boolean.class,pollId,actor,request.clientRequestId())))return response(p,actor);
  requireOpen(p);
  Set<UUID> ids=new LinkedHashSet<>(request.optionIds()); validateSelection(p,ids);
  var previous=votes.findByPollIdAndUserId(pollId,actor);
  Set<UUID> previousIds=previous.map(v->new HashSet<>(choices.findByVoteId(v.getId()).stream().map(PollVoteChoiceEntity::getOptionId).toList())).orElseGet(HashSet::new);
  if(request.clientRequestId()!=null)jdbc.update("INSERT INTO poll_vote_commands(poll_id,user_id,request_id) VALUES (?,?,?)",pollId,actor,request.clientRequestId());
  if(previousIds.equals(ids))return response(p,actor);
  Instant now=clock.instant();
  PollVoteEntity ballot=votes.findByPollIdAndUserId(pollId,actor).orElseGet(()->votes.save(new PollVoteEntity(UUID.randomUUID(),pollId,actor,now)));
  choices.deleteByVoteId(ballot.getId());
  // Hibernate schedules inserts before entity deletes. Flush the old choices
  // while holding the Poll lock, before inserting an overlapping replacement.
  // Both steps remain inside this transaction; rollback restores the old vote.
  choices.flush();
  for(UUID id:ids) choices.save(new PollVoteChoiceEntity(UUID.randomUUID(),ballot.getId(),id,now));
  ballot.touch(now);
  if(chatActivity!=null)chatActivity.append(p,actor,previous.isEmpty());
  emit("POLL_VOTE_CHANGED",p);
  return response(p,actor);
 }
 @Transactional public PollResponse addOption(UUID pollId,UUID actor,CreatePollOptionRequest request){PollEntity p=lockedReadable(pollId,actor); requireOpen(p); if(!p.isAllowMemberAddOption()&&!manager(p,actor))throw new BusinessException(ErrorCode.INSUFFICIENT_GROUP_PERMISSION); String text=request.text().trim(); if(options.findByPollIdOrderBySortOrderAsc(pollId).stream().anyMatch(o->o.getText().equals(text)))throw new BusinessException(ErrorCode.CONFLICT); options.save(new PollOptionEntity(UUID.randomUUID(),pollId,text,(int)options.countByPollId(pollId),actor,clock.instant()));emit("POLL_OPTIONS_CHANGED",p);return response(p,actor);}
 @Transactional public PollResponse updateOption(UUID pollId,UUID optionId,UUID actor,UpdatePollOptionRequest request){PollEntity p=lockedReadable(pollId,actor); requireOpen(p); PollOptionEntity o=option(pollId,optionId); if(!manager(p,actor)&&!actor.equals(o.getCreatedBy()))throw new BusinessException(ErrorCode.INSUFFICIENT_GROUP_PERMISSION); if(choices.countByOptionId(optionId)>0)throw new BusinessException(ErrorCode.POLL_OPTION_CHANGE_NOT_ALLOWED); o.update(request.text().trim());emit("POLL_OPTIONS_CHANGED",p);return response(p,actor);}
 @Transactional public void deleteOption(UUID pollId,UUID optionId,UUID actor){PollEntity p=lockedReadable(pollId,actor); requireOpen(p); PollOptionEntity o=option(pollId,optionId); if(!manager(p,actor)&&!actor.equals(o.getCreatedBy()))throw new BusinessException(ErrorCode.INSUFFICIENT_GROUP_PERMISSION); if(choices.countByOptionId(optionId)>0)throw new BusinessException(ErrorCode.POLL_OPTION_CHANGE_NOT_ALLOWED); options.delete(o);emit("POLL_OPTIONS_CHANGED",p);}
 @Transactional public PollResponse disableOption(UUID pollId,UUID optionId,UUID actor){PollEntity p=lockedReadable(pollId,actor); requireOpen(p); if(!manager(p,actor))throw new BusinessException(ErrorCode.INSUFFICIENT_GROUP_PERMISSION); option(pollId,optionId).disable();emit("POLL_OPTIONS_CHANGED",p);return response(p,actor);}
 @Transactional public PollResponse close(UUID pollId,UUID actor){PollEntity p=lockedReadable(pollId,actor); if(!manager(p,actor))throw new BusinessException(ErrorCode.INSUFFICIENT_GROUP_PERMISSION); closeIfDue(p); boolean wasOpen=p.getStatus()==PollStatus.OPEN; Instant now=clock.instant(); p.close(actor,now); if(wasOpen){publishPollEvent(p,p.getGroupId(),actor,"POLL_CLOSED",now);emit("POLL_CLOSED",p);}return response(p,actor);}
 @Transactional public List<PollVoterResponse> voters(UUID pollId,UUID actor){
  PollEntity p=lockedForRead(pollId,actor);closeIfDue(p);
  if(p.getVoteVisibility()!=VoteVisibility.PUBLIC||!resultsVisible(p))throw new BusinessException(ErrorCode.POLL_VOTERS_PRIVATE);
  return options.findByPollIdOrderBySortOrderAsc(pollId).stream().map(option->{
   var people=jdbc.query("SELECT u.id,COALESCE(u.display_name,u.username::text,'Người dùng') AS name,u.avatar_storage_key FROM poll_votes v JOIN poll_vote_choices c ON c.vote_id=v.id JOIN users u ON u.id=v.user_id WHERE v.poll_id=? AND c.option_id=? ORDER BY v.created_at,u.id",(rs,n)->new PollParticipant(rs.getObject("id",UUID.class),rs.getString("name"),rs.getString("avatar_storage_key")),pollId,option.getId());
   return new PollVoterResponse(option.getId(),people.stream().map(PollParticipant::id).toList(),people);
  }).toList();
 }
 private boolean resultsVisible(PollEntity p){return p.getResultVisibility()==ResultVisibility.IMMEDIATE||p.getStatus()==PollStatus.CLOSED||(p.getDeadlineAt()!=null&&!p.getDeadlineAt().isAfter(clock.instant()));}
 private List<PollParticipant> preview(PollEntity p){
  if(p.getVoteVisibility()!=VoteVisibility.PUBLIC||!resultsVisible(p))return List.of();
  return jdbc.query("SELECT u.id,COALESCE(u.display_name,u.username::text,'Người dùng') AS name,u.avatar_storage_key FROM poll_votes v JOIN users u ON u.id=v.user_id WHERE v.poll_id=? ORDER BY v.created_at,u.id LIMIT 5",(rs,n)->new PollParticipant(rs.getObject("id",UUID.class),rs.getString("name"),rs.getString("avatar_storage_key")),p.getId());
 }
 private PollEntity readable(UUID pollId,UUID actor){PollEntity p=polls.findById(pollId).orElseThrow(()->new BusinessException(ErrorCode.POLL_NOT_FOUND));readableGroup(p,actor);return p;} private PollEntity lockedReadable(UUID pollId,UUID actor){PollEntity p=polls.findByIdForUpdate(pollId).orElseThrow(()->new BusinessException(ErrorCode.POLL_NOT_FOUND));requireMutable(p,actor);return p;}
 private PollEntity lockedForRead(UUID id,UUID actor){PollEntity p=polls.findByIdForUpdate(id).orElseThrow(()->new BusinessException(ErrorCode.POLL_NOT_FOUND));readableGroup(p,actor);return p;}
 private void requireOpen(PollEntity p){if(p.closeIfDue(clock.instant()))polls.save(p);if(p.getStatus()!=PollStatus.OPEN)throw new BusinessException(p.getDeadlineAt()!=null&&!p.getDeadlineAt().isAfter(clock.instant())?ErrorCode.POLL_DEADLINE_PASSED:ErrorCode.POLL_CLOSED);} private void closeIfDue(PollEntity p){if(p.closeIfDue(clock.instant())){polls.save(p);emit("POLL_CLOSED",p);}} private PollOptionEntity option(UUID pollId,UUID optionId){return options.findById(optionId).filter(o->o.getPollId().equals(pollId)).orElseThrow(()->new BusinessException(ErrorCode.INVALID_POLL_SELECTION));}
 private boolean manager(PollEntity p,UUID actor){GroupRole role=readableGroup(p,actor).membership().getRole();return actor.equals(p.getCreatedBy())||role==GroupRole.OWNER||role==GroupRole.ADMIN;}
 private void publishPollEvent(PollEntity poll,UUID groupId,UUID actor,String eventType,Instant now){if(eventPublisher==null||memberships==null||poll.getActivityId()==null)return;List<UUID> recipients=memberships.findActiveMemberResponsesByGroupId(groupId).stream().map(com.wedo.backend.group.repository.GroupMemberProjection::getUserId).filter(id->!id.equals(actor)).toList();if(recipients.isEmpty())return;eventPublisher.publishEvent(new com.wedo.backend.notification.event.NotificationDomainEvent(eventType+":"+poll.getId(),eventType,"POLL","NORMAL",false,actor,groupId,recipients,eventType.equals("POLL_CREATED")?"Bình chọn mới":"Bình chọn đã đóng",poll.getQuestion(),"POLL",poll.getId(),"/activities/detail",Map.of("groupId",groupId.toString(),"activityId",poll.getActivityId().toString()),now));}
 private void validateCreate(CreatePollRequest r){if(r.pollType()==PollType.SINGLE_CHOICE&&r.maxSelections()!=null)throw new BusinessException(ErrorCode.INVALID_POLL_SELECTION);if(r.pollType()==PollType.MULTIPLE_CHOICE&&r.maxSelections()!=null&&r.maxSelections()>r.options().size())throw new BusinessException(ErrorCode.MAX_POLL_SELECTIONS_EXCEEDED);if(r.deadlineAt()!=null&&!r.deadlineAt().isAfter(clock.instant()))throw new BusinessException(ErrorCode.POLL_DEADLINE_PASSED);if(r.options().stream().map(s->s.trim().toLowerCase(Locale.ROOT)).distinct().count()!=r.options().size())throw new BusinessException(ErrorCode.CONFLICT);}
 private void validateSelection(PollEntity p,Set<UUID> ids){if(ids.isEmpty())throw new BusinessException(ErrorCode.INVALID_POLL_SELECTION);if(p.getPollType()==PollType.SINGLE_CHOICE&&ids.size()!=1)throw new BusinessException(ErrorCode.INVALID_POLL_SELECTION);if(p.getMaxSelections()!=null&&ids.size()>p.getMaxSelections())throw new BusinessException(ErrorCode.MAX_POLL_SELECTIONS_EXCEEDED);Map<UUID,PollOptionEntity> allowed=new HashMap<>();for(PollOptionEntity o:options.findByPollIdOrderBySortOrderAsc(p.getId()))allowed.put(o.getId(),o);for(UUID id:ids){PollOptionEntity o=allowed.get(id);if(o==null)throw new BusinessException(ErrorCode.INVALID_POLL_SELECTION);if(o.isDisabled())throw new BusinessException(ErrorCode.POLL_OPTION_DISABLED);}}
 private PollResponse response(PollEntity p,UUID actor){PollStatus effectiveStatus=p.getStatus()==PollStatus.OPEN&&p.getDeadlineAt()!=null&&!p.getDeadlineAt().isAfter(clock.instant())?PollStatus.CLOSED:p.getStatus();List<UUID> mine=votes.findByPollIdAndUserId(p.getId(),actor).map(v->choices.findByVoteId(v.getId()).stream().map(PollVoteChoiceEntity::getOptionId).toList()).orElse(List.of());boolean visible=resultsVisible(p);boolean manager=manager(p,actor),open=effectiveStatus==PollStatus.OPEN&&readableGroup(p,actor).group().getStatus()==com.wedo.backend.group.entity.GroupStatus.ACTIVE;List<PollOptionResponse> os=options.findByPollIdOrderBySortOrderAsc(p.getId()).stream().map(o->{long count=choices.countByOptionId(o.getId());boolean editable=open&&count==0&&(manager||actor.equals(o.getCreatedBy()));return new PollOptionResponse(o.getId(),o.getText(),o.getSortOrder(),o.isDisabled(),o.getCreatedBy(),visible?count:0,editable,open&&manager&&!o.isDisabled(),editable);}).toList();return new PollResponse(p.getId(),p.getActivityId(),p.getCreatedBy(),p.getQuestion(),p.getPollType(),p.isAllowMemberAddOption(),p.getMaxSelections(),p.getVoteVisibility(),p.getResultVisibility(),effectiveStatus,p.getDeadlineAt(),p.getClosedAt()!=null?p.getClosedAt():effectiveStatus==PollStatus.CLOSED?p.getDeadlineAt():null,p.getClosedBy(),os,mine,visible,new PollPermissions(open,open&&(p.isAllowMemberAddOption()||manager),open&&manager,visible&&p.getVoteVisibility()==VoteVisibility.PUBLIC),p.getGroupId(),votes.countByPollId(p.getId()),preview(p));}
}
