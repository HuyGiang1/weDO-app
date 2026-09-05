package com.wedo.backend.auth.dto;

import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.nio.charset.StandardCharsets;

public record ResetPasswordRequest(
        @NotBlank(message = "Email must not be blank")
        @Email(message = "Email must be a valid email address")
        String email,

        @NotBlank(message = "Reset code must not be blank")
        @Pattern(regexp = "^\\d{6}$", message = "Reset code must be exactly 6 digits")
        String code,

        @NotBlank(message = "Password must not be blank")
        @Size(min = 8, max = 72, message = "Password must be between 8 and 72 characters")
        String newPassword
) {
    @AssertTrue(message = "Password must not exceed 72 bytes in UTF-8 encoding")
    public boolean isPasswordByteLengthValid() {
        return newPassword == null || newPassword.getBytes(StandardCharsets.UTF_8).length <= 72;
    }
}
