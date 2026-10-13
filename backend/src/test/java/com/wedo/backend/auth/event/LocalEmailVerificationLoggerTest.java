package com.wedo.backend.auth.event;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;

@ExtendWith(OutputCaptureExtension.class)
class LocalEmailVerificationLoggerTest {

    @Test
    void localVerificationLogOmitsEmailAndCode(CapturedOutput output) {
        UUID userId = UUID.randomUUID();
        new LocalEmailVerificationLogger().handle(
                new EmailVerificationRequestedEvent(userId, "private@example.test", "927143")
        );

        assertThat(output.getOut()).contains(userId.toString())
                .doesNotContain("private@example.test", "927143");
    }
}
