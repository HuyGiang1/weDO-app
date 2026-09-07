package com.wedo.backend.security.jwt;

import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.security.AuthenticatedUserPrincipal;
import com.wedo.backend.security.SecurityErrorResponseWriter;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.util.StringUtils;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Collections;
import java.util.UUID;

public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private static final String AUTHORIZATION_HEADER = "Authorization";
    private static final String BEARER_PREFIX = "bearer ";

    private final JwtService jwtService;
    private final SecurityErrorResponseWriter errorResponseWriter;

    public JwtAuthenticationFilter(
            JwtService jwtService,
            SecurityErrorResponseWriter errorResponseWriter
    ) {
        this.jwtService = jwtService;
        this.errorResponseWriter = errorResponseWriter;
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {
        String authHeader = request.getHeader(AUTHORIZATION_HEADER);

        // A & B: Absent or blank header -> no-op, continue chain
        if (!StringUtils.hasText(authHeader)) {
            filterChain.doFilter(request, response);
            return;
        }

        String trimmedHeader = authHeader.trim();
        String lowerHeader = trimmedHeader.toLowerCase();

        // C: Non-Bearer scheme -> no-op, continue chain
        if (!lowerHeader.startsWith(BEARER_PREFIX)) {
            // Check if it's literally just "bearer" with no token or whitespace
            if (lowerHeader.equals("bearer")) {
                SecurityContextHolder.clearContext();
                errorResponseWriter.writeError(request, response, ErrorCode.AUTH_TOKEN_INVALID);
                return;
            }
            filterChain.doFilter(request, response);
            return;
        }

        // D & E: Bearer scheme selected
        String rawToken = trimmedHeader.substring(BEARER_PREFIX.length()).trim();
        if (rawToken.isEmpty()) {
            SecurityContextHolder.clearContext();
            errorResponseWriter.writeError(request, response, ErrorCode.AUTH_TOKEN_INVALID);
            return;
        }

        // Validate Bearer access token
        UUID userId;
        try {
            userId = jwtService.extractUserId(rawToken);
        } catch (ExpiredJwtException ex) {
            SecurityContextHolder.clearContext();
            errorResponseWriter.writeError(request, response, ErrorCode.AUTH_TOKEN_EXPIRED);
            return;
        } catch (JwtException | IllegalArgumentException ex) {
            SecurityContextHolder.clearContext();
            errorResponseWriter.writeError(request, response, ErrorCode.AUTH_TOKEN_INVALID);
            return;
        }

        // If context does not already have an authenticated principal, populate it
        if (SecurityContextHolder.getContext().getAuthentication() == null) {
            AuthenticatedUserPrincipal principal = new AuthenticatedUserPrincipal(userId);
            UsernamePasswordAuthenticationToken authentication = new UsernamePasswordAuthenticationToken(
                    principal,
                    null,
                    Collections.emptyList()
            );
            authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));

            SecurityContext context = SecurityContextHolder.createEmptyContext();
            context.setAuthentication(authentication);
            SecurityContextHolder.setContext(context);
        }

        filterChain.doFilter(request, response);
    }
}
