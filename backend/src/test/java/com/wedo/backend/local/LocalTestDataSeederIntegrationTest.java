package com.wedo.backend.local;

import static org.assertj.core.api.Assertions.assertThat;

import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.group.entity.GroupMembershipStatus;
import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.repository.GroupMembershipRepository;
import com.wedo.backend.group.repository.GroupRepository;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserCredentialRepository;
import com.wedo.backend.user.repository.UserRepository;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.DefaultApplicationArguments;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest(properties = "wedo.local-test-data.enabled=true")
@ActiveProfiles("local")
class LocalTestDataSeederIntegrationTest extends AbstractPostgresIntegrationTest {
    private static final List<String> EMAILS = List.of(
            "owner@wedo.local", "admin@wedo.local", "member1@wedo.local",
            "member2@wedo.local", "outsider@wedo.local");

    @Autowired private UserRepository users;
    @Autowired private UserCredentialRepository credentials;
    @Autowired private GroupRepository groups;
    @Autowired private GroupMembershipRepository memberships;
    @Autowired private LocalTestDataSeeder seeder;
    @Autowired private PasswordEncoder passwordEncoder;

    @Test
    void localProfileSeedsVerifiedAccountsAndExpectedMemberships() {
        assertThat(EMAILS).allSatisfy(email -> {
            var user = users.findByEmail(email).orElseThrow();
            assertThat(user.getStatus()).isEqualTo(UserStatus.ACTIVE);
            assertThat(user.getEmailVerifiedAt()).isNotNull();
            var credential = credentials.findById(user.getId()).orElseThrow();
            assertThat(credential.getPasswordHash()).isNotEqualTo(LocalTestDataSeeder.PASSWORD);
            assertThat(passwordEncoder.matches(LocalTestDataSeeder.PASSWORD, credential.getPasswordHash())).isTrue();
        });

        var group = groups.findByName(LocalTestDataSeeder.GROUP_NAME).orElseThrow();
        assertRole(group.getId(), "owner@wedo.local", GroupRole.OWNER);
        assertRole(group.getId(), "admin@wedo.local", GroupRole.ADMIN);
        assertRole(group.getId(), "member1@wedo.local", GroupRole.MEMBER);
        assertRole(group.getId(), "member2@wedo.local", GroupRole.MEMBER);
        var outsider = users.findByEmail("outsider@wedo.local").orElseThrow();
        assertThat(memberships.findByGroupIdAndUserIdAndStatus(
                group.getId(), outsider.getId(), GroupMembershipStatus.ACTIVE)).isEmpty();
    }

    @Test
    void rerunIsIdempotentAndPreservesUnrelatedLocalUser() {
        var unrelated = users.save(new UserEntity(UUID.randomUUID(), "unrelated+" + UUID.randomUUID() + "@local.test",
                "unrelated" + UUID.randomUUID().toString().replace("-", "").substring(0, 12),
                "Unrelated", UserStatus.ACTIVE, Instant.now(), Instant.now()));
        seeder.run(new DefaultApplicationArguments());
        seeder.run(new DefaultApplicationArguments());

        assertThat(EMAILS).allSatisfy(email -> assertThat(users.existsByEmail(email)).isTrue());
        assertThat(users.findById(unrelated.getId())).isPresent();
        assertThat(EMAILS.stream().filter(users::existsByEmail).count()).isEqualTo(5);
        var group = groups.findByName(LocalTestDataSeeder.GROUP_NAME).orElseThrow();
        assertThat(memberships.countByGroupIdAndStatus(group.getId(), GroupMembershipStatus.ACTIVE)).isEqualTo(4);
    }

    private void assertRole(UUID groupId, String email, GroupRole expected) {
        var user = users.findByEmail(email).orElseThrow();
        assertThat(memberships.findFirstByGroupIdAndUserIdAndStatus(
                groupId, user.getId(), GroupMembershipStatus.ACTIVE)).get()
                .extracting(membership -> membership.getRole()).isEqualTo(expected);
    }
}
