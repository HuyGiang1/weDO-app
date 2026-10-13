package com.wedo.backend.common.event;

import static org.junit.jupiter.api.Assertions.*;
import java.time.Duration;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import org.awaitility.Awaitility;
import org.junit.jupiter.api.Test;

class PostCommitDeliveryTest {
    @Test
    void boundedSaturationRejectsWithoutCallerRunsAndWorkerSurvivesFailure() throws Exception {
        try (var delivery = new PostCommitDelivery()) {
            CountDownLatch started = new CountDownLatch(2);
            CountDownLatch release = new CountDownLatch(1);
            Runnable blocked = () -> {
                started.countDown();
                try {
                    assertTrue(Thread.currentThread().getName().startsWith("wedo-delivery-"));
                    assertTrue(release.await(5, TimeUnit.SECONDS));
                } catch (InterruptedException ex) {
                    Thread.currentThread().interrupt();
                    throw new IllegalStateException(ex);
                }
            };
            try {
                delivery.submit("test", UUID.randomUUID(), blocked);
                delivery.submit("test", UUID.randomUUID(), blocked);
                assertTrue(started.await(5, TimeUnit.SECONDS));
                AtomicInteger completed = new AtomicInteger();
                for (int i = 0; i < 256; i++) delivery.submit("queued", null, completed::incrementAndGet);
                delivery.submit("rejected", null, () -> fail("Rejected delivery must not run on the caller"));
                assertEquals(0, completed.get());
                release.countDown();
                Awaitility.await().atMost(Duration.ofSeconds(5)).until(delivery::isIdle);
                assertEquals(256, completed.get());
                delivery.submit("failure", null, () -> { throw new IllegalStateException("Do not log this payload"); });
                delivery.submit("survivor", null, completed::incrementAndGet);
                Awaitility.await().atMost(Duration.ofSeconds(5)).until(delivery::isIdle);
                assertEquals(257, completed.get());
            } finally {
                release.countDown();
            }
        }
    }
}
