package com.wedo.backend.security;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

import static org.assertj.core.api.Assertions.assertThat;

class PasswordEncoderTest {

    private PasswordEncoder passwordEncoder;

    @BeforeEach
    void setUp() {
        passwordEncoder = new BCryptPasswordEncoder();
    }

    @Test
    @DisplayName("encode should produce a hash that is not equal to raw password")
    void encode_shouldProduceHashDifferentFromRawPassword() {
        String raw = "mySecretPassword123!";

        String encoded = passwordEncoder.encode(raw);

        assertThat(encoded).isNotBlank();
        assertThat(encoded).isNotEqualTo(raw);
    }

    @Test
    @DisplayName("matches should return true for matching raw and encoded password")
    void matches_shouldReturnTrueForCorrectPassword() {
        String raw = "correctPassword_456#";
        String encoded = passwordEncoder.encode(raw);

        boolean result = passwordEncoder.matches(raw, encoded);

        assertThat(result).isTrue();
    }

    @Test
    @DisplayName("matches should return false for incorrect raw password")
    void matches_shouldReturnFalseForWrongPassword() {
        String raw = "actualPassword_789$";
        String wrong = "wrongPassword_000";
        String encoded = passwordEncoder.encode(raw);

        boolean result = passwordEncoder.matches(wrong, encoded);

        assertThat(result).isFalse();
    }

    @Test
    @DisplayName("encoding the same password twice should produce two different hashes due to random salt")
    void encode_sameRawPasswordTwice_shouldProduceDifferentHashes() {
        String raw = "consistentRawPassword";

        String encoded1 = passwordEncoder.encode(raw);
        String encoded2 = passwordEncoder.encode(raw);

        assertThat(encoded1).isNotEqualTo(encoded2);
        assertThat(passwordEncoder.matches(raw, encoded1)).isTrue();
        assertThat(passwordEncoder.matches(raw, encoded2)).isTrue();
    }
}
