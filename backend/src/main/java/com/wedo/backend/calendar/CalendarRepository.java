package com.wedo.backend.calendar;

import com.wedo.backend.activity.entity.ActivityRsvpStatus;
import com.wedo.backend.activity.entity.ActivityStatus;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class CalendarRepository {
    private final NamedParameterJdbcTemplate jdbc;

    public CalendarRepository(NamedParameterJdbcTemplate jdbc) { this.jdbc = jdbc; }

    public List<CalendarActivityResponse> findActivities(UUID userId, Instant from, Instant to,
                                                          ActivityRsvpStatus rsvp, UUID groupId,
                                                          ActivityStatus status) {
        StringBuilder sql = new StringBuilder("""
                SELECT a.id, a.group_id, g.name AS group_name, a.title, a.status,
                       a.start_at, a.end_at, a.timezone, a.location ->> 'name' AS location_name,
                       COALESCE(pc.going_count, 0) AS going_count,
                       COALESCE(pc.waitlist_count, 0) AS waitlist_count,
                       COALESCE(mine.rsvp_status, 'NO_RESPONSE') AS caller_rsvp,
                       COALESCE(rem.enabled, FALSE) AS reminder_enabled, rem.remind_at AS reminder_at
                FROM activities a
                JOIN groups g ON g.id = a.group_id AND g.status <> 'DELETED'
                JOIN group_memberships gm ON gm.group_id = a.group_id
                     AND gm.user_id = :userId AND gm.status = 'ACTIVE'
                LEFT JOIN activity_participants mine ON mine.activity_id = a.id AND mine.user_id = :userId
                LEFT JOIN (
                    SELECT activity_id,
                           COUNT(*) FILTER (WHERE rsvp_status = 'GOING') AS going_count,
                           COUNT(*) FILTER (WHERE rsvp_status = 'WAITLIST') AS waitlist_count
                    FROM activity_participants GROUP BY activity_id
                ) pc ON pc.activity_id = a.id
                LEFT JOIN user_activity_reminders rem ON rem.activity_id = a.id AND rem.user_id = :userId
                WHERE a.start_at IS NOT NULL
                """);
        MapSqlParameterSource params = new MapSqlParameterSource("userId", userId);
        if (from != null) {
            sql.append(" AND COALESCE(a.end_at, a.start_at) >= :from");
            params.addValue("from", Timestamp.from(from));
        }
        if (to != null) {
            sql.append(" AND a.start_at <= :to");
            params.addValue("to", Timestamp.from(to));
        }
        if (rsvp != null) {
            sql.append(" AND COALESCE(mine.rsvp_status, 'NO_RESPONSE') = :rsvp");
            params.addValue("rsvp", rsvp.name());
        }
        if (groupId != null) {
            sql.append(" AND a.group_id = :groupId");
            params.addValue("groupId", groupId);
        }
        if (status != null) {
            sql.append(" AND a.status = :status");
            params.addValue("status", status.name());
        }
        sql.append(" ORDER BY a.start_at ASC, a.id ASC");
        return jdbc.query(sql.toString(), params, (rs, row) -> new CalendarActivityResponse(
                rs.getObject("id", UUID.class),
                rs.getObject("group_id", UUID.class),
                rs.getString("group_name"),
                rs.getString("title"),
                ActivityStatus.valueOf(rs.getString("status")),
                instant(rs.getTimestamp("start_at")),
                instant(rs.getTimestamp("end_at")),
                rs.getString("timezone"),
                rs.getString("location_name"),
                rs.getLong("going_count"),
                rs.getLong("waitlist_count"),
                ActivityRsvpStatus.valueOf(rs.getString("caller_rsvp")),
                rs.getBoolean("reminder_enabled"),
                instant(rs.getTimestamp("reminder_at"))
        ));
    }

    private static Instant instant(Timestamp timestamp) { return timestamp == null ? null : timestamp.toInstant(); }
}
