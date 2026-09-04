package com.wedo.backend.auth;

import com.wedo.backend.auth.entity.AuthTokenEntity;
import com.wedo.backend.auth.entity.AuthTokenType;
import com.wedo.backend.auth.entity.RefreshSessionEntity;
import com.wedo.backend.auth.repository.AuthTokenRepository;
import com.wedo.backend.auth.repository.RefreshSessionRepository;
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
import com.wedo.backend.auth.entity.AuthTokenEntity;
import com.wedo.backend.auth.entity.AuthTokenType;
import com.wedo.backend.auth.entity.RefreshSessionEntity;
import com.wedo.backend.auth.repository.AuthTokenRepository;
import com.wedo.backend.auth.repository.RefreshSessionRepository;
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

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class AuthJpaMappingTest extends AbstractPostgresIntegrationTest {

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
    private RefreshSessionRepository refreshSessionRepository;

    @Test
    @DisplayName("Should persist UserEntity and verify CITEXT case-insensitive lookup")
    void testUserEntityAndCitext() {
        UUID userId = UUID.randomUUID();
        Instant now = Instant.now();
        String rawEmail = "CaseSensitiveUser_" + userId + "@WeDo.Test";

        UserEntity user = new UserEntity(
                userId,
                rawEmail,
                "CaseUser_" + userId.toString().substring(0, 8),
                "Case Sensitive User",
                UserStatus.PENDING_VERIFICATION,
                now,
                now
        );

        userRepository.saveAndFlush(user);

        // 1. findByEmail case-insensitivity
        Optional<UserEntity> foundByLowerEmail = userRepository.findByEmail(rawEmail.toLowerCase());
        assertThat(foundByLowerEmail).isPresent();
        assertThat(foundByLowerEmail.get().getId()).isEqualTo(userId);

        Optional<UserEntity> foundByUpperEmail = userRepository.findByEmail(rawEmail.toUpperCase());
        assertThat(foundByUpperEmail).isPresent();
        assertThat(foundByUpperEmail.get().getId()).isEqualTo(userId);

        // 2. existsByEmail case-insensitivity
        assertThat(userRepository.existsByEmail(rawEmail.toLowerCase())).isTrue();
        assertThat(userRepository.existsByEmail(rawEmail.toUpperCase())).isTrue();

        // 3. findByUsername case-insensitivity
        String rawUsername = "CaseUser_" + userId.toString().substring(0, 8);
        Optional<UserEntity> foundByLowerUsername = userRepository.findByUsername(rawUsername.toLowerCase());
        assertThat(foundByLowerUsername).isPresent();
        assertThat(foundByLowerUsername.get().getId()).isEqualTo(userId);

        Optional<UserEntity> foundByUpperUsername = userRepository.findByUsername(rawUsername.toUpperCase());
        assertThat(foundByUpperUsername).isPresent();
        assertThat(foundByUpperUsername.get().getId()).isEqualTo(userId);

        // 4. existsByUsername case-insensitivity
        assertThat(userRepository.existsByUsername(rawUsername.toLowerCase())).isTrue();
        assertThat(userRepository.existsByUsername(rawUsername.toUpperCase())).isTrue();
    }

    @Test
    @DisplayName("Should persist and retrieve all Auth-related entities with scalar IDs")
    void testAuthEntitiesPersistence() {
        UUID userId = UUID.randomUUID();
        Instant now = Instant.now();

        // 1. User
        UserEntity user = new UserEntity(
                userId,
                "auth_user_" + userId + "@wedo.test",
                "auth_u_" + userId.toString().substring(0, 8),
                "Auth User",
                UserStatus.ACTIVE,
                now,
                now
        );
        userRepository.save(user);

        // 2. UserCredential
        UserCredentialEntity credential = new UserCredentialEntity(
                userId,
                "$2a$10$hashedPasswordExampleValueForAuthPersistenceTest",
                0,
                null,
                now,
                now,
                now
        );
        userCredentialRepository.save(credential);
        Optional<UserCredentialEntity> foundCred = userCredentialRepository.findById(userId);
        assertThat(foundCred).isPresent();
        assertThat(foundCred.get().getPasswordHash()).contains("hashedPassword");

        // 3. UserPrivacySettings
        UserPrivacySettingsEntity privacy = UserPrivacySettingsEntity.createDefault(userId, now);
        userPrivacySettingsRepository.save(privacy);
        Optional<UserPrivacySettingsEntity> foundPrivacy = userPrivacySettingsRepository.findById(userId);
        assertThat(foundPrivacy).isPresent();
        assertThat(foundPrivacy.get().getDmPolicy()).isEqualTo(DmPolicy.EVERYONE);
        assertThat(foundPrivacy.get().getFriendRequestPolicy()).isEqualTo(FriendRequestPolicy.EVERYONE);

        // 4. UserNotificationSettings
        UserNotificationSettingsEntity notif = UserNotificationSettingsEntity.createDefault(userId, now);
        userNotificationSettingsRepository.save(notif);
        Optional<UserNotificationSettingsEntity> foundNotif = userNotificationSettingsRepository.findById(userId);
        assertThat(foundNotif).isPresent();
        assertThat(foundNotif.get().isPushEnabled()).isTrue();
        assertThat(foundNotif.get().isFundEnabled()).isTrue();

        // 5. AuthToken
        UUID tokenId = UUID.randomUUID();
        AuthTokenEntity token = new AuthTokenEntity(
                tokenId,
                userId,
                AuthTokenType.EMAIL_VERIFICATION,
                "sha256_hash_of_code_123456",
                now.plusSeconds(900),
                0,
                null,
                now
        );
        authTokenRepository.save(token);
        Optional<AuthTokenEntity> foundToken = authTokenRepository.findById(tokenId);
        assertThat(foundToken).isPresent();
        assertThat(foundToken.get().getTokenType()).isEqualTo(AuthTokenType.EMAIL_VERIFICATION);

        // 6. RefreshSession
        UUID sessionId = UUID.randomUUID();
        String sessionTokenHash = "sha256_hash_refresh_session_" + sessionId;
        RefreshSessionEntity session = new RefreshSessionEntity(
                sessionId,
                userId,
                sessionTokenHash,
                now.plusSeconds(14 * 86400),
                null,
                null,
                "iPhone 15 Pro",
                "127.0.0.1",
                now
        );
        refreshSessionRepository.save(session);
        Optional<RefreshSessionEntity> foundSession = refreshSessionRepository.findByTokenHash(sessionTokenHash);
        assertThat(foundSession).isPresent();
        assertThat(foundSession.get().getDeviceName()).isEqualTo("iPhone 15 Pro");
        assertThat(foundSession.get().getUserId()).isEqualTo(userId);
    }
}
