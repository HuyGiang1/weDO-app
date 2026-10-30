package com.wedo.backend.notification.push;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** Explicit opt-out: canonical inbox/realtime work without external FCM credentials. */
@Configuration(proxyBeanMethods = false)
@ConditionalOnProperty(name = "wedo.push.enabled", havingValue = "false")
public class DisabledPushConfiguration {
    @Bean
    PushGateway disabledPushGateway() {
        // Do not pretend an OS notification was delivered or invalidate device tokens.
        return message -> PushGateway.PushDeliveryResult.externalConfigBlocked();
    }
}
