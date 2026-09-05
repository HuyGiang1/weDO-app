package com.wedo.backend.auth.security;

import com.wedo.backend.auth.entity.AuthTokenType;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.InvalidKeyException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Base64;
import java.util.HexFormat;
import java.util.UUID;

@Component
public class AuthTokenHasher {

    private static final String HMAC_SHA256 = "HmacSHA256";
    private final SecretKeySpec secretKeySpec;

    public AuthTokenHasher(@Value("${security.auth-token.pepper-base64}") String pepperBase64) {
        if (pepperBase64 == null || pepperBase64.isBlank()) {
            throw new IllegalArgumentException("Auth token pepper must not be null or blank");
        }
        byte[] pepperBytes = Base64.getDecoder().decode(pepperBase64);
        if (pepperBytes.length < 32) {
            throw new IllegalArgumentException("Auth token pepper must be at least 256 bits");
        }
        this.secretKeySpec = new SecretKeySpec(pepperBytes, HMAC_SHA256);
    }

    public String hash(UUID userId, AuthTokenType tokenType, String rawCode) {
        if (userId == null) {
            throw new IllegalArgumentException("userId must not be null");
        }
        if (tokenType == null) {
            throw new IllegalArgumentException("tokenType must not be null");
        }
        if (rawCode == null || rawCode.isBlank()) {
            throw new IllegalArgumentException("rawCode must not be null or blank");
        }

        String message = userId + ":" + tokenType.name() + ":" + rawCode;
        try {
            Mac mac = Mac.getInstance(HMAC_SHA256);
            mac.init(secretKeySpec);
            byte[] hmacBytes = mac.doFinal(message.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hmacBytes);
        } catch (NoSuchAlgorithmException | InvalidKeyException ex) {
            throw new IllegalStateException("Failed to compute HMAC token hash", ex);
        }
    }

    public boolean matches(UUID userId, AuthTokenType tokenType, String rawCode, String storedHash) {
        if (storedHash == null || storedHash.isBlank()) {
            return false;
        }

        String computedHash = hash(userId, tokenType, rawCode);

        return MessageDigest.isEqual(
                computedHash.getBytes(StandardCharsets.UTF_8),
                storedHash.getBytes(StandardCharsets.UTF_8)
        );
    }
}
