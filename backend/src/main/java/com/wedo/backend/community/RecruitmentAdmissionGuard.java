package com.wedo.backend.community;
import com.wedo.backend.common.error.*;
import com.wedo.backend.realtime.RealtimePublisher;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/** All canonical approval entry points share the same group-first quota lock. */
@Component
public class RecruitmentAdmissionGuard {
 private final JdbcTemplate db;private final RecruitmentProjection projection;private final CommunityAccess access;private final RealtimePublisher events;
 public RecruitmentAdmissionGuard(JdbcTemplate db,RecruitmentProjection projection,CommunityAccess access,RealtimePublisher events){this.db=db;this.projection=projection;this.access=access;this.events=events;}
 public boolean lock(UUID request){var rows=db.queryForList("SELECT r.group_id,a.post_id FROM recruitment_applications a JOIN group_join_requests r ON r.id=a.request_id WHERE r.id=?",request);if(rows.isEmpty())return false;var row=rows.getFirst();db.queryForObject("SELECT id FROM groups WHERE id=? FOR UPDATE",UUID.class,row.get("group_id"));db.queryForObject("SELECT post_id FROM community_recruitment WHERE post_id=? FOR UPDATE",UUID.class,row.get("post_id"));return true;}
 public void checkApproval(UUID request,UUID approver){var row=db.queryForMap("SELECT a.post_id,r.user_id,r.group_id FROM recruitment_applications a JOIN group_join_requests r ON r.id=a.request_id WHERE r.id=?",request);UUID post=(UUID)row.get("post_id"),applicant=(UUID)row.get("user_id"),group=(UUID)row.get("group_id");projection.requireRecruiter(group,approver);access.require(post,applicant);var view=projection.view(post,applicant);if(!view.status().equals("OPEN")||projection.blockedFromManagers(group,applicant))throw new BusinessException(ErrorCode.ACCESS_DENIED);}
 public void changed(UUID request){var ids=db.queryForList("SELECT post_id FROM recruitment_applications WHERE request_id=?",UUID.class,request);for(UUID post:ids)events.resource("COMMUNITY_RECRUITMENT_CHANGED","COMMUNITY_POST",post,"post:"+post,null,null);}
}
