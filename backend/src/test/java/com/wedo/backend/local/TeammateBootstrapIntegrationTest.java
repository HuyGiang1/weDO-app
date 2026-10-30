package com.wedo.backend.local;

import static org.assertj.core.api.Assertions.assertThat;

import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.FirebaseMessaging;
import com.wedo.backend.notification.push.PushGateway;
import java.security.SecureRandom;
import java.net.URI;
import java.time.Duration;
import java.util.Base64;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.ApplicationContext;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

/** Real fresh DB/bootstrap, no shared QA, ADC, copied fixtures, or Firebase mocks. */
@SpringBootTest
@ActiveProfiles({"local", "teammate"})
@Testcontainers
class TeammateBootstrapIntegrationTest {
    @Container static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:17-alpine");
    @Container static final GenericContainer<?> REDIS = new GenericContainer<>("redis:7-alpine").withExposedPorts(6379);
    static final String PASSWORD = "Dev!" + UUID.randomUUID();
    static final String KEY = randomKey();
    @DynamicPropertySource
    static void properties(DynamicPropertyRegistry r) {
        r.add("WEDO_DB_URL", POSTGRES::getJdbcUrl);
        r.add("WEDO_DB_USERNAME", POSTGRES::getUsername);
        r.add("WEDO_DB_PASSWORD", POSTGRES::getPassword);
        r.add("WEDO_REDIS_HOST", REDIS::getHost);
        r.add("WEDO_REDIS_PORT", () -> REDIS.getMappedPort(6379));
        r.add("WEDO_JWT_SECRET_BASE64", () -> KEY);
        r.add("WEDO_AUTH_TOKEN_PEPPER_BASE64", () -> KEY);
        r.add("WEDO_PROFILE_COMPLETION_TOKEN_SECRET_BASE64", () -> KEY);
        r.add("WEDO_MEDIA_ACCESS_KEY", () -> UUID.randomUUID().toString());
        r.add("WEDO_MEDIA_SECRET_KEY", () -> KEY);
        r.add("WEDO_MEDIA_PUBLIC_ENDPOINT", () -> "http://10.0.2.2:19000");
        r.add("WEDO_LOCAL_TEST_PASSWORD", () -> PASSWORD);
        r.add("WEDO_LOCAL_TEST_DATA_ENABLED", () -> true);
    }
    @Autowired JdbcTemplate jdbc;
    @Autowired ApplicationContext context;
    @Autowired PasswordEncoder encoder;
    @Autowired LocalTestDataSeeder seeder;
    @Autowired PushGateway push;
    @Autowired com.wedo.backend.media.storage.ObjectStorageService storage;

    @Test
    void freshSchemaAndSyntheticSeedWorkWithoutFirebaseCredentials() {
        assertThat(jdbc.queryForObject("SELECT count(*) FROM flyway_schema_history WHERE success", Integer.class)).isEqualTo(21);
        assertThat(jdbc.queryForObject("SELECT max(version::int) FROM flyway_schema_history", Integer.class)).isEqualTo(20);
        assertThat(context.getBeansOfType(FirebaseApp.class)).isEmpty();
        assertThat(context.getBeansOfType(FirebaseMessaging.class)).isEmpty();
        assertThat(push.sendPush(null).status()).isEqualTo(PushGateway.PushDeliveryStatus.EXTERNAL_CONFIG_BLOCKED);
        assertThat(jdbc.queryForObject("SELECT count(*) FROM users", Integer.class)).isEqualTo(5);
        String hash = jdbc.queryForObject("SELECT c.password_hash FROM user_credentials c JOIN users u ON u.id=c.user_id WHERE u.email='owner@wedo.local'", String.class);
        assertThat(encoder.matches(PASSWORD, hash)).isTrue();
        assertThat(hash).isNotEqualTo(PASSWORD);
        seeder.run(null);
        assertThat(jdbc.queryForObject("SELECT count(*) FROM users", Integer.class)).isEqualTo(5);
        assertThat(jdbc.queryForObject("SELECT count(*) FROM group_memberships", Integer.class)).isEqualTo(4);
    }

    @Test
    void emulatorUploadAndDownloadSignForTheHostAliasNotBackendLoopback() {
        // Signing is local: no licensed MinIO or existing objects are needed.
        URI put = URI.create(storage.presignPut("synthetic/object.png", "image/png", 1, Duration.ofMinutes(1)).url());
        URI get = URI.create(storage.presignGet("synthetic/object.png", Duration.ofMinutes(1)).url());
        for (URI uri : new URI[]{put, get}) {
            assertThat(uri.getHost()).isEqualTo("10.0.2.2");
            assertThat(uri.getPort()).isEqualTo(19000);
            assertThat(uri.getPath()).endsWith("/synthetic/object.png");
        }
    }

    private static String randomKey() {
        byte[] bytes = new byte[32];
        new SecureRandom().nextBytes(bytes);
        return Base64.getEncoder().encodeToString(bytes);
    }
}
