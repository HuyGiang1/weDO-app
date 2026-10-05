package com.wedo.backend.home;

import com.wedo.backend.home.HomeDtos.RequiredAction;
import com.wedo.backend.home.HomeDtos.UpcomingActivity;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class HomeQueryRepository {
    private static final String ACTIVE_ACCESS = """
            JOIN groups g ON g.id = a.group_id AND g.status = 'ACTIVE'
            JOIN group_memberships gm ON gm.group_id = g.id
                AND gm.user_id = :userId AND gm.status = 'ACTIVE'
            """;

    private final NamedParameterJdbcTemplate jdbc;

    public HomeQueryRepository(NamedParameterJdbcTemplate jdbc) { this.jdbc = jdbc; }

    public List<UpcomingActivity> upcoming(UUID userId, Instant now) {
        return jdbc.query("""
                SELECT a.id, a.group_id, g.name AS group_name, a.title, a.status, a.start_at
                FROM activities a
                """ + ACTIVE_ACCESS + """
                WHERE a.start_at > :now AND a.status IN ('PLANNING', 'CONFIRMED')
                ORDER BY a.start_at, a.id
                LIMIT 5
                """, params(userId, now), (rs, row) -> new UpcomingActivity(
                id(rs, "id"), id(rs, "group_id"), rs.getString("group_name"),
                rs.getString("title"), rs.getString("status"), instant(rs, "start_at")));
    }

    public List<RequiredAction> actions(UUID userId, Instant now) {
        MapSqlParameterSource params = params(userId, now)
                .addValue("taskHorizon", Timestamp.from(now.plus(7, ChronoUnit.DAYS)));
        List<RequiredAction> result = new ArrayList<>();
        result.addAll(jdbc.query("""
                SELECT a.id AS target_id, a.group_id, a.id AS activity_id,
                       a.title, a.start_at AS due_at
                FROM activities a
                """ + ACTIVE_ACCESS + """
                LEFT JOIN activity_participants ap ON ap.activity_id = a.id AND ap.user_id = :userId
                WHERE a.start_at > :now AND a.status IN ('PLANNING', 'CONFIRMED')
                  AND (ap.id IS NULL OR ap.rsvp_status = 'NO_RESPONSE')
                ORDER BY a.start_at, a.id LIMIT 8
                """, params, (rs, row) -> action(rs, "RSVP_REQUIRED")));
        result.addAll(jdbc.query("""
                SELECT p.id AS target_id, a.group_id, a.id AS activity_id,
                       p.question AS title, p.deadline_at AS due_at
                FROM polls p
                JOIN activities a ON a.id = p.activity_id
                """ + ACTIVE_ACCESS + """
                WHERE p.status = 'OPEN' AND (p.deadline_at IS NULL OR p.deadline_at > :now)
                  AND a.status NOT IN ('COMPLETED', 'CANCELLED')
                  AND NOT EXISTS (SELECT 1 FROM poll_votes pv
                                  WHERE pv.poll_id = p.id AND pv.user_id = :userId)
                  AND EXISTS (SELECT 1 FROM poll_options po
                              WHERE po.poll_id = p.id AND po.is_disabled = FALSE)
                ORDER BY p.deadline_at NULLS LAST, p.id LIMIT 8
                """, params, (rs, row) -> action(rs, "POLL_VOTE_REQUIRED")));
        result.addAll(jdbc.query("""
                SELECT t.id AS target_id, a.group_id, a.id AS activity_id,
                       t.title, t.due_at
                FROM tasks t
                JOIN activities a ON a.id = t.activity_id
                """ + ACTIVE_ACCESS + """
                JOIN task_assignees ta ON ta.task_id = t.id AND ta.user_id = :userId
                WHERE t.status <> 'DONE' AND t.due_at IS NOT NULL
                  AND t.due_at <= :taskHorizon
                  AND a.status NOT IN ('COMPLETED', 'CANCELLED')
                ORDER BY t.due_at, t.id LIMIT 8
                """, params, (rs, row) -> action(rs, "TASK_DUE")));
        result.addAll(jdbc.query("""
                SELECT s.id AS target_id, s.group_id, NULL::uuid AS activity_id,
                       g.name AS title, NULL::timestamptz AS due_at
                FROM settlements s
                JOIN groups g ON g.id = s.group_id AND g.status = 'ACTIVE'
                JOIN group_memberships gm ON gm.group_id = g.id
                    AND gm.user_id = :userId AND gm.status = 'ACTIVE'
                WHERE s.status = 'PENDING'
                  AND ((s.declaration_type = 'I_PAID' AND s.to_user_id = :userId)
                    OR (s.declaration_type = 'I_RECEIVED' AND s.from_user_id = :userId))
                ORDER BY s.created_at, s.id LIMIT 8
                """, params, (rs, row) -> action(rs, "SETTLEMENT_CONFIRMATION")));
        return result.stream()
                .sorted(Comparator.comparingInt((RequiredAction action) -> priority(action.type()))
                        .thenComparing(RequiredAction::dueAt, Comparator.nullsLast(Comparator.naturalOrder()))
                        .thenComparing(action -> action.targetId().toString()))
                .limit(8).toList();
    }

    private static int priority(String type) {
        return switch (type) {
            case "SETTLEMENT_CONFIRMATION" -> 0;
            case "TASK_DUE" -> 1;
            case "RSVP_REQUIRED" -> 2;
            default -> 3;
        };
    }

    private static MapSqlParameterSource params(UUID userId, Instant now) {
        return new MapSqlParameterSource("userId", userId)
                .addValue("now", Timestamp.from(now));
    }

    private static RequiredAction action(ResultSet rs, String type) throws SQLException {
        return new RequiredAction(type, id(rs, "target_id"), id(rs, "group_id"),
                id(rs, "activity_id"), rs.getString("title"), instant(rs, "due_at"));
    }

    private static UUID id(ResultSet rs, String column) throws SQLException {
        return rs.getObject(column, UUID.class);
    }

    private static Instant instant(ResultSet rs, String column) throws SQLException {
        Timestamp value = rs.getTimestamp(column);
        return value == null ? null : value.toInstant();
    }
}
