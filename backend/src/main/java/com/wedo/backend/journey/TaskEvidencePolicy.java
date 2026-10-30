package com.wedo.backend.journey;
import com.wedo.backend.common.error.*;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
@Component public class TaskEvidencePolicy {
 final JdbcTemplate db;public TaskEvidencePolicy(JdbcTemplate db){this.db=db;}
 public String mode(UUID task){var modes=db.queryForList("SELECT evidence_mode FROM task_execution WHERE task_id=?",String.class,task);return modes.isEmpty()?"NONE":modes.getFirst();}
 public boolean approved(UUID task,UUID reviewer){return Boolean.TRUE.equals(db.queryForObject("SELECT EXISTS(SELECT 1 FROM task_evidence e JOIN tasks t ON t.id=e.task_id JOIN task_assignees a ON a.task_id=t.id AND a.user_id=e.author_id JOIN activities act ON act.id=t.activity_id JOIN group_memberships member ON member.group_id=act.group_id AND member.user_id=e.author_id AND member.status='ACTIVE' JOIN users author ON author.id=e.author_id AND author.status='ACTIVE' LEFT JOIN task_evidence_reviews r ON r.evidence_id=e.id WHERE e.task_id=? AND e.status='APPROVED' AND NOT EXISTS(SELECT 1 FROM group_bans b WHERE b.group_id=act.group_id AND b.user_id=e.author_id AND b.unbanned_at IS NULL) AND e.task_snapshot=t.updated_at AND (?::uuid IS NULL OR r.reviewer_id=?))",Boolean.class,task,reviewer,reviewer));}
 public void requireCompletion(UUID task){if(!mode(task).equals("NONE")&&!approved(task,null))throw new BusinessException(ErrorCode.TASK_UPDATE_NOT_ALLOWED);}
 public UUID stop(UUID task){var ids=db.queryForList("SELECT stop_id FROM task_execution WHERE task_id=?",UUID.class,task);return ids.isEmpty()?null:ids.getFirst();}
 public boolean canDelete(UUID task){return db.queryForObject("SELECT count(*) FROM task_evidence WHERE task_id=?",Integer.class,task)==0;}
}
