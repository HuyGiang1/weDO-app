package com.wedo.backend.poll.dto;
import jakarta.validation.constraints.*; public record CreatePollOptionRequest(@NotBlank @Size(max=255) String text) { }
