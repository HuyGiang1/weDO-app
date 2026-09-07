package com.wedo.backend.auth.service;

import com.wedo.backend.auth.dto.CompleteProfileRequest;
import com.wedo.backend.auth.dto.CompleteProfileResponse;
import com.wedo.backend.auth.dto.ForgotPasswordRequest;
import com.wedo.backend.auth.dto.ForgotPasswordResponse;
import com.wedo.backend.auth.dto.LoginRequest;
import com.wedo.backend.auth.dto.LoginResponse;
import com.wedo.backend.auth.dto.LogoutRequest;
import com.wedo.backend.auth.dto.RefreshTokenRequest;
import com.wedo.backend.auth.dto.RefreshTokenResponse;
import com.wedo.backend.auth.dto.RegisterRequest;
import com.wedo.backend.auth.dto.RegisterResponse;
import com.wedo.backend.auth.dto.ResetPasswordRequest;
import com.wedo.backend.auth.dto.ResendVerificationRequest;
import com.wedo.backend.auth.dto.ResendVerificationResponse;
import com.wedo.backend.auth.dto.SessionClientMetadata;
import com.wedo.backend.auth.dto.UsernameAvailabilityResponse;
import com.wedo.backend.auth.dto.VerifyEmailRequest;
import com.wedo.backend.auth.dto.VerifyEmailResponse;
import com.wedo.backend.auth.entity.AuthTokenEntity;
import com.wedo.backend.auth.entity.AuthTokenType;
import com.wedo.backend.auth.entity.RefreshSessionEntity;
import com.wedo.backend.auth.event.EmailVerificationRequestedEvent;
import com.wedo.backend.auth.event.PasswordResetRequestedEvent;
import com.wedo.backend.auth.exception.LoginAttemptException;
import com.wedo.backend.auth.exception.PasswordResetAttemptException;
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

    private String getLatestResetCode(UUID userId) {
        return applicationEvents.stream(PasswordResetRequestedEvent.class)
                .filter(e -> e.userId().equals(userId))
                .reduce((first, second) -> second)
                .orElseThrow(() -> new IllegalStateException("No password reset event found for user: " + userId))
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

    @Test
    @DisplayName("logout with active valid session should revoke session and set replacedBySessionId to null")
    void logout_activeValidSession_shouldRevokeAndSetReplacedByNull() {
        String email = "logout.active@example.com";
        UUID userId = registerAndVerifyUser(email);
        String token = profileCompletionTokenService.generate(userId);
        authService.completeProfile(new CompleteProfileRequest(token, "log_active", "Log Active", null, null));

        LoginResponse loginResp = authService.login(new LoginRequest(email, "Password123!"));
        String raw1 = loginResp.refreshToken();
        String hash1 = RefreshTokenService.hashToken(raw1);

        RefreshSessionEntity s1Before = refreshSessionRepository.findByTokenHash(hash1).orElseThrow();
        assertThat(s1Before.getRevokedAt()).isNull();
        assertThat(s1Before.getReplacedBySessionId()).isNull();

        long sessionsBefore = refreshSessionRepository.count();

        authService.logout(new LogoutRequest(raw1));

        RefreshSessionEntity s1After = refreshSessionRepository.findByTokenHash(hash1).orElseThrow();
        assertThat(s1After.getRevokedAt()).isEqualTo(currentInstant);
        assertThat(s1After.getReplacedBySessionId()).isNull();

        long sessionsAfter = refreshSessionRepository.count();
        assertThat(sessionsAfter).isEqualTo(sessionsBefore);
    }

    @Test
    @DisplayName("logout on already non-rotated revoked session should succeed idempotently without overwriting revokedAt")
    void logout_alreadyNonRotatedRevokedSession_shouldSucceedIdempotentlyWithoutOverwritingRevokedAt() {
        String email = "logout.idemp.service@example.com";
        UUID userId = registerAndVerifyUser(email);
        String token = profileCompletionTokenService.generate(userId);
        authService.completeProfile(new CompleteProfileRequest(token, "log_idemp_s", "Log Idemp S", null, null));

        LoginResponse loginResp = authService.login(new LoginRequest(email, "Password123!"));
        String raw1 = loginResp.refreshToken();
        String hash1 = RefreshTokenService.hashToken(raw1);

        // First logout at T1
        Instant t1 = currentInstant;
        authService.logout(new LogoutRequest(raw1));

        RefreshSessionEntity s1AfterFirst = refreshSessionRepository.findByTokenHash(hash1).orElseThrow();
        assertThat(s1AfterFirst.getRevokedAt()).isEqualTo(t1);

        // Advance clock to T2
        currentInstant = currentInstant.plusSeconds(300);

        // Second logout at T2
        authService.logout(new LogoutRequest(raw1));

        RefreshSessionEntity s1AfterSecond = refreshSessionRepository.findByTokenHash(hash1).orElseThrow();
        assertThat(s1AfterSecond.getRevokedAt()).isEqualTo(t1);
        assertThat(s1AfterSecond.getReplacedBySessionId()).isNull();
    }

    @Test
    @DisplayName("logout on rotated session should reject with REFRESH_TOKEN_INVALID and not revoke replacement session")
    void logout_rotatedSession_shouldRejectWithRefreshTokenInvalid() {
        String email = "logout.rotated.service@example.com";
        UUID userId = registerAndVerifyUser(email);
        String token = profileCompletionTokenService.generate(userId);
        authService.completeProfile(new CompleteProfileRequest(token, "log_rot_s", "Log Rot S", null, null));

        LoginResponse loginResp = authService.login(new LoginRequest(email, "Password123!"));
        String raw1 = loginResp.refreshToken();
        String hash1 = RefreshTokenService.hashToken(raw1);

        // Rotate S1 -> S2
        RefreshTokenResponse refreshResp = authService.refreshToken(new RefreshTokenRequest(raw1));
        String raw2 = refreshResp.refreshToken();
        String hash2 = RefreshTokenService.hashToken(raw2);

        RefreshSessionEntity s1 = refreshSessionRepository.findByTokenHash(hash1).orElseThrow();
        RefreshSessionEntity s2 = refreshSessionRepository.findByTokenHash(hash2).orElseThrow();
        assertThat(s1.getRevokedAt()).isNotNull();
        assertThat(s1.getReplacedBySessionId()).isEqualTo(s2.getId());
        assertThat(s2.getRevokedAt()).isNull();

        // Attempt logout with rotated token raw1
        assertThatThrownBy(() -> authService.logout(new LogoutRequest(raw1)))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", ErrorCode.REFRESH_TOKEN_INVALID);

        // S1 unchanged, S2 remains active
        RefreshSessionEntity s1Reload = refreshSessionRepository.findByTokenHash(hash1).orElseThrow();
        RefreshSessionEntity s2Reload = refreshSessionRepository.findByTokenHash(hash2).orElseThrow();
        assertThat(s1Reload.getReplacedBySessionId()).isEqualTo(s2.getId());
        assertThat(s2Reload.getRevokedAt()).isNull();
    }

    @Test
    @DisplayName("logout on expired active session at exact boundary now == expiresAt should reject and not mutate session")
    void logout_expiredActiveSession_exactBoundary_shouldReject() {
        String email = "logout.exp.boundary@example.com";
        UUID userId = registerAndVerifyUser(email);
        String token = profileCompletionTokenService.generate(userId);
        authService.completeProfile(new CompleteProfileRequest(token, "log_exp_b", "Log Exp B", null, null));

        LoginResponse loginResp = authService.login(new LoginRequest(email, "Password123!"));
        String raw1 = loginResp.refreshToken();
        String hash1 = RefreshTokenService.hashToken(raw1);

        RefreshSessionEntity s1 = refreshSessionRepository.findByTokenHash(hash1).orElseThrow();
        Instant expiresAt = s1.getExpiresAt();

        // Set clock to exact expiry
        currentInstant = expiresAt;

        assertThatThrownBy(() -> authService.logout(new LogoutRequest(raw1)))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", ErrorCode.REFRESH_TOKEN_INVALID);

        RefreshSessionEntity s1Reload = refreshSessionRepository.findByTokenHash(hash1).orElseThrow();
        assertThat(s1Reload.getRevokedAt()).isNull();
    }

    @Test
    @DisplayName("logout on expired active session after expiry should reject and not mutate session")
    void logout_expiredActiveSession_afterExpiry_shouldReject() {
        String email = "logout.exp.after@example.com";
        UUID userId = registerAndVerifyUser(email);
        String token = profileCompletionTokenService.generate(userId);
        authService.completeProfile(new CompleteProfileRequest(token, "log_exp_a", "Log Exp A", null, null));

        LoginResponse loginResp = authService.login(new LoginRequest(email, "Password123!"));
        String raw1 = loginResp.refreshToken();
        String hash1 = RefreshTokenService.hashToken(raw1);

        RefreshSessionEntity s1 = refreshSessionRepository.findByTokenHash(hash1).orElseThrow();
        Instant expiresAt = s1.getExpiresAt();

        // Set clock after expiry
        currentInstant = expiresAt.plusSeconds(10);

        assertThatThrownBy(() -> authService.logout(new LogoutRequest(raw1)))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", ErrorCode.REFRESH_TOKEN_INVALID);

        RefreshSessionEntity s1Reload = refreshSessionRepository.findByTokenHash(hash1).orElseThrow();
        assertThat(s1Reload.getRevokedAt()).isNull();
    }

    @Test
    @DisplayName("logout with unknown random token should reject with REFRESH_TOKEN_INVALID")
    void logout_unknownRandomToken_shouldReject() {
        assertThatThrownBy(() -> authService.logout(new LogoutRequest("random-unrecognized-token")))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", ErrorCode.REFRESH_TOKEN_INVALID);
    }

    @Test
    @DisplayName("logout with valid session belonging to SUSPENDED user should succeed")
    void logout_suspendedUser_shouldSucceed() {
        String email = "logout.suspended@example.com";
        UUID userId = registerAndVerifyUser(email);
        String token = profileCompletionTokenService.generate(userId);
        authService.completeProfile(new CompleteProfileRequest(token, "log_susp", "Log Susp", null, null));

        LoginResponse loginResp = authService.login(new LoginRequest(email, "Password123!"));
        String raw1 = loginResp.refreshToken();
        String hash1 = RefreshTokenService.hashToken(raw1);

        UserEntity user = userRepository.findById(userId).orElseThrow();
        user.setStatus(UserStatus.SUSPENDED);
        userRepository.save(user);

        authService.logout(new LogoutRequest(raw1));

        RefreshSessionEntity s1 = refreshSessionRepository.findByTokenHash(hash1).orElseThrow();
        assertThat(s1.getRevokedAt()).isEqualTo(currentInstant);
        assertThat(s1.getReplacedBySessionId()).isNull();
    }

    @Test
    @DisplayName("logout with valid session belonging to DEACTIVATED user should succeed")
    void logout_deactivatedUser_shouldSucceed() {
        String email = "logout.deactivated@example.com";
        UUID userId = registerAndVerifyUser(email);
        String token = profileCompletionTokenService.generate(userId);
        authService.completeProfile(new CompleteProfileRequest(token, "log_deact", "Log Deact", null, null));

        LoginResponse loginResp = authService.login(new LoginRequest(email, "Password123!"));
        String raw1 = loginResp.refreshToken();
        String hash1 = RefreshTokenService.hashToken(raw1);

        UserEntity user = userRepository.findById(userId).orElseThrow();
        user.setStatus(UserStatus.DEACTIVATED);
        userRepository.save(user);

        authService.logout(new LogoutRequest(raw1));

        RefreshSessionEntity s1 = refreshSessionRepository.findByTokenHash(hash1).orElseThrow();
        assertThat(s1.getRevokedAt()).isEqualTo(currentInstant);
        assertThat(s1.getReplacedBySessionId()).isNull();
    }

    @Test
    @DisplayName("concurrent refresh vs logout on same session should produce a valid serializable outcome")
    void logout_concurrent_raceWithRefresh_sameSession_shouldBeConsistent() throws Exception {
        String email = "logout.race@example.com";
        UUID userId = registerAndVerifyUser(email);
        String token = profileCompletionTokenService.generate(userId);
        authService.completeProfile(new CompleteProfileRequest(token, "log_race", "Log Race", null, null));

        LoginResponse loginResp = authService.login(new LoginRequest(email, "Password123!"));
        String raw1 = loginResp.refreshToken();
        String hash1 = RefreshTokenService.hashToken(raw1);

        int threadCount = 2;
        ExecutorService executor = Executors.newFixedThreadPool(threadCount);
        CountDownLatch ready = new CountDownLatch(threadCount);
        CountDownLatch start = new CountDownLatch(1);

        Future<RefreshTokenResponse> refreshFuture = executor.submit(() -> {
            ready.countDown();
            start.await();
            return authService.refreshToken(new RefreshTokenRequest(raw1));
        });

        Future<Boolean> logoutFuture = executor.submit(() -> {
            ready.countDown();
            start.await();
            authService.logout(new LogoutRequest(raw1));
            return true;
        });

        ready.await();
        start.countDown();

        boolean refreshSuccess = false;
        boolean logoutSuccess = false;
        RefreshTokenResponse refreshResp = null;

        try {
            refreshResp = refreshFuture.get(10, TimeUnit.SECONDS);
            refreshSuccess = true;
        } catch (ExecutionException e) {
            assertThat(e.getCause())
                    .isInstanceOf(BusinessException.class)
                    .hasFieldOrPropertyWithValue("errorCode", ErrorCode.REFRESH_TOKEN_INVALID);
        }

        try {
            logoutFuture.get(10, TimeUnit.SECONDS);
            logoutSuccess = true;
        } catch (ExecutionException e) {
            assertThat(e.getCause())
                    .isInstanceOf(BusinessException.class)
                    .hasFieldOrPropertyWithValue("errorCode", ErrorCode.REFRESH_TOKEN_INVALID);
        }

        executor.shutdown();

        // Invariant: Exactly one must succeed, one must fail
        assertThat(refreshSuccess ^ logoutSuccess).isTrue();

        RefreshSessionEntity s1 = refreshSessionRepository.findByTokenHash(hash1).orElseThrow();
        assertThat(s1.getRevokedAt()).isNotNull();

        if (logoutSuccess) {
            // Case A: Logout won lock
            assertThat(s1.getReplacedBySessionId()).isNull();
            long totalSessions = refreshSessionRepository.findAll().stream()
                    .filter(s -> s.getUserId().equals(userId))
                    .count();
            assertThat(totalSessions).isEqualTo(1);
        } else {
            // Case B: Refresh won lock
            assertThat(refreshResp).isNotNull();
            String hash2 = RefreshTokenService.hashToken(refreshResp.refreshToken());
            RefreshSessionEntity s2 = refreshSessionRepository.findByTokenHash(hash2).orElseThrow();
            assertThat(s1.getReplacedBySessionId()).isEqualTo(s2.getId());
            assertThat(s2.getRevokedAt()).isNull();
        }
    }

    @Test
    @DisplayName("concurrent double logout on same session should be idempotent and both succeed")
    void logout_concurrent_doubleLogout_sameSession_shouldBeIdempotentAndPreserveFirstTimestamp() throws Exception {
        String email = "logout.double@example.com";
        UUID userId = registerAndVerifyUser(email);
        String token = profileCompletionTokenService.generate(userId);
        authService.completeProfile(new CompleteProfileRequest(token, "log_double", "Log Double", null, null));

        LoginResponse loginResp = authService.login(new LoginRequest(email, "Password123!"));
        String raw1 = loginResp.refreshToken();
        String hash1 = RefreshTokenService.hashToken(raw1);

        int threadCount = 2;
        ExecutorService executor = Executors.newFixedThreadPool(threadCount);
        CountDownLatch ready = new CountDownLatch(threadCount);
        CountDownLatch start = new CountDownLatch(1);

        Future<Boolean> f1 = executor.submit(() -> {
            ready.countDown();
            start.await();
            authService.logout(new LogoutRequest(raw1));
            return true;
        });

        Future<Boolean> f2 = executor.submit(() -> {
            ready.countDown();
            start.await();
            authService.logout(new LogoutRequest(raw1));
            return true;
        });

        ready.await();
        start.countDown();

        Boolean res1 = f1.get(10, TimeUnit.SECONDS);
        Boolean res2 = f2.get(10, TimeUnit.SECONDS);
        executor.shutdown();

        assertThat(res1).isTrue();
        assertThat(res2).isTrue();

        RefreshSessionEntity s1 = refreshSessionRepository.findByTokenHash(hash1).orElseThrow();
        assertThat(s1.getRevokedAt()).isEqualTo(currentInstant);
        assertThat(s1.getReplacedBySessionId()).isNull();

        long totalSessions = refreshSessionRepository.findAll().stream()
                .filter(s -> s.getUserId().equals(userId))
                .count();
        assertThat(totalSessions).isEqualTo(1);
    }

    // =========================================================================
    // M2.10: FORGOT PASSWORD SERVICE TESTS
    // =========================================================================

    @Test
    @DisplayName("forgotPassword: active known user should create exactly 1 unconsumed reset token and publish event")
    void forgotPassword_activeKnownUser_shouldCreateUnconsumedTokenAndPublishEvent() {
        String email = "forgot.active.test@example.com";
        UUID userId = registerAndVerifyUser(email);

        ForgotPasswordResponse response = authService.forgotPassword(new ForgotPasswordRequest(email));
        assertThat(response.message()).isEqualTo(ForgotPasswordResponse.DEFAULT_MESSAGE);

        List<AuthTokenEntity> resetTokens = authTokenRepository
                .findAllByUserIdAndTokenTypeAndConsumedAtIsNullOrderByCreatedAtDescIdDesc(userId, AuthTokenType.PASSWORD_RESET);
        assertThat(resetTokens).hasSize(1);

        AuthTokenEntity token = resetTokens.get(0);
        assertThat(token.getAttempts()).isZero();
        assertThat(token.getConsumedAt()).isNull();
        assertThat(token.getExpiresAt()).isEqualTo(currentInstant.plus(Duration.ofMinutes(15)));

        List<PasswordResetRequestedEvent> events = applicationEvents.stream(PasswordResetRequestedEvent.class)
                .filter(e -> e.userId().equals(userId))
                .toList();
        assertThat(events).hasSize(1);
        PasswordResetRequestedEvent event = events.get(0);
        assertThat(event.email()).isEqualTo(email);
        assertThat(event.rawCode()).matches("^\\d{6}$");
        assertThat(token.getTokenHash()).isNotEqualTo(event.rawCode());

        // Verify stored hash matches rawCode via AuthTokenHasher
        assertThat(authTokenHasher.matches(
                userId,
                AuthTokenType.PASSWORD_RESET,
                event.rawCode(),
                token.getTokenHash()
        )).isTrue();
    }

    @Test
    @DisplayName("forgotPassword: unknown email returns generic response without creating token or publishing event")
    void forgotPassword_unknownEmail_shouldReturnGenericResponseWithoutTokenOrEvent() {
        ForgotPasswordResponse response = authService.forgotPassword(new ForgotPasswordRequest("ghost.nonexistent@example.com"));
        assertThat(response.message()).isEqualTo(ForgotPasswordResponse.DEFAULT_MESSAGE);

        List<PasswordResetRequestedEvent> events = applicationEvents.stream(PasswordResetRequestedEvent.class)
                .filter(e -> e.email().equals("ghost.nonexistent@example.com"))
                .toList();
        assertThat(events).isEmpty();
    }

    @Test
    @DisplayName("forgotPassword: non-ACTIVE statuses return generic response without token or event")
    void forgotPassword_ineligibleStatuses_shouldReturnGenericResponseWithoutTokenOrEvent() {
        // 1. PENDING_VERIFICATION
        String pendingEmail = "forgot.pending.status@example.com";
        RegisterResponse regPending = authService.register(new RegisterRequest(pendingEmail, "Password123!"));
        ForgotPasswordResponse resp1 = authService.forgotPassword(new ForgotPasswordRequest(pendingEmail));
        assertThat(resp1.message()).isEqualTo(ForgotPasswordResponse.DEFAULT_MESSAGE);
        assertThat(authTokenRepository.findAllByUserIdAndTokenTypeAndConsumedAtIsNullOrderByCreatedAtDescIdDesc(
                regPending.userId(), AuthTokenType.PASSWORD_RESET)).isEmpty();

        // 2. SUSPENDED
        String suspendedEmail = "forgot.suspended.status@example.com";
        UUID suspendedId = registerAndVerifyUser(suspendedEmail);
        UserEntity suspUser = userRepository.findById(suspendedId).orElseThrow();
        suspUser.setStatus(UserStatus.SUSPENDED);
        userRepository.save(suspUser);

        ForgotPasswordResponse resp2 = authService.forgotPassword(new ForgotPasswordRequest(suspendedEmail));
        assertThat(resp2.message()).isEqualTo(ForgotPasswordResponse.DEFAULT_MESSAGE);
        assertThat(authTokenRepository.findAllByUserIdAndTokenTypeAndConsumedAtIsNullOrderByCreatedAtDescIdDesc(
                suspendedId, AuthTokenType.PASSWORD_RESET)).isEmpty();

        // 3. DEACTIVATED
        String deactEmail = "forgot.deact.status@example.com";
        UUID deactId = registerAndVerifyUser(deactEmail);
        UserEntity deactUser = userRepository.findById(deactId).orElseThrow();
        deactUser.setStatus(UserStatus.DEACTIVATED);
        userRepository.save(deactUser);

        ForgotPasswordResponse resp3 = authService.forgotPassword(new ForgotPasswordRequest(deactEmail));
        assertThat(resp3.message()).isEqualTo(ForgotPasswordResponse.DEFAULT_MESSAGE);
        assertThat(authTokenRepository.findAllByUserIdAndTokenTypeAndConsumedAtIsNullOrderByCreatedAtDescIdDesc(
                deactId, AuthTokenType.PASSWORD_RESET)).isEmpty();
    }

    @Test
    @DisplayName("forgotPassword: repeated call invalidates previous token and creates fresh one")
    void forgotPassword_repeatedCall_shouldInvalidatePreviousToken() {
        String email = "forgot.repeat@example.com";
        UUID userId = registerAndVerifyUser(email);

        authService.forgotPassword(new ForgotPasswordRequest(email));
        List<AuthTokenEntity> firstTokens = authTokenRepository
                .findAllByUserIdAndTokenTypeAndConsumedAtIsNullOrderByCreatedAtDescIdDesc(userId, AuthTokenType.PASSWORD_RESET);
        assertThat(firstTokens).hasSize(1);
        AuthTokenEntity firstToken = firstTokens.get(0);

        // Advance time by 2 minutes
        currentInstant = currentInstant.plus(Duration.ofMinutes(2));

        authService.forgotPassword(new ForgotPasswordRequest(email));

        // Re-read first token
        AuthTokenEntity reFirst = authTokenRepository.findById(firstToken.getId()).orElseThrow();
        assertThat(reFirst.getConsumedAt()).isEqualTo(currentInstant);

        List<AuthTokenEntity> activeTokens = authTokenRepository
                .findAllByUserIdAndTokenTypeAndConsumedAtIsNullOrderByCreatedAtDescIdDesc(userId, AuthTokenType.PASSWORD_RESET);
        assertThat(activeTokens).hasSize(1);
        assertThat(activeTokens.get(0).getId()).isNotEqualTo(firstToken.getId());
    }

    @Test
    @DisplayName("forgotPassword: concurrent calls for same user serialize and yield exactly 1 unconsumed token")
    void forgotPassword_concurrentCalls_sameUser_shouldYieldExactlyOneUnconsumedToken() throws Exception {
        String email = "forgot.concurrent@example.com";
        UUID userId = registerAndVerifyUser(email);

        int threads = 2;
        ExecutorService executor = Executors.newFixedThreadPool(threads);
        CountDownLatch ready = new CountDownLatch(threads);
        CountDownLatch start = new CountDownLatch(1);

        Future<ForgotPasswordResponse> f1 = executor.submit(() -> {
            ready.countDown();
            start.await();
            return authService.forgotPassword(new ForgotPasswordRequest(email));
        });

        Future<ForgotPasswordResponse> f2 = executor.submit(() -> {
            ready.countDown();
            start.await();
            return authService.forgotPassword(new ForgotPasswordRequest(email));
        });

        ready.await();
        start.countDown();

        f1.get(10, TimeUnit.SECONDS);
        f2.get(10, TimeUnit.SECONDS);
        executor.shutdown();

        List<AuthTokenEntity> unconsumed = authTokenRepository
                .findAllByUserIdAndTokenTypeAndConsumedAtIsNullOrderByCreatedAtDescIdDesc(userId, AuthTokenType.PASSWORD_RESET);
        assertThat(unconsumed).hasSize(1);
    }

    // =========================================================================
    // M2.10: RESET PASSWORD SERVICE TESTS
    // =========================================================================

    @Test
    @DisplayName("resetPassword: valid reset updates password, resets lockout, consumes token, revokes refresh sessions")
    void resetPassword_valid_shouldUpdatePasswordResetLockoutConsumeTokenAndRevokeRefreshSessions() {
        String email = "reset.valid.service@example.com";
        UUID userId = registerAndVerifyUser(email);

        // Complete profile & login to establish active refresh session
        String compToken = profileCompletionTokenService.generate(userId);
        authService.completeProfile(new CompleteProfileRequest(compToken, "reset_val", "Reset Val", null, null));
        LoginResponse loginResp = authService.login(new LoginRequest(email, "Password123!"));
        String rawRefresh = loginResp.refreshToken();
        String hashRefresh = RefreshTokenService.hashToken(rawRefresh);

        // Simulate failed login attempts and lockout on credential
        UserCredentialEntity cred = userCredentialRepository.findById(userId).orElseThrow();
        cred.setFailedAttempts(3);
        cred.setLockedUntil(currentInstant.plus(Duration.ofMinutes(10)));
        userCredentialRepository.save(cred);

        // Issue forgot password token
        authService.forgotPassword(new ForgotPasswordRequest(email));
        String resetCode = getLatestResetCode(userId);

        // Advance clock slightly
        currentInstant = currentInstant.plus(Duration.ofMinutes(1));

        // Perform reset
        String newPassword = "BrandNewPassword123!";
        authService.resetPassword(new ResetPasswordRequest(email, resetCode, newPassword));

        // 1. Password and lockout assertions
        UserCredentialEntity updatedCred = userCredentialRepository.findById(userId).orElseThrow();
        assertThat(passwordEncoder.matches(newPassword, updatedCred.getPasswordHash())).isTrue();
        assertThat(passwordEncoder.matches("Password123!", updatedCred.getPasswordHash())).isFalse();
        assertThat(updatedCred.getFailedAttempts()).isZero();
        assertThat(updatedCred.getLockedUntil()).isNull();
        assertThat(updatedCred.getPasswordChangedAt()).isEqualTo(currentInstant);

        // 2. Token consumed assertion
        List<AuthTokenEntity> activeTokens = authTokenRepository
                .findAllByUserIdAndTokenTypeAndConsumedAtIsNullOrderByCreatedAtDescIdDesc(userId, AuthTokenType.PASSWORD_RESET);
        assertThat(activeTokens).isEmpty();

        // 3. Refresh session revoked assertion
        RefreshSessionEntity session = refreshSessionRepository.findByTokenHash(hashRefresh).orElseThrow();
        assertThat(session.getRevokedAt()).isEqualTo(currentInstant);
        assertThat(session.getReplacedBySessionId()).isNull();

        // 4. Verification that new password works for login and old password fails
        LoginResponse newLogin = authService.login(new LoginRequest(email, newPassword));
        assertThat(newLogin.accessToken()).isNotBlank();

        assertThatThrownBy(() -> authService.login(new LoginRequest(email, "Password123!")))
                .isInstanceOf(LoginAttemptException.class);
    }

    @Test
    @DisplayName("resetPassword: wrong code increments attempts and throws PASSWORD_RESET_CODE_INVALID with persistence")
    void resetPassword_wrongCode_shouldIncrementAttemptsAndPersist() {
        String email = "reset.wrong.service@example.com";
        UUID userId = registerAndVerifyUser(email);
        authService.forgotPassword(new ForgotPasswordRequest(email));

        // Submit wrong code
        assertThatThrownBy(() -> authService.resetPassword(new ResetPasswordRequest(email, "000000", "NewPassword123!")))
                .isInstanceOf(PasswordResetAttemptException.class)
                .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.PASSWORD_RESET_CODE_INVALID));

        // Verify attempts persisted
        AuthTokenEntity token = authTokenRepository
                .findAllByUserIdAndTokenTypeAndConsumedAtIsNullOrderByCreatedAtDescIdDesc(userId, AuthTokenType.PASSWORD_RESET)
                .get(0);
        assertThat(token.getAttempts()).isEqualTo(1);
    }

    @Test
    @DisplayName("resetPassword: fifth wrong code sets attempts to 5, persists, and returns 400 INVALID; subsequent call rejects")
    void resetPassword_fifthWrongAttempt_shouldPersistAndRejectSubsequentCalls() {
        String email = "reset.maxatt.service@example.com";
        UUID userId = registerAndVerifyUser(email);
        authService.forgotPassword(new ForgotPasswordRequest(email));

        AuthTokenEntity token = authTokenRepository
                .findAllByUserIdAndTokenTypeAndConsumedAtIsNullOrderByCreatedAtDescIdDesc(userId, AuthTokenType.PASSWORD_RESET)
                .get(0);
        token.setAttempts(4);
        authTokenRepository.save(token);

        // 5th wrong attempt
        assertThatThrownBy(() -> authService.resetPassword(new ResetPasswordRequest(email, "000000", "NewPassword123!")))
                .isInstanceOf(PasswordResetAttemptException.class)
                .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.PASSWORD_RESET_CODE_INVALID));

        AuthTokenEntity tokenAfter5 = authTokenRepository.findById(token.getId()).orElseThrow();
        assertThat(tokenAfter5.getAttempts()).isEqualTo(5);

        // 6th attempt (even with CORRECT code!) should reject immediately without incrementing attempts
        String correctCode = getLatestResetCode(userId);
        assertThatThrownBy(() -> authService.resetPassword(new ResetPasswordRequest(email, correctCode, "NewPassword123!")))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.PASSWORD_RESET_CODE_INVALID));

        AuthTokenEntity tokenAfter6 = authTokenRepository.findById(token.getId()).orElseThrow();
        assertThat(tokenAfter6.getAttempts()).isEqualTo(5);
    }

    @Test
    @DisplayName("resetPassword: exact expiry boundary now == expiresAt and now > expiresAt are invalid and do not increment attempts")
    void resetPassword_expiryBoundaries_shouldBeInvalidAndNotIncrementAttempts() {
        String email = "reset.expiry.service@example.com";
        UUID userId = registerAndVerifyUser(email);
        authService.forgotPassword(new ForgotPasswordRequest(email));
        String code = getLatestResetCode(userId);

        // Boundary: now == expiresAt (12:15:00 UTC)
        currentInstant = currentInstant.plus(Duration.ofMinutes(15));

        assertThatThrownBy(() -> authService.resetPassword(new ResetPasswordRequest(email, code, "NewPassword123!")))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.PASSWORD_RESET_CODE_INVALID));

        AuthTokenEntity token = authTokenRepository.findAll().stream()
                .filter(t -> t.getUserId().equals(userId) && t.getTokenType() == AuthTokenType.PASSWORD_RESET)
                .findFirst().orElseThrow();
        assertThat(token.getAttempts()).isZero();

        // After boundary: now > expiresAt
        currentInstant = currentInstant.plusSeconds(1);
        assertThatThrownBy(() -> authService.resetPassword(new ResetPasswordRequest(email, code, "NewPassword123!")))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.PASSWORD_RESET_CODE_INVALID));
        assertThat(token.getAttempts()).isZero();
    }

    @Test
    @DisplayName("resetPassword: reuse consumed token or no unconsumed token rejects with INVALID")
    void resetPassword_reuseConsumedToken_shouldRejectWithInvalid() {
        String email = "reset.reuse.service@example.com";
        UUID userId = registerAndVerifyUser(email);
        authService.forgotPassword(new ForgotPasswordRequest(email));
        String code = getLatestResetCode(userId);

        // First successful reset
        authService.resetPassword(new ResetPasswordRequest(email, code, "NewPassword123!"));

        // Second attempt with same code
        assertThatThrownBy(() -> authService.resetPassword(new ResetPasswordRequest(email, code, "AnotherPassword123!")))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.PASSWORD_RESET_CODE_INVALID));
    }

    @Test
    @DisplayName("resetPassword: unknown email or non-ACTIVE user rejects with PASSWORD_RESET_CODE_INVALID")
    void resetPassword_unknownOrNonActive_shouldRejectWithInvalid() {
        // Unknown email
        assertThatThrownBy(() -> authService.resetPassword(new ResetPasswordRequest("nonexistent@example.com", "123456", "NewPassword123!")))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.PASSWORD_RESET_CODE_INVALID));

        // Non-ACTIVE user
        String email = "reset.susp.check@example.com";
        UUID userId = registerAndVerifyUser(email);
        authService.forgotPassword(new ForgotPasswordRequest(email));
        String code = getLatestResetCode(userId);

        UserEntity user = userRepository.findById(userId).orElseThrow();
        user.setStatus(UserStatus.SUSPENDED);
        userRepository.save(user);

        assertThatThrownBy(() -> authService.resetPassword(new ResetPasswordRequest(email, code, "NewPassword123!")))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.PASSWORD_RESET_CODE_INVALID));
    }

    // =========================================================================
    // M2.10: CONCURRENCY & RACE BARRIER TESTS
    // =========================================================================

    @Test
    @DisplayName("resetPassword concurrent: same OTP submitted simultaneously yields exactly 1 success")
    void resetPassword_concurrent_sameOtp_shouldYieldExactlyOneSuccess() throws Exception {
        String email = "reset.conc.sameotp@example.com";
        UUID userId = registerAndVerifyUser(email);
        authService.forgotPassword(new ForgotPasswordRequest(email));
        String code = getLatestResetCode(userId);

        int threads = 2;
        ExecutorService executor = Executors.newFixedThreadPool(threads);
        CountDownLatch ready = new CountDownLatch(threads);
        CountDownLatch start = new CountDownLatch(1);

        Future<String> f1 = executor.submit(() -> {
            ready.countDown();
            start.await();
            try {
                authService.resetPassword(new ResetPasswordRequest(email, code, "NewPasswordA123!"));
                return "SUCCESS";
            } catch (BusinessException ex) {
                return ex.errorCode().name();
            }
        });

        Future<String> f2 = executor.submit(() -> {
            ready.countDown();
            start.await();
            try {
                authService.resetPassword(new ResetPasswordRequest(email, code, "NewPasswordB123!"));
                return "SUCCESS";
            } catch (BusinessException ex) {
                return ex.errorCode().name();
            }
        });

        ready.await();
        start.countDown();

        String res1 = f1.get(10, TimeUnit.SECONDS);
        String res2 = f2.get(10, TimeUnit.SECONDS);
        executor.shutdown();

        List<String> results = List.of(res1, res2);
        assertThat(results).containsExactlyInAnyOrder("SUCCESS", "PASSWORD_RESET_CODE_INVALID");
    }

    @Test
    @DisplayName("resetPassword concurrent: two wrong code attempts do not lose update (attempts becomes 2)")
    void resetPassword_concurrent_wrongAttempts_shouldIncrementWithoutLostUpdate() throws Exception {
        String email = "reset.conc.wrong@example.com";
        UUID userId = registerAndVerifyUser(email);
        authService.forgotPassword(new ForgotPasswordRequest(email));

        int threads = 2;
        ExecutorService executor = Executors.newFixedThreadPool(threads);
        CountDownLatch ready = new CountDownLatch(threads);
        CountDownLatch start = new CountDownLatch(1);

        Future<String> f1 = executor.submit(() -> {
            ready.countDown();
            start.await();
            try {
                authService.resetPassword(new ResetPasswordRequest(email, "111111", "NewPassword123!"));
                return "SUCCESS";
            } catch (BusinessException ex) {
                return ex.errorCode().name();
            }
        });

        Future<String> f2 = executor.submit(() -> {
            ready.countDown();
            start.await();
            try {
                authService.resetPassword(new ResetPasswordRequest(email, "222222", "NewPassword123!"));
                return "SUCCESS";
            } catch (BusinessException ex) {
                return ex.errorCode().name();
            }
        });

        ready.await();
        start.countDown();

        String res1 = f1.get(10, TimeUnit.SECONDS);
        String res2 = f2.get(10, TimeUnit.SECONDS);
        executor.shutdown();

        assertThat(res1).isEqualTo("PASSWORD_RESET_CODE_INVALID");
        assertThat(res2).isEqualTo("PASSWORD_RESET_CODE_INVALID");

        AuthTokenEntity token = authTokenRepository
                .findAllByUserIdAndTokenTypeAndConsumedAtIsNullOrderByCreatedAtDescIdDesc(userId, AuthTokenType.PASSWORD_RESET)
                .get(0);
        assertThat(token.getAttempts()).isEqualTo(2);
    }

    @Test
    @DisplayName("concurrency: forgotPassword vs resetPassword serialize via UserCredential lock")
    void forgotPassword_vs_resetPassword_concurrent_shouldSerializeConsistently() throws Exception {
        String email = "forgot.vs.reset@example.com";
        UUID userId = registerAndVerifyUser(email);
        authService.forgotPassword(new ForgotPasswordRequest(email));
        String code = getLatestResetCode(userId);

        int threads = 2;
        ExecutorService executor = Executors.newFixedThreadPool(threads);
        CountDownLatch ready = new CountDownLatch(threads);
        CountDownLatch start = new CountDownLatch(1);

        Future<String> fForgot = executor.submit(() -> {
            ready.countDown();
            start.await();
            try {
                authService.forgotPassword(new ForgotPasswordRequest(email));
                return "FORGOT_SUCCESS";
            } catch (Exception ex) {
                return ex.getMessage();
            }
        });

        Future<String> fReset = executor.submit(() -> {
            ready.countDown();
            start.await();
            try {
                authService.resetPassword(new ResetPasswordRequest(email, code, "NewPasswordAfterForgot123!"));
                return "RESET_SUCCESS";
            } catch (BusinessException ex) {
                return ex.errorCode().name();
            }
        });

        ready.await();
        start.countDown();

        String resForgot = fForgot.get(10, TimeUnit.SECONDS);
        String resReset = fReset.get(10, TimeUnit.SECONDS);
        executor.shutdown();

        assertThat(resForgot).isEqualTo("FORGOT_SUCCESS");
        // Reset either succeeded (if it ran before forgot invalidated old token) or failed with INVALID (if forgot ran first)
        assertThat(resReset).isIn("RESET_SUCCESS", "PASSWORD_RESET_CODE_INVALID");
    }

    @Test
    @DisplayName("CRITICAL MANDATORY TEST: resetPassword vs refreshToken leaves ZERO active refresh sessions surviving after reset commits")
    void resetPassword_vs_refreshToken_concurrency_leavesZeroActiveRefreshSessions() throws Exception {
        String email = "reset.vs.refresh@example.com";
        UUID userId = registerAndVerifyUser(email);

        String compToken = profileCompletionTokenService.generate(userId);
        authService.completeProfile(new CompleteProfileRequest(compToken, "rv_ref", "Rv Ref", null, null));
        LoginResponse loginResp = authService.login(new LoginRequest(email, "Password123!"));
        String rawRefresh = loginResp.refreshToken();

        authService.forgotPassword(new ForgotPasswordRequest(email));
        String resetCode = getLatestResetCode(userId);

        int threads = 2;
        ExecutorService executor = Executors.newFixedThreadPool(threads);
        CountDownLatch ready = new CountDownLatch(threads);
        CountDownLatch start = new CountDownLatch(1);

        Future<String> fReset = executor.submit(() -> {
            ready.countDown();
            start.await();
            try {
                authService.resetPassword(new ResetPasswordRequest(email, resetCode, "NewPasswordPostRefresh123!"));
                return "RESET_SUCCESS";
            } catch (BusinessException ex) {
                return ex.errorCode().name();
            }
        });

        Future<String> fRefresh = executor.submit(() -> {
            ready.countDown();
            start.await();
            try {
                authService.refreshToken(new RefreshTokenRequest(rawRefresh));
                return "REFRESH_SUCCESS";
            } catch (BusinessException ex) {
                return ex.errorCode().name();
            }
        });

        ready.await();
        start.countDown();

        String resetRes = fReset.get(10, TimeUnit.SECONDS);
        String refreshRes = fRefresh.get(10, TimeUnit.SECONDS);
        executor.shutdown();

        assertThat(resetRes).isEqualTo("RESET_SUCCESS");
        // refresh either succeeded (and its S2 was subsequently revoked by reset) or failed (if reset ran first)
        assertThat(refreshRes).isIn("REFRESH_SUCCESS", "REFRESH_TOKEN_INVALID");

        // CRITICAL INVARIANT ASSERTION: ZERO active refresh sessions for this user!
        long activeSessionCount = refreshSessionRepository.findAll().stream()
                .filter(s -> s.getUserId().equals(userId) && s.getRevokedAt() == null)
                .count();
        assertThat(activeSessionCount).isZero();
    }

    @Test
    @DisplayName("same user independent refresh sessions serialize through UserCredential lock and both succeed sequentially")
    void refreshToken_sameUser_independentSessions_serializeAndBothSucceed() throws Exception {
        String email = "refresh.two.sessions@example.com";
        UUID userId = registerAndVerifyUser(email);

        String compToken = profileCompletionTokenService.generate(userId);
        authService.completeProfile(new CompleteProfileRequest(compToken, "ref_two", "Ref Two", null, null));

        // Two logins create two independent active refresh sessions for same user
        LoginResponse login1 = authService.login(new LoginRequest(email, "Password123!"));
        LoginResponse login2 = authService.login(new LoginRequest(email, "Password123!"));
        String rawRefresh1 = login1.refreshToken();
        String rawRefresh2 = login2.refreshToken();

        int threads = 2;
        ExecutorService executor = Executors.newFixedThreadPool(threads);
        CountDownLatch ready = new CountDownLatch(threads);
        CountDownLatch start = new CountDownLatch(1);

        Future<RefreshTokenResponse> f1 = executor.submit(() -> {
            ready.countDown();
            start.await();
            return authService.refreshToken(new RefreshTokenRequest(rawRefresh1));
        });

        Future<RefreshTokenResponse> f2 = executor.submit(() -> {
            ready.countDown();
            start.await();
            return authService.refreshToken(new RefreshTokenRequest(rawRefresh2));
        });

        ready.await();
        start.countDown();

        RefreshTokenResponse resp1 = f1.get(10, TimeUnit.SECONDS);
        RefreshTokenResponse resp2 = f2.get(10, TimeUnit.SECONDS);
        executor.shutdown();

        assertThat(resp1.refreshToken()).isNotBlank();
        assertThat(resp2.refreshToken()).isNotBlank();

        // Both original sessions rotated, both replacement sessions active
        long activeSessions = refreshSessionRepository.findAll().stream()
                .filter(s -> s.getUserId().equals(userId) && s.getRevokedAt() == null)
                .count();
        assertThat(activeSessions).isEqualTo(2);
    }

    // ==========================================
    // M2.12 Session Family Hardening & Metadata Tests
    // ==========================================

    @Test
    @DisplayName("M2.12 login: should set createdAt, sliding expiresAt (now+14d), absoluteExpiresAt (now+30d), and store metadata")
    void login_shouldSetFamilyDeadlineAndMetadata() {
        String email = "m212.login@example.com";
        UUID userId = registerAndVerifyUser(email);
        String token = profileCompletionTokenService.generate(userId);
        authService.completeProfile(new CompleteProfileRequest(token, "m212_login", "M212 Login", null, null));

        Instant t0 = currentInstant;
        SessionClientMetadata metadata = SessionClientMetadata.of("  MacBook Pro M3  ", "192.168.1.50");
        LoginResponse response = authService.login(new LoginRequest(email, "Password123!"), metadata);

        String hash = RefreshTokenService.hashToken(response.refreshToken());
        RefreshSessionEntity session = refreshSessionRepository.findByTokenHash(hash).orElseThrow();

        assertThat(session.getCreatedAt()).isEqualTo(t0);
        assertThat(session.getExpiresAt()).isEqualTo(t0.plus(Duration.ofDays(14)));
        assertThat(session.getAbsoluteExpiresAt()).isEqualTo(t0.plus(Duration.ofDays(30)));
        assertThat(session.getDeviceName()).isEqualTo("MacBook Pro M3");
        assertThat(session.getIpAddress()).isEqualTo("192.168.1.50");
        assertThat(session.getRevokedAt()).isNull();
        assertThat(session.getReplacedBySessionId()).isNull();
    }

    @Test
    @DisplayName("M2.12 login: absent or blank device name should store null deviceName, valid IP stored")
    void login_absentOrBlankDeviceName_shouldStoreNull() {
        String email = "m212.blankdev@example.com";
        UUID userId = registerAndVerifyUser(email);
        String token = profileCompletionTokenService.generate(userId);
        authService.completeProfile(new CompleteProfileRequest(token, "m212_blank", "M212 Blank", null, null));

        // 1. Blank device name
        SessionClientMetadata blankMeta = SessionClientMetadata.of("   ", "10.0.0.1");
        LoginResponse resp1 = authService.login(new LoginRequest(email, "Password123!"), blankMeta);
        RefreshSessionEntity s1 = refreshSessionRepository.findByTokenHash(RefreshTokenService.hashToken(resp1.refreshToken())).orElseThrow();
        assertThat(s1.getDeviceName()).isNull();
        assertThat(s1.getIpAddress()).isEqualTo("10.0.0.1");

        // 2. Missing (null) device name
        SessionClientMetadata nullMeta = SessionClientMetadata.of(null, "2001:0db8:85a3:0000:0000:8a2e:0370:7334");
        LoginResponse resp2 = authService.login(new LoginRequest(email, "Password123!"), nullMeta);
        RefreshSessionEntity s2 = refreshSessionRepository.findByTokenHash(RefreshTokenService.hashToken(resp2.refreshToken())).orElseThrow();
        assertThat(s2.getDeviceName()).isNull();
        assertThat(s2.getIpAddress()).isEqualTo("2001:0db8:85a3:0000:0000:8a2e:0370:7334");
    }

    @Test
    @DisplayName("M2.12 refresh non-legacy: S2 inherits exact S1.absoluteExpiresAt across multiple rotations without sliding")
    void refresh_nonLegacy_shouldInheritAbsoluteExpiresAtAcrossMultipleRotations() {
        String email = "m212.nonlegacy@example.com";
        UUID userId = registerAndVerifyUser(email);
        String token = profileCompletionTokenService.generate(userId);
        authService.completeProfile(new CompleteProfileRequest(token, "m212_rot", "M212 Rot", null, null));

        Instant t0 = currentInstant;
        LoginResponse loginResp = authService.login(new LoginRequest(email, "Password123!"), SessionClientMetadata.of("iPhone 15", "1.1.1.1"));
        String raw1 = loginResp.refreshToken();
        String hash1 = RefreshTokenService.hashToken(raw1);
        RefreshSessionEntity s1 = refreshSessionRepository.findByTokenHash(hash1).orElseThrow();
        Instant originalFamilyDeadline = s1.getAbsoluteExpiresAt();
        assertThat(originalFamilyDeadline).isEqualTo(t0.plus(Duration.ofDays(30)));

        // Rotation 1 (S1 -> S2) at t0 + 2 days
        currentInstant = t0.plus(Duration.ofDays(2));
        RefreshTokenResponse rot1 = authService.refreshToken(
                new RefreshTokenRequest(raw1),
                SessionClientMetadata.of("iPad Air", "2.2.2.2")
        );
        String raw2 = rot1.refreshToken();
        String hash2 = RefreshTokenService.hashToken(raw2);
        RefreshSessionEntity s2 = refreshSessionRepository.findByTokenHash(hash2).orElseThrow();
        RefreshSessionEntity s1Reloaded = refreshSessionRepository.findByTokenHash(hash1).orElseThrow();

        assertThat(s1Reloaded.getRevokedAt()).isEqualTo(currentInstant);
        assertThat(s1Reloaded.getReplacedBySessionId()).isEqualTo(s2.getId());
        assertThat(s1Reloaded.getDeviceName()).isEqualTo("iPhone 15"); // S1 historical metadata preserved
        assertThat(s1Reloaded.getIpAddress()).isEqualTo("1.1.1.1");

        assertThat(s2.getCreatedAt()).isEqualTo(currentInstant);
        assertThat(s2.getExpiresAt()).isEqualTo(currentInstant.plus(Duration.ofDays(14)));
        assertThat(s2.getAbsoluteExpiresAt()).isEqualTo(originalFamilyDeadline); // Exact inheritance, no sliding
        assertThat(s2.getDeviceName()).isEqualTo("iPad Air"); // Updated device
        assertThat(s2.getIpAddress()).isEqualTo("2.2.2.2");

        // Rotation 2 (S2 -> S3) at t0 + 10 days, without device-name header (inherit S2 device name)
        currentInstant = t0.plus(Duration.ofDays(10));
        RefreshTokenResponse rot2 = authService.refreshToken(
                new RefreshTokenRequest(raw2),
                SessionClientMetadata.of(null, "3.3.3.3")
        );
        String raw3 = rot2.refreshToken();
        String hash3 = RefreshTokenService.hashToken(raw3);
        RefreshSessionEntity s3 = refreshSessionRepository.findByTokenHash(hash3).orElseThrow();

        assertThat(s3.getCreatedAt()).isEqualTo(currentInstant);
        assertThat(s3.getExpiresAt()).isEqualTo(currentInstant.plus(Duration.ofDays(14)));
        assertThat(s3.getAbsoluteExpiresAt()).isEqualTo(originalFamilyDeadline); // Still exact original deadline!
        assertThat(s3.getDeviceName()).isEqualTo("iPad Air"); // Inherited from S2
        assertThat(s3.getIpAddress()).isEqualTo("3.3.3.3");
    }

    @Test
    @DisplayName("M2.12 refresh effective expiry boundary: child expiresAt clamped to absoluteExpiresAt when near deadline")
    void refresh_nearFamilyDeadline_shouldClampExpiresAtToAbsoluteExpiresAt() {
        String email = "m212.near@example.com";
        UUID userId = registerAndVerifyUser(email);
        String token = profileCompletionTokenService.generate(userId);
        authService.completeProfile(new CompleteProfileRequest(token, "m212_near", "M212 Near", null, null));

        Instant t0 = currentInstant;
        LoginResponse loginResp = authService.login(new LoginRequest(email, "Password123!"));
        String raw1 = loginResp.refreshToken();
        RefreshSessionEntity s1 = refreshSessionRepository.findByTokenHash(RefreshTokenService.hashToken(raw1)).orElseThrow();
        Instant familyDeadline = s1.getAbsoluteExpiresAt();
        // Ensure s1 sliding expiry is active when testing at the 25-day mark
        s1.setExpiresAt(familyDeadline);
        refreshSessionRepository.save(s1);

        // Advance time to 5 days before family deadline (t0 + 25 days)
        // Now + 14d would be t0 + 39d, which exceeds familyDeadline (t0 + 30d)
        currentInstant = familyDeadline.minus(Duration.ofDays(5));
        RefreshTokenResponse rotResp = authService.refreshToken(new RefreshTokenRequest(raw1));

        RefreshSessionEntity s2 = refreshSessionRepository.findByTokenHash(RefreshTokenService.hashToken(rotResp.refreshToken())).orElseThrow();
        assertThat(s2.getExpiresAt()).isEqualTo(familyDeadline); // Clamped to absoluteExpiresAt!
        assertThat(s2.getExpiresAt()).isBefore(currentInstant.plus(Duration.ofDays(14)));
        assertThat(s2.getAbsoluteExpiresAt()).isEqualTo(familyDeadline);
    }

    @Test
    @DisplayName("M2.12 family deadline boundary: now < absolute succeeds, now == absolute and now > absolute rejected with REFRESH_TOKEN_INVALID")
    void refresh_familyDeadline_boundaryChecks() {
        String email = "m212.bound@example.com";
        UUID userId = registerAndVerifyUser(email);
        String token = profileCompletionTokenService.generate(userId);
        authService.completeProfile(new CompleteProfileRequest(token, "m212_bound", "M212 Bound", null, null));

        LoginResponse loginResp = authService.login(new LoginRequest(email, "Password123!"));
        String raw1 = loginResp.refreshToken();
        RefreshSessionEntity s1 = refreshSessionRepository.findByTokenHash(RefreshTokenService.hashToken(raw1)).orElseThrow();
        Instant absoluteDeadline = s1.getAbsoluteExpiresAt();

        // 1. Boundary: now == absoluteExpiresAt -> REJECTED
        currentInstant = absoluteDeadline;
        assertThatThrownBy(() -> authService.refreshToken(new RefreshTokenRequest(raw1)))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", ErrorCode.REFRESH_TOKEN_INVALID);

        // 2. Boundary: now > absoluteExpiresAt -> REJECTED
        currentInstant = absoluteDeadline.plusSeconds(5);
        assertThatThrownBy(() -> authService.refreshToken(new RefreshTokenRequest(raw1)))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", ErrorCode.REFRESH_TOKEN_INVALID);

        // 3. Boundary: now < absoluteExpiresAt -> SUCCEEDS
        // (Also ensure sliding expiresAt has not expired)
        s1.setExpiresAt(absoluteDeadline);
        refreshSessionRepository.save(s1);

        currentInstant = absoluteDeadline.minusSeconds(1);
        RefreshTokenResponse successResp = authService.refreshToken(new RefreshTokenRequest(raw1));
        assertThat(successResp.refreshToken()).isNotBlank();
    }

    @Test
    @DisplayName("M2.12 legacy transition: pre-V11 session with null absoluteExpiresAt receives now+30d on first refresh, second refresh inherits it")
    void refresh_legacySession_shouldTransitionCleanly() {
        String email = "m212.legacy@example.com";
        UUID userId = registerAndVerifyUser(email);
        String token = profileCompletionTokenService.generate(userId);
        authService.completeProfile(new CompleteProfileRequest(token, "m212_leg", "M212 Leg", null, null));

        Instant t0 = currentInstant;
        LoginResponse loginResp = authService.login(new LoginRequest(email, "Password123!"));
        String raw1 = loginResp.refreshToken();
        String hash1 = RefreshTokenService.hashToken(raw1);

        // Simulate legacy pre-V11 session in database: absoluteExpiresAt == null
        RefreshSessionEntity legacyS1 = refreshSessionRepository.findByTokenHash(hash1).orElseThrow();
        legacyS1.setAbsoluteExpiresAt(null);
        refreshSessionRepository.save(legacyS1);

        // First post-V11 refresh at t0 + 1 day
        currentInstant = t0.plus(Duration.ofDays(1));
        RefreshTokenResponse rot1 = authService.refreshToken(new RefreshTokenRequest(raw1));
        String raw2 = rot1.refreshToken();
        RefreshSessionEntity s2 = refreshSessionRepository.findByTokenHash(RefreshTokenService.hashToken(raw2)).orElseThrow();
        RefreshSessionEntity s1Reloaded = refreshSessionRepository.findByTokenHash(hash1).orElseThrow();

        // S1 remains historical row with null absoluteExpiresAt
        assertThat(s1Reloaded.getAbsoluteExpiresAt()).isNull();
        assertThat(s1Reloaded.getRevokedAt()).isEqualTo(currentInstant);

        // S2 receives transition family deadline = currentInstant + 30d
        Instant establishedFamilyDeadline = currentInstant.plus(Duration.ofDays(30));
        assertThat(s2.getAbsoluteExpiresAt()).isEqualTo(establishedFamilyDeadline);
        assertThat(s2.getExpiresAt()).isEqualTo(currentInstant.plus(Duration.ofDays(14)));

        // Second refresh at t0 + 5 days
        currentInstant = t0.plus(Duration.ofDays(5));
        RefreshTokenResponse rot2 = authService.refreshToken(new RefreshTokenRequest(raw2));
        String raw3 = rot2.refreshToken();
        RefreshSessionEntity s3 = refreshSessionRepository.findByTokenHash(RefreshTokenService.hashToken(raw3)).orElseThrow();

        // S3 inherits exact establishedFamilyDeadline, does NOT slide another 30d
        assertThat(s3.getAbsoluteExpiresAt()).isEqualTo(establishedFamilyDeadline);
    }

    @Test
    @DisplayName("M2.12 metadata normalization: device length rejection and IP length fail-safe")
    void sessionClientMetadata_normalization_rules() {
        // Device > 100 chars -> VALIDATION_FAILED
        String longDevice = "a".repeat(101);
        assertThatThrownBy(() -> SessionClientMetadata.of(longDevice, "127.0.0.1"))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", ErrorCode.VALIDATION_FAILED);

        // Device <= 100 chars -> accepted
        String maxDevice = "a".repeat(100);
        SessionClientMetadata meta100 = SessionClientMetadata.of(maxDevice, "127.0.0.1");
        assertThat(meta100.deviceName()).hasSize(100);

        // IP > 45 chars -> fail-safe null
        String longIp = "b".repeat(46);
        SessionClientMetadata metaLongIp = SessionClientMetadata.of("Phone", longIp);
        assertThat(metaLongIp.ipAddress()).isNull();

        // Normal IPv4 and IPv6
        SessionClientMetadata metaIpv4 = SessionClientMetadata.of("Phone", "192.168.1.1");
        assertThat(metaIpv4.ipAddress()).isEqualTo("192.168.1.1");

        SessionClientMetadata metaIpv6 = SessionClientMetadata.of("Phone", "2001:0db8:85a3:0000:0000:8a2e:0370:7334");
        assertThat(metaIpv6.ipAddress()).isEqualTo("2001:0db8:85a3:0000:0000:8a2e:0370:7334");
    }
}
