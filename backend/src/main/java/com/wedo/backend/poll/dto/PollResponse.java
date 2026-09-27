package com.wedo.backend.poll.dto;
import com.wedo.backend.poll.entity.*; import java.time.Instant; import java.util.*;
public record PollResponse(UUID id,UUID activityId,UUID createdBy,String question,PollType pollType,boolean allowMemberAddOption,Integer maxSelections,VoteVisibility voteVisibility,ResultVisibility resultVisibility,PollStatus status,Instant deadlineAt,Instant closedAt,UUID closedBy,List<PollOptionResponse> options,List<UUID> callerOptionIds,boolean resultsVisible,PollPermissions permissions){ }
