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
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
class UserQrControllerTest extends AbstractPostgresIntegrationTest {

    @Autowired private MockMvc mockMvc;
    @Autowired private JwtService jwtService;
    @Autowired private UserRepository userRepository;
    @Autowired private UserPrivacySettingsRepository privacyRepository;
    private final ObjectMapper objectMapper = JsonMapper.builder().build();

    @Test
    void activeOwnerGetsStableQrRegardlessOfUsernameOrQrPrivacy() throws Exception {
        UUID ownerId = createUser(UserStatus.ACTIVE, "owner");
        String expected = "wedo://user/" + ownerId;
        MvcResult first = mockMvc.perform(get("/api/v1/me/qr").header("Authorization", bearer(ownerId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.deepLink").value(expected))
                .andReturn();
        userRepository.findById(ownerId).orElseThrow().setUsername("renamed");
        UserPrivacySettingsEntity settings = privacyRepository.findById(ownerId).orElseThrow();
        settings.setDiscoverByQr(false);
        privacyRepository.saveAndFlush(settings);
        mockMvc.perform(get("/api/v1/me/qr").header("Authorization", bearer(ownerId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.deepLink").value(expected));
        assertEquals(Set.of("deepLink"), fields(first));
    }

    @Test
    void resolverUsesSafeProjectionAndUniformNotFoundSemantics() throws Exception {
        UUID callerId = createUser(UserStatus.ACTIVE, "caller");
        UUID targetId = createUser(UserStatus.ACTIVE, "target");
        MvcResult success = resolve(callerId, "wedo://user/" + targetId);
        assertEquals(200, success.getResponse().getStatus());
        assertEquals(Set.of("id", "username", "displayName", "avatarStorageKey", "bio"), fields(success));

        UserPrivacySettingsEntity settings = privacyRepository.findById(targetId).orElseThrow();
        settings.setDiscoverByQr(false);
        privacyRepository.saveAndFlush(settings);
        MvcResult disabled = resolve(callerId, "wedo://user/" + targetId);
        MvcResult unknown = resolve(callerId, "wedo://user/" + UUID.randomUUID());
        MvcResult malformed = resolve(callerId, "wedo://user/not-a-uuid");
        MvcResult pending = resolve(callerId, "wedo://user/" + createUser(UserStatus.PENDING_VERIFICATION, "pending"));
        MvcResult suspended = resolve(callerId, "wedo://user/" + createUser(UserStatus.SUSPENDED, "suspended"));
        MvcResult deactivated = resolve(callerId, "wedo://user/" + createUser(UserStatus.DEACTIVATED, "deactivated"));
        MvcResult extraPath = resolve(callerId, "wedo://user/" + targetId + "/extra");
        MvcResult query = resolve(callerId, "wedo://user/" + targetId + "?x=1");
        for (MvcResult result : new MvcResult[]{disabled, unknown, malformed, pending, suspended, deactivated, extraPath, query}) assertNotFound(result);
        assertEquals(fields(disabled), fields(unknown));
        assertEquals(fields(unknown), fields(malformed));
        assertEquals(fields(malformed), fields(pending));
        assertEquals(fields(pending), fields(suspended));
        assertEquals(fields(suspended), fields(deactivated));
    }

    @Test
    void resolverRejectsTransportInvalidInputAndProtectedCallers() throws Exception {
        UUID activeId = createUser(UserStatus.ACTIVE, "active");
        mockMvc.perform(post("/api/v1/users/qr/resolve").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"deepLink\":\" \"}").header("Authorization", bearer(activeId)))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
        mockMvc.perform(post("/api/v1/users/qr/resolve").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"deepLink\":\"wedo://user/" + "a".repeat(300) + "\"}"))
                .andExpect(status().isUnauthorized());
        UUID pendingId = createUser(UserStatus.PENDING_VERIFICATION, "pending");
        MvcResult pending = resolve(pendingId, "wedo://user/" + activeId);
        assertEquals(403, pending.getResponse().getStatus());
        assertEquals("EMAIL_NOT_VERIFIED", body(pending).path("code").asText());
    }

    private MvcResult resolve(UUID callerId, String deepLink) throws Exception {
        return mockMvc.perform(post("/api/v1/users/qr/resolve")
                        .header("Authorization", bearer(callerId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"deepLink\":\"" + deepLink + "\"}"))
                .andReturn();
    }

    private void assertNotFound(MvcResult result) throws Exception {
        assertEquals(404, result.getResponse().getStatus());
        JsonNode body = body(result);
        assertEquals("RESOURCE_NOT_FOUND", body.path("code").asText());
        assertEquals("Resource was not found.", body.path("message").asText());
    }

    private JsonNode body(MvcResult result) throws Exception { return objectMapper.readTree(result.getResponse().getContentAsString()); }
    private Set<String> fields(MvcResult result) throws Exception { return new HashSet<>(body(result).propertyNames()); }
    private String bearer(UUID userId) { return "Bearer " + jwtService.generateAccessToken(userId); }

    private UUID createUser(UserStatus status, String username) {
        UUID id = UUID.randomUUID(); Instant now = Instant.now();
        userRepository.saveAndFlush(new UserEntity(id, username + "." + id + "@example.com", username + id.toString().substring(0, 8), username, status, now, now));
        privacyRepository.saveAndFlush(UserPrivacySettingsEntity.createDefault(id, now));
        return id;
    }
}
