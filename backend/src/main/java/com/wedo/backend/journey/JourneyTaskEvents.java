package com.wedo.backend.journey;
import com.wedo.backend.realtime.*;
import java.util.*;
import org.springframework.context.event.EventListener;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
@Component public class JourneyTaskEvents {
 final JdbcTemplate db;final RealtimePublisher events;
 public JourneyTaskEvents(JdbcTemplate db,RealtimePublisher events){this.db=db;this.events=events;}
 @EventListener public void taskChanged(DomainRealtimeEvent event){
  if(!"TASK".equals(event.aggregateType()))return;
  for(var row:db.queryForList("SELECT s.id,s.activity_id,a.group_id FROM task_execution e JOIN activity_stops s ON s.id=e.stop_id JOIN activities a ON a.id=s.activity_id WHERE e.task_id=?",event.aggregateId()))
   events.activityResource("ACTIVITY_STOP_TASK_CHANGED","ACTIVITY_STOP",(UUID)row.get("id"),(UUID)row.get("activity_id"),(UUID)row.get("group_id"),null);
 }
}
