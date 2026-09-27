package com.wedo.backend.poll.dto;
import com.wedo.backend.poll.entity.*; import jakarta.validation.constraints.*; import java.time.Instant; import java.util.List;
public record CreatePollRequest(@NotBlank @Size(max=255) String question, @NotNull PollType pollType, @NotEmpty @Size(min=2,max=50) List<@NotBlank @Size(max=255) String> options, boolean allowMemberAddOption, @Positive Integer maxSelections, @NotNull VoteVisibility voteVisibility, @NotNull ResultVisibility resultVisibility, Instant deadlineAt) { }
