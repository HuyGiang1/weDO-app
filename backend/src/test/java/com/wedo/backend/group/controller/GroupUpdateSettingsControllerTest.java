package com.wedo.backend.group.controller;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.group.entity.GroupEntity;
import com.wedo.backend.group.entity.GroupMembershipEntity;
import com.wedo.backend.group.entity.GroupMembershipStatus;
import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.entity.GroupSettingsEntity;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.group.repository.GroupMembershipRepository;
import com.wedo.backend.group.repository.GroupRepository;
import com.wedo.backend.group.repository.GroupSettingsRepository;
import com.wedo.backend.security.jwt.JwtService;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
class GroupUpdateSettingsControllerTest extends AbstractPostgresIntegrationTest {

    private static final ObjectMapper JSON = new ObjectMapper();
    private static final Instant INITIAL_TIME = Instant.parse("2020-01-01T00:00:00Z");

    @Autowired private MockMvc mockMvc;
    @Autowired private JwtService jwtService;
    @Autowired private UserRepository userRepository;
    @Autowired private GroupRepository groupRepository;
    @Autowired private GroupSettingsRepository groupSettingsRepository;
    @Autowired private GroupMembershipRepository groupMembershipRepository;
    @Autowired private JdbcTemplate jdbcTemplate;

    @Test
    void ownerAndAdminUpdateMetadataWhileMemberNonMemberAndHistoricalCallersCannot() throws Exception {
        UUID ownerId = createUser(UserStatus.ACTIVE);
        UUID adminId = createUser(UserStatus.ACTIVE);
        UUID memberId = createUser(UserStatus.ACTIVE);
        UUID outsiderId = createUser(UserStatus.ACTIVE);
        UUID leftId = createUser(UserStatus.ACTIVE);
        UUID groupId = createGroup(ownerId, GroupStatus.ACTIVE);
        addMembership(groupId, ownerId, GroupRole.OWNER, GroupMembershipStatus.ACTIVE);
        addMembership(groupId, adminId, GroupRole.ADMIN, GroupMembershipStatus.ACTIVE);
        addMembership(groupId, memberId, GroupRole.MEMBER, GroupMembershipStatus.ACTIVE);
        addMembership(groupId, leftId, GroupRole.MEMBER, GroupMembershipStatus.LEFT);

        mockMvc.perform(patch("/api/v1/groups/{groupId}", groupId).header("Authorization", bearer(ownerId))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"name\":\" Exact Name \",\"description\":\"Owner description\",\"avatarStorageKey\":\"group/avatar\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value(" Exact Name "))
                .andExpect(jsonPath("$.description").value("Owner description"));
        mockMvc.perform(patch("/api/v1/groups/{groupId}", groupId).header("Authorization", bearer(adminId))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"description\":\"Admin description\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.description").value("Admin description"));
        assertError(patch("/api/v1/groups/{groupId}", groupId).header("Authorization", bearer(memberId))
                .contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"Denied\"}"), 403, "INSUFFICIENT_GROUP_PERMISSION");
        assertError(patch("/api/v1/groups/{groupId}", groupId).header("Authorization", bearer(outsiderId))
                .contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"Denied\"}"), 404, "GROUP_NOT_FOUND");
        assertError(patch("/api/v1/groups/{groupId}", groupId).header("Authorization", bearer(leftId))
                .contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"Denied\"}"), 404, "GROUP_NOT_FOUND");
    }

    @Test
    void groupPatch_appliesBlankClearNullNoOpAndTimestampRules() throws Exception {
        UUID ownerId = createUser(UserStatus.ACTIVE);
        UUID groupId = createGroup(ownerId, GroupStatus.ACTIVE);
        addMembership(groupId, ownerId, GroupRole.OWNER, GroupMembershipStatus.ACTIVE);
        Instant beforeNoOp = groupRepository.findById(groupId).orElseThrow().getUpdatedAt();

        mockMvc.perform(patch("/api/v1/groups/{groupId}", groupId).header("Authorization", bearer(ownerId))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"name\":null,\"description\":null,\"avatarStorageKey\":null}"))
                .andExpect(status().isOk());
        assertEquals(beforeNoOp, groupRepository.findById(groupId).orElseThrow().getUpdatedAt());

        assertError(patch("/api/v1/groups/{groupId}", groupId).header("Authorization", bearer(ownerId))
                .contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"   \"}"), 400, "VALIDATION_FAILED");
        mockMvc.perform(patch("/api/v1/groups/{groupId}", groupId).header("Authorization", bearer(ownerId))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"description\":\"   \",\"avatarStorageKey\":\" \"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.description").doesNotExist())
                .andExpect(jsonPath("$.avatarStorageKey").doesNotExist());
        assertNotEquals(beforeNoOp, groupRepository.findById(groupId).orElseThrow().getUpdatedAt());
    }

    @Test
    void activeMembersReadSettingsButOnlyOwnerUpdatesExactSettingsDto() throws Exception {
        UUID ownerId = createUser(UserStatus.ACTIVE);
        UUID adminId = createUser(UserStatus.ACTIVE);
        UUID memberId = createUser(UserStatus.ACTIVE);
        UUID groupId = createGroup(ownerId, GroupStatus.ACTIVE);
        addMembership(groupId, ownerId, GroupRole.OWNER, GroupMembershipStatus.ACTIVE);
        addMembership(groupId, adminId, GroupRole.ADMIN, GroupMembershipStatus.ACTIVE);
        addMembership(groupId, memberId, GroupRole.MEMBER, GroupMembershipStatus.ACTIVE);

        String readBody = mockMvc.perform(get("/api/v1/groups/{groupId}/settings", groupId).header("Authorization", bearer(memberId)))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        assertEquals(7, JSON.readTree(readBody).size());
        assertError(patch("/api/v1/groups/{groupId}/settings", groupId).header("Authorization", bearer(adminId))
                .contentType(MediaType.APPLICATION_JSON).content("{\"joinPolicy\":\"APPROVAL_REQUIRED\"}"), 403, "INSUFFICIENT_GROUP_PERMISSION");
        assertError(patch("/api/v1/groups/{groupId}/settings", groupId).header("Authorization", bearer(memberId))
                .contentType(MediaType.APPLICATION_JSON).content("{\"joinPolicy\":\"APPROVAL_REQUIRED\"}"), 403, "INSUFFICIENT_GROUP_PERMISSION");

        mockMvc.perform(patch("/api/v1/groups/{groupId}/settings", groupId).header("Authorization", bearer(ownerId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"joinPolicy\":\"APPROVAL_REQUIRED\",\"memberModifyInfoAllowed\":true,\"memberCreateActivityAllowed\":false,\"memberPinMessageAllowed\":true,\"chatHistoryPolicy\":\"FROM_JOIN_TIME\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.joinPolicy").value("APPROVAL_REQUIRED"))
                .andExpect(jsonPath("$.memberCreateActivityAllowed").value(false))
                .andExpect(jsonPath("$.chatHistoryPolicy").value("FROM_JOIN_TIME"));
    }

    @Test
    void settingsPatch_honorsNullFalseNoOpAndDoesNotChangeGlobalUserProfile() throws Exception {
        UUID ownerId = createUser(UserStatus.ACTIVE);
        UUID memberId = createUser(UserStatus.ACTIVE);
        UUID groupId = createGroup(ownerId, GroupStatus.ACTIVE);
        addMembership(groupId, ownerId, GroupRole.OWNER, GroupMembershipStatus.ACTIVE);
        addMembership(groupId, memberId, GroupRole.MEMBER, GroupMembershipStatus.ACTIVE);
        Instant beforeNoOp = groupSettingsRepository.findById(groupId).orElseThrow().getUpdatedAt();

        mockMvc.perform(patch("/api/v1/groups/{groupId}/settings", groupId).header("Authorization", bearer(ownerId))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"joinPolicy\":null,\"memberModifyInfoAllowed\":null}"))
                .andExpect(status().isOk());
        assertEquals(beforeNoOp, groupSettingsRepository.findById(groupId).orElseThrow().getUpdatedAt());

        UserEntity beforeMember = userRepository.findById(memberId).orElseThrow();
        String displayName = beforeMember.getDisplayName();
        String avatarStorageKey = beforeMember.getAvatarStorageKey();
        mockMvc.perform(patch("/api/v1/groups/{groupId}/settings", groupId).header("Authorization", bearer(ownerId))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"memberModifyInfoAllowed\":true,\"memberCreateActivityAllowed\":false}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.memberCreateActivityAllowed").value(false));
        assertNotEquals(beforeNoOp, groupSettingsRepository.findById(groupId).orElseThrow().getUpdatedAt());
        UserEntity afterMember = userRepository.findById(memberId).orElseThrow();
        assertEquals(displayName, afterMember.getDisplayName());
        assertEquals(avatarStorageKey, afterMember.getAvatarStorageKey());

        assertError(patch("/api/v1/groups/{groupId}/settings", groupId).header("Authorization", bearer(ownerId))
                .contentType(MediaType.APPLICATION_JSON).content("{\"joinPolicy\":\"INVALID\"}"), 400, "VALIDATION_FAILED");
    }

    @Test
    void archivedIsReadableButRejectsWritesAndDeletedIsUnavailable() throws Exception {
        UUID ownerId = createUser(UserStatus.ACTIVE);
        UUID archivedId = createGroup(ownerId, GroupStatus.ARCHIVED);
        addMembership(archivedId, ownerId, GroupRole.OWNER, GroupMembershipStatus.ACTIVE);
        mockMvc.perform(get("/api/v1/groups/{groupId}/settings", archivedId).header("Authorization", bearer(ownerId)))
                .andExpect(status().isOk());
        assertError(patch("/api/v1/groups/{groupId}", archivedId).header("Authorization", bearer(ownerId))
                .contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"No\"}"), 409, "GROUP_ARCHIVED");
        assertError(patch("/api/v1/groups/{groupId}/settings", archivedId).header("Authorization", bearer(ownerId))
                .contentType(MediaType.APPLICATION_JSON).content("{\"memberPinMessageAllowed\":true}"), 409, "GROUP_ARCHIVED");

        UUID deletedId = createGroup(ownerId, GroupStatus.DELETED);
        addMembership(deletedId, ownerId, GroupRole.OWNER, GroupMembershipStatus.ACTIVE);
        assertError(get("/api/v1/groups/{groupId}/settings", deletedId).header("Authorization", bearer(ownerId)), 404, "GROUP_NOT_FOUND");
        assertError(patch("/api/v1/groups/{groupId}", deletedId).header("Authorization", bearer(ownerId))
                .contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"No\"}"), 404, "GROUP_NOT_FOUND");
    }

    @Test
    void joinPolicyUpdate_doesNotMutateM6AdmissionTablesOrMemberships() throws Exception {
        UUID ownerId = createUser(UserStatus.ACTIVE);
        UUID inviteeId = createUser(UserStatus.ACTIVE);
        UUID groupId = createGroup(ownerId, GroupStatus.ACTIVE);
        addMembership(groupId, ownerId, GroupRole.OWNER, GroupMembershipStatus.ACTIVE);
        Timestamp createdAt = Timestamp.from(INITIAL_TIME);
        jdbcTemplate.update("INSERT INTO group_invitations (id, group_id, invitee_id, status, created_at) VALUES (?, ?, ?, 'PENDING', ?)", UUID.randomUUID(), groupId, inviteeId, createdAt);
        jdbcTemplate.update("INSERT INTO group_invite_links (id, group_id, code, uses_count, is_revoked, created_at) VALUES (?, ?, ?, 0, FALSE, ?)", UUID.randomUUID(), groupId, "link-" + UUID.randomUUID(), createdAt);
        jdbcTemplate.update("INSERT INTO group_join_requests (id, group_id, user_id, status, created_at) VALUES (?, ?, ?, 'PENDING', ?)", UUID.randomUUID(), groupId, inviteeId, createdAt);
        long memberships = count("group_memberships", groupId);
        long invitations = count("group_invitations", groupId);
        long links = count("group_invite_links", groupId);
        long requests = count("group_join_requests", groupId);

        mockMvc.perform(patch("/api/v1/groups/{groupId}/settings", groupId).header("Authorization", bearer(ownerId))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"joinPolicy\":\"APPROVAL_REQUIRED\"}"))
                .andExpect(status().isOk());
        assertEquals(memberships, count("group_memberships", groupId));
        assertEquals(invitations, count("group_invitations", groupId));
        assertEquals(links, count("group_invite_links", groupId));
        assertEquals(requests, count("group_join_requests", groupId));
    }

    private void assertError(org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder request, int expectedStatus, String expectedCode) throws Exception {
        mockMvc.perform(request).andExpect(status().is(expectedStatus)).andExpect(jsonPath("$.code").value(expectedCode));
    }

    private UUID createGroup(UUID createdBy, GroupStatus status) {
        UUID groupId = UUID.randomUUID();
        groupRepository.saveAndFlush(new GroupEntity(groupId, "Initial group", "Initial description", "initial/avatar", status, createdBy, INITIAL_TIME, INITIAL_TIME));
        groupSettingsRepository.saveAndFlush(GroupSettingsEntity.createDefault(groupId, INITIAL_TIME));
        return groupId;
    }

    private void addMembership(UUID groupId, UUID userId, GroupRole role, GroupMembershipStatus status) {
        Instant endedAt = status == GroupMembershipStatus.ACTIVE ? null : INITIAL_TIME.plusSeconds(1);
        groupMembershipRepository.saveAndFlush(new GroupMembershipEntity(UUID.randomUUID(), groupId, userId, role, status, INITIAL_TIME, endedAt));
    }

    private UUID createUser(UserStatus status) {
        UUID id = UUID.randomUUID();
        userRepository.saveAndFlush(new UserEntity(id, "update." + id + "@example.com", "update_" + id.toString().substring(0, 8), "Update User", status, INITIAL_TIME, INITIAL_TIME));
        return id;
    }

    private long count(String table, UUID groupId) {
        return jdbcTemplate.queryForObject("SELECT COUNT(*) FROM " + table + " WHERE group_id = ?", Long.class, groupId);
    }

    private String bearer(UUID userId) {
        return "Bearer " + jwtService.generateAccessToken(userId);
    }
}
