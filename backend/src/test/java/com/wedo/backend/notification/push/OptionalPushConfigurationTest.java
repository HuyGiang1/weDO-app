package com.wedo.backend.notification.push;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.FirebaseMessaging;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

class OptionalPushConfigurationTest {
    @Test
    void explicitOptOutBootsWithoutFirebaseAndNeverClaimsDelivery() {
        new ApplicationContextRunner()
                .withUserConfiguration(FirebaseAdminConfiguration.class, FcmPushGateway.class,
                        DisabledPushConfiguration.class)
                .withPropertyValues("wedo.push.enabled=false")
                .run(context -> {
                    assertThat(context).hasNotFailed().hasSingleBean(PushGateway.class);
                    assertThat(context).doesNotHaveBean(FirebaseApp.class).doesNotHaveBean(FirebaseMessaging.class);
                    assertThat(context.getBean(PushGateway.class).sendPush(null).status())
                            .isEqualTo(PushGateway.PushDeliveryStatus.EXTERNAL_CONFIG_BLOCKED);
                });
    }

    @Test
    void existingDefaultStillSelectsRealFcmGateway() {
        enabledContext().run(context -> assertThat(context).hasNotFailed().hasSingleBean(PushGateway.class)
                .hasSingleBean(FcmPushGateway.class));
    }

    @Test
    void explicitEnableSelectsRealFcmGateway() {
        enabledContext().withPropertyValues("wedo.push.enabled=true")
                .run(context -> assertThat(context).hasNotFailed().hasSingleBean(FcmPushGateway.class));
    }

    private ApplicationContextRunner enabledContext() {
        return new ApplicationContextRunner()
                .withUserConfiguration(FcmPushGateway.class, DisabledPushConfiguration.class)
                .withBean(FirebaseMessaging.class, () -> mock(FirebaseMessaging.class));
    }
}
