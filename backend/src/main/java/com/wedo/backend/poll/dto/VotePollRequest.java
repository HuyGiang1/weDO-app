package com.wedo.backend.poll.dto;
import jakarta.validation.constraints.*; import java.util.*; public record VotePollRequest(@NotEmpty List<@NotNull UUID> optionIds) { }
