package com.wedo.backend.security;

import com.wedo.backend.auth.security.ProfileCompletionTokenService;
import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.security.jwt.JwtService;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserRepository;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.io.Decoders;
import io.jsonwebtoken.security.Keys;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;

import javax.crypto.SecretKey;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
class SecurityConfigTest extends AbstractPostgresIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private ProfileCompletionTokenService profileCompletionTokenService;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RestAccessDeniedHandler accessDeniedHandler;

    @Value("${security.jwt.secret-base64}")
    private String secretBase64;

    private SecretKey getSigningKey() {
        byte[] keyBytes = Decoders.BASE64.decode(secretBase64);
        return Keys.hmacShaKeyFor(keyBytes);
    }

    private String createExpiredToken(UUID userId) {
        Instant now = Instant.now();
        return Jwts.builder()
                .subject(userId.toString())
                .issuedAt(Date.from(now.minus(Duration.ofHours(2))))
                .expiration(Date.from(now.minus(Duration.ofHours(1))))
                .signWith(getSigningKey(), Jwts.SIG.HS256)
                .compact();
    }

    private String createWrongSignatureToken(UUID userId) {
        SecretKey wrongKey = Jwts.SIG.HS256.key().build();
        Instant now = Instant.now();
        return Jwts.builder()
                .subject(userId.toString())
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plus(Duration.ofHours(1))))
                .signWith(wrongKey, Jwts.SIG.HS256)
                .compact();
    }

    private String createNonUuidSubjectToken() {
        Instant now = Instant.now();
        return Jwts.builder()
                .subject("not-a-valid-uuid")
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plus(Duration.ofHours(1))))
                .signWith(getSigningKey(), Jwts.SIG.HS256)
                .compact();
    }

    @Test
    @DisplayName("PasswordEncoder bean should exist in Spring context and be functional")
    void passwordEncoderBean_shouldExistAndBeFunctional() {
        assertThat(passwordEncoder).isNotNull();
        assertThat(passwordEncoder).isInstanceOf(BCryptPasswordEncoder.class);

        String raw = "samplePassword";
        String encoded = passwordEncoder.encode(raw);

        assertThat(passwordEncoder.matches(raw, encoded)).isTrue();
    }

    @Test
    @DisplayName("GET /api/v1/health should be permitted for all without authentication")
    void getHealth_shouldBePublic() throws Exception {
        mockMvc.perform(get("/api/v1/health"))
                .andExpect(status().isOk())
                .andExpect(header().doesNotExist("Set-Cookie"));
    }

    @Test
    @DisplayName("GET /actuator/health should be permitted for all without authentication")
    void getActuatorHealth_shouldBePublic() throws Exception {
        mockMvc.perform(get("/actuator/health"))
                .andExpect(status().isOk())
                .andExpect(header().doesNotExist("Set-Cookie"));
    }

    @Test
    @DisplayName("GET /v3/api-docs should be permitted for all without authentication")
    void getSwaggerDocs_shouldBePublic() throws Exception {
        mockMvc.perform(get("/v3/api-docs"))
                .andExpect(status().isOk())
                .andExpect(header().doesNotExist("Set-Cookie"));
    }

    @Test
    @DisplayName("GET unauthenticated protected route should return exactly 401 Unauthorized JSON with matching X-Request-Id and no redirect")
    void getUnauthenticatedProtected_shouldReturn401UnauthorizedJsonWithMatchingRequestId() throws Exception {
        String testRequestId = "test-req-id-401";

        mockMvc.perform(get("/api/v1/non-existent-protected")
                        .header("X-Request-Id", testRequestId))
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(header().string("X-Request-Id", testRequestId))
                .andExpect(header().doesNotExist("Location"))
                .andExpect(header().doesNotExist("WWW-Authenticate"))
                .andExpect(header().doesNotExist("Set-Cookie"))
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"))
                .andExpect(jsonPath("$.message").value("Authentication is required."))
                .andExpect(jsonPath("$.path").value("/api/v1/non-existent-protected"))
                .andExpect(jsonPath("$.requestId").value(testRequestId))
                .andExpect(jsonPath("$.timestamp").isNotEmpty());
    }

    @Test
    @DisplayName("POST /api/v1/auth/register should be permitted without authentication")
    void postRegister_shouldBePublic() throws Exception {
        String payload = """
                {
                    "email": "security.public@example.com",
                    "password": "Password123!"
                }
                """;

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.userId").isNotEmpty())
                .andExpect(jsonPath("$.email").value("security.public@example.com"));
    }

    @Test
    @DisplayName("GET /api/v1/auth/register without authentication should return exactly 401 Unauthorized")
    void getRegister_unauthenticated_shouldReturn401() throws Exception {
        mockMvc.perform(get("/api/v1/auth/register"))
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/verify-email should be permitted without authentication (not 401)")
    void postVerifyEmail_shouldBePublic() throws Exception {
        mockMvc.perform(post("/api/v1/auth/verify-email")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
    }

    @Test
    @DisplayName("GET /api/v1/auth/verify-email without authentication should return exactly 401 Unauthorized")
    void getVerifyEmail_unauthenticated_shouldReturn401() throws Exception {
        mockMvc.perform(get("/api/v1/auth/verify-email"))
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/resend-verification should be permitted without authentication (not 401)")
    void postResendVerification_shouldBePublic() throws Exception {
        mockMvc.perform(post("/api/v1/auth/resend-verification")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
    }

    @Test
    @DisplayName("GET /api/v1/auth/resend-verification without authentication should return exactly 401 Unauthorized")
    void getResendVerification_unauthenticated_shouldReturn401() throws Exception {
        mockMvc.perform(get("/api/v1/auth/resend-verification"))
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }

    @Test
    @DisplayName("GET /api/v1/auth/usernames/{username}/availability should be permitted without authentication (reaches endpoint)")
    void getUsernameAvailability_shouldBePublic() throws Exception {
        mockMvc.perform(get("/api/v1/auth/usernames/huygiang/availability"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.username").value("huygiang"))
                .andExpect(jsonPath("$.available").isBoolean());
    }

    @Test
    @DisplayName("POST /api/v1/auth/usernames/{username}/availability without authentication should return 401 Unauthorized")
    void postUsernameAvailability_unauthenticated_shouldReturn401() throws Exception {
        mockMvc.perform(post("/api/v1/auth/usernames/huygiang/availability"))
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/complete-profile should be permitted without authentication (not 401)")
    void postCompleteProfile_shouldBePublic() throws Exception {
        mockMvc.perform(post("/api/v1/auth/complete-profile")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
    }

    @Test
    @DisplayName("GET /api/v1/auth/complete-profile without authentication should return exactly 401 Unauthorized")
    void getCompleteProfile_unauthenticated_shouldReturn401() throws Exception {
        mockMvc.perform(get("/api/v1/auth/complete-profile"))
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/login should be permitted without authentication (not 401)")
    void postLogin_shouldBePublic() throws Exception {
        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
    }

    @Test
    @DisplayName("GET /api/v1/auth/login without authentication should return exactly 401 Unauthorized")
    void getLogin_unauthenticated_shouldReturn401() throws Exception {
        mockMvc.perform(get("/api/v1/auth/login"))
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/refresh should be permitted without authentication (not 401)")
    void postRefresh_shouldBePublic() throws Exception {
        mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
    }

    @Test
    @DisplayName("GET /api/v1/auth/refresh without authentication should return exactly 401 Unauthorized")
    void getRefresh_unauthenticated_shouldReturn401() throws Exception {
        mockMvc.perform(get("/api/v1/auth/refresh"))
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/logout should be permitted without authentication (not 401)")
    void postLogout_shouldBePublic() throws Exception {
        mockMvc.perform(post("/api/v1/auth/logout")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/logout without authentication should return exactly 401 Unauthorized")
    void getLogout_unauthenticated_shouldReturn401() throws Exception {
        mockMvc.perform(get("/api/v1/auth/logout"))
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/forgot-password should be permitted without authentication (not 401)")
    void postForgotPassword_shouldBePublic() throws Exception {
        mockMvc.perform(post("/api/v1/auth/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
    }

    @Test
    @DisplayName("GET /api/v1/auth/forgot-password without authentication should return exactly 401 Unauthorized")
    void getForgotPassword_unauthenticated_shouldReturn401() throws Exception {
        mockMvc.perform(get("/api/v1/auth/forgot-password"))
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/reset-password should be permitted without authentication (not 401)")
    void postResetPassword_shouldBePublic() throws Exception {
        mockMvc.perform(post("/api/v1/auth/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
    }

    @Test
    @DisplayName("GET /api/v1/auth/reset-password without authentication should return exactly 401 Unauthorized")
    void getResetPassword_unauthenticated_shouldReturn401() throws Exception {
        mockMvc.perform(get("/api/v1/auth/reset-password"))
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }

    @Test
    @DisplayName("1. public endpoint no auth header -> not rejected by JWT filter")
    void publicEndpoint_noAuthHeader_shouldSucceed() throws Exception {
        mockMvc.perform(get("/api/v1/health"))
                .andExpect(status().isOk());
    }

    @Test
    @DisplayName("2. public endpoint Basic header -> JWT filter ignored")
    void publicEndpoint_basicAuthHeader_shouldBeIgnoredByJwtFilter() throws Exception {
        mockMvc.perform(get("/api/v1/health")
                        .header("Authorization", "Basic dXNlcjpwYXNzd29yZA=="))
                .andExpect(status().isOk());
    }

    @Test
    @DisplayName("3. public endpoint invalid Bearer -> 401 AUTH_TOKEN_INVALID")
    void publicEndpoint_invalidBearer_shouldReturn401AuthTokenInvalid() throws Exception {
        mockMvc.perform(get("/api/v1/health")
                        .header("Authorization", "Bearer invalid.jwt.token"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("AUTH_TOKEN_INVALID"))
                .andExpect(jsonPath("$.message").value("Invalid authentication token."));
    }

    @Test
    @DisplayName("4. public endpoint expired Bearer -> 401 AUTH_TOKEN_EXPIRED")
    void publicEndpoint_expiredBearer_shouldReturn401AuthTokenExpired() throws Exception {
        String expired = createExpiredToken(UUID.randomUUID());
        mockMvc.perform(get("/api/v1/health")
                        .header("Authorization", "Bearer " + expired))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("AUTH_TOKEN_EXPIRED"))
                .andExpect(jsonPath("$.message").value("Authentication token has expired."));
    }

    @Test
    @DisplayName("5. GET /api/v1/me no header -> 401 UNAUTHORIZED")
    void getMe_noHeader_shouldReturn401Unauthorized() throws Exception {
        mockMvc.perform(get("/api/v1/me"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"))
                .andExpect(jsonPath("$.message").value("Authentication is required."));
    }

    @Test
    @DisplayName("6. GET /api/v1/me Basic -> 401 UNAUTHORIZED")
    void getMe_basicHeader_shouldReturn401Unauthorized() throws Exception {
        mockMvc.perform(get("/api/v1/me")
                        .header("Authorization", "Basic dXNlcjpwYXNzd29yZA=="))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"))
                .andExpect(jsonPath("$.message").value("Authentication is required."));
    }

    @Test
    @DisplayName("7. Bearer blank/missing credential -> 401 AUTH_TOKEN_INVALID")
    void bearer_blankOrMissingCredential_shouldReturn401AuthTokenInvalid() throws Exception {
        mockMvc.perform(get("/api/v1/me")
                        .header("Authorization", "Bearer"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("AUTH_TOKEN_INVALID"));

        mockMvc.perform(get("/api/v1/me")
                        .header("Authorization", "Bearer   "))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("AUTH_TOKEN_INVALID"));
    }

    @Test
    @DisplayName("8. valid access JWT -> reaches protected handler / not 401")
    void validAccessJwt_shouldReachProtectedHandler() throws Exception {
        UUID userId = UUID.randomUUID();
        UserEntity user = new UserEntity(
                userId,
                "valid-jwt-" + userId + "@example.com",
                "validuser" + userId.toString().substring(0, 8),
                "Valid User",
                UserStatus.ACTIVE,
                Instant.now(),
                Instant.now()
        );
        userRepository.save(user);

        String token = jwtService.generateAccessToken(userId);

        mockMvc.perform(get("/api/v1/me")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(userId.toString()))
                .andExpect(jsonPath("$.email").value(user.getEmail()));
    }

    @Test
    @DisplayName("9. expired JWT -> 401 AUTH_TOKEN_EXPIRED")
    void expiredJwt_shouldReturn401AuthTokenExpired() throws Exception {
        String expired = createExpiredToken(UUID.randomUUID());
        mockMvc.perform(get("/api/v1/me")
                        .header("Authorization", "Bearer " + expired))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("AUTH_TOKEN_EXPIRED"))
                .andExpect(jsonPath("$.message").value("Authentication token has expired."));
    }

    @Test
    @DisplayName("10. wrong-signature JWT -> 401 AUTH_TOKEN_INVALID")
    void wrongSignatureJwt_shouldReturn401AuthTokenInvalid() throws Exception {
        String wrongSig = createWrongSignatureToken(UUID.randomUUID());
        mockMvc.perform(get("/api/v1/me")
                        .header("Authorization", "Bearer " + wrongSig))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("AUTH_TOKEN_INVALID"));
    }

    @Test
    @DisplayName("11. malformed JWT -> 401 AUTH_TOKEN_INVALID")
    void malformedJwt_shouldReturn401AuthTokenInvalid() throws Exception {
        mockMvc.perform(get("/api/v1/me")
                        .header("Authorization", "Bearer not.a.valid.jwt"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("AUTH_TOKEN_INVALID"));
    }

    @Test
    @DisplayName("12. non-UUID subject -> 401 AUTH_TOKEN_INVALID")
    void nonUuidSubject_shouldReturn401AuthTokenInvalid() throws Exception {
        String nonUuid = createNonUuidSubjectToken();
        mockMvc.perform(get("/api/v1/me")
                        .header("Authorization", "Bearer " + nonUuid))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("AUTH_TOKEN_INVALID"));
    }

    @Test
    @DisplayName("13. profileCompletionToken -> 401 AUTH_TOKEN_INVALID")
    void profileCompletionToken_shouldReturn401AuthTokenInvalid() throws Exception {
        String profileToken = profileCompletionTokenService.generate(UUID.randomUUID());
        mockMvc.perform(get("/api/v1/me")
                        .header("Authorization", "Bearer " + profileToken))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("AUTH_TOKEN_INVALID"));
    }

    @Test
    @DisplayName("14. opaque refresh token -> 401 AUTH_TOKEN_INVALID")
    void opaqueRefreshToken_shouldReturn401AuthTokenInvalid() throws Exception {
        String opaqueToken = UUID.randomUUID().toString();
        mockMvc.perform(get("/api/v1/me")
                        .header("Authorization", "Bearer " + opaqueToken))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("AUTH_TOKEN_INVALID"));
    }

    @Test
    @DisplayName("15. bearer / BEARER case-insensitive -> accepted")
    void bearerCaseInsensitive_shouldBeAccepted() throws Exception {
        UUID userId = UUID.randomUUID();
        UserEntity user = new UserEntity(
                userId,
                "case-test-" + userId + "@example.com",
                "casetest" + userId.toString().substring(0, 8),
                "Case User",
                UserStatus.ACTIVE,
                Instant.now(),
                Instant.now()
        );
        userRepository.save(user);

        String token = jwtService.generateAccessToken(userId);

        mockMvc.perform(get("/api/v1/me")
                        .header("Authorization", "bearer " + token))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/v1/me")
                        .header("Authorization", "BEARER " + token))
                .andExpect(status().isOk());
    }

    @Test
    @DisplayName("16. JWT error response requestId -> matches X-Request-Id")
    void jwtError_requestId_shouldMatchXRequestIdHeader() throws Exception {
        String customReqId = "custom-req-id-jwt-fail";
        mockMvc.perform(get("/api/v1/me")
                        .header("Authorization", "Bearer invalid.jwt")
                        .header("X-Request-Id", customReqId))
                .andExpect(status().isUnauthorized())
                .andExpect(header().string("X-Request-Id", customReqId))
                .andExpect(jsonPath("$.requestId").value(customReqId));
    }

    @Test
    @DisplayName("17. unauthenticated regression -> UNAUTHORIZED envelope unchanged")
    void unauthenticatedRegression_envelopeUnchanged() throws Exception {
        String customReqId = "unauth-req-id-reg";
        mockMvc.perform(get("/api/v1/me")
                        .header("X-Request-Id", customReqId))
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(header().string("X-Request-Id", customReqId))
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"))
                .andExpect(jsonPath("$.message").value("Authentication is required."))
                .andExpect(jsonPath("$.path").value("/api/v1/me"))
                .andExpect(jsonPath("$.requestId").value(customReqId))
                .andExpect(jsonPath("$.timestamp").isNotEmpty());
    }

    @Test
    @DisplayName("18. access denied regression -> ACCESS_DENIED envelope unchanged")
    void accessDeniedRegression_envelopeUnchanged() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/forbidden-path");
        request.addHeader("X-Request-Id", "test-req-403-reg");
        MockHttpServletResponse response = new MockHttpServletResponse();

        accessDeniedHandler.handle(request, response, new AccessDeniedException("Access is denied"));

        assertThat(response.getStatus()).isEqualTo(403);
        assertThat(response.getContentType()).contains(MediaType.APPLICATION_JSON_VALUE);
        assertThat(response.getHeader("X-Request-Id")).isEqualTo("test-req-403-reg");

        String body = response.getContentAsString();
        assertThat(body).contains("\"status\":403");
        assertThat(body).contains("\"code\":\"ACCESS_DENIED\"");
        assertThat(body).contains("\"message\":\"Access is denied.\"");
        assertThat(body).contains("\"path\":\"/api/v1/forbidden-path\"");
        assertThat(body).contains("\"requestId\":\"test-req-403-reg\"");
        assertThat(body).contains("\"timestamp\":");
    }
}
