package com.wedo.backend.user.service;

import org.hibernate.exception.ConstraintViolationException;
import org.springframework.dao.DataIntegrityViolationException;

public final class UsernameUniqueViolationDetector {

    private static final String USERS_USERNAME_KEY_CONSTRAINT = "users_username_key";
    private static final String POSTGRES_UNIQUE_VIOLATION_SQL_STATE = "23505";

    private UsernameUniqueViolationDetector() {
    }

    public static boolean isUsernameUniqueViolation(DataIntegrityViolationException exception) {
        Throwable current = exception;
        while (current != null) {
            if (current instanceof ConstraintViolationException constraintViolation) {
                String constraint = constraintViolation.getConstraintName();
                if (constraint != null && constraint.equalsIgnoreCase(USERS_USERNAME_KEY_CONSTRAINT)) {
                    return true;
                }
                if (constraintViolation.getSQLException() != null) {
                    String sqlState = constraintViolation.getSQLException().getSQLState();
                    if (POSTGRES_UNIQUE_VIOLATION_SQL_STATE.equals(sqlState)
                            && constraint != null
                            && constraint.contains("users_username")) {
                        return true;
                    }
                }
            }
            if (current instanceof java.sql.SQLException sqlException) {
                String sqlState = sqlException.getSQLState();
                if (POSTGRES_UNIQUE_VIOLATION_SQL_STATE.equals(sqlState)) {
                    String message = sqlException.getMessage();
                    if (message != null && message.contains(USERS_USERNAME_KEY_CONSTRAINT)) {
                        return true;
                    }
                }
            }
            current = current.getCause();
        }
        return false;
    }
}
