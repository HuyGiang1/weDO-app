package com.wedo.backend.discussion.repository;
import com.wedo.backend.discussion.entity.ActivityCommentEntity; import org.springframework.data.jpa.repository.JpaRepository; import java.util.*;
public interface ActivityCommentRepository extends JpaRepository<ActivityCommentEntity,UUID> { List<ActivityCommentEntity> findByActivityIdOrderByCreatedAtAsc(UUID activityId); }
