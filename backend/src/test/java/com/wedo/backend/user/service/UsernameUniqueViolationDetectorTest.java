package com.wedo.backend.user.service;

import org.hibernate.exception.ConstraintViolationException;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataIntegrityViolationException;

import java.sql.SQLException;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class UsernameUniqueViolationDetectorTest {

    @Test
    void classifiesOnlyTheUsersUsernameUniqueConstraint() {
        DataIntegrityViolationException usernameConflict = new DataIntegrityViolationException(
                "username conflict",
                new ConstraintViolationException(
                        "duplicate key",
                        new SQLException("duplicate users_username_key", "23505"),
                        "users_username_key"
                )
        );
        DataIntegrityViolationException unrelatedConflict = new DataIntegrityViolationException(
                "email conflict",
                new ConstraintViolationException(
                        "duplicate key",
                        new SQLException("duplicate users_email_key", "23505"),
                        "users_email_key"
                )
        );

        assertTrue(UsernameUniqueViolationDetector.isUsernameUniqueViolation(usernameConflict));
        assertFalse(UsernameUniqueViolationDetector.isUsernameUniqueViolation(unrelatedConflict));
    }
}
