package com.wedo.backend.auth.security;

import org.springframework.stereotype.Component;

import java.security.SecureRandom;
import java.util.Locale;

@Component
public class VerificationCodeGenerator {

    private final SecureRandom secureRandom = new SecureRandom();

    public String generate() {
        int code = secureRandom.nextInt(1_000_000);
        return String.format(Locale.ROOT, "%06d", code);
    }
}
