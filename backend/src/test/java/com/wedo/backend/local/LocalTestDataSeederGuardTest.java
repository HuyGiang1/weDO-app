package com.wedo.backend.local;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Import;

class LocalTestDataSeederGuardTest {
    private final ApplicationContextRunner contexts = new ApplicationContextRunner()
            .withUserConfiguration(SeederConfiguration.class);

    @Test
    void seederIsAbsentWhenOptInPropertyIsDisabled() {
        contexts.withPropertyValues("spring.profiles.active=local", "wedo.local-test-data.enabled=false")
                .run(context -> assertThat(context).doesNotHaveBean(LocalTestDataSeeder.class));
    }

    @Test
    void seederIsAbsentOutsideLocalProfileEvenWhenOptedIn() {
        contexts.withPropertyValues("spring.profiles.active=test", "wedo.local-test-data.enabled=true")
                .run(context -> assertThat(context).doesNotHaveBean(LocalTestDataSeeder.class));
    }

    @Configuration(proxyBeanMethods = false)
    @Import(LocalTestDataSeeder.class)
    static class SeederConfiguration { }
}
