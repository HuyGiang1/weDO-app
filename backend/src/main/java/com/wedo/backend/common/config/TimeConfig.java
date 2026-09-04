package com.wedo.backend.common.config;

import java.time.Clock;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Configuration providing a centralized Clock bean.
 * Ensures consistent UTC time resolution across the entire backend
 * and facilitates deterministic time mocking during unit testing.
 */
@Configuration
public class TimeConfig {

    @Bean
    public Clock clock() {
        return Clock.systemUTC();
    }
}
