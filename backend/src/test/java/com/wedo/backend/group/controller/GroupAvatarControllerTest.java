package com.wedo.backend.group.controller;

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
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
class GroupAvatarControllerTest extends AbstractPostgresIntegrationTest {

    @Autowired private MockMvc mockMvc;
    @Autowired private JwtService jwtService;
    @Autowired private UserRepository userRepository;
    @Autowired private GroupRepository groupRepository;
    @Autowired private GroupSettingsRepository groupSettingsRepository;
    @Autowired private GroupMembershipRepository groupMembershipRepository;

    private UUID ownerId;
    private UUID adminId;
    private UUID memberId;

    @BeforeEach
    void setUp() {
        ownerId = createUser("owner");
        adminId = createUser("admin");
        memberId = createUser("member");
    }

    private UUID createUser(String prefix) {
        UUID id = UUID.randomUUID();
        userRepository.save(new UserEntity(
                id,
                prefix + "_" + id.toString().substring(0, 8) + "@example.com",
                prefix + "_" + id.toString().substring(0, 8),
                prefix + " User",
                UserStatus.ACTIVE,
                Instant.now(),
                Instant.now()
        ));
        return id;
    }

    private String bearer(UUID userId) {
        return "Bearer " + jwtService.generateAccessToken(userId);
    }

    private UUID createGroupWithMembers(boolean memberModifyInfoAllowed, GroupStatus groupStatus) {
        UUID groupId = UUID.randomUUID();
        Instant now = Instant.now();
        groupRepository.save(new GroupEntity(
                groupId,
                "Test Group",
                "Description",
                null,
                groupStatus,
                ownerId,
                now,
                now
        ));
        GroupSettingsEntity settings = GroupSettingsEntity.createDefault(groupId, now);
        if (memberModifyInfoAllowed) {
            settings.update(
                    settings.getJoinPolicy(),
                    true,
                    settings.isMemberCreateActivityAllowed(),
                    settings.isMemberPinMessageAllowed(),
                    settings.getChatHistoryPolicy(),
                    now
            );
        }
        groupSettingsRepository.save(settings);

        groupMembershipRepository.save(new GroupMembershipEntity(UUID.randomUUID(), groupId, ownerId, GroupRole.OWNER, GroupMembershipStatus.ACTIVE, now, null));
        groupMembershipRepository.save(new GroupMembershipEntity(UUID.randomUUID(), groupId, adminId, GroupRole.ADMIN, GroupMembershipStatus.ACTIVE, now, null));
        groupMembershipRepository.save(new GroupMembershipEntity(UUID.randomUUID(), groupId, memberId, GroupRole.MEMBER, GroupMembershipStatus.ACTIVE, now, null));
        return groupId;
    }

    @Test
    void ownerUpdatesAvatar_succeedsAndReturnsAvatarStorageKey() throws Exception {
        UUID groupId = createGroupWithMembers(false, GroupStatus.ACTIVE);

        mockMvc.perform(patch("/api/v1/groups/{groupId}", groupId)
                        .header("Authorization", bearer(ownerId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"avatarStorageKey\":\"avatars/owner-avatar.png\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.avatarStorageKey").value("avatars/owner-avatar.png"));

        GroupEntity group = groupRepository.findById(groupId).orElseThrow();
        assertEquals("avatars/owner-avatar.png", group.getAvatarStorageKey());
    }

    @Test
    void adminUpdatesAvatar_succeeds() throws Exception {
        UUID groupId = createGroupWithMembers(false, GroupStatus.ACTIVE);

        mockMvc.perform(patch("/api/v1/groups/{groupId}", groupId)
                        .header("Authorization", bearer(adminId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"avatarStorageKey\":\"avatars/admin-avatar.jpg\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.avatarStorageKey").value("avatars/admin-avatar.jpg"));
    }

    @Test
    void memberUpdatesAvatar_whenDisallowed_returnsForbidden() throws Exception {
        UUID groupId = createGroupWithMembers(false, GroupStatus.ACTIVE);

        mockMvc.perform(patch("/api/v1/groups/{groupId}", groupId)
                        .header("Authorization", bearer(memberId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"avatarStorageKey\":\"avatars/member-avatar.png\"}"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("INSUFFICIENT_GROUP_PERMISSION"));
    }

    @Test
    void memberUpdatesAvatar_whenAllowed_succeeds() throws Exception {
        UUID groupId = createGroupWithMembers(true, GroupStatus.ACTIVE);

        mockMvc.perform(patch("/api/v1/groups/{groupId}", groupId)
                        .header("Authorization", bearer(memberId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"avatarStorageKey\":\"avatars/member-allowed.webp\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.avatarStorageKey").value("avatars/member-allowed.webp"));
    }

    @Test
    void updateAvatar_whenGroupArchived_returnsConflict() throws Exception {
        UUID groupId = createGroupWithMembers(false, GroupStatus.ARCHIVED);

        mockMvc.perform(patch("/api/v1/groups/{groupId}", groupId)
                        .header("Authorization", bearer(ownerId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"avatarStorageKey\":\"avatars/archived.png\"}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("GROUP_ARCHIVED"));
    }
}
