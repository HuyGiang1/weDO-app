package com.wedo.backend.auth.event;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionalEventListener;

@Component
@Profile("local")
public class LocalEmailVerificationLogger {

    private static final Logger log = LoggerFactory.getLogger(LocalEmailVerificationLogger.class);

    @TransactionalEventListener
    public void handle(EmailVerificationRequestedEvent event) {
        log.warn(
                "LOCAL EMAIL VERIFICATION | email={} | code={} | userId={}",
                event.email(),
                event.rawCode(),
                event.userId());
    }
}