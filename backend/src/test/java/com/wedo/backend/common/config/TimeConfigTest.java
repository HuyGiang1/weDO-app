package com.wedo.backend.common.config;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class TimeConfigTest {

    @Test
    @DisplayName("Clock bean should be configured with UTC time zone and return current instant")
    void clockShouldUseUtcZoneAndProvideCurrentInstant() {
        TimeConfig timeConfig = new TimeConfig();
        Clock clock = timeConfig.clock();

        assertThat(clock).isNotNull();
        assertThat(clock.getZone()).isEqualTo(ZoneOffset.UTC);

        Instant clockNow = clock.instant();
        Instant systemNow = Instant.now();

        // Ensure the clock instant is in sync with system time (within 1 second)
        assertThat(Duration.between(clockNow, systemNow).abs())
                .isLessThan(Duration.ofSeconds(1));
    }
}
