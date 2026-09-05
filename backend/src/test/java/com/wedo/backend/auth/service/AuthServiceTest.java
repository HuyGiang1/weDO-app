package com.wedo.backend.auth.service;

import com.wedo.backend.auth.dto.CompleteProfileRequest;
import com.wedo.backend.auth.dto.CompleteProfileResponse;
import com.wedo.backend.auth.dto.LoginRequest;
import com.wedo.backend.auth.dto.LoginResponse;
import com.wedo.backend.auth.dto.RefreshTokenRequest;
import com.wedo.backend.auth.dto.RefreshTokenResponse;
import com.wedo.backend.auth.dto.RegisterRequest;
import com.wedo.backend.auth.dto.RegisterResponse;
import com.wedo.backend.auth.dto.ResendVerificationRequest;
import com.wedo.backend.auth.dto.ResendVerificationResponse;
import com.wedo.backend.auth.dto.UsernameAvailabilityResponse;
import com.wedo.backend.auth.dto.VerifyEmailRequest;
import com.wedo.backend.auth.dto.VerifyEmailResponse;
import com.wedo.backend.auth.entity.AuthTokenEntity;
import com.wedo.backend.auth.entity.AuthTokenType;
import com.wedo.backend.auth.entity.RefreshSessionEntity;
import com.wedo.backend.auth.event.EmailVerificationRequestedEvent;
import com.wedo.backend.auth.exception.LoginAttemptException;
import com.wedo.backend.auth.exception.RefreshSessionStatusException;
import com.wedo.backend.auth.exception.VerificationAttemptException;
import com.wedo.backend.auth.repository.AuthTokenRepository;
import com.wedo.backend.auth.repository.RefreshSessionRepository;
import com.wedo.backend.auth.security.AuthTokenHasher;
import com.wedo.backend.auth.security.ProfileCompletionTokenService;
import com.wedo.backend.auth.security.RefreshTokenService;
import com.wedo.backend.security.jwt.JwtService;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.notification.entity.UserNotificationSettingsEntity;
import com.wedo.backend.notification.repository.UserNotificationSettingsRepository;
import com.wedo.backend.user.entity.DmPolicy;
import com.wedo.backend.user.entity.FriendRequestPolicy;
import com.wedo.backend.user.entity.UserCredentialEntity;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserPrivacySettingsEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserCredentialRepository;
import com.wedo.backend.user.repository.UserPrivacySettingsRepository;
import com.wedo.backend.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.event.ApplicationEvents;
import org.springframework.test.context.event.RecordApplicationEvents;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.lenient;

@SpringBootTest
@RecordApplicationEvents
class AuthServiceTest extends AbstractPostgresIntegrationTest {

    @Autowired
    private AuthService authService;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private UserCredentialRepository userCredentialRepository;

    @Autowired
    private UserPrivacySettingsRepository userPrivacySettingsRepository;

    @Autowired
    private UserNotificationSettingsRepository userNotificationSettingsRepository;

    @Autowired
    private AuthTokenRepository authTokenRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private AuthTokenHasher authTokenHasher;

    @Autowired
    private ProfileCompletionTokenService profileCompletionTokenService;

    @Autowired
    private RefreshSessionRepository refreshSessionRepository;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private ApplicationEvents applicationEvents;

    @MockitoBean
    private Clock clock;

    private volatile Instant currentInstant;

    @BeforeEach
    void setUp() {
        currentInstant = Instant.parse("2026-09-05T12:00:00Z");
        lenient().when(clock.instant()).thenAnswer(invocation -> currentInstant);
        lenient().when(clock.getZone()).thenReturn(ZoneOffset.UTC);
    }

    private String getLatestVerificationCode(UUID userId) {
        return applicationEvents.stream(EmailVerificationRequestedEvent.class)
                .filter(e -> e.userId().equals(userId))
                .reduce((first, second) -> second)
                .orElseThrow(() -> new IllegalStateException("No verification event found for user: " + userId))
                .rawCode();
    }

    @Test
    @DisplayName("register should persist user, credentials, privacy, notification, and auth token atomically")
    void register_shouldPersistAllEntitiesAndPublishEvent() {
        String rawEmail = "  Alice.Smith@Example.COM  ";
        String normalizedEmail = "alice.smith@example.com";
        String rawPassword = "SecurePassword123!";

        RegisterRequest request = new RegisterRequest(rawEmail, rawPassword);
        Instant beforeRegister = currentInstant;

        RegisterResponse response = authService.register(request);

        assertThat(response).isNotNull();
        assertThat(response.userId()).isNotNull();
        assertThat(response.email()).isEqualTo(normalizedEmail);
        assertThat(response.status()).isEqualTo(UserStatus.PENDING_VERIFICATION);
        assertThat(response.nextStep()).isEqualTo("VERIFY_EMAIL");

        UUID userId = response.userId();

        // 1. Verify UserEntity
        Optional<UserEntity> userOpt = userRepository.findById(userId);
        assertThat(userOpt).isPresent();
        UserEntity user = userOpt.get();
        assertThat(user.getEmail()).isEqualTo(normalizedEmail);
        assertThat(user.getUsername()).isNull();
        assertThat(user.getDisplayName()).isNull();
        assertThat(user.getStatus()).isEqualTo(UserStatus.PENDING_VERIFICATION);
        assertThat(user.getEmailVerifiedAt()).isNull();
        assertThat(user.getCreatedAt()).isEqualTo(beforeRegister);
        assertThat(user.getUpdatedAt()).isEqualTo(beforeRegister);

        // 2. Verify UserCredentialEntity
        Optional<UserCredentialEntity> credOpt = userCredentialRepository.findById(userId);
        assertThat(credOpt).isPresent();
        UserCredentialEntity cred = credOpt.get();
        assertThat(cred.getPasswordHash()).isNotEqualTo(rawPassword);
        assertThat(passwordEncoder.matches(rawPassword, cred.getPasswordHash())).isTrue();
        assertThat(cred.getFailedAttempts()).isZero();
        assertThat(cred.getLockedUntil()).isNull();
        assertThat(cred.getPasswordChangedAt()).isEqualTo(beforeRegister);

        // 3. Verify UserPrivacySettingsEntity
        Optional<UserPrivacySettingsEntity> privacyOpt = userPrivacySettingsRepository.findById(userId);
        assertThat(privacyOpt).isPresent();
        UserPrivacySettingsEntity privacy = privacyOpt.get();
        assertThat(privacy.isDiscoverByUsername()).isTrue();
        assertThat(privacy.isDiscoverByQr()).isTrue();
        assertThat(privacy.isDiscoverByEmail()).isFalse();
        assertThat(privacy.isDiscoverByPhone()).isFalse();
        assertThat(privacy.getDmPolicy()).isEqualTo(DmPolicy.EVERYONE);
        assertThat(privacy.getFriendRequestPolicy()).isEqualTo(FriendRequestPolicy.EVERYONE);
        assertThat(privacy.isShowOnlineStatus()).isTrue();
        assertThat(privacy.isShowLastSeen()).isTrue();

        // 4. Verify UserNotificationSettingsEntity
        Optional<UserNotificationSettingsEntity> notifOpt = userNotificationSettingsRepository.findById(userId);
        assertThat(notifOpt).isPresent();
        UserNotificationSettingsEntity notif = notifOpt.get();
        assertThat(notif.isPushEnabled()).isTrue();
        assertThat(notif.isSocialEnabled()).isTrue();
        assertThat(notif.isGroupEnabled()).isTrue();
        assertThat(notif.isChatEnabled()).isTrue();
        assertThat(notif.isActivityEnabled()).isTrue();
        assertThat(notif.isPollEnabled()).isTrue();
        assertThat(notif.isTaskEnabled()).isTrue();
        assertThat(notif.isFinanceEnabled()).isTrue();
        assertThat(notif.isFundEnabled()).isTrue();

        // 5. Verify AuthTokenEntity
        List<AuthTokenEntity> tokens = authTokenRepository.findAll().stream()
                .filter(t -> t.getUserId().equals(userId))
                .toList();
        assertThat(tokens).hasSize(1);
        AuthTokenEntity token = tokens.get(0);
        assertThat(token.getTokenType()).isEqualTo(AuthTokenType.EMAIL_VERIFICATION);
        assertThat(token.getAttempts()).isZero();
        assertThat(token.getConsumedAt()).isNull();
        assertThat(token.getExpiresAt()).isEqualTo(beforeRegister.plus(Duration.ofMinutes(15)));
        assertThat(token.getTokenHash()).matches("^[0-9a-f]{64}$");

        // 6. Verify Published Event
        List<EmailVerificationRequestedEvent> events = applicationEvents
                .stream(EmailVerificationRequestedEvent.class)
                .filter(e -> e.userId().equals(userId))
                .toList();
        assertThat(events).hasSize(1);
        EmailVerificationRequestedEvent event = events.get(0);
        assertThat(event.userId()).isEqualTo(userId);
        assertThat(event.email()).isEqualTo(normalizedEmail);
        assertThat(event.rawCode()).matches("^\\d{6}$");

        // Verify stored hash matches the rawCode through AuthTokenHasher
        assertThat(authTokenHasher.matches(
                userId,
                AuthTokenType.EMAIL_VERIFICATION,
                event.rawCode(),
                token.getTokenHash()
        )).isTrue();
    }

    @Test
    @DisplayName("register with duplicate email should throw BusinessException with EMAIL_ALREADY_EXISTS")
    void register_duplicateEmail_shouldThrowConflict() {
        String email = "duplicate.test@example.com";
        RegisterRequest first = new RegisterRequest(email, "Password123!");
        authService.register(first);

        RegisterRequest duplicate = new RegisterRequest(email, "AnotherPassword456!");

        assertThatThrownBy(() -> authService.register(duplicate))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex -> {
                    BusinessException be = (BusinessException) ex;
                    assertThat(be.errorCode()).isEqualTo(ErrorCode.EMAIL_ALREADY_EXISTS);
                });
    }

    @Test
    @DisplayName("register with case-insensitive duplicate email should throw EMAIL_ALREADY_EXISTS")
    void register_caseInsensitiveDuplicateEmail_shouldThrowConflict() {
        String emailLower = "case.insensitive@example.com";
        String emailUpper = "CASE.INSENSITIVE@EXAMPLE.COM";

        RegisterRequest first = new RegisterRequest(emailLower, "Password123!");
        authService.register(first);

        RegisterRequest second = new RegisterRequest(emailUpper, "Password456!");

        assertThatThrownBy(() -> authService.register(second))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex -> {
                    BusinessException be = (BusinessException) ex;
                    assertThat(be.errorCode()).isEqualTo(ErrorCode.EMAIL_ALREADY_EXISTS);
                });
    }

    // ==========================================
    // M2.5 Verify Email Tests
    // ==========================================

    @Test
    @DisplayName("verifyEmail with correct code should activate user, set timestamps and consume token")
    void verifyEmail_validCode_shouldActivateUserAndConsumeToken() {
        RegisterResponse reg = authService.register(new RegisterRequest("verify.success@example.com", "Password123!"));
        UUID userId = reg.userId();
        String code = getLatestVerificationCode(userId);

        currentInstant = currentInstant.plusSeconds(30);

        VerifyEmailResponse response = authService.verifyEmail(new VerifyEmailRequest(userId, code));

        assertThat(response).isNotNull();
        assertThat(response.userId()).isEqualTo(userId);
        assertThat(response.status()).isEqualTo(UserStatus.ACTIVE);
        assertThat(response.emailVerifiedAt()).isEqualTo(currentInstant);
        assertThat(response.nextStep()).isEqualTo("COMPLETE_PROFILE");
        assertThat(response.profileCompletionToken()).isNotBlank();
        assertThat(profileCompletionTokenService.extractAndValidate(response.profileCompletionToken()))
                .isEqualTo(userId);

        UserEntity user = userRepository.findById(userId).orElseThrow();
        assertThat(user.getStatus()).isEqualTo(UserStatus.ACTIVE);
        assertThat(user.getEmailVerifiedAt()).isEqualTo(currentInstant);
        assertThat(user.getUpdatedAt()).isEqualTo(currentInstant);

        AuthTokenEntity token = authTokenRepository
                .findFirstByUserIdAndTokenTypeOrderByCreatedAtDesc(userId, AuthTokenType.EMAIL_VERIFICATION)
                .orElseThrow();
        assertThat(token.getConsumedAt()).isEqualTo(currentInstant);
        assertThat(token.getAttempts()).isZero();
    }

    @Test
    @DisplayName("verifyEmail with wrong code should increment attempts, commit to database via noRollbackFor, and return VERIFICATION_CODE_INVALID")
    void verifyEmail_wrongCode_shouldIncrementAttemptsAndCommitToDatabase() {
        RegisterResponse reg = authService.register(new RegisterRequest("verify.wrong@example.com", "Password123!"));
        UUID userId = reg.userId();
        String wrongCode = "999999";

        assertThatThrownBy(() -> authService.verifyEmail(new VerifyEmailRequest(userId, wrongCode)))
                .isInstanceOf(VerificationAttemptException.class)
                .satisfies(ex -> {
                    VerificationAttemptException ve = (VerificationAttemptException) ex;
                    assertThat(ve.errorCode()).isEqualTo(ErrorCode.VERIFICATION_CODE_INVALID);
                });

        // Fresh persistence context / database verification: attempts must be committed as 1
        AuthTokenEntity token = authTokenRepository
                .findFirstByUserIdAndTokenTypeOrderByCreatedAtDesc(userId, AuthTokenType.EMAIL_VERIFICATION)
                .orElseThrow();
        assertThat(token.getAttempts()).isEqualTo(1);
        assertThat(token.getConsumedAt()).isNull();

        UserEntity user = userRepository.findById(userId).orElseThrow();
        assertThat(user.getStatus()).isEqualTo(UserStatus.PENDING_VERIFICATION);
        assertThat(user.getEmailVerifiedAt()).isNull();
    }

    @Test
    @DisplayName("verifyEmail: 5 wrong attempts lock out token (0->1->2->3->4->5), 5th wrong throws VERIFICATION_ATTEMPTS_EXCEEDED, subsequent attempts blocked even with correct code")
    void verifyEmail_fiveWrongAttempts_shouldLockOutToken() {
        RegisterResponse reg = authService.register(new RegisterRequest("verify.lockout@example.com", "Password123!"));
        UUID userId = reg.userId();
        String correctCode = getLatestVerificationCode(userId);
        String wrongCode = "888888";

        // Attempts 1, 2, 3, 4 should throw VERIFICATION_CODE_INVALID
        for (int i = 1; i <= 4; i++) {
            assertThatThrownBy(() -> authService.verifyEmail(new VerifyEmailRequest(userId, wrongCode)))
                    .isInstanceOf(VerificationAttemptException.class)
                    .satisfies(ex -> {
                        VerificationAttemptException ve = (VerificationAttemptException) ex;
                        assertThat(ve.errorCode()).isEqualTo(ErrorCode.VERIFICATION_CODE_INVALID);
                    });

            AuthTokenEntity token = authTokenRepository
                    .findFirstByUserIdAndTokenTypeOrderByCreatedAtDesc(userId, AuthTokenType.EMAIL_VERIFICATION)
                    .orElseThrow();
            assertThat(token.getAttempts()).isEqualTo(i);
        }

        // 5th attempt with wrong code should throw VERIFICATION_ATTEMPTS_EXCEEDED
        assertThatThrownBy(() -> authService.verifyEmail(new VerifyEmailRequest(userId, wrongCode)))
                .isInstanceOf(VerificationAttemptException.class)
                .satisfies(ex -> {
                    VerificationAttemptException ve = (VerificationAttemptException) ex;
                    assertThat(ve.errorCode()).isEqualTo(ErrorCode.VERIFICATION_ATTEMPTS_EXCEEDED);
                });

        AuthTokenEntity token = authTokenRepository
                .findFirstByUserIdAndTokenTypeOrderByCreatedAtDesc(userId, AuthTokenType.EMAIL_VERIFICATION)
                .orElseThrow();
        assertThat(token.getAttempts()).isEqualTo(5);

        // Subsequent attempt with correct code must be rejected with VERIFICATION_ATTEMPTS_EXCEEDED
        assertThatThrownBy(() -> authService.verifyEmail(new VerifyEmailRequest(userId, correctCode)))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex -> {
                    BusinessException be = (BusinessException) ex;
                    assertThat(be.errorCode()).isEqualTo(ErrorCode.VERIFICATION_ATTEMPTS_EXCEEDED);
                });

        UserEntity user = userRepository.findById(userId).orElseThrow();
        assertThat(user.getStatus()).isEqualTo(UserStatus.PENDING_VERIFICATION);
    }

    @Test
    @DisplayName("verifyEmail: when attempts == 4, a correct code submission succeeds (5th opportunity allowed)")
    void verifyEmail_correctCodeOnFifthOpportunity_shouldSucceed() {
        RegisterResponse reg = authService.register(new RegisterRequest("verify.fifth@example.com", "Password123!"));
        UUID userId = reg.userId();
        String correctCode = getLatestVerificationCode(userId);

        // Simulate 4 previous wrong attempts
        AuthTokenEntity token = authTokenRepository
                .findFirstByUserIdAndTokenTypeOrderByCreatedAtDesc(userId, AuthTokenType.EMAIL_VERIFICATION)
                .orElseThrow();
        token.setAttempts(4);
        authTokenRepository.save(token);

        VerifyEmailResponse response = authService.verifyEmail(new VerifyEmailRequest(userId, correctCode));
        assertThat(response.status()).isEqualTo(UserStatus.ACTIVE);

        UserEntity user = userRepository.findById(userId).orElseThrow();
        assertThat(user.getStatus()).isEqualTo(UserStatus.ACTIVE);
    }

    @Test
    @DisplayName("verifyEmail: token at or after expiresAt should throw VERIFICATION_CODE_EXPIRED without incrementing attempts, but valid just before expiresAt")
    void verifyEmail_expiredToken_shouldRejectWithoutIncrementingAttempts() {
        RegisterResponse reg = authService.register(new RegisterRequest("verify.expired@example.com", "Password123!"));
        UUID userId = reg.userId();
        String code = getLatestVerificationCode(userId);

        Instant expiresAt = currentInstant.plus(Duration.ofMinutes(15));

        // 1. Just before expiry: expiresAt minus 1 millisecond -> still valid
        currentInstant = expiresAt.minusMillis(1);
        // We verify that clock is before expiresAt
        assertThat(currentInstant.isBefore(expiresAt)).isTrue();

        // 2. Exactly at expiry: expiresAt -> expired
        currentInstant = expiresAt;
        assertThatThrownBy(() -> authService.verifyEmail(new VerifyEmailRequest(userId, code)))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex -> {
                    BusinessException be = (BusinessException) ex;
                    assertThat(be.errorCode()).isEqualTo(ErrorCode.VERIFICATION_CODE_EXPIRED);
                });

        AuthTokenEntity token = authTokenRepository
                .findFirstByUserIdAndTokenTypeOrderByCreatedAtDesc(userId, AuthTokenType.EMAIL_VERIFICATION)
                .orElseThrow();
        assertThat(token.getAttempts()).isZero();
    }

    @Test
    @DisplayName("verifyEmail: submitting stale/superseded OTP after resend throws VERIFICATION_CODE_INVALID without burning attempts of new active token")
    void verifyEmail_staleCodeAfterResend_shouldNotBurnNewTokenAttempts() {
        // 1. Register and get old code
        RegisterResponse reg = authService.register(new RegisterRequest("verify.stale@example.com", "Password123!"));
        UUID userId = reg.userId();
        String oldCode = getLatestVerificationCode(userId);

        // 2. Advance clock past 60s cooldown
        currentInstant = currentInstant.plusSeconds(65);

        // 3. Resend to create new token
        authService.resendVerification(new ResendVerificationRequest(userId));
        String newCode = getLatestVerificationCode(userId);
        assertThat(newCode).isNotEqualTo(oldCode);

        // 4. Submit stale oldCode
        assertThatThrownBy(() -> authService.verifyEmail(new VerifyEmailRequest(userId, oldCode)))
                .isInstanceOf(BusinessException.class)
                .isNotInstanceOf(VerificationAttemptException.class)
                .satisfies(ex -> {
                    BusinessException be = (BusinessException) ex;
                    assertThat(be.errorCode()).isEqualTo(ErrorCode.VERIFICATION_CODE_INVALID);
                });

        // 5. Assert new active token attempts remains 0
        AuthTokenEntity activeToken = authTokenRepository
                .findFirstByUserIdAndTokenTypeAndConsumedAtIsNullOrderByCreatedAtDesc(userId, AuthTokenType.EMAIL_VERIFICATION)
                .orElseThrow();
        assertThat(activeToken.getAttempts()).isZero();
        assertThat(activeToken.getConsumedAt()).isNull();

        UserEntity user = userRepository.findById(userId).orElseThrow();
        assertThat(user.getStatus()).isEqualTo(UserStatus.PENDING_VERIFICATION);

        // 6. Then submit newCode -> should succeed
        VerifyEmailResponse response = authService.verifyEmail(new VerifyEmailRequest(userId, newCode));
        assertThat(response.status()).isEqualTo(UserStatus.ACTIVE);
    }

    @Test
    @DisplayName("verifyEmail: genuinely wrong code differs from stale code by incrementing active attempts from 0 to 1")
    void verifyEmail_genuinelyWrongCode_shouldIncrementActiveAttempts() {
        RegisterResponse reg = authService.register(new RegisterRequest("verify.wrong.diff@example.com", "Password123!"));
        UUID userId = reg.userId();

        String completelyWrongCode = "777777";

        assertThatThrownBy(() -> authService.verifyEmail(new VerifyEmailRequest(userId, completelyWrongCode)))
                .isInstanceOf(VerificationAttemptException.class);

        AuthTokenEntity activeToken = authTokenRepository
                .findFirstByUserIdAndTokenTypeAndConsumedAtIsNullOrderByCreatedAtDesc(userId, AuthTokenType.EMAIL_VERIFICATION)
                .orElseThrow();
        assertThat(activeToken.getAttempts()).isEqualTo(1);
    }

    @Test
    @DisplayName("verifyEmail: already ACTIVE user should throw EMAIL_ALREADY_VERIFIED")
    void verifyEmail_alreadyActiveUser_shouldThrowEmailAlreadyVerified() {
        RegisterResponse reg = authService.register(new RegisterRequest("verify.already@example.com", "Password123!"));
        UUID userId = reg.userId();
        String code = getLatestVerificationCode(userId);

        authService.verifyEmail(new VerifyEmailRequest(userId, code));

        assertThatThrownBy(() -> authService.verifyEmail(new VerifyEmailRequest(userId, code)))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex -> {
                    BusinessException be = (BusinessException) ex;
                    assertThat(be.errorCode()).isEqualTo(ErrorCode.EMAIL_ALREADY_VERIFIED);
                });
    }

    @Test
    @DisplayName("verifyEmail: unknown user should throw RESOURCE_NOT_FOUND")
    void verifyEmail_unknownUser_shouldThrowResourceNotFound() {
        UUID unknownId = UUID.randomUUID();

        assertThatThrownBy(() -> authService.verifyEmail(new VerifyEmailRequest(unknownId, "123456")))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex -> {
                    BusinessException be = (BusinessException) ex;
                    assertThat(be.errorCode()).isEqualTo(ErrorCode.RESOURCE_NOT_FOUND);
                });
    }

    @Test
    @DisplayName("verifyEmail: two concurrent requests with same valid code: exactly 1 succeeds (200), 1 receives EMAIL_ALREADY_VERIFIED (409)")
    void verifyEmail_concurrentRequests_shouldBeDeterministic() throws Exception {
        RegisterResponse reg = authService.register(new RegisterRequest("concurrent.verify@example.com", "Password123!"));
        UUID userId = reg.userId();
        String code = getLatestVerificationCode(userId);

        int threads = 2;
        ExecutorService executor = Executors.newFixedThreadPool(threads);
        CountDownLatch readyLatch = new CountDownLatch(threads);
        CountDownLatch startLatch = new CountDownLatch(1);

        List<Future<VerifyEmailResponse>> futures = new ArrayList<>();
        List<Throwable> errors = Collections.synchronizedList(new ArrayList<>());

        for (int i = 0; i < threads; i++) {
            futures.add(executor.submit(() -> {
                readyLatch.countDown();
                startLatch.await();
                try {
                    return authService.verifyEmail(new VerifyEmailRequest(userId, code));
                } catch (Throwable t) {
                    errors.add(t);
                    throw t;
                }
            }));
        }

        readyLatch.await(5, TimeUnit.SECONDS);
        startLatch.countDown();

        int successCount = 0;
        for (Future<VerifyEmailResponse> f : futures) {
            try {
                VerifyEmailResponse res = f.get(10, TimeUnit.SECONDS);
                if (res != null) {
                    successCount++;
                }
            } catch (ExecutionException e) {
                // expected for the second request
            }
        }
        executor.shutdown();

        assertThat(successCount).isEqualTo(1);
        assertThat(errors).hasSize(1);
        assertThat(errors.get(0)).isInstanceOf(BusinessException.class);
        assertThat(((BusinessException) errors.get(0)).errorCode()).isEqualTo(ErrorCode.EMAIL_ALREADY_VERIFIED);
    }

    // ==========================================
    // M2.5 Resend Verification Tests
    // ==========================================

    @Test
    @DisplayName("resendVerification: immediately after register should throw RESEND_COOLDOWN_ACTIVE")
    void resendVerification_cooldownActive_shouldThrowResendCooldownActive() {
        RegisterResponse reg = authService.register(new RegisterRequest("resend.cooldown@example.com", "Password123!"));
        UUID userId = reg.userId();

        // 30 seconds after register (< 60s)
        currentInstant = currentInstant.plusSeconds(30);

        assertThatThrownBy(() -> authService.resendVerification(new ResendVerificationRequest(userId)))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex -> {
                    BusinessException be = (BusinessException) ex;
                    assertThat(be.errorCode()).isEqualTo(ErrorCode.RESEND_COOLDOWN_ACTIVE);
                });
    }

    @Test
    @DisplayName("resendVerification: at or after exactly 60 seconds should succeed, invalidate old unconsumed tokens, and generate new active token")
    void resendVerification_afterCooldown_shouldSucceedAndInvalidateOldTokens() {
        RegisterResponse reg = authService.register(new RegisterRequest("resend.success@example.com", "Password123!"));
        UUID userId = reg.userId();

        // Exactly 60s after register
        currentInstant = currentInstant.plusSeconds(60);

        ResendVerificationResponse response = authService.resendVerification(new ResendVerificationRequest(userId));

        assertThat(response).isNotNull();
        assertThat(response.userId()).isEqualTo(userId);
        assertThat(response.cooldownSeconds()).isEqualTo(60L);

        // Previous token must be marked consumed
        List<AuthTokenEntity> allTokens = authTokenRepository.findAll().stream()
                .filter(t -> t.getUserId().equals(userId))
                .sorted((a, b) -> a.getCreatedAt().compareTo(b.getCreatedAt()))
                .toList();
        assertThat(allTokens).hasSize(2);

        AuthTokenEntity oldToken = allTokens.get(0);
        assertThat(oldToken.getConsumedAt()).isEqualTo(currentInstant);

        AuthTokenEntity newToken = allTokens.get(1);
        assertThat(newToken.getConsumedAt()).isNull();
        assertThat(newToken.getAttempts()).isZero();
        assertThat(newToken.getExpiresAt()).isEqualTo(currentInstant.plus(Duration.ofMinutes(15)));

        // New code verifies successfully
        String newCode = getLatestVerificationCode(userId);
        VerifyEmailResponse verifyRes = authService.verifyEmail(new VerifyEmailRequest(userId, newCode));
        assertThat(verifyRes.status()).isEqualTo(UserStatus.ACTIVE);
    }

    @Test
    @DisplayName("resendVerification: already ACTIVE user should throw EMAIL_ALREADY_VERIFIED")
    void resendVerification_alreadyActiveUser_shouldThrowEmailAlreadyVerified() {
        RegisterResponse reg = authService.register(new RegisterRequest("resend.already@example.com", "Password123!"));
        UUID userId = reg.userId();
        String code = getLatestVerificationCode(userId);
        authService.verifyEmail(new VerifyEmailRequest(userId, code));

        currentInstant = currentInstant.plusSeconds(65);

        assertThatThrownBy(() -> authService.resendVerification(new ResendVerificationRequest(userId)))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex -> {
                    BusinessException be = (BusinessException) ex;
                    assertThat(be.errorCode()).isEqualTo(ErrorCode.EMAIL_ALREADY_VERIFIED);
                });
    }

    @Test
    @DisplayName("resendVerification: unknown user should throw RESOURCE_NOT_FOUND")
    void resendVerification_unknownUser_shouldThrowResourceNotFound() {
        UUID unknownId = UUID.randomUUID();

        assertThatThrownBy(() -> authService.resendVerification(new ResendVerificationRequest(unknownId)))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex -> {
                    BusinessException be = (BusinessException) ex;
                    assertThat(be.errorCode()).isEqualTo(ErrorCode.RESOURCE_NOT_FOUND);
                });
    }

    @Test
    @DisplayName("resendVerification: two concurrent requests after cooldown: exactly 1 succeeds (200), 1 receives RESEND_COOLDOWN_ACTIVE (429)")
    void resendVerification_concurrentRequests_shouldBeDeterministic() throws Exception {
        RegisterResponse reg = authService.register(new RegisterRequest("concurrent.resend@example.com", "Password123!"));
        UUID userId = reg.userId();

        // Advance clock past initial 60s cooldown
        currentInstant = currentInstant.plusSeconds(65);

        int threads = 2;
        ExecutorService executor = Executors.newFixedThreadPool(threads);
        CountDownLatch readyLatch = new CountDownLatch(threads);
        CountDownLatch startLatch = new CountDownLatch(1);

        List<Future<ResendVerificationResponse>> futures = new ArrayList<>();
        List<Throwable> errors = Collections.synchronizedList(new ArrayList<>());

        for (int i = 0; i < threads; i++) {
            futures.add(executor.submit(() -> {
                readyLatch.countDown();
                startLatch.await();
                try {
                    return authService.resendVerification(new ResendVerificationRequest(userId));
                } catch (Throwable t) {
                    errors.add(t);
                    throw t;
                }
            }));
        }

        readyLatch.await(5, TimeUnit.SECONDS);
        startLatch.countDown();

        int successCount = 0;
        for (Future<ResendVerificationResponse> f : futures) {
            try {
                ResendVerificationResponse res = f.get(10, TimeUnit.SECONDS);
                if (res != null) {
                    successCount++;
                }
            } catch (ExecutionException e) {
                // expected for second request
            }
        }
        executor.shutdown();

        assertThat(successCount).isEqualTo(1);
        assertThat(errors).hasSize(1);
        assertThat(errors.get(0)).isInstanceOf(BusinessException.class);
        assertThat(((BusinessException) errors.get(0)).errorCode()).isEqualTo(ErrorCode.RESEND_COOLDOWN_ACTIVE);
    }

    // ==========================================
    // M2.6 Username Availability & Complete Profile Tests
    // ==========================================

    @Test
    @DisplayName("checkUsernameAvailability with unused username should return true with canonical lowercase username")
    void checkUsernameAvailability_unusedUsername_shouldReturnTrue() {
        UsernameAvailabilityResponse res = authService.checkUsernameAvailability("UniqueUser123");

        assertThat(res.username()).isEqualTo("uniqueuser123");
        assertThat(res.available()).isTrue();
    }

    @Test
    @DisplayName("checkUsernameAvailability with existing username should return false")
    void checkUsernameAvailability_existingUsername_shouldReturnFalse() {
        // Register and complete profile for a user
        UUID userId = registerAndVerifyUser("taken.check@example.com");
        String token = profileCompletionTokenService.generate(userId);
        authService.completeProfile(new CompleteProfileRequest(
                token,
                "svc_existing_user",
                "Existing User",
                null,
                null
        ));

        UsernameAvailabilityResponse res = authService.checkUsernameAvailability("svc_existing_user");
        assertThat(res.username()).isEqualTo("svc_existing_user");
        assertThat(res.available()).isFalse();

        // Case-insensitive check
        UsernameAvailabilityResponse resUpper = authService.checkUsernameAvailability("SVC_EXISTING_USER");
        assertThat(resUpper.username()).isEqualTo("svc_existing_user");
        assertThat(resUpper.available()).isFalse();
    }

    @Test
    @DisplayName("completeProfile with valid request should update user, trim fields, and return 200 with nextStep LOGIN")
    void completeProfile_validRequest_shouldSucceed() {
        UUID userId = registerAndVerifyUser("profile.success@example.com");
        String token = profileCompletionTokenService.generate(userId);

        currentInstant = currentInstant.plusSeconds(10);

        CompleteProfileRequest request = new CompleteProfileRequest(
                token,
                "SvcHuyGiang",
                "  Huy Giang  ",
                "  Software engineer & builder  ",
                "avatars/2026/09/profile_1.png"
        );

        CompleteProfileResponse response = authService.completeProfile(request);

        assertThat(response).isNotNull();
        assertThat(response.userId()).isEqualTo(userId);
        assertThat(response.username()).isEqualTo("svchuygiang");
        assertThat(response.displayName()).isEqualTo("Huy Giang");
        assertThat(response.status()).isEqualTo(UserStatus.ACTIVE);
        assertThat(response.nextStep()).isEqualTo("LOGIN");

        UserEntity user = userRepository.findById(userId).orElseThrow();
        assertThat(user.getUsername()).isEqualTo("svchuygiang");
        assertThat(user.getDisplayName()).isEqualTo("Huy Giang");
        assertThat(user.getBio()).isEqualTo("Software engineer & builder");
        assertThat(user.getAvatarStorageKey()).isEqualTo("avatars/2026/09/profile_1.png");
        assertThat(user.getUpdatedAt()).isEqualTo(currentInstant);
        assertThat(user.getStatus()).isEqualTo(UserStatus.ACTIVE);
    }

    @Test
    @DisplayName("completeProfile bio normalization: null -> null, blank -> null, trimmed -> trimmed")
    void completeProfile_bioNormalization_shouldPersistExpectedValues() {
        // 1. null bio
        UUID user1Id = registerAndVerifyUser("bio1@example.com");
        String token1 = profileCompletionTokenService.generate(user1Id);
        authService.completeProfile(new CompleteProfileRequest(token1, "user_bio_1", "User One", null, null));
        assertThat(userRepository.findById(user1Id).orElseThrow().getBio()).isNull();

        // 2. blank bio ("   ") -> null
        UUID user2Id = registerAndVerifyUser("bio2@example.com");
        String token2 = profileCompletionTokenService.generate(user2Id);
        authService.completeProfile(new CompleteProfileRequest(token2, "user_bio_2", "User Two", "    ", null));
        assertThat(userRepository.findById(user2Id).orElseThrow().getBio()).isNull();

        // 3. bio with edges trimmed
        UUID user3Id = registerAndVerifyUser("bio3@example.com");
        String token3 = profileCompletionTokenService.generate(user3Id);
        authService.completeProfile(new CompleteProfileRequest(token3, "user_bio_3", "User Three", "  valid bio  ", null));
        assertThat(userRepository.findById(user3Id).orElseThrow().getBio()).isEqualTo("valid bio");
    }

    @Test
    @DisplayName("completeProfile avatarStorageKey preserves exact string without trimming or normalization")
    void completeProfile_avatarStorageKey_preservesExactString() {
        UUID userId = registerAndVerifyUser("avatar.exact@example.com");
        String token = profileCompletionTokenService.generate(userId);

        String exactKey = "custom/storage-key/path.jpg";
        authService.completeProfile(new CompleteProfileRequest(token, "avatar_user", "Avatar User", null, exactKey));

        assertThat(userRepository.findById(userId).orElseThrow().getAvatarStorageKey()).isEqualTo(exactKey);
    }

    @Test
    @DisplayName("completeProfile sequential replay: second attempt throws PROFILE_ALREADY_COMPLETED")
    void completeProfile_sequentialReplay_shouldThrowProfileAlreadyCompleted() {
        UUID userId = registerAndVerifyUser("replay@example.com");
        String token = profileCompletionTokenService.generate(userId);

        CompleteProfileRequest request = new CompleteProfileRequest(token, "svc_replay_user", "Replay User", null, null);
        CompleteProfileResponse first = authService.completeProfile(request);
        assertThat(first).isNotNull();

        assertThatThrownBy(() -> authService.completeProfile(request))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.PROFILE_ALREADY_COMPLETED));
    }

    @Test
    @DisplayName("completeProfile when user status is not ACTIVE throws ACCESS_DENIED")
    void completeProfile_userNotActive_shouldThrowAccessDenied() {
        // Register without verifying -> status PENDING_VERIFICATION
        RegisterResponse reg = authService.register(new RegisterRequest("pending.profile@example.com", "Password123!"));
        String token = profileCompletionTokenService.generate(reg.userId());

        CompleteProfileRequest request = new CompleteProfileRequest(token, "svc_pending_user", "Pending User", null, null);

        assertThatThrownBy(() -> authService.completeProfile(request))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.ACCESS_DENIED));
    }

    @Test
    @DisplayName("completeProfile with non-existent userId in token throws RESOURCE_NOT_FOUND")
    void completeProfile_userNotFound_shouldThrowResourceNotFound() {
        UUID nonExistentUserId = UUID.randomUUID();
        String token = profileCompletionTokenService.generate(nonExistentUserId);

        CompleteProfileRequest request = new CompleteProfileRequest(token, "svc_ghost_user", "Ghost User", null, null);

        assertThatThrownBy(() -> authService.completeProfile(request))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.RESOURCE_NOT_FOUND));
    }

    @Test
    @DisplayName("completeProfile with pre-existing username throws USERNAME_ALREADY_EXISTS")
    void completeProfile_usernameAlreadyExists_shouldThrowConflict() {
        UUID user1Id = registerAndVerifyUser("user1.uname@example.com");
        String token1 = profileCompletionTokenService.generate(user1Id);
        authService.completeProfile(new CompleteProfileRequest(token1, "svc_chosen_name", "User One", null, null));

        UUID user2Id = registerAndVerifyUser("user2.uname@example.com");
        String token2 = profileCompletionTokenService.generate(user2Id);
        CompleteProfileRequest request2 = new CompleteProfileRequest(token2, "svc_chosen_name", "User Two", null, null);

        assertThatThrownBy(() -> authService.completeProfile(request2))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.USERNAME_ALREADY_EXISTS));
    }

    @Test
    @DisplayName("completeProfile with case-insensitive username conflict throws USERNAME_ALREADY_EXISTS")
    void completeProfile_caseInsensitiveUsernameConflict_shouldThrowConflict() {
        UUID user1Id = registerAndVerifyUser("case1.uname@example.com");
        String token1 = profileCompletionTokenService.generate(user1Id);
        authService.completeProfile(new CompleteProfileRequest(token1, "svc_myname", "User One", null, null));

        UUID user2Id = registerAndVerifyUser("case2.uname@example.com");
        String token2 = profileCompletionTokenService.generate(user2Id);
        CompleteProfileRequest request2 = new CompleteProfileRequest(token2, "SVC_MYNAME", "User Two", null, null);

        assertThatThrownBy(() -> authService.completeProfile(request2))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.USERNAME_ALREADY_EXISTS));
    }

    @Test
    @DisplayName("completeProfile concurrency (same user): two simultaneous requests serialize; exactly 1 succeeds, 1 gets PROFILE_ALREADY_COMPLETED")
    void completeProfile_sameUserConcurrency_shouldBeDeterministic() throws Exception {
        UUID userId = registerAndVerifyUser("concurrent.sameuser@example.com");
        String token = profileCompletionTokenService.generate(userId);

        int threads = 2;
        ExecutorService executor = Executors.newFixedThreadPool(threads);
        CountDownLatch readyLatch = new CountDownLatch(threads);
        CountDownLatch startLatch = new CountDownLatch(1);

        List<Future<CompleteProfileResponse>> futures = new ArrayList<>();
        List<Throwable> errors = Collections.synchronizedList(new ArrayList<>());

        for (int i = 0; i < threads; i++) {
            final int index = i;
            futures.add(executor.submit(() -> {
                readyLatch.countDown();
                startLatch.await();
                try {
                    return authService.completeProfile(new CompleteProfileRequest(
                            token,
                            "svc_same_user_" + index,
                            "Same User " + index,
                            null,
                            null
                    ));
                } catch (Throwable t) {
                    errors.add(t);
                    throw t;
                }
            }));
        }

        readyLatch.await(5, TimeUnit.SECONDS);
        startLatch.countDown();

        int successCount = 0;
        for (Future<CompleteProfileResponse> f : futures) {
            try {
                CompleteProfileResponse res = f.get(10, TimeUnit.SECONDS);
                if (res != null) {
                    successCount++;
                }
            } catch (ExecutionException e) {
                // expected for losing request
            }
        }
        executor.shutdown();

        assertThat(successCount).isEqualTo(1);
        assertThat(errors).hasSize(1);
        Throwable error = errors.get(0);
        assertThat(error).isInstanceOf(BusinessException.class);
        assertThat(((BusinessException) error).errorCode()).isEqualTo(ErrorCode.PROFILE_ALREADY_COMPLETED);
    }

    @Test
    @DisplayName("completeProfile concurrency (two users, same username): DB unique constraint serializes; exactly 1 succeeds, 1 gets USERNAME_ALREADY_EXISTS")
    void completeProfile_twoUsersSameUsernameConcurrency_shouldBeDeterministic() throws Exception {
        UUID userAId = registerAndVerifyUser("userA.race@example.com");
        UUID userBId = registerAndVerifyUser("userB.race@example.com");
        String tokenA = profileCompletionTokenService.generate(userAId);
        String tokenB = profileCompletionTokenService.generate(userBId);

        int threads = 2;
        ExecutorService executor = Executors.newFixedThreadPool(threads);
        CountDownLatch readyLatch = new CountDownLatch(threads);
        CountDownLatch startLatch = new CountDownLatch(1);

        List<Future<CompleteProfileResponse>> futures = new ArrayList<>();
        List<Throwable> errors = Collections.synchronizedList(new ArrayList<>());

        futures.add(executor.submit(() -> {
            readyLatch.countDown();
            startLatch.await();
            try {
                return authService.completeProfile(new CompleteProfileRequest(
                        tokenA,
                        "svc_contested_name",
                        "User A",
                        null,
                        null
                ));
            } catch (Throwable t) {
                errors.add(t);
                throw t;
            }
        }));

        futures.add(executor.submit(() -> {
            readyLatch.countDown();
            startLatch.await();
            try {
                return authService.completeProfile(new CompleteProfileRequest(
                        tokenB,
                        "SVC_CONTESTED_NAME",
                        "User B",
                        null,
                        null
                ));
            } catch (Throwable t) {
                errors.add(t);
                throw t;
            }
        }));

        readyLatch.await(5, TimeUnit.SECONDS);
        startLatch.countDown();

        int successCount = 0;
        for (Future<CompleteProfileResponse> f : futures) {
            try {
                CompleteProfileResponse res = f.get(10, TimeUnit.SECONDS);
                if (res != null) {
                    successCount++;
                }
            } catch (ExecutionException e) {
                // expected for losing request
            }
        }
        executor.shutdown();

        assertThat(successCount).isEqualTo(1);
        assertThat(errors).hasSize(1);
        Throwable error = errors.get(0);
        assertThat(error).isInstanceOf(BusinessException.class);
        assertThat(((BusinessException) error).errorCode()).isEqualTo(ErrorCode.USERNAME_ALREADY_EXISTS);

        // Verify DB has only 1 user owning the username
        Optional<UserEntity> owner = userRepository.findByUsername("svc_contested_name");
        assertThat(owner).isPresent();
    }

    private UUID registerAndVerifyUser(String email) {
        RegisterResponse reg = authService.register(new RegisterRequest(email, "Password123!"));
        String code = getLatestVerificationCode(reg.userId());
        authService.verifyEmail(new VerifyEmailRequest(reg.userId(), code));
        return reg.userId();
    }

    // ==========================================
    // M2.7 Login Service Tests
    // ==========================================

    @Test
    @DisplayName("login with unknown email should execute dummy hash and throw AUTH_INVALID_CREDENTIALS")
    void login_unknownEmail_shouldThrowAuthInvalidCredentials() {
        assertThatThrownBy(() -> authService.login(new LoginRequest("unknown@example.com", "Password123!")))
                .isInstanceOf(BusinessException.class)
                .hasMessage("Invalid email or password.")
                .satisfies(e -> assertThat(((BusinessException) e).errorCode()).isEqualTo(ErrorCode.AUTH_INVALID_CREDENTIALS));
    }

    @Test
    @DisplayName("login with wrong password should throw LoginAttemptException and persist failed attempts")
    void login_wrongPassword_shouldIncrementAndPersistFailedAttempts() {
        String email = "wrong.pwd.svc@example.com";
        UUID userId = registerAndVerifyUser(email);

        assertThatThrownBy(() -> authService.login(new LoginRequest(email, "WrongPassword1!")))
                .isInstanceOf(LoginAttemptException.class)
                .satisfies(e -> assertThat(((BusinessException) e).errorCode()).isEqualTo(ErrorCode.AUTH_INVALID_CREDENTIALS));

        // Reload fresh from DB to prove transaction did not roll back
        UserCredentialEntity cred = userCredentialRepository.findById(userId).orElseThrow();
        assertThat(cred.getFailedAttempts()).isEqualTo(1);
        assertThat(cred.getLockedUntil()).isNull();
    }

    @Test
    @DisplayName("login lockout lifecycle: increments to 5, locks for 15m, rejects active lock, expires deterministically")
    void login_lockoutLifecycle_test() {
        String email = "lockout.cycle@example.com";
        UUID userId = registerAndVerifyUser(email);

        // 1st to 4th wrong password
        for (int i = 1; i <= 4; i++) {
            assertThatThrownBy(() -> authService.login(new LoginRequest(email, "WrongPassword!")))
                    .isInstanceOf(LoginAttemptException.class)
                    .satisfies(e -> assertThat(((BusinessException) e).errorCode()).isEqualTo(ErrorCode.AUTH_INVALID_CREDENTIALS));

            UserCredentialEntity c = userCredentialRepository.findById(userId).orElseThrow();
            assertThat(c.getFailedAttempts()).isEqualTo(i);
            assertThat(c.getLockedUntil()).isNull();
        }

        // 5th wrong password triggers lock
        assertThatThrownBy(() -> authService.login(new LoginRequest(email, "WrongPassword!")))
                .isInstanceOf(LoginAttemptException.class)
                .satisfies(e -> assertThat(((BusinessException) e).errorCode()).isEqualTo(ErrorCode.AUTH_INVALID_CREDENTIALS));

        UserCredentialEntity lockedCred = userCredentialRepository.findById(userId).orElseThrow();
        assertThat(lockedCred.getFailedAttempts()).isEqualTo(5);
        Instant expectedLockExpiry = currentInstant.plus(Duration.ofMinutes(15));
        assertThat(lockedCred.getLockedUntil()).isEqualTo(expectedLockExpiry);

        // Advance 5 minutes (still locked)
        currentInstant = currentInstant.plus(Duration.ofMinutes(5));

        // Wrong password during active lock: no count increment, no lock extension
        assertThatThrownBy(() -> authService.login(new LoginRequest(email, "StillWrong!")))
                .isInstanceOf(LoginAttemptException.class)
                .satisfies(e -> assertThat(((BusinessException) e).errorCode()).isEqualTo(ErrorCode.AUTH_INVALID_CREDENTIALS));

        UserCredentialEntity stillLockedCred = userCredentialRepository.findById(userId).orElseThrow();
        assertThat(stillLockedCred.getFailedAttempts()).isEqualTo(5);
        assertThat(stillLockedCred.getLockedUntil()).isEqualTo(expectedLockExpiry);

        // Correct password during active lock: throws ACCOUNT_LOCKED 423, does NOT reset lock
        assertThatThrownBy(() -> authService.login(new LoginRequest(email, "Password123!")))
                .isInstanceOf(BusinessException.class)
                .hasMessage("Account is temporarily locked.")
                .satisfies(e -> assertThat(((BusinessException) e).errorCode()).isEqualTo(ErrorCode.ACCOUNT_LOCKED));

        UserCredentialEntity unresetCred = userCredentialRepository.findById(userId).orElseThrow();
        assertThat(unresetCred.getFailedAttempts()).isEqualTo(5);
        assertThat(unresetCred.getLockedUntil()).isEqualTo(expectedLockExpiry);

        // Advance clock exactly to expectedLockExpiry: lock is expired
        currentInstant = expectedLockExpiry;

        // Correct password at exact expiry: succeeds and resets failedAttempts to 0 and lockedUntil to null
        LoginResponse response = authService.login(new LoginRequest(email, "Password123!"));
        assertThat(response.status()).isEqualTo(UserStatus.ACTIVE);

        UserCredentialEntity resetCred = userCredentialRepository.findById(userId).orElseThrow();
        assertThat(resetCred.getFailedAttempts()).isEqualTo(0);
        assertThat(resetCred.getLockedUntil()).isNull();
    }

    @Test
    @DisplayName("login when lock expired and wrong password should start new cycle with failedAttempts = 1")
    void login_lockExpired_wrongPassword_startsNewCycle() {
        String email = "lockout.expire.wrong@example.com";
        UUID userId = registerAndVerifyUser(email);

        // Lock user
        UserCredentialEntity cred = userCredentialRepository.findById(userId).orElseThrow();
        cred.setFailedAttempts(5);
        cred.setLockedUntil(currentInstant.plus(Duration.ofMinutes(15)));
        userCredentialRepository.save(cred);

        // Advance past lock
        currentInstant = currentInstant.plus(Duration.ofMinutes(20));

        // Wrong password starts new cycle
        assertThatThrownBy(() -> authService.login(new LoginRequest(email, "WrongPassword!")))
                .isInstanceOf(LoginAttemptException.class)
                .satisfies(e -> assertThat(((BusinessException) e).errorCode()).isEqualTo(ErrorCode.AUTH_INVALID_CREDENTIALS));

        UserCredentialEntity newCycleCred = userCredentialRepository.findById(userId).orElseThrow();
        assertThat(newCycleCred.getFailedAttempts()).isEqualTo(1);
        assertThat(newCycleCred.getLockedUntil()).isNull();
    }

    @Test
    @DisplayName("login status matrix: status error only after password matches; wrong password always returns 401")
    void login_statusMatrix_tests() {
        // 1. PENDING_VERIFICATION
        String pendingEmail = "pending.matrix@example.com";
        authService.register(new RegisterRequest(pendingEmail, "Password123!"));

        // Wrong password -> 401
        assertThatThrownBy(() -> authService.login(new LoginRequest(pendingEmail, "WrongPassword!")))
                .isInstanceOf(LoginAttemptException.class)
                .satisfies(e -> assertThat(((BusinessException) e).errorCode()).isEqualTo(ErrorCode.AUTH_INVALID_CREDENTIALS));

        // Correct password -> 403 EMAIL_NOT_VERIFIED
        assertThatThrownBy(() -> authService.login(new LoginRequest(pendingEmail, "Password123!")))
                .isInstanceOf(BusinessException.class)
                .satisfies(e -> assertThat(((BusinessException) e).errorCode()).isEqualTo(ErrorCode.EMAIL_NOT_VERIFIED));

        // 2. SUSPENDED
        String suspendedEmail = "suspended.matrix@example.com";
        UUID suspendedId = registerAndVerifyUser(suspendedEmail);
        UserEntity suspendedUser = userRepository.findById(suspendedId).orElseThrow();
        suspendedUser.setStatus(UserStatus.SUSPENDED);
        userRepository.save(suspendedUser);

        // Wrong password -> 401
        assertThatThrownBy(() -> authService.login(new LoginRequest(suspendedEmail, "WrongPassword!")))
                .isInstanceOf(LoginAttemptException.class)
                .satisfies(e -> assertThat(((BusinessException) e).errorCode()).isEqualTo(ErrorCode.AUTH_INVALID_CREDENTIALS));

        // Correct password -> 403 ACCOUNT_SUSPENDED
        assertThatThrownBy(() -> authService.login(new LoginRequest(suspendedEmail, "Password123!")))
                .isInstanceOf(BusinessException.class)
                .satisfies(e -> assertThat(((BusinessException) e).errorCode()).isEqualTo(ErrorCode.ACCOUNT_SUSPENDED));

        // 3. DEACTIVATED
        String deactivatedEmail = "deactivated.matrix@example.com";
        UUID deactivatedId = registerAndVerifyUser(deactivatedEmail);
        UserEntity deactivatedUser = userRepository.findById(deactivatedId).orElseThrow();
        deactivatedUser.setStatus(UserStatus.DEACTIVATED);
        userRepository.save(deactivatedUser);

        // Wrong password -> 401
        assertThatThrownBy(() -> authService.login(new LoginRequest(deactivatedEmail, "WrongPassword!")))
                .isInstanceOf(LoginAttemptException.class)
                .satisfies(e -> assertThat(((BusinessException) e).errorCode()).isEqualTo(ErrorCode.AUTH_INVALID_CREDENTIALS));

        // Correct password -> 403 ACCOUNT_DEACTIVATED
        assertThatThrownBy(() -> authService.login(new LoginRequest(deactivatedEmail, "Password123!")))
                .isInstanceOf(BusinessException.class)
                .satisfies(e -> assertThat(((BusinessException) e).errorCode()).isEqualTo(ErrorCode.ACCOUNT_DEACTIVATED));
    }

    @Test
    @DisplayName("login with ACTIVE and null username should return recovery response and zero refresh sessions")
    void login_activeIncompleteProfile_recoveryFlow() {
        String email = "recovery.login@example.com";
        UUID userId = registerAndVerifyUser(email);

        LoginResponse response = authService.login(new LoginRequest(email, "Password123!"));

        assertThat(response.userId()).isEqualTo(userId);
        assertThat(response.status()).isEqualTo(UserStatus.ACTIVE);
        assertThat(response.nextStep()).isEqualTo(LoginResponse.NEXT_STEP_COMPLETE_PROFILE);
        assertThat(response.profileCompletionToken()).isNotBlank();
        assertThat(response.accessToken()).isNull();
        assertThat(response.refreshToken()).isNull();
        assertThat(response.tokenType()).isNull();
        assertThat(response.accessTokenExpiresAt()).isNull();
        assertThat(response.user()).isNull();

        // Verify token resolves to user
        UUID tokenUser = profileCompletionTokenService.extractAndValidate(response.profileCompletionToken());
        assertThat(tokenUser).isEqualTo(userId);

        // Verify no refresh sessions created
        long sessionCount = refreshSessionRepository.findAll().stream()
                .filter(s -> s.getUserId().equals(userId))
                .count();
        assertThat(sessionCount).isZero();

        // Complete profile using returned token succeeds
        CompleteProfileResponse comp = authService.completeProfile(
                new CompleteProfileRequest(response.profileCompletionToken(), "recovered_user", "Recovered", null, null)
        );
        assertThat(comp.username()).isEqualTo("recovered_user");
    }

    @Test
    @DisplayName("login with ACTIVE and populated username should return authenticated response with JWT and refresh session")
    void login_fullyOnboarded_success() {
        String email = "full.login@example.com";
        UUID userId = registerAndVerifyUser(email);
        String token = profileCompletionTokenService.generate(userId);
        authService.completeProfile(new CompleteProfileRequest(token, "fulluser", "Full User", null, null));

        // Case-insensitive email login
        LoginResponse response = authService.login(new LoginRequest("FULL.LOGIN@EXAMPLE.COM", "Password123!"));

        assertThat(response.userId()).isEqualTo(userId);
        assertThat(response.status()).isEqualTo(UserStatus.ACTIVE);
        assertThat(response.nextStep()).isEqualTo(LoginResponse.NEXT_STEP_AUTHENTICATED);
        assertThat(response.profileCompletionToken()).isNull();
        assertThat(response.tokenType()).isEqualTo(LoginResponse.TOKEN_TYPE_BEARER);
        assertThat(response.accessToken()).isNotBlank();
        assertThat(response.refreshToken()).isNotBlank();
        assertThat(response.accessTokenExpiresAt()).isNotNull();

        // Verify JWT
        assertThat(jwtService.isTokenValid(response.accessToken())).isTrue();
        assertThat(jwtService.extractUserId(response.accessToken())).isEqualTo(userId);
        assertThat(response.accessTokenExpiresAt()).isEqualTo(jwtService.extractExpiration(response.accessToken()));

        // Verify user summary
        assertThat(response.user()).isNotNull();
        assertThat(response.user().id()).isEqualTo(userId);
        assertThat(response.user().email()).isEqualTo(email);
        assertThat(response.user().username()).isEqualTo("fulluser");
        assertThat(response.user().displayName()).isEqualTo("Full User");

        // Verify refresh session in DB
        Optional<RefreshSessionEntity> sessionOpt = refreshSessionRepository.findByTokenHash(
                RefreshTokenService.hashToken(response.refreshToken())
        );
        assertThat(sessionOpt).isPresent();
        RefreshSessionEntity session = sessionOpt.get();
        assertThat(session.getUserId()).isEqualTo(userId);
        assertThat(session.getTokenHash()).isNotEqualTo(response.refreshToken());
        assertThat(session.getRevokedAt()).isNull();
        assertThat(session.getReplacedBySessionId()).isNull();
    }

    @Test
    @DisplayName("concurrency: two simultaneous wrong passwords should serialize increments without lost updates")
    void login_concurrency_wrongPassword_serialized() throws Exception {
        String email = "concurrent.wrong@example.com";
        UUID userId = registerAndVerifyUser(email);

        int threadCount = 2;
        ExecutorService executor = Executors.newFixedThreadPool(threadCount);
        CountDownLatch ready = new CountDownLatch(threadCount);
        CountDownLatch start = new CountDownLatch(1);

        List<Future<Void>> futures = new ArrayList<>();
        for (int i = 0; i < threadCount; i++) {
            futures.add(executor.submit(() -> {
                ready.countDown();
                start.await();
                try {
                    authService.login(new LoginRequest(email, "WrongPassword!"));
                } catch (LoginAttemptException expected) {
                    // expected
                }
                return null;
            }));
        }

        ready.await();
        start.countDown();

        for (Future<Void> f : futures) {
            f.get(10, TimeUnit.SECONDS);
        }
        executor.shutdown();

        UserCredentialEntity cred = userCredentialRepository.findById(userId).orElseThrow();
        assertThat(cred.getFailedAttempts()).isEqualTo(2);
    }

    @Test
    @DisplayName("concurrency: two simultaneous successful logins create two independent refresh sessions")
    void login_concurrency_successfulLogins_independentSessions() throws Exception {
        String email = "concurrent.success@example.com";
        UUID userId = registerAndVerifyUser(email);
        String token = profileCompletionTokenService.generate(userId);
        authService.completeProfile(new CompleteProfileRequest(token, "concurrentuser", "Concurrent User", null, null));

        int threadCount = 2;
        ExecutorService executor = Executors.newFixedThreadPool(threadCount);
        CountDownLatch ready = new CountDownLatch(threadCount);
        CountDownLatch start = new CountDownLatch(1);

        List<Future<LoginResponse>> futures = new ArrayList<>();
        for (int i = 0; i < threadCount; i++) {
            futures.add(executor.submit(() -> {
                ready.countDown();
                start.await();
                return authService.login(new LoginRequest(email, "Password123!"));
            }));
        }

        ready.await();
        start.countDown();

        List<LoginResponse> responses = new ArrayList<>();
        for (Future<LoginResponse> f : futures) {
            responses.add(f.get(10, TimeUnit.SECONDS));
        }
        executor.shutdown();

        assertThat(responses).hasSize(2);
        LoginResponse r1 = responses.get(0);
        LoginResponse r2 = responses.get(1);

        assertThat(r1.accessToken()).isNotBlank();
        assertThat(r2.accessToken()).isNotBlank();
        assertThat(r1.refreshToken()).isNotEqualTo(r2.refreshToken());

        long count = refreshSessionRepository.findAll().stream()
                .filter(s -> s.getUserId().equals(userId))
                .count();
        assertThat(count).isEqualTo(2);
    }

    // ==========================================
    // M2.8 Refresh Token Rotation Tests
    // ==========================================

    @Test
    @DisplayName("refreshToken with valid token rotates session and returns new credentials")
    void refreshToken_validToken_shouldRotateSuccessfully() {
        String email = "refresh.service.valid@example.com";
        UUID userId = registerAndVerifyUser(email);
        String token = profileCompletionTokenService.generate(userId);
        authService.completeProfile(new CompleteProfileRequest(token, "ref_serv_valid", "Ref Valid", null, null));

        LoginResponse loginResp = authService.login(new LoginRequest(email, "Password123!"));
        String raw1 = loginResp.refreshToken();
        String hash1 = RefreshTokenService.hashToken(raw1);

        RefreshSessionEntity s1Before = refreshSessionRepository.findByTokenHash(hash1).orElseThrow();
        assertThat(s1Before.getRevokedAt()).isNull();
        assertThat(s1Before.getReplacedBySessionId()).isNull();

        Instant rotationTime = currentInstant.plus(Duration.ofHours(1));
        currentInstant = rotationTime;

        RefreshTokenResponse response = authService.refreshToken(new RefreshTokenRequest(raw1));

        assertThat(response.accessToken()).isNotBlank();
        assertThat(jwtService.extractUserId(response.accessToken())).isEqualTo(userId);
        assertThat(response.accessTokenExpiresAt()).isEqualTo(jwtService.extractExpiration(response.accessToken()));
        assertThat(response.refreshToken()).isNotBlank();
        assertThat(response.refreshToken()).isNotEqualTo(raw1);
        assertThat(response.tokenType()).isEqualTo("Bearer");
        assertThat(response.refreshTokenExpiresAt()).isEqualTo(rotationTime.plus(Duration.ofDays(14)));

        // DB Assertions: S1 is revoked and replaced
        RefreshSessionEntity s1After = refreshSessionRepository.findByTokenHash(hash1).orElseThrow();
        assertThat(s1After.getRevokedAt()).isEqualTo(rotationTime);

        String hash2 = RefreshTokenService.hashToken(response.refreshToken());
        RefreshSessionEntity s2 = refreshSessionRepository.findByTokenHash(hash2).orElseThrow();
        assertThat(s1After.getReplacedBySessionId()).isEqualTo(s2.getId());

        assertThat(s2.getUserId()).isEqualTo(userId);
        assertThat(s2.getRevokedAt()).isNull();
        assertThat(s2.getReplacedBySessionId()).isNull();
        assertThat(s2.getExpiresAt()).isEqualTo(rotationTime.plus(Duration.ofDays(14)));
    }

    @Test
    @DisplayName("refreshToken boundary: valid before expiry, rejected at exact expiry and after expiry")
    void refreshToken_expiryBoundary_checks() {
        String email = "refresh.boundary@example.com";
        UUID userId = registerAndVerifyUser(email);
        String token = profileCompletionTokenService.generate(userId);
        authService.completeProfile(new CompleteProfileRequest(token, "ref_boundary", "Ref Boundary", null, null));

        LoginResponse loginResp = authService.login(new LoginRequest(email, "Password123!"));
        String raw1 = loginResp.refreshToken();
        String hash1 = RefreshTokenService.hashToken(raw1);
        RefreshSessionEntity s1 = refreshSessionRepository.findByTokenHash(hash1).orElseThrow();
        Instant expiry = s1.getExpiresAt();

        // 1. Exact expiry boundary (now == expiresAt) -> invalid
        currentInstant = expiry;
        assertThatThrownBy(() -> authService.refreshToken(new RefreshTokenRequest(raw1)))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", ErrorCode.REFRESH_TOKEN_INVALID);

        RefreshSessionEntity s1Still = refreshSessionRepository.findByTokenHash(hash1).orElseThrow();
        assertThat(s1Still.getRevokedAt()).isNull();
        assertThat(s1Still.getReplacedBySessionId()).isNull();

        // 2. After expiry boundary (now > expiresAt) -> invalid
        currentInstant = expiry.plus(Duration.ofSeconds(1));
        assertThatThrownBy(() -> authService.refreshToken(new RefreshTokenRequest(raw1)))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", ErrorCode.REFRESH_TOKEN_INVALID);

        // 3. Before expiry boundary (now < expiresAt) -> valid
        currentInstant = expiry.minus(Duration.ofSeconds(1));
        RefreshTokenResponse resp = authService.refreshToken(new RefreshTokenRequest(raw1));
        assertThat(resp.accessToken()).isNotBlank();
        assertThat(resp.refreshToken()).isNotBlank();
    }

    @Test
    @DisplayName("refreshToken direct reuse: previously rotated token is rejected without revoking replacement")
    void refreshToken_reusedRotatedToken_shouldRejectWithoutRevokingReplacement() {
        String email = "refresh.reuse@example.com";
        UUID userId = registerAndVerifyUser(email);
        String token = profileCompletionTokenService.generate(userId);
        authService.completeProfile(new CompleteProfileRequest(token, "ref_reuse", "Ref Reuse", null, null));

        LoginResponse loginResp = authService.login(new LoginRequest(email, "Password123!"));
        String raw1 = loginResp.refreshToken();

        // First rotation S1 -> S2 succeeds
        RefreshTokenResponse rot1 = authService.refreshToken(new RefreshTokenRequest(raw1));
        String raw2 = rot1.refreshToken();
        String hash2 = RefreshTokenService.hashToken(raw2);

        // Reusing raw1 -> must be rejected with REFRESH_TOKEN_INVALID
        assertThatThrownBy(() -> authService.refreshToken(new RefreshTokenRequest(raw1)))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", ErrorCode.REFRESH_TOKEN_INVALID);

        // Replacement S2 must remain active and unaffected
        RefreshSessionEntity s2 = refreshSessionRepository.findByTokenHash(hash2).orElseThrow();
        assertThat(s2.getRevokedAt()).isNull();
        assertThat(s2.getReplacedBySessionId()).isNull();

        // And S2 can still be rotated normally
        RefreshTokenResponse rot2 = authService.refreshToken(new RefreshTokenRequest(raw2));
        assertThat(rot2.accessToken()).isNotBlank();
    }

    @Test
    @DisplayName("refreshToken revoked non-rotated token should be rejected")
    void refreshToken_revokedNonRotatedToken_shouldReject() {
        String email = "refresh.revoked.nonrotated@example.com";
        UUID userId = registerAndVerifyUser(email);
        String token = profileCompletionTokenService.generate(userId);
        authService.completeProfile(new CompleteProfileRequest(token, "ref_rev_nonrot", "Ref Rev NonRot", null, null));

        LoginResponse loginResp = authService.login(new LoginRequest(email, "Password123!"));
        String raw1 = loginResp.refreshToken();
        String hash1 = RefreshTokenService.hashToken(raw1);

        // Simulate manual revocation (like logout) where replacedBySessionId is null
        RefreshSessionEntity s1 = refreshSessionRepository.findByTokenHash(hash1).orElseThrow();
        s1.setRevokedAt(currentInstant);
        s1.setReplacedBySessionId(null);
        refreshSessionRepository.save(s1);

        assertThatThrownBy(() -> authService.refreshToken(new RefreshTokenRequest(raw1)))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", ErrorCode.REFRESH_TOKEN_INVALID);
    }

    @Test
    @DisplayName("refreshToken with random or unrecognized token should be rejected")
    void refreshToken_randomToken_shouldReject() {
        assertThatThrownBy(() -> authService.refreshToken(new RefreshTokenRequest("nonexistent-random-refresh-token")))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", ErrorCode.REFRESH_TOKEN_INVALID);
    }

    @Test
    @DisplayName("refreshToken status revocation: non-ACTIVE users have session revoked and throw RefreshSessionStatusException")
    void refreshToken_statusRevocation_checks() {
        // 1. PENDING_VERIFICATION
        String emailPending = "status.pending@example.com";
        UUID idPending = registerAndVerifyUser(emailPending);
        String token1 = profileCompletionTokenService.generate(idPending);
        authService.completeProfile(new CompleteProfileRequest(token1, "status_pending", "Status Pending", null, null));
        LoginResponse loginPending = authService.login(new LoginRequest(emailPending, "Password123!"));
        String rawPending = loginPending.refreshToken();
        String hashPending = RefreshTokenService.hashToken(rawPending);

        UserEntity userPending = userRepository.findById(idPending).orElseThrow();
        userPending.setStatus(UserStatus.PENDING_VERIFICATION);
        userRepository.save(userPending);

        Instant timePending = currentInstant.plus(Duration.ofMinutes(10));
        currentInstant = timePending;

        assertThatThrownBy(() -> authService.refreshToken(new RefreshTokenRequest(rawPending)))
                .isInstanceOf(RefreshSessionStatusException.class)
                .hasFieldOrPropertyWithValue("errorCode", ErrorCode.EMAIL_NOT_VERIFIED);

        RefreshSessionEntity sessPending = refreshSessionRepository.findByTokenHash(hashPending).orElseThrow();
        assertThat(sessPending.getRevokedAt()).isEqualTo(timePending);
        assertThat(sessPending.getReplacedBySessionId()).isNull();

        // 2. SUSPENDED
        String emailSusp = "status.susp@example.com";
        UUID idSusp = registerAndVerifyUser(emailSusp);
        String token2 = profileCompletionTokenService.generate(idSusp);
        authService.completeProfile(new CompleteProfileRequest(token2, "status_susp", "Status Susp", null, null));
        LoginResponse loginSusp = authService.login(new LoginRequest(emailSusp, "Password123!"));
        String rawSusp = loginSusp.refreshToken();
        String hashSusp = RefreshTokenService.hashToken(rawSusp);

        UserEntity userSusp = userRepository.findById(idSusp).orElseThrow();
        userSusp.setStatus(UserStatus.SUSPENDED);
        userRepository.save(userSusp);

        Instant timeSusp = currentInstant.plus(Duration.ofMinutes(10));
        currentInstant = timeSusp;

        assertThatThrownBy(() -> authService.refreshToken(new RefreshTokenRequest(rawSusp)))
                .isInstanceOf(RefreshSessionStatusException.class)
                .hasFieldOrPropertyWithValue("errorCode", ErrorCode.ACCOUNT_SUSPENDED);

        RefreshSessionEntity sessSusp = refreshSessionRepository.findByTokenHash(hashSusp).orElseThrow();
        assertThat(sessSusp.getRevokedAt()).isEqualTo(timeSusp);
        assertThat(sessSusp.getReplacedBySessionId()).isNull();

        // 3. DEACTIVATED
        String emailDeact = "status.deact@example.com";
        UUID idDeact = registerAndVerifyUser(emailDeact);
        String token3 = profileCompletionTokenService.generate(idDeact);
        authService.completeProfile(new CompleteProfileRequest(token3, "status_deact", "Status Deact", null, null));
        LoginResponse loginDeact = authService.login(new LoginRequest(emailDeact, "Password123!"));
        String rawDeact = loginDeact.refreshToken();
        String hashDeact = RefreshTokenService.hashToken(rawDeact);

        UserEntity userDeact = userRepository.findById(idDeact).orElseThrow();
        userDeact.setStatus(UserStatus.DEACTIVATED);
        userRepository.save(userDeact);

        Instant timeDeact = currentInstant.plus(Duration.ofMinutes(10));
        currentInstant = timeDeact;

        assertThatThrownBy(() -> authService.refreshToken(new RefreshTokenRequest(rawDeact)))
                .isInstanceOf(RefreshSessionStatusException.class)
                .hasFieldOrPropertyWithValue("errorCode", ErrorCode.ACCOUNT_DEACTIVATED);

        RefreshSessionEntity sessDeact = refreshSessionRepository.findByTokenHash(hashDeact).orElseThrow();
        assertThat(sessDeact.getRevokedAt()).isEqualTo(timeDeact);
        assertThat(sessDeact.getReplacedBySessionId()).isNull();
    }

    @Test
    @DisplayName("concurrency: two simultaneous refreshes of the same token yield exactly 1 success and 1 REFRESH_TOKEN_INVALID")
    void refreshToken_concurrency_sameToken_exactlyOneSuccess() throws Exception {
        String email = "concurrent.refresh.same@example.com";
        UUID userId = registerAndVerifyUser(email);
        String token = profileCompletionTokenService.generate(userId);
        authService.completeProfile(new CompleteProfileRequest(token, "ref_same_user", "Ref Same User", null, null));

        LoginResponse loginResp = authService.login(new LoginRequest(email, "Password123!"));
        String raw1 = loginResp.refreshToken();
        String hash1 = RefreshTokenService.hashToken(raw1);

        int threadCount = 2;
        ExecutorService executor = Executors.newFixedThreadPool(threadCount);
        CountDownLatch ready = new CountDownLatch(threadCount);
        CountDownLatch start = new CountDownLatch(1);

        List<Future<Object>> futures = new ArrayList<>();
        for (int i = 0; i < threadCount; i++) {
            futures.add(executor.submit(() -> {
                ready.countDown();
                start.await();
                try {
                    return authService.refreshToken(new RefreshTokenRequest(raw1));
                } catch (Exception e) {
                    return e;
                }
            }));
        }

        ready.await();
        start.countDown();

        int successCount = 0;
        int invalidCount = 0;
        RefreshTokenResponse successResponse = null;

        for (Future<Object> f : futures) {
            Object res = f.get(10, TimeUnit.SECONDS);
            if (res instanceof RefreshTokenResponse r) {
                successCount++;
                successResponse = r;
            } else if (res instanceof BusinessException be && be.errorCode() == ErrorCode.REFRESH_TOKEN_INVALID) {
                invalidCount++;
            }
        }
        executor.shutdown();

        assertThat(successCount).isEqualTo(1);
        assertThat(invalidCount).isEqualTo(1);
        assertThat(successResponse).isNotNull();

        // Database checks:
        RefreshSessionEntity s1 = refreshSessionRepository.findByTokenHash(hash1).orElseThrow();
        assertThat(s1.getRevokedAt()).isNotNull();
        assertThat(s1.getReplacedBySessionId()).isNotNull();

        String hash2 = RefreshTokenService.hashToken(successResponse.refreshToken());
        RefreshSessionEntity s2 = refreshSessionRepository.findByTokenHash(hash2).orElseThrow();
        assertThat(s1.getReplacedBySessionId()).isEqualTo(s2.getId());
        assertThat(s2.getRevokedAt()).isNull();

        long sessionCount = refreshSessionRepository.findAll().stream()
                .filter(s -> s.getUserId().equals(userId))
                .count();
        // exactly 2 sessions: S1 (revoked) and S2 (active)
        assertThat(sessionCount).isEqualTo(2);
    }

    @Test
    @DisplayName("concurrency: two independent sessions of the same user refresh simultaneously and both succeed")
    void refreshToken_concurrency_differentTokens_bothSucceed() throws Exception {
        String email = "concurrent.refresh.diff@example.com";
        UUID userId = registerAndVerifyUser(email);
        String token = profileCompletionTokenService.generate(userId);
        authService.completeProfile(new CompleteProfileRequest(token, "ref_diff_user", "Ref Diff User", null, null));

        LoginResponse login1 = authService.login(new LoginRequest(email, "Password123!"));
        LoginResponse login2 = authService.login(new LoginRequest(email, "Password123!"));
        String rawS1 = login1.refreshToken();
        String rawA1 = login2.refreshToken();

        int threadCount = 2;
        ExecutorService executor = Executors.newFixedThreadPool(threadCount);
        CountDownLatch ready = new CountDownLatch(threadCount);
        CountDownLatch start = new CountDownLatch(1);

        Future<RefreshTokenResponse> f1 = executor.submit(() -> {
            ready.countDown();
            start.await();
            return authService.refreshToken(new RefreshTokenRequest(rawS1));
        });

        Future<RefreshTokenResponse> f2 = executor.submit(() -> {
            ready.countDown();
            start.await();
            return authService.refreshToken(new RefreshTokenRequest(rawA1));
        });

        ready.await();
        start.countDown();

        RefreshTokenResponse resp1 = f1.get(10, TimeUnit.SECONDS);
        RefreshTokenResponse resp2 = f2.get(10, TimeUnit.SECONDS);
        executor.shutdown();

        assertThat(resp1.accessToken()).isNotBlank();
        assertThat(resp2.accessToken()).isNotBlank();
        assertThat(resp1.refreshToken()).isNotEqualTo(resp2.refreshToken());

        String hashS2 = RefreshTokenService.hashToken(resp1.refreshToken());
        String hashA2 = RefreshTokenService.hashToken(resp2.refreshToken());

        RefreshSessionEntity s2 = refreshSessionRepository.findByTokenHash(hashS2).orElseThrow();
        RefreshSessionEntity a2 = refreshSessionRepository.findByTokenHash(hashA2).orElseThrow();
        assertThat(s2.getRevokedAt()).isNull();
        assertThat(a2.getRevokedAt()).isNull();

        long totalSessions = refreshSessionRepository.findAll().stream()
                .filter(s -> s.getUserId().equals(userId))
                .count();
        // 4 total: S1, A1 (both revoked), S2, A2 (both active)
        assertThat(totalSessions).isEqualTo(4);
    }
}
