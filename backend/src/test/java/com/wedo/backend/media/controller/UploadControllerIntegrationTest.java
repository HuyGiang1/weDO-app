package com.wedo.backend.media.controller;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

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
import com.wedo.backend.fund.dto.FundDtos.CreateFundRequest;
import com.wedo.backend.fund.service.FundService;
import com.wedo.backend.media.storage.InMemoryObjectStorageService;
import com.wedo.backend.security.jwt.JwtService;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserRepository;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

@AutoConfigureMockMvc
class UploadControllerIntegrationTest extends AbstractPostgresIntegrationTest {
    @Autowired private MockMvc mockMvc;
    @Autowired private JwtService jwtService;
    @Autowired private UserRepository userRepository;
    @Autowired private GroupRepository groupRepository;
    @Autowired private GroupSettingsRepository groupSettingsRepository;
    @Autowired private GroupMembershipRepository membershipRepository;
    @Autowired private FundService fundService;
    @Autowired private InMemoryObjectStorageService objectStorage;

    private UUID ownerId;
    private UUID memberId;
    private UUID outsiderId;
    private UUID groupId;

    @BeforeEach
    void setUp() {
        ownerId = createUser();
        memberId = createUser();
        outsiderId = createUser();
        groupId = UUID.randomUUID();
        Instant now = Instant.now();
        groupRepository.save(new GroupEntity(groupId, "Upload test", null, null,
                GroupStatus.ACTIVE, ownerId, now, now));
        groupSettingsRepository.save(GroupSettingsEntity.createDefault(groupId, now));
        membershipRepository.save(new GroupMembershipEntity(UUID.randomUUID(), groupId, ownerId,
                GroupRole.OWNER, GroupMembershipStatus.ACTIVE, now, null));
        membershipRepository.save(new GroupMembershipEntity(UUID.randomUUID(), groupId, memberId,
                GroupRole.MEMBER, GroupMembershipStatus.ACTIVE, now, null));
    }

    @Test
    void avatarPresignUsesAuthenticatedUserAndReturnsServerGeneratedTarget() throws Exception {
        mockMvc.perform(post("/api/v1/uploads/presign")
                        .header("Authorization", bearer(ownerId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"category\":\"AVATAR\",\"fileName\":\"../photo.png\",\"contentType\":\"image/png\",\"fileSize\":42,\"contextId\":null}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.storageKey").value(org.hamcrest.Matchers.matchesRegex(
                        "avatar/" + ownerId + "/[0-9a-f-]{36}")))
                .andExpect(jsonPath("$.uploadUrl").value("http://storage.test/put"))
                .andExpect(jsonPath("$.expiresAt").isNotEmpty())
                .andExpect(jsonPath("$.requiredHeaders.Content-Type").value("image/png"))
                .andExpect(jsonPath("$.requiredHeaders.x-amz-meta-declared-size").value("42"));
    }

    @Test
    void avatarRejectsContextAndGroupAvatarRequiresValidContextAndPermission() throws Exception {
        mockMvc.perform(post("/api/v1/uploads/presign").header("Authorization", bearer(ownerId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"category\":\"AVATAR\",\"fileName\":\"p.png\",\"contentType\":\"image/png\",\"fileSize\":42,\"contextId\":\"" + groupId + "\"}"))
                .andExpect(status().isBadRequest());
        mockMvc.perform(post("/api/v1/uploads/presign").header("Authorization", bearer(ownerId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"category\":\"GROUP_AVATAR\",\"fileName\":\"g.png\",\"contentType\":\"image/png\",\"fileSize\":42}"))
                .andExpect(status().isBadRequest());
        mockMvc.perform(post("/api/v1/uploads/presign").header("Authorization", bearer(ownerId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"category\":\"GROUP_AVATAR\",\"fileName\":\"g.png\",\"contentType\":\"image/png\",\"fileSize\":42,\"contextId\":\"not-a-uuid\"}"))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post("/api/v1/uploads/presign").header("Authorization", bearer(ownerId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"category\":\"GROUP_AVATAR\",\"fileName\":\"g.png\",\"contentType\":\"image/png\",\"fileSize\":42,\"contextId\":\"" + groupId + "\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.storageKey").value(org.hamcrest.Matchers.startsWith("group-avatar/" + groupId + "/")));

        mockMvc.perform(post("/api/v1/uploads/presign").header("Authorization", bearer(memberId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"category\":\"GROUP_AVATAR\",\"fileName\":\"g.png\",\"contentType\":\"image/png\",\"fileSize\":42,\"contextId\":\"" + groupId + "\"}"))
                .andExpect(status().isForbidden());
        mockMvc.perform(post("/api/v1/uploads/presign").header("Authorization", bearer(outsiderId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"category\":\"GROUP_AVATAR\",\"fileName\":\"g.png\",\"contentType\":\"image/png\",\"fileSize\":42,\"contextId\":\"" + groupId + "\"}"))
                .andExpect(status().isNotFound());
    }

    @Test
    void presignRequiresAuthentication() throws Exception {
        mockMvc.perform(post("/api/v1/uploads/presign")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"category\":\"AVATAR\",\"fileName\":\"p.png\",\"contentType\":\"image/png\",\"fileSize\":42}"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void fundExpenseReceiptPresignIsReadOnlyAndRequiresManagerPermission() throws Exception {
        fundService.createFund(groupId, ownerId, new CreateFundRequest("Upload test fund"));

        mockMvc.perform(post("/api/v1/uploads/presign").header("Authorization", bearer(ownerId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"category\":\"FUND_EXPENSE_RECEIPT\",\"fileName\":\"receipt.png\",\"contentType\":\"image/png\",\"fileSize\":42,\"contextId\":\"" + groupId + "\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.storageKey").value(org.hamcrest.Matchers.startsWith("fund-expense-receipt/" + groupId + "/")));

        mockMvc.perform(post("/api/v1/uploads/presign").header("Authorization", bearer(memberId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"category\":\"FUND_EXPENSE_RECEIPT\",\"fileName\":\"receipt.png\",\"contentType\":\"image/png\",\"fileSize\":42,\"contextId\":\"" + groupId + "\"}"))
                .andExpect(status().isForbidden());
    }

    private UUID createUser() {
        UUID id = UUID.randomUUID();
        String suffix = id.toString().substring(0, 8);
        userRepository.save(new UserEntity(id, "upload_" + suffix + "@example.com", "upload_" + suffix,
                "Upload Test", UserStatus.ACTIVE, Instant.now(), Instant.now()));
        return id;
    }

    private String bearer(UUID userId) {
        return "Bearer " + jwtService.generateAccessToken(userId);
    }
}
