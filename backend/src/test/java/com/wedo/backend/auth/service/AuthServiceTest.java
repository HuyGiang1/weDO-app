package com.wedo.backend.auth.service;

import com.wedo.backend.auth.dto.RegisterRequest;
import com.wedo.backend.auth.dto.RegisterResponse;
import com.wedo.backend.auth.entity.AuthTokenEntity;
import com.wedo.backend.auth.entity.AuthTokenType;
import com.wedo.backend.auth.event.EmailVerificationRequestedEvent;
import com.wedo.backend.auth.repository.AuthTokenRepository;
import com.wedo.backend.auth.security.AuthTokenHasher;
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
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.event.ApplicationEvents;
import org.springframework.test.context.event.RecordApplicationEvents;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

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
    private ApplicationEvents applicationEvents;

    @Test
    @DisplayName("register should persist user, credentials, privacy, notification, and auth token atomically")
    void register_shouldPersistAllEntitiesAndPublishEvent() {
        String rawEmail = "  Alice.Smith@Example.COM  ";
        String normalizedEmail = "alice.smith@example.com";
        String rawPassword = "SecurePassword123!";

        RegisterRequest request = new RegisterRequest(rawEmail, rawPassword);
        Instant beforeRegister = Instant.now().minus(Duration.ofSeconds(1));

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
        assertThat(user.getCreatedAt()).isAfterOrEqualTo(beforeRegister);
        assertThat(user.getUpdatedAt()).isAfterOrEqualTo(beforeRegister);

        // 2. Verify UserCredentialEntity
        Optional<UserCredentialEntity> credOpt = userCredentialRepository.findById(userId);
        assertThat(credOpt).isPresent();
        UserCredentialEntity cred = credOpt.get();
        assertThat(cred.getPasswordHash()).isNotEqualTo(rawPassword);
        assertThat(passwordEncoder.matches(rawPassword, cred.getPasswordHash())).isTrue();
        assertThat(cred.getFailedAttempts()).isZero();
        assertThat(cred.getLockedUntil()).isNull();
        assertThat(cred.getPasswordChangedAt()).isAfterOrEqualTo(beforeRegister);

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
        assertThat(token.getExpiresAt()).isAfter(Instant.now());
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
}
