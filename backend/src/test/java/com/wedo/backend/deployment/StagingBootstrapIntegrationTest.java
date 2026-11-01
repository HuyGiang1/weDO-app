package com.wedo.backend.deployment;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.google.firebase.FirebaseApp;
import com.wedo.backend.local.LocalTestDataSeeder;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CompletionException;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.ApplicationContext;
import org.springframework.core.env.Environment;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

/** CI-only until adequate local disk is available. All fixtures/containers are isolated. */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("staging")
@Testcontainers
class StagingBootstrapIntegrationTest {
    @Container static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:17-alpine");
    @Container static final GenericContainer<?> REDIS = new GenericContainer<>("redis:7-alpine").withExposedPorts(6379);
    static final Path SECRETS = secretTree();

    private static Path secretTree() {
        try {
            Path path = Files.createTempDirectory("wedo-staging-ci-");
            path.toFile().deleteOnExit();
            for (String name : new String[]{"WEDO_JWT_SECRET_BASE64", "WEDO_AUTH_TOKEN_PEPPER_BASE64",
                    "WEDO_PROFILE_COMPLETION_TOKEN_SECRET_BASE64", "WEDO_MEDIA_ACCESS_KEY", "WEDO_MEDIA_SECRET_KEY"}) {
                Path file = Files.writeString(path.resolve(name), StagingProfileTest.key());
                file.toFile().deleteOnExit();
            }
            return path;
        } catch (java.io.IOException failure) { throw new IllegalStateException(failure); }
    }

    @DynamicPropertySource static void isolated(DynamicPropertyRegistry r) {
        r.add("WEDO_STAGING_SECRETS_DIR", () -> SECRETS + "/");
        r.add("WEDO_DB_URL", POSTGRES::getJdbcUrl);
        r.add("WEDO_DB_USERNAME", POSTGRES::getUsername);
        r.add("WEDO_DB_PASSWORD", POSTGRES::getPassword);
        r.add("WEDO_REDIS_HOST", REDIS::getHost);
        r.add("WEDO_REDIS_PORT", () -> REDIS.getMappedPort(6379));
        r.add("WEDO_PUBLIC_API_ORIGIN", () -> "https://api.staging.example.invalid");
        r.add("WEDO_MEDIA_S3_ENDPOINT", () -> "https://s3.staging.example.invalid");
        r.add("WEDO_MEDIA_PUBLIC_ENDPOINT", () -> "https://s3.staging.example.invalid");
        r.add("WEDO_MEDIA_BUCKET", () -> "synthetic-staging");
        r.add("WEDO_MEDIA_REGION", () -> "us-east-1");
        r.add("server.address", () -> "127.0.0.1");
    }

    @Autowired JdbcTemplate db;
    @Autowired PasswordEncoder passwords;
    @Autowired ObjectMapper json;
    @Autowired Environment env;
    @Autowired ApplicationContext context;

    @Test void freshFlywayReadinessAuthAndAuthorizedSocketWithoutFirebase() throws Exception {
        assertThat(db.queryForObject("SELECT count(*) FROM flyway_schema_history WHERE success", Integer.class)).isEqualTo(21);
        assertThat(db.queryForObject("SELECT count(*) FROM users", Integer.class)).isZero();
        assertThat(context.getBeansOfType(LocalTestDataSeeder.class)).isEmpty();
        assertThat(context.getBeansOfType(FirebaseApp.class)).isEmpty();
        String base = "http://127.0.0.1:" + env.getProperty("local.server.port");
        var client = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build();
        var readiness = client.send(HttpRequest.newBuilder(URI.create(base + "/actuator/health")).build(), HttpResponse.BodyHandlers.ofString());
        assertThat(readiness.statusCode()).isEqualTo(200);
        assertThat(json.readTree(readiness.body()).path("status").asText()).isEqualTo("UP");
        assertThat(json.readTree(readiness.body()).has("components")).isFalse();
        assertThat(client.send(HttpRequest.newBuilder(URI.create(base + "/api/v1/me")).build(), HttpResponse.BodyHandlers.discarding()).statusCode()).isEqualTo(401);

        UUID user = UUID.randomUUID();
        String password = StagingProfileTest.key();
        db.update("INSERT INTO users(id,email,username,display_name,status) VALUES (?,?,?,?, 'ACTIVE')",
                user, "staging@example.invalid", "staging_smoke", "Synthetic staging smoke");
        db.update("INSERT INTO user_credentials(user_id,password_hash) VALUES (?,?)", user, passwords.encode(password));
        db.update("INSERT INTO user_privacy_settings(user_id) VALUES (?)", user);
        db.update("INSERT INTO user_notification_settings(user_id) VALUES (?)", user);
        var login = client.send(HttpRequest.newBuilder(URI.create(base + "/api/v1/auth/login"))
                .header("Content-Type", "application/json").POST(HttpRequest.BodyPublishers.ofString(
                        json.writeValueAsString(Map.of("email", "staging@example.invalid", "password", password)))).build(), HttpResponse.BodyHandlers.ofString());
        assertThat(login.statusCode()).isEqualTo(200);
        String token = json.readTree(login.body()).path("accessToken").asText();
        assertThat(token.isBlank()).isFalse();
        for (String path : new String[]{"/api/v1/me", "/api/v1/groups"}) {
            assertThat(client.send(HttpRequest.newBuilder(URI.create(base + path)).header("Authorization", "Bearer " + token).build(), HttpResponse.BodyHandlers.discarding()).statusCode()).isEqualTo(200);
        }
        URI socket = URI.create(base.replace("http://", "ws://") + "/ws");
        assertThatThrownBy(() -> client.newWebSocketBuilder().connectTimeout(Duration.ofSeconds(5))
                .buildAsync(socket, new java.net.http.WebSocket.Listener() {}).join()).isInstanceOf(CompletionException.class);
        var connected = client.newWebSocketBuilder().connectTimeout(Duration.ofSeconds(5))
                .header("Authorization", "Bearer " + token).buildAsync(socket, new java.net.http.WebSocket.Listener() {}).join();
        connected.sendClose(java.net.http.WebSocket.NORMAL_CLOSURE, "CI complete").join();
        // No real S3 operations, FCM delivery, QA users or financial mutations.
    }
}
