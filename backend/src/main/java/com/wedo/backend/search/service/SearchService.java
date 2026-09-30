package com.wedo.backend.search.service;

import com.wedo.backend.activity.dto.ActivityLocationDto;
import com.wedo.backend.activity.entity.ActivityStatus;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.search.dto.SearchCategory;
import com.wedo.backend.search.dto.SearchDtos;
import com.wedo.backend.search.dto.SearchDtos.Activity;
import com.wedo.backend.search.dto.SearchDtos.Conversation;
import com.wedo.backend.search.dto.SearchDtos.Group;
import com.wedo.backend.search.dto.SearchDtos.Person;
import com.wedo.backend.search.dto.SearchDtos.Response;
import com.wedo.backend.search.dto.SearchDtos.Section;
import com.wedo.backend.user.service.UserService;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class SearchService {
    private static final int ALL_CATEGORY_SIZE = 5;
    private static final String MATCH = " ILIKE :contains ESCAPE '!'";
    private static final String EXACT = " ILIKE :exact ESCAPE '!'";
    private static final String PREFIX = " ILIKE :prefix ESCAPE '!'";

    private final NamedParameterJdbcTemplate jdbc;
    private final UserService users;

    public SearchService(NamedParameterJdbcTemplate jdbc, UserService users) {
        this.jdbc = jdbc;
        this.users = users;
    }

    @Transactional(readOnly = true)
    public Response searchAll(UUID actorId, String query) {
        users.requireActiveUser(actorId);
        MapSqlParameterSource params = baseParams(actorId, query)
                .addValue("limit", ALL_CATEGORY_SIZE + 1)
                .addValue("offset", 0L);
        return new Response(query,
                section(findPeople(params), ALL_CATEGORY_SIZE),
                section(findGroups(params), ALL_CATEGORY_SIZE),
                section(findActivities(params), ALL_CATEGORY_SIZE),
                section(findConversations(params), ALL_CATEGORY_SIZE));
    }

    @Transactional(readOnly = true)
    public Response searchCategory(UUID actorId, String query, SearchCategory category, int page, int size) {
        users.requireActiveUser(actorId);
        if (page < 0 || size < 1 || size > 50) throw invalid();
        MapSqlParameterSource params = baseParams(actorId, query)
                .addValue("limit", size + 1)
                .addValue("offset", (long) page * size);
        return switch (category) {
            case PEOPLE -> new Response(query, section(findPeople(params), size), null, null, null);
            case GROUPS -> new Response(query, null, section(findGroups(params), size), null, null);
            case ACTIVITIES -> new Response(query, null, null, section(findActivities(params), size), null);
            case CONVERSATIONS -> new Response(query, null, null, null, section(findConversations(params), size));
        };
    }

    private MapSqlParameterSource baseParams(UUID actorId, String query) {
        String escaped = escapeLike(query);
        return new MapSqlParameterSource()
                .addValue("actorId", actorId)
                .addValue("contains", "%" + escaped + "%")
                .addValue("exact", escaped)
                .addValue("prefix", escaped + "%");
    }

    private String escapeLike(String value) {
        return value.replace("!", "!!").replace("%", "!%").replace("_", "!_");
    }

    private List<Person> findPeople(MapSqlParameterSource params) {
        String username = "COALESCE(u.username, '')";
        String display = "COALESCE(u.display_name, '')";
        String email = "u.email";
        String phone = "COALESCE(u.phone, '')";
        String usernameTerms = "(" + username + MATCH + " OR " + display + MATCH + ")";
        String emailTerm = email + MATCH;
        String phoneTerm = phone + MATCH;
        String searchable = "((COALESCE(p.discover_by_username, TRUE) AND " + usernameTerms + ")"
                + " OR (COALESCE(p.discover_by_email, FALSE) AND " + emailTerm + ")"
                + " OR (COALESCE(p.discover_by_phone, FALSE) AND " + phoneTerm + "))";
        String exact = "((COALESCE(p.discover_by_username, TRUE) AND (" + username + EXACT + " OR " + display + EXACT + "))"
                + " OR (COALESCE(p.discover_by_email, FALSE) AND " + email + EXACT + ")"
                + " OR (COALESCE(p.discover_by_phone, FALSE) AND " + phone + EXACT + "))";
        String prefix = "((COALESCE(p.discover_by_username, TRUE) AND (" + username + PREFIX + " OR " + display + PREFIX + "))"
                + " OR (COALESCE(p.discover_by_email, FALSE) AND " + email + PREFIX + ")"
                + " OR (COALESCE(p.discover_by_phone, FALSE) AND " + phone + PREFIX + "))";
        String sql = "SELECT u.id, u.username, u.display_name, (u.avatar_storage_key IS NOT NULL) AS avatar_available "
                + "FROM users u LEFT JOIN user_privacy_settings p ON p.user_id=u.id "
                + "WHERE u.status='ACTIVE' AND u.id<>:actorId AND " + searchable + " "
                + "AND NOT EXISTS (SELECT 1 FROM user_blocks b WHERE "
                + "(b.blocker_id=:actorId AND b.blocked_id=u.id) OR (b.blocker_id=u.id AND b.blocked_id=:actorId)) "
                + "ORDER BY CASE WHEN " + exact + " THEN 0 WHEN " + prefix + " THEN 1 ELSE 2 END, "
                + "LOWER(COALESCE(u.display_name,'')), LOWER(COALESCE(u.username,'')), u.id "
                + "LIMIT :limit OFFSET :offset";
        return jdbc.query(sql, params, (rs, row) -> new Person(
                rs.getObject("id", UUID.class), rs.getString("username"), rs.getString("display_name"),
                rs.getBoolean("avatar_available")));
    }

    private List<Group> findGroups(MapSqlParameterSource params) {
        String name = "g.name";
        String sql = "SELECT g.id, g.name, g.status, (g.avatar_storage_key IS NOT NULL) AS avatar_available "
                + "FROM groups g JOIN group_memberships gm ON gm.group_id=g.id AND gm.user_id=:actorId AND gm.status='ACTIVE' "
                + "WHERE g.status IN ('ACTIVE','ARCHIVED') AND " + name + MATCH + " "
                + "ORDER BY CASE WHEN " + name + EXACT + " THEN 0 WHEN " + name + PREFIX + " THEN 1 ELSE 2 END, "
                + "LOWER(g.name), g.id LIMIT :limit OFFSET :offset";
        return jdbc.query(sql, params, (rs, row) -> new Group(
                rs.getObject("id", UUID.class), rs.getString("name"), GroupStatus.valueOf(rs.getString("status")),
                rs.getBoolean("avatar_available")));
    }

    private List<Activity> findActivities(MapSqlParameterSource params) {
        String title = "a.title";
        String description = "COALESCE(a.description, '')";
        String locationName = "COALESCE(a.location->>'name', '')";
        String locationAddress = "COALESCE(a.location->>'address', '')";
        String location = "(" + locationName + MATCH + " OR " + locationAddress + MATCH + ")";
        String allFields = "(" + title + MATCH + " OR " + description + MATCH + " OR " + location + ")";
        String exactFields = "(" + title + EXACT + " OR " + description + EXACT + " OR " + locationName + EXACT + " OR " + locationAddress + EXACT + ")";
        String prefixFields = "(" + title + PREFIX + " OR " + description + PREFIX + " OR " + locationName + PREFIX + " OR " + locationAddress + PREFIX + ")";
        String fieldRank = "CASE WHEN " + title + MATCH + " THEN 0 WHEN " + description + MATCH + " THEN 1 ELSE 2 END";
        String sql = "SELECT a.id, a.group_id, a.title, a.start_at, a.status, "
                + "a.location->>'type' AS location_type, a.location->>'name' AS location_name, "
                + "a.location->>'address' AS location_address, a.location->>'latitude' AS location_latitude, "
                + "a.location->>'longitude' AS location_longitude "
                + "FROM activities a JOIN groups g ON g.id=a.group_id "
                + "JOIN group_memberships gm ON gm.group_id=g.id AND gm.user_id=:actorId AND gm.status='ACTIVE' "
                + "WHERE g.status IN ('ACTIVE','ARCHIVED') AND " + allFields + " "
                + "ORDER BY CASE WHEN " + exactFields + " THEN 0 WHEN " + prefixFields + " THEN 1 ELSE 2 END, "
                + fieldRank + ", a.start_at DESC NULLS LAST, a.id LIMIT :limit OFFSET :offset";
        return jdbc.query(sql, params, (rs, row) -> mapActivity(rs));
    }

    private Activity mapActivity(ResultSet rs) throws SQLException {
        ActivityLocationDto location = null;
        if (rs.getString("location_type") != null || rs.getString("location_name") != null
                || rs.getString("location_address") != null || rs.getString("location_latitude") != null
                || rs.getString("location_longitude") != null) {
            location = new ActivityLocationDto(rs.getString("location_type"), rs.getString("location_name"),
                    rs.getString("location_address"), parseDouble(rs.getString("location_latitude")),
                    parseDouble(rs.getString("location_longitude")));
        }
        Timestamp start = rs.getTimestamp("start_at");
        return new Activity(rs.getObject("id", UUID.class), rs.getObject("group_id", UUID.class),
                rs.getString("title"), start == null ? null : start.toInstant(),
                ActivityStatus.valueOf(rs.getString("status")), location);
    }

    private Double parseDouble(String value) {
        return value == null ? null : Double.valueOf(value);
    }

    private List<Conversation> findConversations(MapSqlParameterSource params) {
        String sql = "WITH matching AS ("
                + "SELECT c.id, c.type AS kind, gc.group_id, "
                + "CASE WHEN c.type='GROUP' THEN g.name ELSE COALESCE(peer.display_name, peer.username, '') END AS title, "
                + "m.content AS matched_text_snippet, m.created_at AS matched_at, m.sequence, "
                + "CASE WHEN m.content" + EXACT + " THEN 0 WHEN m.content" + PREFIX + " THEN 1 ELSE 2 END AS match_rank, "
                + "ROW_NUMBER() OVER (PARTITION BY c.id ORDER BY m.sequence DESC) AS conversation_row "
                + "FROM conversations c JOIN messages m ON m.conversation_id=c.id "
                + "LEFT JOIN direct_conversations dc ON dc.conversation_id=c.id "
                + "LEFT JOIN group_conversations gc ON gc.conversation_id=c.id "
                + "LEFT JOIN groups g ON g.id=gc.group_id "
                + "LEFT JOIN group_settings gs ON gs.group_id=gc.group_id "
                + "LEFT JOIN users peer ON peer.id=CASE WHEN dc.user_id_1=:actorId THEN dc.user_id_2 ELSE dc.user_id_1 END "
                + "WHERE m.status='ACTIVE' AND m.content" + MATCH + " "
                + "AND NOT EXISTS (SELECT 1 FROM message_hidden_users h WHERE h.message_id=m.id AND h.user_id=:actorId) "
                + "AND ((c.type='DIRECT' AND (dc.user_id_1=:actorId OR dc.user_id_2=:actorId) "
                + "AND NOT EXISTS (SELECT 1 FROM user_blocks b WHERE "
                + "(b.blocker_id=:actorId AND b.blocked_id=CASE WHEN dc.user_id_1=:actorId THEN dc.user_id_2 ELSE dc.user_id_1 END) "
                + "OR (b.blocked_id=:actorId AND b.blocker_id=CASE WHEN dc.user_id_1=:actorId THEN dc.user_id_2 ELSE dc.user_id_1 END))) "
                + "OR (c.type='GROUP' AND g.status IN ('ACTIVE','ARCHIVED') "
                + "AND EXISTS (SELECT 1 FROM group_memberships gm WHERE gm.group_id=gc.group_id AND gm.user_id=:actorId AND gm.status='ACTIVE') "
                + "AND (COALESCE(gs.chat_history_policy,'FULL_HISTORY')='FULL_HISTORY' OR m.created_at >= "
                + "(SELECT gm.created_at FROM group_memberships gm WHERE gm.group_id=gc.group_id AND gm.user_id=:actorId "
                + "AND gm.status='ACTIVE' ORDER BY gm.created_at DESC LIMIT 1))))"
                + ") SELECT id, kind, group_id, title, matched_text_snippet, matched_at, sequence, match_rank "
                + "FROM matching WHERE conversation_row=1 "
                + "ORDER BY match_rank, matched_at DESC, sequence DESC, id LIMIT :limit OFFSET :offset";
        return jdbc.query(sql, params, (rs, row) -> new Conversation(
                rs.getObject("id", UUID.class), rs.getString("kind"), rs.getObject("group_id", UUID.class),
                rs.getString("title"), rs.getString("matched_text_snippet"), rs.getTimestamp("matched_at").toInstant()));
    }

    private <T> Section<T> section(List<T> rows, int size) {
        boolean hasMore = rows.size() > size;
        return new Section<>(rows.subList(0, Math.min(rows.size(), size)), hasMore);
    }

    private BusinessException invalid() {
        return new BusinessException(ErrorCode.VALIDATION_FAILED);
    }
}
