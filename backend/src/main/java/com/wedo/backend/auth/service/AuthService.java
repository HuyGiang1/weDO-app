package com.wedo.backend.auth.service;

import com.wedo.backend.auth.dto.CompleteProfileRequest;
import com.wedo.backend.auth.dto.CompleteProfileResponse;
import com.wedo.backend.auth.dto.LoginRequest;
import com.wedo.backend.auth.dto.LoginResponse;
import com.wedo.backend.auth.dto.LogoutRequest;
import com.wedo.backend.auth.dto.RefreshTokenRequest;
import com.wedo.backend.auth.dto.RefreshTokenResponse;
import com.wedo.backend.auth.dto.RegisterRequest;
import com.wedo.backend.auth.dto.RegisterResponse;
import com.wedo.backend.auth.dto.ResendVerificationRequest;
import com.wedo.backend.auth.dto.ResendVerificationResponse;
import com.wedo.backend.auth.dto.UserSummaryDto;
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
import com.wedo.backend.auth.security.VerificationCodeGenerator;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.security.jwt.JwtService;
import com.wedo.backend.notification.entity.UserNotificationSettingsEntity;
import com.wedo.backend.notification.repository.UserNotificationSettingsRepository;
import com.wedo.backend.user.entity.UserCredentialEntity;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserPrivacySettingsEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserCredentialRepository;
import com.wedo.backend.user.repository.UserPrivacySettingsRepository;
import com.wedo.backend.user.repository.UserRepository;
import org.hibernate.exception.ConstraintViolationException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
import java.util.UUID;

@Service
public class AuthService {

    private static final String USERS_EMAIL_KEY_CONSTRAINT = "users_email_key";
    private static final String USERS_USERNAME_KEY_CONSTRAINT = "users_username_key";
    private static final String POSTGRES_UNIQUE_VIOLATION_SQL_STATE = "23505";
    private static final Duration EMAIL_VERIFICATION_TTL = Duration.ofMinutes(15);
    private static final Duration RESEND_COOLDOWN = Duration.ofSeconds(60);
    private static final int MAX_VERIFICATION_ATTEMPTS = 5;

    private final UserRepository userRepository;
    private final UserCredentialRepository userCredentialRepository;
    private final UserPrivacySettingsRepository userPrivacySettingsRepository;
    private final UserNotificationSettingsRepository userNotificationSettingsRepository;
    private final AuthTokenRepository authTokenRepository;
    private final PasswordEncoder passwordEncoder;
    private final VerificationCodeGenerator verificationCodeGenerator;
    private final AuthTokenHasher authTokenHasher;
    private final ProfileCompletionTokenService profileCompletionTokenService;
    private final JwtService jwtService;
    private final RefreshTokenService refreshTokenService;
    private final RefreshSessionRepository refreshSessionRepository;
    private final ApplicationEventPublisher eventPublisher;
    private final Clock clock;
    private final int maxFailedAttempts;
    private final Duration lockDuration;
    private final String dummyPasswordHash;

    public AuthService(
            UserRepository userRepository,
            UserCredentialRepository userCredentialRepository,
            UserPrivacySettingsRepository userPrivacySettingsRepository,
            UserNotificationSettingsRepository userNotificationSettingsRepository,
            AuthTokenRepository authTokenRepository,
            PasswordEncoder passwordEncoder,
            VerificationCodeGenerator verificationCodeGenerator,
            AuthTokenHasher authTokenHasher,
            ProfileCompletionTokenService profileCompletionTokenService,
            JwtService jwtService,
            RefreshTokenService refreshTokenService,
            RefreshSessionRepository refreshSessionRepository,
            ApplicationEventPublisher eventPublisher,
            Clock clock,
            @Value("${security.login.max-failed-attempts:5}") int maxFailedAttempts,
            @Value("${security.login.lock-duration:15m}") Duration lockDuration
    ) {
        if (maxFailedAttempts <= 0) {
            throw new IllegalStateException("max-failed-attempts must be positive");
        }
        if (lockDuration == null || lockDuration.isZero() || lockDuration.isNegative()) {
            throw new IllegalStateException("lock-duration must be positive");
        }

        this.userRepository = userRepository;
        this.userCredentialRepository = userCredentialRepository;
        this.userPrivacySettingsRepository = userPrivacySettingsRepository;
        this.userNotificationSettingsRepository = userNotificationSettingsRepository;
        this.authTokenRepository = authTokenRepository;
        this.passwordEncoder = passwordEncoder;
        this.verificationCodeGenerator = verificationCodeGenerator;
        this.authTokenHasher = authTokenHasher;
        this.profileCompletionTokenService = profileCompletionTokenService;
        this.jwtService = jwtService;
        this.refreshTokenService = refreshTokenService;
        this.refreshSessionRepository = refreshSessionRepository;
        this.eventPublisher = eventPublisher;
        this.clock = clock;
        this.maxFailedAttempts = maxFailedAttempts;
        this.lockDuration = lockDuration;
        this.dummyPasswordHash = passwordEncoder.encode("wedo-login-dummy-password");
    }

    @Transactional
    public RegisterResponse register(RegisterRequest request) {
        String normalizedEmail = request.email().trim().toLowerCase(Locale.ROOT);

        if (userRepository.existsByEmail(normalizedEmail)) {
            throw new BusinessException(ErrorCode.EMAIL_ALREADY_EXISTS);
        }

        Instant now = clock.instant();
        String passwordHash = passwordEncoder.encode(request.password());

        UUID userId = UUID.randomUUID();
        UserEntity user = new UserEntity(
                userId,
                normalizedEmail,
                null,
                null,
                UserStatus.PENDING_VERIFICATION,
                now,
                now
        );

        try {
            userRepository.saveAndFlush(user);
        } catch (DataIntegrityViolationException ex) {
            if (isEmailUniqueViolation(ex)) {
                throw new BusinessException(ErrorCode.EMAIL_ALREADY_EXISTS);
            }
            throw ex;
        }

        UserCredentialEntity credential = new UserCredentialEntity(
                userId,
                passwordHash,
                0,
                null,
                now,
                now,
                now
        );
        userCredentialRepository.save(credential);

        UserPrivacySettingsEntity privacySettings = UserPrivacySettingsEntity.createDefault(userId, now);
        userPrivacySettingsRepository.save(privacySettings);

        UserNotificationSettingsEntity notificationSettings = UserNotificationSettingsEntity.createDefault(userId, now);
        userNotificationSettingsRepository.save(notificationSettings);

        String rawCode = verificationCodeGenerator.generate();
        String tokenHash = authTokenHasher.hash(userId, AuthTokenType.EMAIL_VERIFICATION, rawCode);

        AuthTokenEntity authToken = new AuthTokenEntity(
                UUID.randomUUID(),
                userId,
                AuthTokenType.EMAIL_VERIFICATION,
                tokenHash,
                now.plus(EMAIL_VERIFICATION_TTL),
                0,
                null,
                now
        );
        authTokenRepository.save(authToken);

        eventPublisher.publishEvent(new EmailVerificationRequestedEvent(
                userId,
                normalizedEmail,
                rawCode
        ));

        return RegisterResponse.of(userId, normalizedEmail, UserStatus.PENDING_VERIFICATION);
    }

    @Transactional(noRollbackFor = VerificationAttemptException.class)
    public VerifyEmailResponse verifyEmail(VerifyEmailRequest request) {
        UserEntity user = userRepository.findByIdWithLock(request.userId())
                .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));

        if (user.getStatus() == UserStatus.ACTIVE) {
            throw new BusinessException(ErrorCode.EMAIL_ALREADY_VERIFIED);
        }

        if (user.getStatus() != UserStatus.PENDING_VERIFICATION) {
            throw new BusinessException(ErrorCode.ACCESS_DENIED);
        }

        AuthTokenEntity activeToken = authTokenRepository
                .findFirstByUserIdAndTokenTypeAndConsumedAtIsNullOrderByCreatedAtDesc(user.getId(), AuthTokenType.EMAIL_VERIFICATION)
                .orElseThrow(() -> new BusinessException(ErrorCode.VERIFICATION_CODE_INVALID));

        Instant now = clock.instant();

        if (!now.isBefore(activeToken.getExpiresAt())) {
            throw new BusinessException(ErrorCode.VERIFICATION_CODE_EXPIRED);
        }

        if (activeToken.getAttempts() >= MAX_VERIFICATION_ATTEMPTS) {
            throw new BusinessException(ErrorCode.VERIFICATION_ATTEMPTS_EXCEEDED);
        }

        boolean matches = authTokenHasher.matches(
                user.getId(),
                AuthTokenType.EMAIL_VERIFICATION,
                request.code(),
                activeToken.getTokenHash()
        );

        if (matches) {
            activeToken.setConsumedAt(now);
            authTokenRepository.save(activeToken);

            user.setStatus(UserStatus.ACTIVE);
            user.setEmailVerifiedAt(now);
            user.setUpdatedAt(now);
            userRepository.save(user);

            String profileCompletionToken = profileCompletionTokenService.generate(user.getId());
            return VerifyEmailResponse.of(user.getId(), UserStatus.ACTIVE, now, profileCompletionToken);
        }

        String candidateHash = authTokenHasher.hash(
                user.getId(),
                AuthTokenType.EMAIL_VERIFICATION,
                request.code()
        );

        boolean isStaleCode = authTokenRepository
                .existsByUserIdAndTokenTypeAndTokenHashAndConsumedAtIsNotNull(
                        user.getId(),
                        AuthTokenType.EMAIL_VERIFICATION,
                        candidateHash
                );

        if (isStaleCode) {
            throw new BusinessException(ErrorCode.VERIFICATION_CODE_INVALID);
        }

        activeToken.setAttempts(activeToken.getAttempts() + 1);
        authTokenRepository.save(activeToken);

        if (activeToken.getAttempts() >= MAX_VERIFICATION_ATTEMPTS) {
            throw new VerificationAttemptException(ErrorCode.VERIFICATION_ATTEMPTS_EXCEEDED);
        } else {
            throw new VerificationAttemptException(ErrorCode.VERIFICATION_CODE_INVALID);
        }
    }

    @Transactional
    public ResendVerificationResponse resendVerification(ResendVerificationRequest request) {
        UserEntity user = userRepository.findByIdWithLock(request.userId())
                .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));

        if (user.getStatus() == UserStatus.ACTIVE) {
            throw new BusinessException(ErrorCode.EMAIL_ALREADY_VERIFIED);
        }

        if (user.getStatus() != UserStatus.PENDING_VERIFICATION) {
            throw new BusinessException(ErrorCode.ACCESS_DENIED);
        }

        Instant now = clock.instant();

        Optional<AuthTokenEntity> latestTokenOpt = authTokenRepository
                .findFirstByUserIdAndTokenTypeOrderByCreatedAtDesc(user.getId(), AuthTokenType.EMAIL_VERIFICATION);

        if (latestTokenOpt.isPresent()) {
            Instant boundary = latestTokenOpt.get().getCreatedAt().plus(RESEND_COOLDOWN);
            if (now.isBefore(boundary)) {
                throw new BusinessException(ErrorCode.RESEND_COOLDOWN_ACTIVE);
            }
        }

        List<AuthTokenEntity> unconsumedTokens = authTokenRepository
                .findAllByUserIdAndTokenTypeAndConsumedAtIsNull(user.getId(), AuthTokenType.EMAIL_VERIFICATION);
        for (AuthTokenEntity oldToken : unconsumedTokens) {
            oldToken.setConsumedAt(now);
        }
        if (!unconsumedTokens.isEmpty()) {
            authTokenRepository.saveAll(unconsumedTokens);
        }

        String rawCode = verificationCodeGenerator.generate();
        String tokenHash = authTokenHasher.hash(user.getId(), AuthTokenType.EMAIL_VERIFICATION, rawCode);

        AuthTokenEntity newToken = new AuthTokenEntity(
                UUID.randomUUID(),
                user.getId(),
                AuthTokenType.EMAIL_VERIFICATION,
                tokenHash,
                now.plus(EMAIL_VERIFICATION_TTL),
                0,
                null,
                now
        );
        authTokenRepository.save(newToken);

        eventPublisher.publishEvent(new EmailVerificationRequestedEvent(
                user.getId(),
                user.getEmail(),
                rawCode
        ));

        return ResendVerificationResponse.of(user.getId(), RESEND_COOLDOWN.toSeconds());
    }

    private boolean isEmailUniqueViolation(DataIntegrityViolationException ex) {
        Throwable current = ex;
        while (current != null) {
            if (current instanceof ConstraintViolationException cve) {
                String constraint = cve.getConstraintName();
                if (constraint != null && constraint.equalsIgnoreCase(USERS_EMAIL_KEY_CONSTRAINT)) {
                    return true;
                }
                if (cve.getSQLException() != null) {
                    String sqlState = cve.getSQLException().getSQLState();
                    if (POSTGRES_UNIQUE_VIOLATION_SQL_STATE.equals(sqlState)
                            && constraint != null
                            && constraint.contains("users_email")) {
                        return true;
                    }
                }
            }
            if (current instanceof java.sql.SQLException sqlEx) {
                String sqlState = sqlEx.getSQLState();
                if (POSTGRES_UNIQUE_VIOLATION_SQL_STATE.equals(sqlState)) {
                    String message = sqlEx.getMessage();
                    if (message != null && message.contains(USERS_EMAIL_KEY_CONSTRAINT)) {
                        return true;
                    }
                }
            }
            current = current.getCause();
        }
        return false;
    }

    @Transactional(readOnly = true)
    public UsernameAvailabilityResponse checkUsernameAvailability(String username) {
        String canonicalUsername = username.toLowerCase(Locale.ROOT);
        boolean available = !userRepository.existsByUsername(canonicalUsername);
        return UsernameAvailabilityResponse.of(canonicalUsername, available);
    }

    @Transactional
    public CompleteProfileResponse completeProfile(CompleteProfileRequest request) {
        UUID userId = profileCompletionTokenService.extractAndValidate(request.profileCompletionToken());

        UserEntity user = userRepository.findByIdWithLock(userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));

        if (user.getStatus() != UserStatus.ACTIVE) {
            throw new BusinessException(ErrorCode.ACCESS_DENIED);
        }

        if (user.getUsername() != null) {
            throw new BusinessException(ErrorCode.PROFILE_ALREADY_COMPLETED);
        }

        String canonicalUsername = request.username().toLowerCase(Locale.ROOT);

        if (userRepository.existsByUsername(canonicalUsername)) {
            throw new BusinessException(ErrorCode.USERNAME_ALREADY_EXISTS);
        }

        String displayName = request.displayName().trim();
        String bio = null;
        if (request.bio() != null) {
            String trimmedBio = request.bio().trim();
            if (!trimmedBio.isEmpty()) {
                bio = trimmedBio;
            }
        }
        String avatarStorageKey = request.avatarStorageKey();

        Instant now = clock.instant();
        user.setUsername(canonicalUsername);
        user.setDisplayName(displayName);
        user.setBio(bio);
        user.setAvatarStorageKey(avatarStorageKey);
        user.setUpdatedAt(now);

        try {
            userRepository.saveAndFlush(user);
        } catch (DataIntegrityViolationException ex) {
            if (isUsernameUniqueViolation(ex)) {
                throw new BusinessException(ErrorCode.USERNAME_ALREADY_EXISTS);
            }
            throw ex;
        }

        return CompleteProfileResponse.of(user.getId(), user.getUsername(), user.getDisplayName(), user.getStatus());
    }

    @Transactional(noRollbackFor = LoginAttemptException.class)
    public LoginResponse login(LoginRequest request) {
        String normalizedEmail = request.email().trim().toLowerCase(Locale.ROOT);
        Optional<UserEntity> userOpt = userRepository.findByEmail(normalizedEmail);

        if (userOpt.isEmpty()) {
            passwordEncoder.matches(request.password(), dummyPasswordHash);
            throw new BusinessException(ErrorCode.AUTH_INVALID_CREDENTIALS);
        }

        UserEntity user = userOpt.get();
        Optional<UserCredentialEntity> credentialOpt = userCredentialRepository.findByUserIdWithLock(user.getId());

        if (credentialOpt.isEmpty()) {
            passwordEncoder.matches(request.password(), dummyPasswordHash);
            throw new BusinessException(ErrorCode.AUTH_INVALID_CREDENTIALS);
        }

        UserCredentialEntity credential = credentialOpt.get();
        Instant now = clock.instant();
        boolean currentlyLocked = credential.getLockedUntil() != null && now.isBefore(credential.getLockedUntil());

        boolean passwordMatches = passwordEncoder.matches(request.password(), credential.getPasswordHash());

        if (!passwordMatches) {
            if (currentlyLocked) {
                // A. PASSWORD WRONG + currentlyLocked: no increment, no lock extension
                throw new LoginAttemptException(ErrorCode.AUTH_INVALID_CREDENTIALS);
            }

            if (credential.getLockedUntil() != null) {
                // B. PASSWORD WRONG + lock expired: start new cycle
                credential.setFailedAttempts(1);
                credential.setLockedUntil(null);
                credential.setUpdatedAt(now);
                userCredentialRepository.save(credential);
                throw new LoginAttemptException(ErrorCode.AUTH_INVALID_CREDENTIALS);
            }

            // C. PASSWORD WRONG + normal unlocked cycle:
            int newFailedAttempts = credential.getFailedAttempts() + 1;
            credential.setFailedAttempts(newFailedAttempts);
            if (newFailedAttempts >= maxFailedAttempts) {
                credential.setLockedUntil(now.plus(lockDuration));
            }
            credential.setUpdatedAt(now);
            userCredentialRepository.save(credential);
            throw new LoginAttemptException(ErrorCode.AUTH_INVALID_CREDENTIALS);
        }

        // PASSWORD MATCHES
        if (currentlyLocked) {
            // D. PASSWORD CORRECT + currentlyLocked
            throw new BusinessException(ErrorCode.ACCOUNT_LOCKED);
        }

        // Check status only after password matches and account is not actively locked:
        if (user.getStatus() == UserStatus.PENDING_VERIFICATION) {
            throw new BusinessException(ErrorCode.EMAIL_NOT_VERIFIED);
        }
        if (user.getStatus() == UserStatus.SUSPENDED) {
            throw new BusinessException(ErrorCode.ACCOUNT_SUSPENDED);
        }
        if (user.getStatus() == UserStatus.DEACTIVATED) {
            throw new BusinessException(ErrorCode.ACCOUNT_DEACTIVATED);
        }

        // ACTIVE success: reset failed attempts and lock
        if (credential.getFailedAttempts() != 0 || credential.getLockedUntil() != null) {
            credential.setFailedAttempts(0);
            credential.setLockedUntil(null);
            credential.setUpdatedAt(now);
            userCredentialRepository.save(credential);
        }

        if (user.getUsername() == null) {
            String profileCompletionToken = profileCompletionTokenService.generate(user.getId());
            return LoginResponse.recovery(user.getId(), user.getStatus(), profileCompletionToken);
        }

        String accessToken = jwtService.generateAccessToken(user.getId());
        Instant accessTokenExpiresAt = jwtService.extractExpiration(accessToken);
        RefreshTokenService.IssuedRefreshToken issuedRefresh = refreshTokenService.issue(user.getId());

        UserSummaryDto userSummary = new UserSummaryDto(
                user.getId(),
                user.getEmail(),
                user.getUsername(),
                user.getDisplayName(),
                user.getAvatarStorageKey()
        );

        return LoginResponse.authenticated(
                user.getId(),
                user.getStatus(),
                accessToken,
                issuedRefresh.rawToken(),
                accessTokenExpiresAt,
                userSummary
        );
    }

    @Transactional(noRollbackFor = RefreshSessionStatusException.class)
    public RefreshTokenResponse refreshToken(RefreshTokenRequest request) {
        if (request == null || request.refreshToken() == null || request.refreshToken().isBlank()) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }

        String rawToken = request.refreshToken();
        String tokenHash = RefreshTokenService.hashToken(rawToken);

        Optional<RefreshSessionEntity> sessionOpt = refreshSessionRepository.findByTokenHashWithLock(tokenHash);
        if (sessionOpt.isEmpty()) {
            throw new BusinessException(ErrorCode.REFRESH_TOKEN_INVALID);
        }

        RefreshSessionEntity session = sessionOpt.get();
        Instant now = clock.instant();

        if (session.getRevokedAt() != null) {
            throw new BusinessException(ErrorCode.REFRESH_TOKEN_INVALID);
        }

        if (!now.isBefore(session.getExpiresAt())) {
            throw new BusinessException(ErrorCode.REFRESH_TOKEN_INVALID);
        }

        Optional<UserEntity> userOpt = userRepository.findById(session.getUserId());
        if (userOpt.isEmpty()) {
            throw new BusinessException(ErrorCode.REFRESH_TOKEN_INVALID);
        }

        UserEntity user = userOpt.get();

        if (user.getStatus() == UserStatus.PENDING_VERIFICATION) {
            session.setRevokedAt(now);
            refreshSessionRepository.save(session);
            throw new RefreshSessionStatusException(ErrorCode.EMAIL_NOT_VERIFIED);
        }
        if (user.getStatus() == UserStatus.SUSPENDED) {
            session.setRevokedAt(now);
            refreshSessionRepository.save(session);
            throw new RefreshSessionStatusException(ErrorCode.ACCOUNT_SUSPENDED);
        }
        if (user.getStatus() == UserStatus.DEACTIVATED) {
            session.setRevokedAt(now);
            refreshSessionRepository.save(session);
            throw new RefreshSessionStatusException(ErrorCode.ACCOUNT_DEACTIVATED);
        }

        String accessToken = jwtService.generateAccessToken(user.getId());
        Instant accessTokenExpiresAt = jwtService.extractExpiration(accessToken);

        RefreshTokenService.IssuedRefreshToken issuedRefresh = refreshTokenService.issue(user.getId());

        session.setRevokedAt(now);
        session.setReplacedBySessionId(issuedRefresh.sessionId());
        refreshSessionRepository.save(session);

        return RefreshTokenResponse.of(
                accessToken,
                issuedRefresh.rawToken(),
                accessTokenExpiresAt,
                issuedRefresh.expiresAt()
        );
    }

    @Transactional
    public void logout(LogoutRequest request) {
        if (request == null || request.refreshToken() == null || request.refreshToken().isBlank()) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }

        String rawToken = request.refreshToken();
        String tokenHash = RefreshTokenService.hashToken(rawToken);

        Optional<RefreshSessionEntity> sessionOpt = refreshSessionRepository.findByTokenHashWithLock(tokenHash);
        if (sessionOpt.isEmpty()) {
            throw new BusinessException(ErrorCode.REFRESH_TOKEN_INVALID);
        }

        RefreshSessionEntity session = sessionOpt.get();

        if (session.getRevokedAt() != null) {
            if (session.getReplacedBySessionId() != null) {
                throw new BusinessException(ErrorCode.REFRESH_TOKEN_INVALID);
            }
            return;
        }

        Instant now = clock.instant();
        if (!now.isBefore(session.getExpiresAt())) {
            throw new BusinessException(ErrorCode.REFRESH_TOKEN_INVALID);
        }

        session.setRevokedAt(now);
        refreshSessionRepository.save(session);
    }

    private boolean isUsernameUniqueViolation(DataIntegrityViolationException ex) {
        Throwable current = ex;
        while (current != null) {
            if (current instanceof ConstraintViolationException cve) {
                String constraint = cve.getConstraintName();
                if (constraint != null && constraint.equalsIgnoreCase(USERS_USERNAME_KEY_CONSTRAINT)) {
                    return true;
                }
                if (cve.getSQLException() != null) {
                    String sqlState = cve.getSQLException().getSQLState();
                    if (POSTGRES_UNIQUE_VIOLATION_SQL_STATE.equals(sqlState)
                            && constraint != null
                            && constraint.contains("users_username")) {
                        return true;
                    }
                }
            }
            if (current instanceof java.sql.SQLException sqlEx) {
                String sqlState = sqlEx.getSQLState();
                if (POSTGRES_UNIQUE_VIOLATION_SQL_STATE.equals(sqlState)) {
                    String message = sqlEx.getMessage();
                    if (message != null && message.contains(USERS_USERNAME_KEY_CONSTRAINT)) {
                        return true;
                    }
                }
            }
            current = current.getCause();
        }
        return false;
    }
}
