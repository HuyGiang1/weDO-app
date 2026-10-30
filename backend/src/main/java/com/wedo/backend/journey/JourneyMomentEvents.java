package com.wedo.backend.journey;
import com.wedo.backend.realtime.*;
import java.util.*;
import org.springframework.context.event.EventListener;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
@Component public class JourneyMomentEvents {
 final JdbcTemplate db;final RealtimePublisher events;
 public JourneyMomentEvents(JdbcTemplate db,RealtimePublisher events){this.db=db;this.events=events;}
 @EventListener public void momentChanged(DomainRealtimeEvent event){
  if(!Set.of("MOMENT_UPDATED","MOMENT_DELETED").contains(event.eventType()))return;
  for(var row:db.queryForList("SELECT s.id,s.activity_id,a.group_id FROM activity_stop_checkins c JOIN activity_stops s ON s.id=c.stop_id JOIN activities a ON a.id=s.activity_id WHERE c.moment_id=?",event.aggregateId()))
   events.activityResource("ACTIVITY_STOP_CHECKIN_CHANGED","ACTIVITY_STOP",(UUID)row.get("id"),(UUID)row.get("activity_id"),(UUID)row.get("group_id"),null);
 }
}
