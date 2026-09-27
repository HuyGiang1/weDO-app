package com.wedo.backend.poll.dto;

public record PollPermissions(
        boolean canVote,
        boolean canAddOption,
        boolean canClose,
        boolean canViewVoters
) { }
