package com.wedo.backend.chat.realtime;

import com.wedo.backend.chat.service.ChatService;
import com.wedo.backend.security.AuthenticatedUserPrincipal;
import com.wedo.backend.security.jwt.JwtService;
import java.net.URI;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.server.ServerHttpRequest;
import org.springframework.http.server.ServerHttpResponse;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.util.MultiValueMap;
import org.springframework.util.StringUtils;
import org.springframework.web.socket.WebSocketHandler;
import org.springframework.web.socket.server.HandshakeInterceptor;
import org.springframework.web.util.UriComponentsBuilder;

@Component
public class ChatWebSocketHandshakeInterceptor implements HandshakeInterceptor {
    public static final String USER_ID_ATTR = "wedo.authenticatedUserId";

    private final JwtService jwtService;
    private final ChatService chatService;

    public ChatWebSocketHandshakeInterceptor(JwtService jwtService, ChatService chatService) {
        this.jwtService = jwtService;
        this.chatService = chatService;
    }

    @Override
    public boolean beforeHandshake(
            ServerHttpRequest request,
            ServerHttpResponse response,
            WebSocketHandler wsHandler,
            Map<String, Object> attributes
    ) {
        UUID userId = resolveUserId(request);
        if (userId == null || !chatService.isUserActive(userId)) {
            response.setStatusCode(HttpStatus.UNAUTHORIZED);
            return false;
        }
        attributes.put(USER_ID_ATTR, userId);
        return true;
    }

    @Override
    public void afterHandshake(
            ServerHttpRequest request,
            ServerHttpResponse response,
            WebSocketHandler wsHandler,
            Exception exception
    ) { }

    private UUID resolveUserId(ServerHttpRequest request) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.getPrincipal() instanceof AuthenticatedUserPrincipal principal) {
            return principal.userId();
        }
        String token = extractBearerToken(request.getHeaders());
        if (!StringUtils.hasText(token)) {
            token = extractQueryToken(request.getURI());
        }
        if (!StringUtils.hasText(token)) {
            return null;
        }
        try {
            return jwtService.extractUserId(token.trim());
        } catch (RuntimeException ex) {
            return null;
        }
    }

    private String extractBearerToken(HttpHeaders headers) {
        if (headers == null) return null;
        List<String> values = headers.get(HttpHeaders.AUTHORIZATION);
        if (values == null || values.isEmpty()) return null;
        for (String value : values) {
            if (value != null && value.trim().regionMatches(true, 0, "Bearer ", 0, 7)) {
                String candidate = value.trim().substring(7).trim();
                if (!candidate.isEmpty()) return candidate;
            }
        }
        return null;
    }

    private String extractQueryToken(URI uri) {
        if (uri == null || uri.getRawQuery() == null) return null;
        MultiValueMap<String, String> params = UriComponentsBuilder.fromUri(uri).build().getQueryParams();
        String accessToken = params.getFirst("access_token");
        if (StringUtils.hasText(accessToken)) return accessToken;
        String token = params.getFirst("token");
        if (StringUtils.hasText(token)) return token;
        return null;
    }
}
