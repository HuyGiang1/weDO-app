package com.wedo.backend.poll.repository;
import com.wedo.backend.poll.entity.PollVoteEntity; import org.springframework.data.jpa.repository.JpaRepository; import java.util.*;
public interface PollVoteRepository extends JpaRepository<PollVoteEntity,UUID> { Optional<PollVoteEntity> findByPollIdAndUserId(UUID pollId,UUID userId); boolean existsByPollId(UUID pollId); long countByPollId(UUID pollId); }
