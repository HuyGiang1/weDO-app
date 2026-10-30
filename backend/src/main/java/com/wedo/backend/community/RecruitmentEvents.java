package com.wedo.backend.community;
import com.wedo.backend.realtime.*;
import java.util.*;
import org.springframework.context.event.EventListener;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
/** Translate existing group/Activity mutations while still inside their write TX. */
@Component
public class RecruitmentEvents {
 private final JdbcTemplate db;private final RealtimePublisher events;
 public RecruitmentEvents(JdbcTemplate db,RealtimePublisher events){this.db=db;this.events=events;}
 @EventListener public void changed(DomainRealtimeEvent e){
  if(e.eventType().startsWith("COMMUNITY_")||e.groupId()==null)return;
  boolean activity=e.aggregateType().equals("ACTIVITY"),group=e.aggregateType().equals("GROUP");if(!activity&&!group)return;
  for(UUID id:db.queryForList("SELECT post_id FROM community_recruitment WHERE "+(activity?"activity_id":"group_id")+"=?",UUID.class,activity?e.aggregateId():e.groupId()))events.resource("COMMUNITY_RECRUITMENT_CHANGED","COMMUNITY_POST",id,"post:"+id,null,null);
 }
}
