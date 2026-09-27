package com.wedo.backend.poll.dto;
import jakarta.validation.constraints.*; public record UpdatePollOptionRequest(@NotBlank @Size(max=255) String text) { }
