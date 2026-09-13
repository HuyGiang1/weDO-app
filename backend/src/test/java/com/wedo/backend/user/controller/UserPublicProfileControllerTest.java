package com.wedo.backend.user.controller;

import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.security.jwt.JwtService;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserPrivacySettingsEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserPrivacySettingsRepository;
import com.wedo.backend.user.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.json.JsonMapper;

import java.time.Instant;
import java.util.HashSet;
import java.util.Set;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
class UserPublicProfileControllerTest extends AbstractPostgresIntegrationTest {

    @Autowired private MockMvc mockMvc;
    @Autowired private JwtService jwtService;
    @Autowired private UserRepository userRepository;
    @Autowired private UserPrivacySettingsRepository privacyRepository;
    private final ObjectMapper objectMapper = JsonMapper.builder().build();

    @Test
    void activeCaller_canReadExactFiveFieldPublicProjectionOfActiveTarget() throws Exception {
        UUID callerId = createUser(UserStatus.ACTIVE, "caller", "Caller");
        UUID targetId = createUser(UserStatus.ACTIVE, "target", "Target Name");
        UserEntity target = userRepository.findById(targetId).orElseThrow();
        target.setAvatarStorageKey("avatars/target.jpg");
        target.setBio("Safe public bio");
        target.setPhone("+84987654321");
        target.setEmailVerifiedAt(Instant.now());
        userRepository.saveAndFlush(target);

        MvcResult result = mockMvc.perform(get("/api/v1/users/{userId}", targetId).header("Authorization", bearer(callerId)))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.id").value(targetId.toString()))
                .andExpect(jsonPath("$.username").value(target.getUsername()))
                .andExpect(jsonPath("$.displayName").value("Target Name"))
                .andExpect(jsonPath("$.avatarStorageKey").value("avatars/target.jpg"))
                .andExpect(jsonPath("$.bio").value("Safe public bio"))
                .andExpect(jsonPath("$.email").doesNotExist())
                .andExpect(jsonPath("$.phone").doesNotExist())
                .andExpect(jsonPath("$.status").doesNotExist())
                .andExpect(jsonPath("$.emailVerified").doesNotExist())
                .andExpect(jsonPath("$.privacySettings").doesNotExist())
                .andExpect(jsonPath("$.createdAt").doesNotExist())
                .andExpect(jsonPath("$.updatedAt").doesNotExist())
                .andExpect(jsonPath("$.passwordHash").doesNotExist())
                .andExpect(jsonPath("$.refreshSessions").doesNotExist())
                .andExpect(jsonPath("$.isFriend").doesNotExist())
                .andExpect(jsonPath("$.isBlocked").doesNotExist())
                .andReturn();
        assertEquals(
                Set.of("id", "username", "displayName", "avatarStorageKey", "bio"),
                responseFieldNames(result)
        );
    }

    @Test
    void nullablePublicFields_areSupportedAndSelfLookupStillUsesPublicProjection() throws Exception {
        UUID callerId = createUser(UserStatus.ACTIVE, null, null);

        mockMvc.perform(get("/api/v1/users/{userId}", callerId).header("Authorization", bearer(callerId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(callerId.toString()))
                .andExpect(jsonPath("$.username").doesNotExist())
                .andExpect(jsonPath("$.displayName").doesNotExist())
                .andExpect(jsonPath("$.avatarStorageKey").doesNotExist())
                .andExpect(jsonPath("$.bio").doesNotExist())
                .andExpect(jsonPath("$.email").doesNotExist())
                .andExpect(jsonPath("$.status").doesNotExist());
    }

    @Test
    void directKnownIdLookup_isIndependentFromAllDiscoveryPreferences() throws Exception {
        UUID callerId = createUser(UserStatus.ACTIVE, "caller", "Caller");
        UUID targetId = createUser(UserStatus.ACTIVE, "hidden", "Hidden");
        UserPrivacySettingsEntity settings = privacyRepository.findById(targetId).orElseThrow();
        settings.setDiscoverByUsername(false);
        settings.setDiscoverByEmail(false);
        settings.setDiscoverByPhone(false);
        settings.setDiscoverByQr(false);
        privacyRepository.saveAndFlush(settings);

        mockMvc.perform(get("/api/v1/users/{userId}", targetId).header("Authorization", bearer(callerId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(targetId.toString()))
                .andExpect(jsonPath("$.username").exists());
    }

    @Test
    void publicProfile_requiresAnAuthenticatedActiveCaller() throws Exception {
        UUID targetId = createUser(UserStatus.ACTIVE, "target", "Target");
        mockMvc.perform(get("/api/v1/users/{userId}", targetId))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));

        assertCallerStatus(targetId, UserStatus.PENDING_VERIFICATION, "EMAIL_NOT_VERIFIED");
        assertCallerStatus(targetId, UserStatus.SUSPENDED, "ACCOUNT_SUSPENDED");
        assertCallerStatus(targetId, UserStatus.DEACTIVATED, "ACCOUNT_DEACTIVATED");
    }

    @Test
    void unknownAndEveryNonActiveTarget_haveTheSamePublicNotFoundContract() throws Exception {
        UUID callerId = createUser(UserStatus.ACTIVE, "caller", "Caller");
        MvcResult unknown = lookup(callerId, UUID.randomUUID());
        assertNotFoundContract(unknown);

        for (UserStatus targetStatus : new UserStatus[]{
                UserStatus.PENDING_VERIFICATION,
                UserStatus.SUSPENDED,
                UserStatus.DEACTIVATED
        }) {
            MvcResult result = lookup(callerId, createUser(targetStatus, "private", "Private"));
            assertNotFoundContract(result);
            assertEquals(responseFieldNames(unknown), responseFieldNames(result));
        }
    }

    private void assertCallerStatus(UUID targetId, UserStatus callerStatus, String expectedCode) throws Exception {
        UUID callerId = createUser(callerStatus, "caller", "Caller");
        mockMvc.perform(get("/api/v1/users/{userId}", targetId).header("Authorization", bearer(callerId)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value(expectedCode));
    }

    private MvcResult lookup(UUID callerId, UUID targetId) throws Exception {
        return mockMvc.perform(get("/api/v1/users/{userId}", targetId).header("Authorization", bearer(callerId)))
                .andReturn();
    }

    private void assertNotFoundContract(MvcResult result) throws Exception {
        assertEquals(404, result.getResponse().getStatus());
        JsonNode body = objectMapper.readTree(result.getResponse().getContentAsString());
        assertEquals("RESOURCE_NOT_FOUND", body.path("code").asText());
        assertEquals("Resource was not found.", body.path("message").asText());
    }

    private Set<String> responseFieldNames(MvcResult result) throws Exception {
        JsonNode body = objectMapper.readTree(result.getResponse().getContentAsString());
        Set<String> fieldNames = new HashSet<>();
        fieldNames.addAll(body.propertyNames());
        return fieldNames;
    }

    private UUID createUser(UserStatus status, String username, String displayName) {
        UUID id = UUID.randomUUID();
        Instant now = Instant.now();
        String uniqueUsername = username == null ? null : username + "-" + id;
        UserEntity user = new UserEntity(id, "public." + id + "@example.com", uniqueUsername, displayName, status, now, now);
        userRepository.saveAndFlush(user);
        privacyRepository.saveAndFlush(UserPrivacySettingsEntity.createDefault(id, now));
        return id;
    }

    private String bearer(UUID userId) {
        return "Bearer " + jwtService.generateAccessToken(userId);
    }
}
