package com.wedo.backend.common.event;

import java.util.UUID;
import java.util.concurrent.RejectedExecutionException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;
import org.springframework.stereotype.Component;

/** Bounded, non-durable delivery; never runs rejected work on a transaction thread. */
@Component
public class PostCommitDelivery implements AutoCloseable {
    private static final Logger log = LoggerFactory.getLogger(PostCommitDelivery.class);
    private final ThreadPoolTaskExecutor executor;
    private final ThreadPoolTaskExecutor pushExecutor;

    public PostCommitDelivery() {
        executor = createExecutor("wedo-delivery-");
        pushExecutor = createExecutor("wedo-push-");
    }

    private static ThreadPoolTaskExecutor createExecutor(String name) {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(2);
        executor.setMaxPoolSize(2);
        executor.setQueueCapacity(256);
        executor.setThreadNamePrefix(name);
        executor.setWaitForTasksToCompleteOnShutdown(true);
        executor.setAwaitTerminationSeconds(30);
        executor.initialize();
        return executor;
    }

    public void submit(String operation, UUID id, Runnable work) {
        submit(executor, operation, id, work);
    }

    public void submitPush(UUID notificationId, Runnable work) {
        submit(pushExecutor, "push", notificationId, work);
    }

    private void submit(ThreadPoolTaskExecutor executor, String operation, UUID id, Runnable work) {
        try {
            executor.execute(() -> {
                try {
                    work.run();
                } catch (RuntimeException ex) {
                    // Exception messages/stack traces can contain provider tokens or SQL binds.
                    log.warn("Post-commit delivery failed operation={} id={} failure={}",
                            operation, id, ex.getClass().getSimpleName());
                }
            });
        } catch (RejectedExecutionException ex) {
            log.warn("Post-commit delivery rejected operation={} id={}; durable business state unchanged", operation, id);
        }
    }

    public boolean isIdle() {
        return idle(executor) && idle(pushExecutor);
    }

    private boolean idle(ThreadPoolTaskExecutor executor) {
        return executor.getActiveCount() == 0 && executor.getThreadPoolExecutor().getQueue().isEmpty();
    }

    @Override
    public void close() {
        executor.shutdown();
        pushExecutor.shutdown();
    }
}
