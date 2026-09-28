package com.wedo.backend.chat.realtime;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import java.nio.charset.StandardCharsets;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.context.SmartLifecycle;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.connection.MessageListener;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.listener.ChannelTopic;
import org.springframework.data.redis.listener.RedisMessageListenerContainer;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;

@Configuration
@EnableWebSocket
@EnableScheduling
public class ChatWebSocketConfig implements WebSocketConfigurer {
    private final ChatWebSocketHandler handler;
    private final ChatWebSocketHandshakeInterceptor handshakeInterceptor;

    public ChatWebSocketConfig(
            ChatWebSocketHandler handler,
            ChatWebSocketHandshakeInterceptor handshakeInterceptor
    ) {
        this.handler = handler;
        this.handshakeInterceptor = handshakeInterceptor;
    }

    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        registry.addHandler(handler, "/ws", "/api/v1/ws")
                .addInterceptors(handshakeInterceptor)
                .setAllowedOriginPatterns("*");
    }

    @Bean
    @ConditionalOnMissingBean(ObjectMapper.class)
    public static ObjectMapper objectMapper() {
        return new ObjectMapper()
                .findAndRegisterModules()
                .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
    }

    @Bean
    public SmartLifecycle chatRedisSubscriptionRegistrar(
            ChatRealtimeCoordinator coordinator,
            @Autowired(required = false) RedisConnectionFactory connectionFactory
    ) {
        return new SmartLifecycle() {
            private RedisMessageListenerContainer container;
            private volatile boolean running = false;

            @Override
            public void start() {
                if (connectionFactory == null || running) return;
                try {
                    connectionFactory.getConnection().close();
                    RedisMessageListenerContainer c = new RedisMessageListenerContainer();
                    c.setConnectionFactory(connectionFactory);
                    MessageListener listener = (message, pattern) -> {
                        String payload = new String(message.getBody(), StandardCharsets.UTF_8);
                        coordinator.onRedisMessage(payload);
                    };
                    c.addMessageListener(listener, new ChannelTopic(ChatRealtimeCoordinator.REDIS_FANOUT_CHANNEL));
                    c.afterPropertiesSet();
                    c.start();
                    this.container = c;
                    this.running = true;
                } catch (Exception ignored) {
                    // Graceful fallback when Redis is not reachable in isolated unit tests
                }
            }

            @Override
            public void stop() {
                if (container != null) {
                    try {
                        container.stop();
                        container.destroy();
                    } catch (Exception ignored) { }
                    container = null;
                }
                running = false;
            }

            @Override
            public boolean isRunning() {
                return running;
            }
        };
    }
}
