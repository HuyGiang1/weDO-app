package com.wedo.backend.poll.dto;
import java.util.*; public record PollVoterResponse(UUID optionId,List<UUID> userIds){ }
