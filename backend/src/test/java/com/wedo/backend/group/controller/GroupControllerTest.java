package com.wedo.backend.group.controller;

import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.group.dto.CreateGroupRequest;
import com.wedo.backend.group.entity.GroupActivityAction;
import com.wedo.backend.group.entity.GroupMembershipEntity;
import com.wedo.backend.group.entity.GroupMembershipStatus;
import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.entity.GroupSettingsEntity;
import com.wedo.backend.group.repository.GroupActivityLogRepository;
import com.wedo.backend.group.repository.GroupMembershipRepository;
import com.wedo.backend.group.repository.GroupRepository;
import com.wedo.backend.group.repository.GroupSettingsRepository;
import com.wedo.backend.group.service.GroupService;
import com.wedo.backend.security.jwt.JwtService;
import com.wedo.backend.social.service.MutualGroupChecker;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
class GroupControllerTest extends AbstractPostgresIntegrationTest {

    @Autowired private MockMvc mockMvc;
    @Autowired private JwtService jwtService;
    @Autowired private UserRepository userRepository;
    @Autowired private GroupRepository groupRepository;
    @Autowired private GroupSettingsRepository groupSettingsRepository;
    @Autowired private GroupMembershipRepository groupMembershipRepository;
    @Autowired private GroupActivityLogRepository groupActivityLogRepository;
    @Autowired private GroupService groupService;
    @Autowired private MutualGroupChecker mutualGroupChecker;
    @Autowired private JdbcTemplate jdbcTemplate;

    @Test
    void createGroup_activeCallerCreatesTheEntireM5AggregateWithExactResponseContract() throws Exception {
        UUID creatorId = createUser(UserStatus.ACTIVE);

        String body = mockMvc.perform(post("/api/v1/groups")
                        .header("Authorization", bearer(creatorId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Da Nang 2026\",\"description\":\"Summer trip\",\"avatarStorageKey\":\"groups/da-nang.png\",\"ownerUserId\":\"" + UUID.randomUUID() + "\",\"status\":\"DELETED\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.name").value("Da Nang 2026"))
                .andExpect(jsonPath("$.description").value("Summer trip"))
                .andExpect(jsonPath("$.avatarStorageKey").value("groups/da-nang.png"))
                .andExpect(jsonPath("$.status").value("ACTIVE"))
                .andExpect(jsonPath("$.createdBy").value(creatorId.toString()))
                .andReturn().getResponse().getContentAsString();

        Matcher idMatcher = Pattern.compile("\\\"id\\\":\\\"([^\\\"]+)\\\"").matcher(body);
        assertTrue(idMatcher.find());
        UUID groupId = UUID.fromString(idMatcher.group(1));
        assertEquals(8, Pattern.compile("\\\"[^\\\"]+\\\":").matcher(body).results().count());

        assertTrue(groupRepository.existsById(groupId));
        GroupSettingsEntity settings = groupSettingsRepository.findById(groupId).orElseThrow();
        assertEquals("AUTO_JOIN", settings.getJoinPolicy().name());
        assertFalse(settings.isMemberModifyInfoAllowed());
        assertTrue(settings.isMemberCreateActivityAllowed());
        assertFalse(settings.isMemberPinMessageAllowed());
        assertEquals("FULL_HISTORY", settings.getChatHistoryPolicy().name());

        assertEquals(1, groupMembershipRepository.countByGroupIdAndStatus(groupId, GroupMembershipStatus.ACTIVE));
        assertEquals(1, groupMembershipRepository.countByGroupIdAndRoleAndStatus(groupId, GroupRole.OWNER, GroupMembershipStatus.ACTIVE));
        GroupMembershipEntity owner = groupMembershipRepository.findByGroupIdAndUserIdAndStatus(groupId, creatorId, GroupMembershipStatus.ACTIVE).getFirst();
        assertEquals(GroupRole.OWNER, owner.getRole());
        assertEquals(GroupMembershipStatus.ACTIVE, owner.getStatus());
        assertNull(owner.getEndedAt());
        assertEquals(1, groupActivityLogRepository.findByGroupId(groupId).size());
        assertEquals(GroupActivityAction.GROUP_CREATED, groupActivityLogRepository.findByGroupId(groupId).getFirst().getAction());

        UUID peerId = createUser(UserStatus.ACTIVE);
        groupMembershipRepository.saveAndFlush(new GroupMembershipEntity(
                UUID.randomUUID(), groupId, peerId, GroupRole.MEMBER, GroupMembershipStatus.ACTIVE, Instant.now(), null
        ));
        assertTrue(mutualGroupChecker.haveMutualActiveGroup(creatorId, peerId));
    }

    @Test
    void createGroup_requiresAuthenticationAndAnActiveCallerWithoutPersistingGroupsForRejectedCallers() throws Exception {
        long before = groupRepository.count();
        mockMvc.perform(post("/api/v1/groups").contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"Group\"}"))
                .andExpect(status().isUnauthorized());

        for (UserStatus statusValue : new UserStatus[]{UserStatus.PENDING_VERIFICATION, UserStatus.SUSPENDED, UserStatus.DEACTIVATED}) {
            UUID userId = createUser(statusValue);
            mockMvc.perform(post("/api/v1/groups").header("Authorization", bearer(userId))
                            .contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"Group\"}"))
                    .andExpect(status().isForbidden());
        }
        assertEquals(before, groupRepository.count());
    }

    @Test
    void createGroup_validatesOnlyTheDocumentedRequestFields() throws Exception {
        UUID creatorId = createUser(UserStatus.ACTIVE);
        for (String body : new String[]{
                "{}",
                "{\"name\":\"   \"}",
                "{\"name\":\"" + "n".repeat(101) + "\"}",
                "{\"name\":\"Group\",\"description\":\"" + "d".repeat(501) + "\"}"
        }) {
            mockMvc.perform(post("/api/v1/groups").header("Authorization", bearer(creatorId))
                            .contentType(MediaType.APPLICATION_JSON).content(body))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
        }
    }

    @Test
    void createGroup_rollsBackAllAggregateRowsWhenTheFinalActivityLogWriteFails() {
        UUID creatorId = createUser(UserStatus.ACTIVE);
        long groupsBefore = groupRepository.count();
        long settingsBefore = groupSettingsRepository.count();
        long membershipsBefore = groupMembershipRepository.count();
        long logsBefore = groupActivityLogRepository.count();
        jdbcTemplate.execute("ALTER TABLE group_activity_logs ADD CONSTRAINT test_reject_group_created CHECK (action <> 'GROUP_CREATED')");
        try {
            assertThrows(DataIntegrityViolationException.class, () -> groupService.createGroup(
                    creatorId, new CreateGroupRequest("Rollback group", null, null)
            ));
        } finally {
            jdbcTemplate.execute("ALTER TABLE group_activity_logs DROP CONSTRAINT IF EXISTS test_reject_group_created");
        }
        assertEquals(groupsBefore, groupRepository.count());
        assertEquals(settingsBefore, groupSettingsRepository.count());
        assertEquals(membershipsBefore, groupMembershipRepository.count());
        assertEquals(logsBefore, groupActivityLogRepository.count());
    }

    private UUID createUser(UserStatus status) {
        UUID id = UUID.randomUUID();
        Instant now = Instant.now();
        userRepository.saveAndFlush(new UserEntity(id, "group." + id + "@example.com", "group_" + id.toString().substring(0, 8), "Group User", status, now, now));
        return id;
    }

    private String bearer(UUID userId) {
        return "Bearer " + jwtService.generateAccessToken(userId);
    }
}
