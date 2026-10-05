package com.wedo.backend.search;

import static org.hamcrest.Matchers.hasSize;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.group.entity.GroupEntity;
import com.wedo.backend.group.entity.GroupMembershipEntity;
import com.wedo.backend.group.entity.GroupMembershipStatus;
import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.entity.GroupSettingsEntity;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.group.repository.GroupMembershipRepository;
import com.wedo.backend.group.repository.GroupRepository;
import com.wedo.backend.group.repository.GroupSettingsRepository;
import com.wedo.backend.security.jwt.JwtService;
import com.wedo.backend.social.service.BlockService;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserRepository;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;

@AutoConfigureMockMvc
class SearchControllerIntegrationTest extends AbstractPostgresIntegrationTest {
    @Autowired private MockMvc mockMvc;
    @Autowired private JwtService jwtService;
    @Autowired private UserRepository users;
    @Autowired private GroupRepository groups;
    @Autowired private GroupSettingsRepository settings;
    @Autowired private GroupMembershipRepository memberships;
    @Autowired private JdbcTemplate jdbc;
    @Autowired private BlockService blocks;

    private UUID actor;
    private String needle;

    @BeforeEach
    void setUp() {
        needle = "q" + UUID.randomUUID().toString().substring(0, 8);
        actor = user(needle + "-actor", "Search Actor", UserStatus.ACTIVE);
        privacy(actor, true, false, false);
    }

    @Test
    void validatesQueryCategoryAndPaginationAndOmitsUnrequestedSections() throws Exception {
        String token = bearer(actor);
        mockMvc.perform(get("/api/v1/search").param("q", "ab"))
                .andExpect(status().isUnauthorized());
        mockMvc.perform(get("/api/v1/search").header("Authorization", token))
                .andExpect(status().isBadRequest());
        for (String invalid : new String[] {"", "a", "x".repeat(101)}) {
            mockMvc.perform(get("/api/v1/search").header("Authorization", token).param("q", invalid))
                    .andExpect(status().isBadRequest());
        }
        mockMvc.perform(get("/api/v1/search").header("Authorization", token).param("q", "ab")
                        .param("type", "UNKNOWN"))
                .andExpect(status().isBadRequest());
        mockMvc.perform(get("/api/v1/search").header("Authorization", token).param("q", "ab")
                        .param("page", "0"))
                .andExpect(status().isBadRequest());
        for (String[] paging : new String[][] {{"-1", "20"}, {"0", "0"}, {"0", "51"}, {"", "20"}}) {
            mockMvc.perform(get("/api/v1/search").header("Authorization", token).param("q", "ab")
                            .param("type", "PEOPLE").param("page", paging[0]).param("size", paging[1]))
                    .andExpect(status().isBadRequest());
        }
        mockMvc.perform(get("/api/v1/search").header("Authorization", token).param("q", "ab")
                        .param("type", "PEOPLE").param("page", "0").param("size", "20"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.people.items").isArray())
                .andExpect(jsonPath("$.groups").doesNotExist())
                .andExpect(jsonPath("$.activities").doesNotExist())
                .andExpect(jsonPath("$.conversations").doesNotExist());
    }

    @Test
    void peopleSearchAppliesDiscoveryStatusSelfBlockAndVisibleRowPagination() throws Exception {
        UUID usernameMatch = user(needle + "-username", "A Person", UserStatus.ACTIVE);
        UUID emailMatch = user("email-target", "Another Person", UserStatus.ACTIVE);
        UUID phoneMatch = user("phone-target", "Phone Person", UserStatus.ACTIVE);
        UUID hidden = user(needle + "-hidden", "Hidden Person", UserStatus.ACTIVE);
        UUID blocked = user(needle + "-blocked", "Blocked Person", UserStatus.ACTIVE);
        UUID reverseBlocked = user(needle + "-reverse-blocked", "Reverse Blocked", UserStatus.ACTIVE);
        UUID inactive = user(needle + "-inactive", "Inactive Person", UserStatus.SUSPENDED);
        UUID displayMatch = user("display-target", needle + " Display Match", UserStatus.ACTIVE);
        privacy(usernameMatch, true, false, false);
        privacy(emailMatch, false, true, false);
        privacy(phoneMatch, false, false, true);
        privacy(hidden, false, false, false);
        privacy(blocked, true, false, false);
        privacy(reverseBlocked, true, false, false);
        privacy(inactive, true, false, false);
        privacy(displayMatch, true, false, false);
        jdbc.update("UPDATE users SET email=? WHERE id=?", needle + "-mail@example.test", emailMatch);
        jdbc.update("UPDATE users SET phone=? WHERE id=?", needle + "-555", phoneMatch);
        jdbc.update("UPDATE users SET email=?, phone=? WHERE id=?", needle + "-private@example.test", needle + "-999", hidden);
        jdbc.update("UPDATE users SET avatar_storage_key='avatar/private/key' WHERE id=?", usernameMatch);
        blocks.blockUser(actor, blocked);
        blocks.blockUser(reverseBlocked, actor);

        mockMvc.perform(get("/api/v1/search").header("Authorization", bearer(actor))
                        .param("q", needle).param("type", "PEOPLE").param("size", "2"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.people.items", hasSize(2)))
                .andExpect(jsonPath("$.people.hasMore").value(true))
                .andExpect(jsonPath("$.people.items[*].email").doesNotExist())
                .andExpect(jsonPath("$.people.items[*].phone").doesNotExist())
                .andExpect(jsonPath("$.people.items[*].avatarStorageKey").doesNotExist());

        mockMvc.perform(get("/api/v1/search").header("Authorization", bearer(actor))
                        .param("q", needle).param("type", "PEOPLE").param("size", "2").param("page", "1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.people.items", hasSize(2)))
                .andExpect(jsonPath("$.people.hasMore").value(false))
                .andExpect(jsonPath("$.people.items[*].id").value(org.hamcrest.Matchers.containsInAnyOrder(
                        phoneMatch.toString(), displayMatch.toString())));
        mockMvc.perform(get("/api/v1/search").header("Authorization", bearer(actor))
                        .param("q", needle).param("type", "PEOPLE").param("size", "2").param("page", "0"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.people.items[*].id").value(org.hamcrest.Matchers.containsInAnyOrder(
                        usernameMatch.toString(), emailMatch.toString())));
        assertEquals(1, jdbc.queryForObject("SELECT count(*) FROM users WHERE id=? AND status='ACTIVE'", Integer.class, actor));
    }

    @Test
    void groupsIncludeReadableActiveAndArchivedButDoNotLeakOtherMembershipsOrWildcardMatches() throws Exception {
        UUID activeGroup = group("Citrine active", GroupStatus.ACTIVE, actor, actor);
        UUID archivedGroup = group("Citrine archived", GroupStatus.ARCHIVED, actor, actor);
        UUID nonMemberGroup = group("Citrine hidden", GroupStatus.ACTIVE, actor, null);
        UUID formerGroup = group("Citrine former", GroupStatus.ACTIVE, actor, actor);
        jdbc.update("UPDATE group_memberships SET status='LEFT',ended_at=CURRENT_TIMESTAMP WHERE group_id=? AND user_id=?",
                formerGroup, actor);
        UUID bannedGroup = group("Citrine banned", GroupStatus.ACTIVE, actor, actor);
        jdbc.update("UPDATE group_memberships SET status='BANNED',ended_at=CURRENT_TIMESTAMP WHERE group_id=? AND user_id=?",
                bannedGroup, actor);
        UUID bannedBy = user("ban-admin", "Ban Admin", UserStatus.ACTIVE);
        jdbc.update("INSERT INTO group_bans(id,group_id,user_id,banned_by,created_at) VALUES (?,?,?,?,CURRENT_TIMESTAMP)",
                UUID.randomUUID(), bannedGroup, actor, bannedBy);
        UUID deletedGroup = group("Citrine deleted", GroupStatus.DELETED, actor, actor);
        UUID literalGroup = group("Rate 100%_safe", GroupStatus.ACTIVE, actor, actor);

        mockMvc.perform(get("/api/v1/search").header("Authorization", bearer(actor))
                        .param("q", "citrine").param("type", "GROUPS").param("size", "10"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.groups.items", hasSize(2)))
                .andExpect(jsonPath("$.groups.hasMore").value(false))
                .andExpect(jsonPath("$.groups.items[*].id").value(org.hamcrest.Matchers.containsInAnyOrder(
                        activeGroup.toString(), archivedGroup.toString())))
                .andExpect(jsonPath("$.groups.items[*].avatarStorageKey").doesNotExist());
        mockMvc.perform(get("/api/v1/search").header("Authorization", bearer(actor))
                        .param("q", "%_").param("type", "GROUPS"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.groups.items", hasSize(1)))
                .andExpect(jsonPath("$.groups.items[0].id").value(literalGroup.toString()));
        UUID accentedGroup = group(needle + " Café", GroupStatus.ACTIVE, actor, actor);
        mockMvc.perform(get("/api/v1/search").header("Authorization", bearer(actor))
                        .param("q", needle + " cafe").param("type", "GROUPS"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.groups.items", hasSize(0)));
        mockMvc.perform(get("/api/v1/search").header("Authorization", bearer(actor))
                        .param("q", needle + " café").param("type", "GROUPS"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.groups.items[0].id").value(accentedGroup.toString()));
        assertEquals(1, jdbc.queryForObject("SELECT count(*) FROM groups WHERE id=?", Integer.class, nonMemberGroup));
        assertEquals(1, jdbc.queryForObject("SELECT count(*) FROM groups WHERE id=?", Integer.class, formerGroup));
        assertEquals(1, jdbc.queryForObject("SELECT count(*) FROM groups WHERE id=?", Integer.class, bannedGroup));
        assertEquals(1, jdbc.queryForObject("SELECT count(*) FROM groups WHERE id=? AND status='DELETED'", Integer.class, deletedGroup));
    }

    @Test
    void allModeCapsVisibleSectionsAndGroupRankingIsDeterministic() throws Exception {
        for (int index = 0; index < 7; index++) {
            group(needle + " collection " + index, GroupStatus.ACTIVE, actor, actor);
        }
        mockMvc.perform(get("/api/v1/search").header("Authorization", bearer(actor)).param("q", needle))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.groups.items", hasSize(5)))
                .andExpect(jsonPath("$.groups.hasMore").value(true))
                .andExpect(jsonPath("$.people.items", hasSize(0)))
                .andExpect(jsonPath("$.activities.items", hasSize(0)))
                .andExpect(jsonPath("$.conversations.items", hasSize(0)))
                .andExpect(jsonPath("$.groups.totalElements").doesNotExist());

        String rankedQuery = needle + " rank";
        UUID substring = group("North " + rankedQuery, GroupStatus.ACTIVE, actor, actor);
        UUID prefix = group(rankedQuery + " garden", GroupStatus.ACTIVE, actor, actor);
        UUID exact = group(rankedQuery, GroupStatus.ACTIVE, actor, actor);
        mockMvc.perform(get("/api/v1/search").header("Authorization", bearer(actor))
                        .param("q", rankedQuery).param("type", "GROUPS"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.groups.items[0].id").value(exact.toString()))
                .andExpect(jsonPath("$.groups.items[1].id").value(prefix.toString()))
                .andExpect(jsonPath("$.groups.items[2].id").value(substring.toString()));
    }

    @Test
    void activitiesSearchTitleDescriptionAndLocationOnlyForReadableGroups() throws Exception {
        UUID accessible = group("Activity scope", GroupStatus.ACTIVE, actor, actor);
        UUID hidden = group("Hidden activity scope", GroupStatus.ACTIVE, actor, null);
        UUID titleActivity = activity(accessible, "Aurora gathering", "Quiet notes", "Harbor", "Citrine Way", "COMPLETED");
        UUID descriptionActivity = activity(accessible, "Other title", "Citrine description", null, null, "CANCELLED");
        UUID hiddenActivity = activity(hidden, "Aurora private", "Citrine hidden text", null, null, "PLANNING");

        mockMvc.perform(get("/api/v1/search").header("Authorization", bearer(actor))
                        .param("q", "harbor").param("type", "ACTIVITIES"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.activities.items", hasSize(1)))
                .andExpect(jsonPath("$.activities.items[0].id").value(titleActivity.toString()))
                .andExpect(jsonPath("$.activities.items[0].status").value("COMPLETED"))
                .andExpect(jsonPath("$.activities.items[0].location.name").value("Harbor"));
        mockMvc.perform(get("/api/v1/search").header("Authorization", bearer(actor))
                        .param("q", "citrine").param("type", "ACTIVITIES"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.activities.items", hasSize(2)))
                .andExpect(jsonPath("$.activities.items[*].id").value(org.hamcrest.Matchers.containsInAnyOrder(
                        titleActivity.toString(), descriptionActivity.toString())))
                .andExpect(jsonPath("$.activities.items[*].id").value(org.hamcrest.Matchers.not(
                        org.hamcrest.Matchers.hasItem(hiddenActivity.toString()))));
    }

    @Test
    void conversationsUseLatestVisibleTextAndEnforceGroupMembershipHistoryAndMessageState() throws Exception {
        UUID group = group("Conversation access", GroupStatus.ARCHIVED, actor, actor);
        jdbc.update("UPDATE group_settings SET chat_history_policy='FROM_JOIN_TIME' WHERE group_id=?", group);
        Instant joinedAt = Instant.now().minusSeconds(30);
        jdbc.update("UPDATE group_memberships SET created_at=? WHERE group_id=? AND user_id=? AND status='ACTIVE'",
                java.sql.Timestamp.from(joinedAt), group, actor);
        UUID conversation = UUID.randomUUID();
        jdbc.update("INSERT INTO conversations(id,type) VALUES (?,'GROUP')", conversation);
        jdbc.update("INSERT INTO group_conversations(conversation_id,group_id) VALUES (?,?)", conversation, group);
        UUID old = message(conversation, actor, 1, needle + " before join", "ACTIVE", joinedAt.minusSeconds(10), "TEXT");
        UUID visible = message(conversation, actor, 2, needle + " current result", "ACTIVE", joinedAt.plusSeconds(1), "TEXT");
        UUID latestVisible = message(conversation, actor, 3, needle + " newest visible", "ACTIVE", joinedAt.plusSeconds(2), "TEXT");
        UUID hidden = message(conversation, actor, 4, needle + " hidden", "ACTIVE", joinedAt.plusSeconds(3), "TEXT");
        jdbc.update("INSERT INTO message_hidden_users(message_id,user_id) VALUES (?,?)", hidden, actor);
        message(conversation, actor, 5, needle + " unsent", "UNSENT", joinedAt.plusSeconds(4), "TEXT");
        message(conversation, actor, 6, "", "ACTIVE", joinedAt.plusSeconds(5), "IMAGE");

        UUID outsider = user("conversation-outsider", "Outsider", UserStatus.ACTIVE);
        privacy(outsider, true, false, false);
        UUID direct = directConversation(actor, outsider);
        message(direct, outsider, 1, needle + " direct private", "ACTIVE", Instant.now(), "TEXT");
        UUID blockedPeer = user("conversation-blocked", "Blocked", UserStatus.ACTIVE);
        privacy(blockedPeer, true, false, false);
        UUID blockedDirect = directConversation(actor, blockedPeer);
        message(blockedDirect, blockedPeer, 1, needle + " blocked text", "ACTIVE", Instant.now(), "TEXT");
        blocks.blockUser(actor, blockedPeer);

        mockMvc.perform(get("/api/v1/search").header("Authorization", bearer(actor))
                        .param("q", needle).param("type", "CONVERSATIONS").param("size", "20"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.conversations.items", hasSize(2)))
                .andExpect(jsonPath("$.conversations.items[*].id").value(org.hamcrest.Matchers.containsInAnyOrder(
                        conversation.toString(), direct.toString())))
                .andExpect(jsonPath("$.conversations.items[0].matchedTextSnippet").value(
                        org.hamcrest.Matchers.anyOf(org.hamcrest.Matchers.equalTo(needle + " newest visible"),
                                org.hamcrest.Matchers.equalTo(needle + " direct private"))))
                .andExpect(jsonPath("$.conversations.items[1].matchedTextSnippet").value(needle + " newest visible"))
                .andExpect(jsonPath("$.conversations.items[*].storageKey").doesNotExist())
                .andExpect(jsonPath("$.conversations.items[*].attachments").doesNotExist());
        mockMvc.perform(get("/api/v1/search").header("Authorization", bearer(outsider))
                        .param("q", needle).param("type", "CONVERSATIONS"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.conversations.items", hasSize(1)))
                .andExpect(jsonPath("$.conversations.items[0].id").value(direct.toString()));
        assertEquals(1, jdbc.queryForObject("SELECT count(*) FROM messages WHERE id=?", Integer.class, old));
        assertEquals(1, jdbc.queryForObject("SELECT count(*) FROM messages WHERE id=?", Integer.class, latestVisible));
    }

    private UUID user(String username, String displayName, UserStatus status) {
        UUID id = UUID.randomUUID();
        Instant now = Instant.now();
        String unique = username + "-" + id.toString().substring(0, 8);
        users.save(new UserEntity(id, unique + "@example.test", unique, displayName, status, now, now));
        return id;
    }

    private void privacy(UUID userId, boolean username, boolean email, boolean phone) {
        jdbc.update("""
                INSERT INTO user_privacy_settings(user_id,discover_by_username,discover_by_qr,discover_by_email,discover_by_phone)
                VALUES (?, ?, TRUE, ?, ?) ON CONFLICT(user_id) DO UPDATE SET
                discover_by_username=EXCLUDED.discover_by_username,
                discover_by_email=EXCLUDED.discover_by_email,
                discover_by_phone=EXCLUDED.discover_by_phone
                """, userId, username, email, phone);
    }

    private UUID group(String name, GroupStatus status, UUID creator, UUID member) {
        UUID id = UUID.randomUUID();
        Instant now = Instant.now();
        groups.save(new GroupEntity(id, name, null, null, status, creator, now, now));
        settings.save(GroupSettingsEntity.createDefault(id, now));
        if (member != null) memberships.save(new GroupMembershipEntity(UUID.randomUUID(), id, member,
                GroupRole.MEMBER, GroupMembershipStatus.ACTIVE, now, null));
        return id;
    }

    private UUID activity(UUID groupId, String title, String description, String place, String address, String status) {
        UUID id = UUID.randomUUID();
        String location = place == null ? null
                : "{\"type\":\"PHYSICAL\",\"name\":\"" + place + "\",\"address\":\"" + address + "\"}";
        jdbc.update("""
                INSERT INTO activities(id,group_id,title,description,status,start_at,timezone,location)
                VALUES (?,?,?,?,?,CURRENT_TIMESTAMP,'UTC',?::jsonb)
                """, id, groupId, title, description, status, location);
        return id;
    }

    private UUID message(UUID conversationId, UUID sender, long sequence, String content, String status,
                         Instant createdAt, String type) {
        UUID id = UUID.randomUUID();
        jdbc.update("""
                INSERT INTO messages(id,conversation_id,sender_id,sequence,type,content,status,created_at,unsent_at)
                VALUES (?,?,?,?,?,?,?,?,?)
                """, id, conversationId, sender, sequence, type, content, status,
                java.sql.Timestamp.from(createdAt), "UNSENT".equals(status) ? java.sql.Timestamp.from(createdAt) : null);
        return id;
    }

    private UUID directConversation(UUID userA, UUID userB) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO conversations(id,type) VALUES (?,'DIRECT')", id);
        UUID low = userA.toString().compareTo(userB.toString()) < 0 ? userA : userB;
        UUID high = low.equals(userA) ? userB : userA;
        jdbc.update("INSERT INTO direct_conversations(conversation_id,user_id_1,user_id_2) VALUES (?,?,?)", id, low, high);
        return id;
    }

    private String bearer(UUID id) {
        return "Bearer " + jwtService.generateAccessToken(id);
    }
}
