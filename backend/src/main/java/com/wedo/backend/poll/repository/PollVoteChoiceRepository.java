package com.wedo.backend.poll.repository;
import com.wedo.backend.poll.entity.PollVoteChoiceEntity; import org.springframework.data.jpa.repository.*; import java.util.*;
public interface PollVoteChoiceRepository extends JpaRepository<PollVoteChoiceEntity,UUID> { List<PollVoteChoiceEntity> findByVoteId(UUID voteId); long countByOptionId(UUID optionId); @Modifying void deleteByVoteId(UUID voteId); }
