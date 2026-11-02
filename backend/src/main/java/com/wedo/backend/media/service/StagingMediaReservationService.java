package com.wedo.backend.media.service;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import java.sql.Timestamp;
import java.time.OffsetDateTime;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/** PostgreSQL serializes the small staging budget across processes/restarts. */
@Service
public class StagingMediaReservationService {
    private final JdbcTemplate jdbc;

    public StagingMediaReservationService(JdbcTemplate jdbc) { this.jdbc = jdbc; }

    // Commit before a URL can escape, even if a caller's later transaction fails.
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void reserve(UUID userId, String key, long bytes, long quotaBytes, int requests, long windowSeconds) {
        if (userId == null || key == null || bytes <= 0 || quotaBytes <= 0 || requests <= 0 || windowSeconds <= 0) {
            throw new IllegalArgumentException("Invalid staging admission parameters");
        }
        // The same operator latch serializes quota/rate decisions across instances.
        // No public endpoint can alter it. Missing/unavailable state fails closed.
        boolean open = Boolean.TRUE.equals(jdbc.queryForObject(
                "SELECT enabled FROM staging_media_upload_control WHERE id=1 FOR UPDATE", Boolean.class));
        if (!open) throw new BusinessException(ErrorCode.STAGING_MEDIA_UPLOAD_DISABLED);
        var now = jdbc.queryForObject("SELECT clock_timestamp()", OffsetDateTime.class).toInstant();
        long recent = jdbc.queryForObject("SELECT count(*) FROM staging_media_upload_reservations "
                + "WHERE user_id=? AND created_at>?", Long.class, userId, Timestamp.from(now.minusSeconds(windowSeconds)));
        if (recent >= requests) throw new BusinessException(ErrorCode.STAGING_MEDIA_RATE_LIMIT);
        long used = jdbc.queryForObject("SELECT coalesce(sum(reserved_bytes),0) FROM staging_media_upload_reservations", Long.class);
        if (bytes > quotaBytes || used > quotaBytes - bytes) {
            throw new BusinessException(ErrorCode.STAGING_MEDIA_QUOTA_EXCEEDED);
        }
        jdbc.update("INSERT INTO staging_media_upload_reservations(id,user_id,storage_key,reserved_bytes,created_at) "
                + "VALUES (?,?,?,?,?)", UUID.randomUUID(), userId, key, bytes, Timestamp.from(now));
    }
}
