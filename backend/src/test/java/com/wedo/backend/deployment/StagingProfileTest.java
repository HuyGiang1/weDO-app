package com.wedo.backend.deployment;

import static org.assertj.core.api.Assertions.assertThat;

import com.google.firebase.FirebaseApp;
import com.wedo.backend.local.LocalTestDataSeeder;
import com.wedo.backend.media.storage.S3ObjectStorageService;
import com.wedo.backend.notification.push.DisabledPushConfiguration;
import com.wedo.backend.notification.push.FcmPushGateway;
import com.wedo.backend.notification.push.FirebaseAdminConfiguration;
import com.wedo.backend.notification.push.PushGateway;
import com.wedo.backend.security.jwt.JwtService;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Clock;
import java.time.Duration;
import java.util.Base64;
import java.security.SecureRandom;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.boot.test.context.ConfigDataApplicationContextInitializer;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

/** Real config-data/config-tree loading; no DB, Docker, ADC or external S3 calls. */
class StagingProfileTest {
    @TempDir Path secrets;

    static String key() {
        byte[] bytes = new byte[32];
        new SecureRandom().nextBytes(bytes);
        return Base64.getEncoder().encodeToString(bytes);
    }

    @BeforeEach void syntheticSecrets() throws Exception {
        for (String name : new String[]{"WEDO_DB_PASSWORD", "WEDO_JWT_SECRET_BASE64",
                "WEDO_AUTH_TOKEN_PEPPER_BASE64", "WEDO_PROFILE_COMPLETION_TOKEN_SECRET_BASE64",
                "WEDO_MEDIA_ACCESS_KEY", "WEDO_MEDIA_SECRET_KEY"}) {
            Files.writeString(secrets.resolve(name), key());
        }
    }

    private ApplicationContextRunner runner() {
        return new ApplicationContextRunner()
                .withInitializer(context -> context.getBeanFactory().setConversionService(
                        org.springframework.boot.convert.ApplicationConversionService.getSharedInstance()))
                .withInitializer(new ConfigDataApplicationContextInitializer())
                .withUserConfiguration(JwtService.class, FirebaseAdminConfiguration.class,
                        FcmPushGateway.class, DisabledPushConfiguration.class, LocalTestDataSeeder.class)
                .withBean(Clock.class, Clock::systemUTC)
                .withPropertyValues("spring.config.location=classpath:/application.yml",
                        "spring.profiles.active=staging", "WEDO_STAGING_SECRETS_DIR=" + secrets + "/",
                        "WEDO_PUBLIC_API_ORIGIN=https://api.staging.example.invalid",
                        "WEDO_MEDIA_S3_ENDPOINT=https://storage.internal.example.invalid",
                        "WEDO_MEDIA_PUBLIC_ENDPOINT=https://media.staging.example.invalid",
                        "WEDO_MEDIA_BUCKET=synthetic-staging", "WEDO_MEDIA_REGION=us-east-1");
    }

    @Test void configTreeLoadsAndNoPushDoesNotNeedAdcOrQaSeed() {
        runner().run(context -> {
            assertThat(context).hasNotFailed().hasSingleBean(JwtService.class)
                    .hasSingleBean(PushGateway.class).doesNotHaveBean(FirebaseApp.class)
                    .doesNotHaveBean(LocalTestDataSeeder.class);
            assertThat(context.getEnvironment().getActiveProfiles()).containsExactly("staging");
            assertThat(context.getEnvironment().getProperty("security.jwt.secret-base64"))
                    .isEqualTo(Files.readString(secrets.resolve("WEDO_JWT_SECRET_BASE64")));
            assertThat(context.getBean(PushGateway.class).sendPush(null).status())
                    .isEqualTo(PushGateway.PushDeliveryStatus.EXTERNAL_CONFIG_BLOCKED);
        });
    }

    @Test void databaseAndMigrationDefaultsAreDedicatedAndFailSafe() {
        runner().run(context -> {
            var env = context.getEnvironment();
            assertThat(context).hasNotFailed();
            assertThat(env.getProperty("spring.datasource.url"))
                    .isEqualTo("jdbc:postgresql://postgres:5432/wedo_staging");
            assertThat(env.getProperty("spring.jpa.hibernate.ddl-auto")).isEqualTo("validate");
            assertThat(env.getProperty("spring.flyway.clean-disabled")).isEqualTo("true");
            assertThat(env.getProperty("spring.flyway.baseline-on-migrate")).isEqualTo("false");
            assertThat(env.getProperty("media.s3.bootstrap-bucket")).isEqualTo("false");
            assertThat(env.getProperty("wedo.local-test-data.enabled")).isEqualTo("false");
        });
    }

    @Test void readinessChecksDbAndRedisWithoutPublishingDetailsOrSwagger() {
        runner().run(context -> {
            var env = context.getEnvironment();
            assertThat(context).hasNotFailed();
            assertThat(env.getProperty("management.endpoint.health.group.readiness.include"))
                    .isEqualTo("readinessState,db,redis");
            assertThat(env.getProperty("management.endpoint.health.show-details")).isEqualTo("never");
            assertThat(env.getProperty("management.endpoint.health.show-components")).isEqualTo("never");
            assertThat(env.getProperty("management.endpoints.web.exposure.include")).isEqualTo("health");
            assertThat(env.getProperty("springdoc.api-docs.enabled")).isEqualTo("false");
            assertThat(env.getProperty("server.forward-headers-strategy")).isEqualTo("none");
        });
    }

    @Test void realSignerUsesPublicStorageHostForPutAndGet() {
        runner().withUserConfiguration(S3ObjectStorageService.class).run(context -> {
            assertThat(context).hasNotFailed();
            var store = context.getBean(S3ObjectStorageService.class);
            var put = java.net.URI.create(store.presignPut("synthetic/object.png", "image/png", 1,
                    Duration.ofMinutes(1)).url());
            var get = java.net.URI.create(store.presignGet("synthetic/object.png", Duration.ofMinutes(1)).url());
            for (var uri : new java.net.URI[]{put, get}) {
                assertThat(uri.getScheme()).isEqualTo("https");
                assertThat(uri.getHost()).isEqualTo("media.staging.example.invalid");
                assertThat(uri.getPath()).isEqualTo("/synthetic-staging/synthetic/object.png");
            }
        });
    }

    @Test void missingSigningSecretHasNoHardcodedFallback() throws Exception {
        Files.delete(secrets.resolve("WEDO_JWT_SECRET_BASE64"));
        runner().run(context -> assertThat(context).hasFailed());
    }

    @Test void missingSecretDirectoryFailsClosed() {
        runner().withPropertyValues("WEDO_STAGING_SECRETS_DIR=" + secrets.resolve("missing") + "/")
                .run(context -> assertThat(context).hasFailed());
    }
}
