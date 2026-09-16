package com.wedo.backend.activity.entity;

import com.wedo.backend.activity.dto.ActivityLocationDto;

/** JSONB value object. Validation is deliberately performed at the DTO/service boundary. */
public record ActivityLocation(String type, String name, String address, Double latitude, Double longitude) {
    public static ActivityLocation from(ActivityLocationDto value) {
        return value == null ? null : new ActivityLocation(value.type(), value.name(), value.address(), value.latitude(), value.longitude());
    }

    public ActivityLocationDto toDto() {
        return new ActivityLocationDto(type, name, address, latitude, longitude);
    }
}
