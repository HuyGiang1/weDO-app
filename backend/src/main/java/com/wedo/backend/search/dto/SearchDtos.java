package com.wedo.backend.search.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.wedo.backend.activity.dto.ActivityLocationDto;
import com.wedo.backend.activity.entity.ActivityStatus;
import com.wedo.backend.group.entity.GroupStatus;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class SearchDtos {
    private SearchDtos() { }

    @JsonInclude(JsonInclude.Include.NON_NULL)
    public record Response(
            String query,
            Section<Person> people,
            Section<Group> groups,
            Section<Activity> activities,
            Section<Conversation> conversations
    ) { }

    public record Section<T>(List<T> items, boolean hasMore) { }

    public record Person(UUID id, String username, String displayName, boolean avatarAvailable) { }

    public record Group(UUID id, String name, GroupStatus status, boolean avatarAvailable) { }

    public record Activity(
            UUID id,
            UUID groupId,
            String title,
            Instant startAt,
            ActivityStatus status,
            ActivityLocationDto location
    ) { }

    public record Conversation(
            UUID id,
            String kind,
            UUID groupId,
            String title,
            String matchedTextSnippet,
            Instant matchedAt
    ) { }
}
