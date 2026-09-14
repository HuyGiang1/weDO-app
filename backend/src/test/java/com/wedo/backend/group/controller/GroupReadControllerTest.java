package com.wedo.backend.group.controller;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.group.entity.GroupEntity;
import com.wedo.backend.group.entity.GroupMembershipEntity;
import com.wedo.backend.group.entity.GroupMembershipStatus;
import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.group.entity.GroupActivityAction;
import com.wedo.backend.group.entity.GroupActivityLogEntity;
import com.wedo.backend.group.repository.GroupActivityLogRepository;
import com.wedo.backend.group.repository.GroupMembershipRepository;
import com.wedo.backend.group.repository.GroupRepository;
import com.wedo.backend.security.jwt.JwtService;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
class GroupReadControllerTest extends AbstractPostgresIntegrationTest {

    private static final ObjectMapper JSON = new ObjectMapper();

    @Autowired private MockMvc mockMvc;
    @Autowired private JwtService jwtService;
    @Autowired private UserRepository userRepository;
    @Autowired private GroupRepository groupRepository;
    @Autowired private GroupMembershipRepository groupMembershipRepository;
    @Autowired private GroupActivityLogRepository groupActivityLogRepository;

    @Test
    void activityLogs_areMemberScopedPagedAndDeterministicallyNewestFirst() throws Exception {
        UUID caller = createUser(UserStatus.ACTIVE); UUID other = createUser(UserStatus.ACTIVE);
        UUID group = createGroup(caller, GroupStatus.ACTIVE, Instant.now());
        addMembership(group, caller, GroupRole.OWNER, GroupMembershipStatus.ACTIVE, Instant.now());
        Instant same = Instant.parse("2026-01-01T00:00:00Z"); UUID low = new UUID(0, 1); UUID high = new UUID(0, 2);
        groupActivityLogRepository.saveAndFlush(new GroupActivityLogEntity(low, group, null, GroupActivityAction.GROUP_CREATED, same));
        groupActivityLogRepository.saveAndFlush(new GroupActivityLogEntity(high, group, caller, GroupActivityAction.GROUP_MEMBER_LEFT, caller, same));
        mockMvc.perform(get("/api/v1/groups/{groupId}/activity-logs", group).header("Authorization", bearer(caller)))
                .andExpect(status().isOk()).andExpect(jsonPath("$.page").value(0)).andExpect(jsonPath("$.size").value(30))
                .andExpect(jsonPath("$.items[0].id").value(high.toString())).andExpect(jsonPath("$.items[0].actorUserId").value(caller.toString()))
                .andExpect(jsonPath("$.items[1].actorUserId").doesNotExist());
        mockMvc.perform(get("/api/v1/groups/{groupId}/activity-logs", group).queryParam("size", "101").header("Authorization", bearer(caller))).andExpect(status().isBadRequest());
        mockMvc.perform(get("/api/v1/groups/{groupId}/activity-logs", group).header("Authorization", bearer(other))).andExpect(status().isNotFound()).andExpect(jsonPath("$.code").value("GROUP_NOT_FOUND"));

        UUID archived = createGroup(caller, GroupStatus.ARCHIVED, Instant.now());
        addMembership(archived, caller, GroupRole.MEMBER, GroupMembershipStatus.ACTIVE, Instant.now());
        groupActivityLogRepository.saveAndFlush(new GroupActivityLogEntity(UUID.randomUUID(), archived, caller, GroupActivityAction.GROUP_UPDATED, Instant.now()));
        mockMvc.perform(get("/api/v1/groups/{groupId}/activity-logs", archived).header("Authorization", bearer(caller)))
                .andExpect(status().isOk()).andExpect(jsonPath("$.items.length()").value(1));

        UUID deleted = createGroup(caller, GroupStatus.DELETED, Instant.now());
        addMembership(deleted, caller, GroupRole.MEMBER, GroupMembershipStatus.ACTIVE, Instant.now());
        mockMvc.perform(get("/api/v1/groups/{groupId}/activity-logs", deleted).header("Authorization", bearer(caller)))
                .andExpect(status().isNotFound()).andExpect(jsonPath("$.code").value("GROUP_NOT_FOUND"));
    }

    @Test
    void listGroups_usesOnlyActiveMembershipsFiltersStatusAndAppliesStablePagingOrder() throws Exception {
        UUID callerId = createUser(UserStatus.ACTIVE);
        UUID activeOlder = createGroup(callerId, GroupStatus.ACTIVE, Instant.parse("2026-01-01T00:00:00Z"));
        UUID activeNewer = createGroup(callerId, GroupStatus.ACTIVE, Instant.parse("2026-02-01T00:00:00Z"));
        UUID archived = createGroup(callerId, GroupStatus.ARCHIVED, Instant.parse("2026-03-01T00:00:00Z"));
        UUID deleted = createGroup(callerId, GroupStatus.DELETED, Instant.parse("2026-04-01T00:00:00Z"));
        UUID unrelated = createGroup(createUser(UserStatus.ACTIVE), GroupStatus.ACTIVE, Instant.parse("2026-05-01T00:00:00Z"));
        addMembership(activeOlder, callerId, GroupRole.MEMBER, GroupMembershipStatus.ACTIVE, Instant.parse("2026-01-01T00:00:00Z"));
        addMembership(activeNewer, callerId, GroupRole.ADMIN, GroupMembershipStatus.ACTIVE, Instant.parse("2026-01-02T00:00:00Z"));
        addMembership(activeNewer, callerId, GroupRole.MEMBER, GroupMembershipStatus.LEFT, Instant.parse("2025-12-01T00:00:00Z"));
        addMembership(archived, callerId, GroupRole.OWNER, GroupMembershipStatus.ACTIVE, Instant.parse("2026-01-03T00:00:00Z"));
        addMembership(deleted, callerId, GroupRole.MEMBER, GroupMembershipStatus.ACTIVE, Instant.parse("2026-01-04T00:00:00Z"));
        addMembership(createGroup(callerId, GroupStatus.ACTIVE, Instant.now()), callerId, GroupRole.MEMBER, GroupMembershipStatus.LEFT, Instant.now());

        String activeBody = mockMvc.perform(get("/api/v1/groups").header("Authorization", bearer(callerId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.page").value(0))
                .andExpect(jsonPath("$.size").value(30))
                .andExpect(jsonPath("$.totalElements").value(2))
                .andReturn().getResponse().getContentAsString();
        JsonNode active = JSON.readTree(activeBody);
        assertEquals(6, active.size());
        assertEquals(2, active.get("items").size());
        assertEquals(activeNewer.toString(), active.at("/items/0/id").asText());
        assertEquals("ADMIN", active.at("/items/0/callerRole").asText());
        assertEquals(activeOlder.toString(), active.at("/items/1/id").asText());
        assertEquals(6, active.at("/items/0").size());
        assertFalse(activeBody.contains(unrelated.toString()));
        assertFalse(activeBody.contains(deleted.toString()));

        mockMvc.perform(get("/api/v1/groups").queryParam("status", "ARCHIVED").header("Authorization", bearer(callerId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.items[0].id").value(archived.toString()))
                .andExpect(jsonPath("$.items[0].status").value("ARCHIVED"));

        mockMvc.perform(get("/api/v1/groups").queryParam("page", "0").queryParam("size", "1").header("Authorization", bearer(callerId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.size").value(1))
                .andExpect(jsonPath("$.hasNext").value(true))
                .andExpect(jsonPath("$.items[0].id").value(activeNewer.toString()));
        mockMvc.perform(get("/api/v1/groups").queryParam("size", "100").header("Authorization", bearer(callerId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.size").value(100));
    }

    @Test
    void listGroups_validatesPagingAndStatus() throws Exception {
        UUID callerId = createUser(UserStatus.ACTIVE);
        for (String[] parameters : new String[][]{{"page", "-1"}, {"size", "0"}, {"size", "101"}, {"status", "DELETED"}}) {
            mockMvc.perform(get("/api/v1/groups").queryParam(parameters[0], parameters[1]).header("Authorization", bearer(callerId)))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
        }
    }

    @Test
    void groupDetail_authorizesActiveMembersAllowsArchivedAndDerivesCurrentOwner() throws Exception {
        UUID creatorId = createUser(UserStatus.ACTIVE);
        UUID currentOwnerId = createUser(UserStatus.ACTIVE);
        UUID groupId = createGroup(creatorId, GroupStatus.ACTIVE, Instant.parse("2026-01-01T00:00:00Z"));
        addMembership(groupId, creatorId, GroupRole.ADMIN, GroupMembershipStatus.ACTIVE, Instant.parse("2026-01-01T00:00:00Z"));
        addMembership(groupId, currentOwnerId, GroupRole.OWNER, GroupMembershipStatus.ACTIVE, Instant.parse("2026-01-02T00:00:00Z"));

        String detailBody = mockMvc.perform(get("/api/v1/groups/{groupId}", groupId).header("Authorization", bearer(creatorId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.ownerUserId").value(currentOwnerId.toString()))
                .andExpect(jsonPath("$.callerRole").value("ADMIN"))
                .andReturn().getResponse().getContentAsString();
        assertEquals(9, JSON.readTree(detailBody).size());

        UUID archivedId = createGroup(creatorId, GroupStatus.ARCHIVED, Instant.now());
        addMembership(archivedId, creatorId, GroupRole.MEMBER, GroupMembershipStatus.ACTIVE, Instant.now());
        addMembership(archivedId, currentOwnerId, GroupRole.OWNER, GroupMembershipStatus.ACTIVE, Instant.now());
        mockMvc.perform(get("/api/v1/groups/{groupId}", archivedId).header("Authorization", bearer(creatorId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("ARCHIVED"));
    }

    @Test
    void privateGroupReads_makeUnknownNonMemberHistoricalAndDeletedGroupsExternallyIndistinguishable() throws Exception {
        UUID memberId = createUser(UserStatus.ACTIVE);
        UUID nonMemberId = createUser(UserStatus.ACTIVE);
        UUID groupId = createGroup(memberId, GroupStatus.ACTIVE, Instant.now());
        addMembership(groupId, memberId, GroupRole.OWNER, GroupMembershipStatus.ACTIVE, Instant.now());
        UUID unknownGroupId = UUID.randomUUID();
        JsonNode unknown = errorFor(get("/api/v1/groups/{groupId}", unknownGroupId).header("Authorization", bearer(nonMemberId)));
        JsonNode nonMember = errorFor(get("/api/v1/groups/{groupId}", groupId).header("Authorization", bearer(nonMemberId)));
        assertSameNotFound(unknown, nonMember, "GROUP_NOT_FOUND");

        for (GroupMembershipStatus historicalStatus : new GroupMembershipStatus[]{GroupMembershipStatus.LEFT, GroupMembershipStatus.KICKED, GroupMembershipStatus.BANNED}) {
            UUID historicalUserId = createUser(UserStatus.ACTIVE);
            addMembership(groupId, historicalUserId, GroupRole.MEMBER, historicalStatus, Instant.now());
            JsonNode historical = errorFor(get("/api/v1/groups/{groupId}/members", groupId).header("Authorization", bearer(historicalUserId)));
            assertSameNotFound(unknown, historical, "GROUP_NOT_FOUND");
        }

        UUID deletedId = createGroup(memberId, GroupStatus.DELETED, Instant.now());
        addMembership(deletedId, memberId, GroupRole.OWNER, GroupMembershipStatus.ACTIVE, Instant.now());
        JsonNode deleted = errorFor(get("/api/v1/groups/{groupId}", deletedId).header("Authorization", bearer(memberId)));
        assertSameNotFound(unknown, deleted, "GROUP_NOT_FOUND");
    }

    @Test
    void memberReads_returnOnlyActiveMembersWithExactSafeDtoAndScopeTargetByGroup() throws Exception {
        UUID callerId = createUser(UserStatus.ACTIVE);
        UUID earlierId = createUser(UserStatus.ACTIVE);
        UUID targetId = createUser(UserStatus.ACTIVE);
        UUID groupId = createGroup(callerId, GroupStatus.ACTIVE, Instant.now());
        addMembership(groupId, callerId, GroupRole.OWNER, GroupMembershipStatus.ACTIVE, Instant.parse("2026-01-02T00:00:00Z"));
        addMembership(groupId, earlierId, GroupRole.MEMBER, GroupMembershipStatus.ACTIVE, Instant.parse("2026-01-01T00:00:00Z"));
        addMembership(groupId, targetId, GroupRole.ADMIN, GroupMembershipStatus.ACTIVE, Instant.parse("2026-01-03T00:00:00Z"));
        UUID leftId = createUser(UserStatus.ACTIVE);
        addMembership(groupId, leftId, GroupRole.MEMBER, GroupMembershipStatus.LEFT, Instant.now());

        String membersBody = mockMvc.perform(get("/api/v1/groups/{groupId}/members", groupId).header("Authorization", bearer(callerId)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        JsonNode members = JSON.readTree(membersBody);
        assertEquals(3, members.size());
        assertEquals(earlierId.toString(), members.get(0).get("userId").asText());
        assertEquals(6, members.get(0).size());
        assertFalse(membersBody.contains(leftId.toString()));
        assertFalse(membersBody.contains("email"));
        assertFalse(membersBody.contains("phone"));

        String memberBody = mockMvc.perform(get("/api/v1/groups/{groupId}/members/{userId}", groupId, targetId).header("Authorization", bearer(callerId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.role").value("ADMIN"))
                .andReturn().getResponse().getContentAsString();
        assertEquals(6, JSON.readTree(memberBody).size());

        JsonNode unknownTarget = errorFor(get("/api/v1/groups/{groupId}/members/{userId}", groupId, UUID.randomUUID()).header("Authorization", bearer(callerId)));
        JsonNode leftTarget = errorFor(get("/api/v1/groups/{groupId}/members/{userId}", groupId, leftId).header("Authorization", bearer(callerId)));
        assertSameNotFound(unknownTarget, leftTarget, "GROUP_MEMBER_NOT_FOUND");
        for (GroupMembershipStatus historicalStatus : new GroupMembershipStatus[]{GroupMembershipStatus.KICKED, GroupMembershipStatus.BANNED}) {
            UUID historicalTargetId = createUser(UserStatus.ACTIVE);
            addMembership(groupId, historicalTargetId, GroupRole.MEMBER, historicalStatus, Instant.now());
            JsonNode historicalTarget = errorFor(get("/api/v1/groups/{groupId}/members/{userId}", groupId, historicalTargetId).header("Authorization", bearer(callerId)));
            assertSameNotFound(unknownTarget, historicalTarget, "GROUP_MEMBER_NOT_FOUND");
        }

        UUID otherGroupId = createGroup(callerId, GroupStatus.ACTIVE, Instant.now());
        UUID crossGroupOnlyId = createUser(UserStatus.ACTIVE);
        addMembership(otherGroupId, callerId, GroupRole.OWNER, GroupMembershipStatus.ACTIVE, Instant.now());
        addMembership(otherGroupId, crossGroupOnlyId, GroupRole.MEMBER, GroupMembershipStatus.ACTIVE, Instant.now());
        JsonNode crossGroup = errorFor(get("/api/v1/groups/{groupId}/members/{userId}", groupId, crossGroupOnlyId).header("Authorization", bearer(callerId)));
        assertSameNotFound(unknownTarget, crossGroup, "GROUP_MEMBER_NOT_FOUND");
    }

    @Test
    void groupReads_requireAuthenticationAndExistingActiveUserPolicy() throws Exception {
        UUID groupId = UUID.randomUUID();
        mockMvc.perform(get("/api/v1/groups/{groupId}", groupId))
                .andExpect(status().isUnauthorized());
        for (UserStatus statusValue : new UserStatus[]{UserStatus.PENDING_VERIFICATION, UserStatus.SUSPENDED, UserStatus.DEACTIVATED}) {
            UUID userId = createUser(statusValue);
            mockMvc.perform(get("/api/v1/groups/{groupId}", groupId).header("Authorization", bearer(userId)))
                    .andExpect(status().isForbidden());
        }
    }

    private JsonNode errorFor(org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder request) throws Exception {
        String body = mockMvc.perform(request).andExpect(status().isNotFound()).andReturn().getResponse().getContentAsString();
        return JSON.readTree(body);
    }

    private void assertSameNotFound(JsonNode expected, JsonNode actual, String code) {
        assertEquals(404, expected.get("status").asInt());
        assertEquals(code, expected.get("code").asText());
        assertEquals(expected.get("status").asInt(), actual.get("status").asInt());
        assertEquals(expected.get("code").asText(), actual.get("code").asText());
        assertEquals(expected.get("message").asText(), actual.get("message").asText());
        assertEquals(expected.size(), actual.size());
    }

    private UUID createGroup(UUID createdBy, GroupStatus status, Instant time) {
        UUID groupId = UUID.randomUUID();
        groupRepository.saveAndFlush(new GroupEntity(groupId, "Group " + groupId.toString().substring(0, 8), null, null, status, createdBy, time, time));
        return groupId;
    }

    private void addMembership(UUID groupId, UUID userId, GroupRole role, GroupMembershipStatus status, Instant createdAt) {
        Instant endedAt = status == GroupMembershipStatus.ACTIVE ? null : createdAt.plusSeconds(1);
        groupMembershipRepository.saveAndFlush(new GroupMembershipEntity(UUID.randomUUID(), groupId, userId, role, status, createdAt, endedAt));
    }

    private UUID createUser(UserStatus status) {
        UUID id = UUID.randomUUID();
        Instant now = Instant.now();
        userRepository.saveAndFlush(new UserEntity(id, "read." + id + "@example.com", "read_" + id.toString().substring(0, 8), "Read User", status, now, now));
        return id;
    }

    private String bearer(UUID userId) {
        return "Bearer " + jwtService.generateAccessToken(userId);
    }
}
