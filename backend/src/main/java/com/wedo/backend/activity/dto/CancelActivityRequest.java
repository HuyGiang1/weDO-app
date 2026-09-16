package com.wedo.backend.activity.dto;

import jakarta.validation.constraints.Size;

public record CancelActivityRequest(@Size(max = 500) String reason) { }
