package com.wedo.backend.media.service;

import static org.junit.jupiter.api.Assertions.*;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import java.util.UUID;
import java.util.stream.IntStream;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.mock.env.MockEnvironment;

class MediaUploadAdmissionGuardTest {
    static final UUID USER = UUID.nameUUIDFromBytes("synthetic-allowed".getBytes(java.nio.charset.StandardCharsets.UTF_8));
    static MockEnvironment staging() {
        var env = new MockEnvironment();
        env.setActiveProfiles("staging");
        return env;
    }
    static MediaUploadAdmissionGuard guard(String enabled, String users) {
        var env = staging();
        if (enabled != null) env.setProperty("wedo.staging.media-upload.enabled", enabled);
        if (users != null) env.setProperty("wedo.staging.media-upload.allowed-user-ids", users);
        return new MediaUploadAdmissionGuard(env);
    }
    static void denied(MediaUploadAdmissionGuard guard, UUID user) {
        BusinessException failure = assertThrows(BusinessException.class, () -> guard.requireAllowed(user));
        assertEquals(ErrorCode.ACCESS_DENIED, failure.errorCode());
        assertEquals("Access is denied.", failure.getMessage());
    }
    @Test void defaultMissingSwitchIsClosedEvenWithValidAllowlist() {
        denied(guard(null, USER.toString()), USER);
        denied(guard(null, null), USER);
    }
    @Test void explicitClosedSwitchDeniesAllowlistedUser() { denied(guard("false", USER.toString()), USER); }
    @Test void openSwitchPermitsOnlyAllowlistedNonNullUser() {
        var guard = guard("true", USER.toString());
        assertDoesNotThrow(() -> guard.requireAllowed(USER));
        denied(guard, UUID.randomUUID());
        denied(guard, null);
    }
    @ParameterizedTest @ValueSource(strings = {"", "TRUE", "yes", "1", " true "})
    void invalidSwitchNeverOpens(String value) { denied(guard(value, USER.toString()), USER); }
    @ParameterizedTest @ValueSource(strings = {"", " ", "*", "not-a-uuid", "1-1-1-1-1"})
    void invalidOrMissingAllowlistNeverOpens(String value) {
        denied(guard("true", value), USER);
        denied(guard("true", null), USER);
    }
    @Test void duplicateOrEmptyCsvEntryFailsClosed() {
        denied(guard("true", USER + "," + USER), USER);
        denied(guard("true", USER + ","), USER);
        denied(guard("true", "," + USER), USER);
    }
    @Test void maximumTenDistinctCanonicalIdsAndTrimmedCsvSupported() {
        String users = IntStream.range(0, 10).mapToObj(i -> new UUID(0, i + 1).toString())
                .collect(java.util.stream.Collectors.joining(", "));
        assertDoesNotThrow(() -> guard("true", users).requireAllowed(new UUID(0, 1)));
        denied(guard("true", users + "," + USER), new UUID(0, 1));
    }
    @ParameterizedTest @ValueSource(strings = {"local", "test", "teammate", "production"})
    void otherProfilesIgnoreEvenMalformedStagingProperties(String profile) {
        var env = new MockEnvironment().withProperty("wedo.staging.media-upload.enabled", "INVALID")
                .withProperty("wedo.staging.media-upload.allowed-user-ids", "*");
        env.setActiveProfiles(profile);
        assertDoesNotThrow(() -> new MediaUploadAdmissionGuard(env).requireAllowed(USER));
    }
    @Test void defaultProfileUnchangedAndMixedProfilesCannotBypassStaging() {
        assertDoesNotThrow(() -> new MediaUploadAdmissionGuard(new MockEnvironment()).requireAllowed(USER));
        var env = staging();
        env.setActiveProfiles("local", "staging");
        denied(new MediaUploadAdmissionGuard(env), USER);
    }
    @Test void configurationIsSnapshotAndDoesNotImplicitlyHotEnable() {
        var env = staging();
        var guard = new MediaUploadAdmissionGuard(env);
        env.setProperty("wedo.staging.media-upload.enabled", "true");
        env.setProperty("wedo.staging.media-upload.allowed-user-ids", USER.toString());
        denied(guard, USER);
    }
}
