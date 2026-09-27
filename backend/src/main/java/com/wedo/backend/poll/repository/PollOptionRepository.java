package com.wedo.backend.poll.repository;
import com.wedo.backend.poll.entity.PollOptionEntity; import org.springframework.data.jpa.repository.JpaRepository; import java.util.*;
public interface PollOptionRepository extends JpaRepository<PollOptionEntity,UUID> { List<PollOptionEntity> findByPollIdOrderBySortOrderAsc(UUID pollId); long countByPollId(UUID pollId); }
