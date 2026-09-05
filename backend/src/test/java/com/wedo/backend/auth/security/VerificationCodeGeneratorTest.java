package com.wedo.backend.auth.security;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class VerificationCodeGeneratorTest {

    private VerificationCodeGenerator generator;

    @BeforeEach
    void setUp() {
        generator = new VerificationCodeGenerator();
    }

    @Test
    @DisplayName("generate should produce a 6-digit numeric string")
    void generate_shouldProduceSixDigitNumericString() {
        String code = generator.generate();

        assertThat(code).isNotNull();
        assertThat(code).hasSize(6);
        assertThat(code).matches("^\\d{6}$");
    }

    @Test
    @DisplayName("multiple generated codes should all have length 6 and contain only digits")
    void generateMultiple_shouldAllBeValidSixDigitCodes() {
        for (int i = 0; i < 100; i++) {
            String code = generator.generate();
            assertThat(code).hasSize(6);
            assertThat(code).matches("^\\d{6}$");
        }
    }
}
