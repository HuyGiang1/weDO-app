package com.wedo.backend.auth.service;

import com.wedo.backend.auth.dto.RegisterRequest;
import com.wedo.backend.auth.dto.RegisterResponse;
import com.wedo.backend.auth.dto.ResendVerificationRequest;
import com.wedo.backend.auth.dto.ResendVerificationResponse;
import com.wedo.backend.auth.dto.VerifyEmailRequest;
import com.wedo.backend.auth.dto.VerifyEmailResponse;
import com.wedo.backend.auth.entity.AuthTokenEntity;
import com.wedo.backend.auth.entity.AuthTokenType;
import com.wedo.backend.auth.event.EmailVerificationRequestedEvent;
import com.wedo.backend.auth.exception.VerificationAttemptException;
import com.wedo.backend.auth.repository.AuthTokenRepository;
import com.wedo.backend.auth.security.AuthTokenHasher;
import com.wedo.backend.auth.security.VerificationCodeGenerator;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
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
    private final ApplicationEventPublisher eventPublisher;
    private final Clock clock;

    public AuthService(
            UserRepository userRepository,
            UserCredentialRepository userCredentialRepository,
            UserPrivacySettingsRepository userPrivacySettingsRepository,
            UserNotificationSettingsRepository userNotificationSettingsRepository,
            AuthTokenRepository authTokenRepository,
            PasswordEncoder passwordEncoder,
            VerificationCodeGenerator verificationCodeGenerator,
            AuthTokenHasher authTokenHasher,
            ApplicationEventPublisher eventPublisher,
            Clock clock
    ) {
        this.userRepository = userRepository;
        this.userCredentialRepository = userCredentialRepository;
        this.userPrivacySettingsRepository = userPrivacySettingsRepository;
        this.userNotificationSettingsRepository = userNotificationSettingsRepository;
        this.authTokenRepository = authTokenRepository;
        this.passwordEncoder = passwordEncoder;
        this.verificationCodeGenerator = verificationCodeGenerator;
        this.authTokenHasher = authTokenHasher;
        this.eventPublisher = eventPublisher;
        this.clock = clock;
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

            return VerifyEmailResponse.of(user.getId(), UserStatus.ACTIVE, now);
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
}
