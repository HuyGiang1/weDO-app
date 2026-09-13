package com.wedo.backend.user.controller;

import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.security.jwt.JwtService;
import com.wedo.backend.user.entity.DmPolicy;
import com.wedo.backend.user.entity.FriendRequestPolicy;
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

import java.time.Instant;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
class UserPrivacySettingsControllerTest extends AbstractPostgresIntegrationTest {

    @Autowired private MockMvc mockMvc;
    @Autowired private JwtService jwtService;
    @Autowired private UserRepository userRepository;
    @Autowired private UserPrivacySettingsRepository privacyRepository;

    @Test
    void getPrivacySettings_returnsRegisteredDefaultsAndPersistedCustomValues() throws Exception {
        UUID defaultUser = createUser(UserStatus.ACTIVE);
        mockMvc.perform(get("/api/v1/me/privacy").header("Authorization", bearer(defaultUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.discoverByUsername").value(true))
                .andExpect(jsonPath("$.discoverByQr").value(true))
                .andExpect(jsonPath("$.discoverByEmail").value(false))
                .andExpect(jsonPath("$.discoverByPhone").value(false))
                .andExpect(jsonPath("$.dmPolicy").value("EVERYONE"))
                .andExpect(jsonPath("$.friendRequestPolicy").value("EVERYONE"))
                .andExpect(jsonPath("$.showOnlineStatus").value(true))
                .andExpect(jsonPath("$.showLastSeen").value(true));

        UserPrivacySettingsEntity custom = privacyRepository.findById(defaultUser).orElseThrow();
        custom.setDiscoverByUsername(false);
        custom.setDmPolicy(DmPolicy.FRIENDS_ONLY);
        privacyRepository.saveAndFlush(custom);
        mockMvc.perform(get("/api/v1/me/privacy").header("Authorization", bearer(defaultUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.discoverByUsername").value(false))
                .andExpect(jsonPath("$.dmPolicy").value("FRIENDS_ONLY"));
    }

    @Test
    void patchPrivacySettings_updatesEveryBooleanAndBothPolicies() throws Exception {
        UUID userId = createUser(UserStatus.ACTIVE);
        assertPatch(userId, "{\"discoverByUsername\":false}", "discoverByUsername", false);
        assertPatch(userId, "{\"discoverByQr\":false}", "discoverByQr", false);
        assertPatch(userId, "{\"discoverByEmail\":true}", "discoverByEmail", true);
        assertPatch(userId, "{\"discoverByPhone\":true}", "discoverByPhone", true);
        assertPatch(userId, "{\"showOnlineStatus\":false}", "showOnlineStatus", false);
        assertPatch(userId, "{\"showLastSeen\":false}", "showLastSeen", false);
        assertPatch(userId, "{\"dmPolicy\":\"MUTUAL_GROUPS\"}", "dmPolicy", "MUTUAL_GROUPS");
        assertPatch(userId, "{\"friendRequestPolicy\":\"NONE\"}", "friendRequestPolicy", "NONE");

        mockMvc.perform(patch("/api/v1/me/privacy").header("Authorization", bearer(userId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"discoverByUsername\":true,\"discoverByQr\":true,\"discoverByEmail\":false,\"discoverByPhone\":false,\"showOnlineStatus\":true,\"showLastSeen\":true,\"dmPolicy\":\"FRIENDS_ONLY\",\"friendRequestPolicy\":\"MUTUAL_GROUPS\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.discoverByUsername").value(true))
                .andExpect(jsonPath("$.discoverByPhone").value(false))
                .andExpect(jsonPath("$.dmPolicy").value("FRIENDS_ONLY"))
                .andExpect(jsonPath("$.friendRequestPolicy").value("MUTUAL_GROUPS"));
    }

    @Test
    void patchPrivacySettings_treatsOmittedNullAndSameValuesAsTimestampPreservingNoOps() throws Exception {
        UUID userId = createUser(UserStatus.ACTIVE);
        UserPrivacySettingsEntity settings = privacyRepository.findById(userId).orElseThrow();
        Instant originalUpdatedAt = Instant.parse("2020-01-01T00:00:00Z");
        settings.setUpdatedAt(originalUpdatedAt);
        privacyRepository.saveAndFlush(settings);

        for (String request : new String[]{"{}", "{\"discoverByPhone\":null,\"dmPolicy\":null}", "{\"discoverByPhone\":false,\"dmPolicy\":\"EVERYONE\"}"}) {
            mockMvc.perform(patch("/api/v1/me/privacy").header("Authorization", bearer(userId))
                            .contentType(MediaType.APPLICATION_JSON).content(request))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.discoverByPhone").value(false));
            assertEquals(originalUpdatedAt, privacyRepository.findById(userId).orElseThrow().getUpdatedAt());
        }

        mockMvc.perform(patch("/api/v1/me/privacy").header("Authorization", bearer(userId))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"discoverByPhone\":true}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.discoverByPhone").value(true));
        assertNotEquals(originalUpdatedAt, privacyRepository.findById(userId).orElseThrow().getUpdatedAt());
    }

    @Test
    void patchPrivacySettings_invalidEnums_mustReturnValidationFailed() throws Exception {
        UUID userId = createUser(UserStatus.ACTIVE);
        for (String request : new String[]{"{\"dmPolicy\":\"NOT_A_REAL_POLICY\"}", "{\"friendRequestPolicy\":\"NOT_A_REAL_POLICY\"}"}) {
            mockMvc.perform(patch("/api/v1/me/privacy").header("Authorization", bearer(userId))
                            .contentType(MediaType.APPLICATION_JSON).content(request))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
        }
    }

    @Test
    void privacySettings_requireAuthenticationActiveStatusAndExistingSettingsRow() throws Exception {
        mockMvc.perform(get("/api/v1/me/privacy")).andExpect(status().isUnauthorized());
        for (UserStatus statusValue : new UserStatus[]{UserStatus.PENDING_VERIFICATION, UserStatus.SUSPENDED, UserStatus.DEACTIVATED}) {
            UUID userId = createUser(statusValue);
            mockMvc.perform(get("/api/v1/me/privacy").header("Authorization", bearer(userId))).andExpect(status().isForbidden());
        }
        UUID missingSettingsUser = createUser(UserStatus.ACTIVE);
        privacyRepository.deleteById(missingSettingsUser);
        privacyRepository.flush();
        mockMvc.perform(get("/api/v1/me/privacy").header("Authorization", bearer(missingSettingsUser)))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.code").value("INTERNAL_SERVER_ERROR"));
    }

    @Test
    void patchPrivacySettings_ignoresExtraPropertiesAndPersistsOnlyAllowListedFields() throws Exception {
        UUID userId = createUser(UserStatus.ACTIVE);
        UserEntity user = userRepository.findById(userId).orElseThrow();
        Instant userUpdatedAt = user.getUpdatedAt();
        mockMvc.perform(patch("/api/v1/me/privacy").header("Authorization", bearer(userId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"discoverByEmail\":true,\"userId\":\"" + UUID.randomUUID() + "\",\"status\":\"SUSPENDED\",\"updatedAt\":\"2020-01-01T00:00:00Z\"}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.discoverByEmail").value(true));
        assertEquals(UserStatus.ACTIVE, userRepository.findById(userId).orElseThrow().getStatus());
        assertEquals(userUpdatedAt, userRepository.findById(userId).orElseThrow().getUpdatedAt());
    }

    private void assertPatch(UUID userId, String request, String field, Object value) throws Exception {
        mockMvc.perform(patch("/api/v1/me/privacy").header("Authorization", bearer(userId))
                        .contentType(MediaType.APPLICATION_JSON).content(request))
                .andExpect(status().isOk()).andExpect(jsonPath("$." + field).value(value));
    }

    private UUID createUser(UserStatus status) {
        UUID id = UUID.randomUUID();
        Instant now = Instant.now();
        userRepository.saveAndFlush(new UserEntity(id, "privacy." + id + "@example.com", "privacy_" + id.toString().substring(0, 8), "Privacy", status, now, now));
        privacyRepository.saveAndFlush(UserPrivacySettingsEntity.createDefault(id, now));
        return id;
    }

    private String bearer(UUID userId) {
        return "Bearer " + jwtService.generateAccessToken(userId);
    }
}
