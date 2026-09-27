package com.wedo.backend.local;

import com.wedo.backend.group.entity.GroupEntity;
import com.wedo.backend.group.entity.GroupMembershipEntity;
import com.wedo.backend.group.entity.GroupMembershipStatus;
import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.entity.GroupSettingsEntity;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.group.repository.GroupMembershipRepository;
import com.wedo.backend.group.repository.GroupRepository;
import com.wedo.backend.group.repository.GroupSettingsRepository;
import com.wedo.backend.notification.entity.UserNotificationSettingsEntity;
import com.wedo.backend.notification.repository.UserNotificationSettingsRepository;
import com.wedo.backend.user.entity.UserCredentialEntity;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserPrivacySettingsEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserCredentialRepository;
import com.wedo.backend.user.repository.UserPrivacySettingsRepository;
import com.wedo.backend.user.repository.UserRepository;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/** Local-only, opt-in QA identities for manual multi-account testing. */
@Component
@Profile("local")
@ConditionalOnProperty(prefix = "wedo.local-test-data", name = "enabled", havingValue = "true")
public class LocalTestDataSeeder implements ApplicationRunner {
    static final String PASSWORD = "WeDOTest@123";
    static final String GROUP_NAME = "weDO QA Team";

    private final UserRepository users;
    private final UserCredentialRepository credentials;
    private final UserPrivacySettingsRepository privacySettings;
    private final UserNotificationSettingsRepository notifications;
    private final GroupRepository groups;
    private final GroupSettingsRepository groupSettings;
    private final GroupMembershipRepository memberships;
    private final PasswordEncoder passwordEncoder;
    private final Clock clock;

    public LocalTestDataSeeder(UserRepository users, UserCredentialRepository credentials,
            UserPrivacySettingsRepository privacySettings, UserNotificationSettingsRepository notifications,
            GroupRepository groups, GroupSettingsRepository groupSettings, GroupMembershipRepository memberships,
            PasswordEncoder passwordEncoder, Clock clock) {
        this.users = users;
        this.credentials = credentials;
        this.privacySettings = privacySettings;
        this.notifications = notifications;
        this.groups = groups;
        this.groupSettings = groupSettings;
        this.memberships = memberships;
        this.passwordEncoder = passwordEncoder;
        this.clock = clock;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        Instant now = clock.instant();
        UserEntity owner = user("owner@wedo.local", "qa_owner", "QA Owner", now);
        UserEntity admin = user("admin@wedo.local", "qa_admin", "QA Admin", now);
        UserEntity member1 = user("member1@wedo.local", "qa_member1", "QA Member 1", now);
        UserEntity member2 = user("member2@wedo.local", "qa_member2", "QA Member 2", now);
        user("outsider@wedo.local", "qa_outsider", "QA Outsider", now);

        GroupEntity group = groups.findByName(GROUP_NAME).orElseGet(() ->
                groups.save(new GroupEntity(UUID.randomUUID(), GROUP_NAME, null, null, GroupStatus.ACTIVE,
                        owner.getId(), now, now)));
        groupSettings.findById(group.getId()).orElseGet(() -> groupSettings.save(GroupSettingsEntity.createDefault(group.getId(), now)));
        membership(group.getId(), owner.getId(), GroupRole.OWNER, now);
        membership(group.getId(), admin.getId(), GroupRole.ADMIN, now);
        membership(group.getId(), member1.getId(), GroupRole.MEMBER, now);
        membership(group.getId(), member2.getId(), GroupRole.MEMBER, now);
    }

    private UserEntity user(String email, String username, String displayName, Instant now) {
        UserEntity user = users.findByEmail(email).orElseGet(() -> users.save(new UserEntity(
                UUID.randomUUID(), email, username, displayName, UserStatus.ACTIVE, now, now)));
        user.setUsername(username);
        user.setDisplayName(displayName);
        user.setStatus(UserStatus.ACTIVE);
        user.setEmailVerifiedAt(now);
        user.setUpdatedAt(now);
        users.save(user);
        credentials.findById(user.getId()).ifPresentOrElse(credential -> {
            if (!passwordEncoder.matches(PASSWORD, credential.getPasswordHash())) {
                credential.setPasswordHash(passwordEncoder.encode(PASSWORD));
                credential.setPasswordChangedAt(now);
                credential.setUpdatedAt(now);
                credentials.save(credential);
            }
        }, () -> credentials.save(new UserCredentialEntity(user.getId(), passwordEncoder.encode(PASSWORD), 0, null, now, now, now)));
        privacySettings.findById(user.getId()).orElseGet(() -> privacySettings.save(UserPrivacySettingsEntity.createDefault(user.getId(), now)));
        notifications.findById(user.getId()).orElseGet(() -> notifications.save(UserNotificationSettingsEntity.createDefault(user.getId(), now)));
        return user;
    }

    private void membership(UUID groupId, UUID userId, GroupRole role, Instant now) {
        memberships.findFirstByGroupIdAndUserIdAndStatus(groupId, userId, GroupMembershipStatus.ACTIVE)
                .orElseGet(() -> memberships.save(new GroupMembershipEntity(UUID.randomUUID(), groupId, userId,
                        role, GroupMembershipStatus.ACTIVE, now, null)));
    }
}
