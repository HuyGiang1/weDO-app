package com.wedo.backend.auth.security;

import com.wedo.backend.auth.entity.AuthTokenType;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class AuthTokenHasherTest {

    private static final String PEPPER_A = "k7e8pP5Fj9sW2mN1bV4cZ0xL8qJ3hT6rY9uI2oP5aD8=";
    private static final String PEPPER_B = "t6rY9uI2oP5aD8k7e8pP5Fj9sW2mN1bV4cZ0xL8qJ3h=";

    private AuthTokenHasher hasherA;
    private AuthTokenHasher hasherB;

    @BeforeEach
    void setUp() {
        hasherA = new AuthTokenHasher(PEPPER_A);
        hasherB = new AuthTokenHasher(PEPPER_B);
    }

    @Test
    @DisplayName("same userId, tokenType, rawCode and pepper must produce identical hash")
    void hash_sameInputs_shouldProduceIdenticalHash() {
        UUID userId = UUID.randomUUID();
        String code = "123456";

        String hash1 = hasherA.hash(userId, AuthTokenType.EMAIL_VERIFICATION, code);
        String hash2 = hasherA.hash(userId, AuthTokenType.EMAIL_VERIFICATION, code);

        assertThat(hash1).isEqualTo(hash2);
    }

    @Test
    @DisplayName("hash output must be exactly 64 lowercase hex characters")
    void hash_outputFormat_shouldBeSixtyFourHexChars() {
        UUID userId = UUID.randomUUID();
        String hash = hasherA.hash(userId, AuthTokenType.EMAIL_VERIFICATION, "654321");

        assertThat(hash).hasSize(64);
        assertThat(hash).matches("^[0-9a-f]{64}$");
    }

    @Test
    @DisplayName("different raw code must produce different hash")
    void hash_differentCode_shouldProduceDifferentHash() {
        UUID userId = UUID.randomUUID();

        String hash1 = hasherA.hash(userId, AuthTokenType.EMAIL_VERIFICATION, "111111");
        String hash2 = hasherA.hash(userId, AuthTokenType.EMAIL_VERIFICATION, "222222");

        assertThat(hash1).isNotEqualTo(hash2);
    }

    @Test
    @DisplayName("different userId must produce different hash for the same raw code")
    void hash_differentUserId_shouldProduceDifferentHash() {
        UUID user1 = UUID.randomUUID();
        UUID user2 = UUID.randomUUID();
        String code = "123456";

        String hash1 = hasherA.hash(user1, AuthTokenType.EMAIL_VERIFICATION, code);
        String hash2 = hasherA.hash(user2, AuthTokenType.EMAIL_VERIFICATION, code);

        assertThat(hash1).isNotEqualTo(hash2);
    }

    @Test
    @DisplayName("different tokenType must produce different hash")
    void hash_differentTokenType_shouldProduceDifferentHash() {
        UUID userId = UUID.randomUUID();
        String code = "123456";

        String hashVerification = hasherA.hash(userId, AuthTokenType.EMAIL_VERIFICATION, code);
        String hashReset = hasherA.hash(userId, AuthTokenType.PASSWORD_RESET, code);

        assertThat(hashVerification).isNotEqualTo(hashReset);
    }

    @Test
    @DisplayName("different pepper must produce different hash")
    void hash_differentPepper_shouldProduceDifferentHash() {
        UUID userId = UUID.randomUUID();
        String code = "123456";

        String hashPepperA = hasherA.hash(userId, AuthTokenType.EMAIL_VERIFICATION, code);
        String hashPepperB = hasherB.hash(userId, AuthTokenType.EMAIL_VERIFICATION, code);

        assertThat(hashPepperA).isNotEqualTo(hashPepperB);
    }

    @Test
    @DisplayName("matches should return true for correct code and false for wrong code")
    void matches_shouldValidateCorrectly() {
        UUID userId = UUID.randomUUID();
        String code = "123456";
        String wrongCode = "999999";

        String storedHash = hasherA.hash(userId, AuthTokenType.EMAIL_VERIFICATION, code);

        assertThat(hasherA.matches(userId, AuthTokenType.EMAIL_VERIFICATION, code, storedHash)).isTrue();
        assertThat(hasherA.matches(userId, AuthTokenType.EMAIL_VERIFICATION, wrongCode, storedHash)).isFalse();
    }

    @Test
    @DisplayName("matches should return false for null or blank storedHash")
    void matches_nullOrBlankStoredHash_shouldReturnFalse() {
        UUID userId = UUID.randomUUID();

        assertThat(hasherA.matches(userId, AuthTokenType.EMAIL_VERIFICATION, "123456", null)).isFalse();
        assertThat(hasherA.matches(userId, AuthTokenType.EMAIL_VERIFICATION, "123456", "")).isFalse();
        assertThat(hasherA.matches(userId, AuthTokenType.EMAIL_VERIFICATION, "123456", "   ")).isFalse();
    }

    @Test
    @DisplayName("stored hash must not equal raw code")
    void hash_shouldNotEqualRawCode() {
        UUID userId = UUID.randomUUID();
        String code = "123456";

        String hash = hasherA.hash(userId, AuthTokenType.EMAIL_VERIFICATION, code);

        assertThat(hash).isNotEqualTo(code);
    }

    @Test
    @DisplayName("hash with null userId, null tokenType, or null/blank rawCode should throw IllegalArgumentException")
    void hash_invalidArguments_shouldThrowException() {
        UUID userId = UUID.randomUUID();

        assertThatThrownBy(() -> hasherA.hash(null, AuthTokenType.EMAIL_VERIFICATION, "123456"))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> hasherA.hash(userId, null, "123456"))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> hasherA.hash(userId, AuthTokenType.EMAIL_VERIFICATION, null))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> hasherA.hash(userId, AuthTokenType.EMAIL_VERIFICATION, ""))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> hasherA.hash(userId, AuthTokenType.EMAIL_VERIFICATION, "   "))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    @DisplayName("pepper with exactly 32 bytes (256 bits) must be accepted")
    void constructor_thirtyTwoBytePepper_shouldBeAccepted() {
        byte[] thirtyTwoBytes = new byte[32];
        java.util.Arrays.fill(thirtyTwoBytes, (byte) 1);
        String base64Pepper = java.util.Base64.getEncoder().encodeToString(thirtyTwoBytes);

        AuthTokenHasher hasher = new AuthTokenHasher(base64Pepper);

        assertThat(hasher).isNotNull();
    }

    @Test
    @DisplayName("pepper with 31 bytes (under 256 bits) must be rejected with IllegalArgumentException")
    void constructor_thirtyOneBytePepper_shouldBeRejected() {
        byte[] thirtyOneBytes = new byte[31];
        java.util.Arrays.fill(thirtyOneBytes, (byte) 1);
        String base64Pepper = java.util.Base64.getEncoder().encodeToString(thirtyOneBytes);

        assertThatThrownBy(() -> new AuthTokenHasher(base64Pepper))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("Auth token pepper must be at least 256 bits");
    }

    @Test
    @DisplayName("null, blank, or invalid Base64 pepper must be rejected with IllegalArgumentException")
    void constructor_invalidBase64Pepper_shouldBeRejected() {
        assertThatThrownBy(() -> new AuthTokenHasher(null))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> new AuthTokenHasher(""))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> new AuthTokenHasher("   "))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> new AuthTokenHasher("not-valid-base64!!!"))
                .isInstanceOf(IllegalArgumentException.class);
    }
}
