package com.wedo.backend.journey;
import static com.wedo.backend.journey.ActionDtos.*;
import com.wedo.backend.common.error.*;
import com.wedo.backend.poll.service.PollService;
import com.wedo.backend.task.service.TaskService;
import com.wedo.backend.task.dto.CreateTaskRequest;
import com.wedo.backend.group.service.GroupPermissionService;
import com.wedo.backend.group.entity.GroupRole;
import java.sql.Timestamp;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
@Service @Transactional(readOnly=true)
public class PollActionService {
 final JdbcTemplate db;final PollService polls;final TaskService tasks;final JourneyService journey;final GroupPermissionService groups;final com.wedo.backend.realtime.RealtimePublisher events;
 @jakarta.persistence.PersistenceContext jakarta.persistence.EntityManager em;
 public PollActionService(JdbcTemplate db,PollService polls,TaskService tasks,JourneyService journey,GroupPermissionService groups,com.wedo.backend.realtime.RealtimePublisher events){this.events=events;this.db=db;this.polls=polls;this.tasks=tasks;this.journey=journey;this.groups=groups;}
 Link link(Map<String,Object> r){return new Link((UUID)r.get("id"),(UUID)r.get("poll_id"),(UUID)r.get("option_id"),(String)r.get("source_question"),(String)r.get("source_option"),(UUID)r.get("activity_id"),Target.valueOf((String)r.get("target_kind")),(UUID)r.get("task_id"),(UUID)r.get("stop_id"));}
 public List<Link> targetSources(Target target,UUID id,UUID actor){var stops=target==Target.STOP?db.queryForList("SELECT activity_id FROM activity_stops WHERE id=?",UUID.class,id):List.<UUID>of();if(target==Target.STOP&&stops.isEmpty())throw journey.missing();UUID activity=target==Target.TASK?tasks.get(id,actor).activityId():stops.getFirst();journey.readable(activity,actor);return db.queryForList("SELECT * FROM poll_conversion_links WHERE "+(target==Target.TASK?"task_id":"stop_id")+"=?",id).stream().map(this::link).toList();}
 @Transactional public ConversionContext context(UUID poll,UUID actor){var p=polls.get(poll,actor);groups.requireReadableMembership(p.groupId(),actor);var role=groups.requireReadableMembership(p.groupId(),actor).membership().getRole();boolean manage=p.activityId()==null?role!=GroupRole.MEMBER:journey.manager(journey.readable(p.activityId(),actor),actor);return new ConversionContext(p.groupId(),p.activityId(),manage,db.queryForList("SELECT * FROM poll_conversion_links WHERE poll_id=? ORDER BY created_at,id",poll).stream().filter(r->{try{journey.readable((UUID)r.get("activity_id"),actor);return true;}catch(BusinessException denied){return false;}}).map(this::link).toList());}
 @Transactional public Link convert(UUID poll,UUID actor,Convert r){var a=journey.mutable(r.activityId(),actor);var p=polls.get(poll,actor);if(!a.activity().getGroupId().equals(p.groupId())||(p.activityId()!=null&&!p.activityId().equals(r.activityId())))throw journey.denied();if(r.target()==Target.STOP)journey.requireManager(a,actor);if(!p.resultsVisible()||p.participantCount()<1)throw journey.denied();var option=p.options().stream().filter(o->o.id().equals(r.optionId())&&!o.disabled()).findFirst().orElseThrow(journey::missing);
  var old=db.queryForList("SELECT * FROM poll_conversion_links WHERE id=? OR (option_id=? AND target_kind=? AND activity_id=?) ORDER BY created_at,id",r.clientRequestId(),r.optionId(),r.target().name(),r.activityId());if(!old.isEmpty()){var previous=old.getFirst();if(!poll.equals(previous.get("poll_id"))||!r.optionId().equals(previous.get("option_id"))||!r.target().name().equals(previous.get("target_kind"))||!r.activityId().equals(previous.get("activity_id")))throw journey.invalid();return link(previous);}
  UUID task=null,stop=null;String notes=r.notes().trim()+"\nTừ bình chọn: "+p.question();
  if(r.target()==Target.TASK){if(r.dueAt()!=null&&!r.dueAt().isAfter(java.time.Instant.now()))throw journey.invalid();String title=r.taskTitle()==null?p.question().trim():r.taskTitle().trim();if(title.isEmpty()||title.length()>255)throw journey.invalid();task=tasks.create(r.activityId(),actor,new CreateTaskRequest(title,notes+"\nPhương án đã chọn: "+option.text(),r.assigneeUserIds(),r.dueAt())).id();em.flush();}
  else{if(r.startsAt()==null)throw journey.invalid();String title=r.stopTitle()==null?option.text().trim():r.stopTitle().trim();if(title.isEmpty()||title.length()>255)throw journey.invalid();stop=journey.create(r.activityId(),actor,new JourneyDtos.Save(r.clientRequestId(),title,notes+"\nPhương án đã chọn: "+option.text(),r.startsAt(),r.endsAt(),r.locationLabel(),null,null,null)).id();}
  db.update("INSERT INTO poll_conversion_links(id,poll_id,option_id,group_id,activity_id,target_kind,task_id,stop_id,source_question,source_option,created_by) VALUES (?,?,?,?,?,?,?,?,?,?,?)",r.clientRequestId(),poll,r.optionId(),p.groupId(),r.activityId(),r.target().name(),task,stop,p.question(),option.text(),actor);
  events.resource("POLL_CONVERTED","POLL",poll,"group:"+p.groupId(),p.groupId(),null);return link(db.queryForMap("SELECT * FROM poll_conversion_links WHERE id=?",r.clientRequestId()));
 }
}
