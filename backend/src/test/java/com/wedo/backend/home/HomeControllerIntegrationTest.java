package com.wedo.backend.home;

import static org.hamcrest.Matchers.hasSize;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.expense.service.ExpenseService;
import com.wedo.backend.group.entity.GroupEntity;
import com.wedo.backend.group.entity.GroupMembershipEntity;
import com.wedo.backend.group.entity.GroupMembershipStatus;
import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.group.repository.GroupMembershipRepository;
import com.wedo.backend.group.repository.GroupRepository;
import com.wedo.backend.security.jwt.JwtService;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserRepository;
import java.math.BigDecimal;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;

@AutoConfigureMockMvc
class HomeControllerIntegrationTest extends AbstractPostgresIntegrationTest {
    @Autowired MockMvc mvc;
    @Autowired JwtService jwt;
    @Autowired UserRepository users;
    @Autowired GroupRepository groups;
    @Autowired GroupMembershipRepository memberships;
    @Autowired JdbcTemplate jdbc;
    @Autowired ExpenseService expenses;
    @Autowired ObjectMapper mapper;

    private UUID actor;
    private UUID peer;

    @BeforeEach
    void setUp() {
        actor = user("actor");
        peer = user("peer");
    }

    @Test
    void requiresAuthenticationAndReturnsBoundedEmptySections() throws Exception {
        mvc.perform(get("/api/v1/home")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/me/actions-required")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/groups/recent")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/home").header("Authorization", bearer(actor)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.recentGroups", hasSize(0)))
                .andExpect(jsonPath("$.upcomingActivities", hasSize(0)))
                .andExpect(jsonPath("$.financeSummary.totalOwedByMe").value("0.00"))
                .andExpect(jsonPath("$.financeSummary.totalOwedToMe").value("0.00"))
                .andExpect(jsonPath("$.actionsRequired", hasSize(0)))
                .andExpect(jsonPath("$.recentUpdates", hasSize(0)));
        mvc.perform(get("/api/v1/me/actions-required").header("Authorization", bearer(actor)))
                .andExpect(status().isOk()).andExpect(jsonPath("$", hasSize(0)));
        mvc.perform(get("/api/v1/groups/recent").header("Authorization", bearer(actor)))
                .andExpect(status().isOk()).andExpect(jsonPath("$", hasSize(0)));
    }

    @Test
    void recentAndUpcomingExcludeOutsidersArchivedAndTerminalRowsAndSortDeterministically() throws Exception {
        UUID older = group("older", GroupStatus.ACTIVE, actor, actor, Instant.now().minusSeconds(100));
        UUID newer = group("newer", GroupStatus.ACTIVE, actor, actor, Instant.now());
        UUID archived = group("archived", GroupStatus.ARCHIVED, actor, actor, Instant.now());
        UUID outsider = group("outsider", GroupStatus.ACTIVE, peer, peer, Instant.now());
        Instant now = Instant.now();
        UUID first = activity(older, "first", "CONFIRMED", now.plusSeconds(3600));
        UUID second = activity(newer, "second", "PLANNING", now.plusSeconds(7200));
        activity(older, "past", "CONFIRMED", now.minusSeconds(3600));
        activity(older, "cancelled", "CANCELLED", now.plusSeconds(1800));
        activity(archived, "archived activity", "CONFIRMED", now.plusSeconds(1800));
        activity(outsider, "private activity", "CONFIRMED", now.plusSeconds(1800));

        mvc.perform(get("/api/v1/home").header("Authorization", bearer(actor)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.recentGroups", hasSize(2)))
                .andExpect(jsonPath("$.recentGroups[0].id").value(newer.toString()))
                .andExpect(jsonPath("$.recentGroups[1].id").value(older.toString()))
                .andExpect(jsonPath("$.upcomingActivities", hasSize(2)))
                .andExpect(jsonPath("$.upcomingActivities[0].id").value(first.toString()))
                .andExpect(jsonPath("$.upcomingActivities[1].id").value(second.toString()))
                .andExpect(jsonPath("$.actionsRequired", hasSize(2)));
        var home = mvc.perform(get("/api/v1/home").header("Authorization", bearer(actor)))
                .andReturn().getResponse().getContentAsString();
        var recent = mvc.perform(get("/api/v1/groups/recent").header("Authorization", bearer(actor)))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        assertEquals(mapper.readTree(home).get("recentGroups"), mapper.readTree(recent));
    }

    @Test
    void boundedSectionsExcludeBannedAndKickedMemberships() throws Exception {
        Instant now = Instant.now();
        for (int index = 0; index < 9; index++) {
            UUID visible = group("visible-" + index, GroupStatus.ACTIVE, actor, actor, now.plusSeconds(index));
            activity(visible, "upcoming-" + index, "CONFIRMED", now.plusSeconds(3600 + index));
        }
        UUID banned = group("banned", GroupStatus.ACTIVE, peer, peer, now.plusSeconds(100));
        UUID kicked = group("kicked", GroupStatus.ACTIVE, peer, peer, now.plusSeconds(101));
        memberships.save(new GroupMembershipEntity(UUID.randomUUID(), banned, actor,
                GroupRole.MEMBER, GroupMembershipStatus.BANNED, now, now));
        memberships.save(new GroupMembershipEntity(UUID.randomUUID(), kicked, actor,
                GroupRole.MEMBER, GroupMembershipStatus.KICKED, now, now));
        activity(banned, "banned activity", "CONFIRMED", now.plusSeconds(600));
        activity(kicked, "kicked activity", "CONFIRMED", now.plusSeconds(601));

        mvc.perform(get("/api/v1/home").header("Authorization", bearer(actor)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.recentGroups", hasSize(5)))
                .andExpect(jsonPath("$.upcomingActivities", hasSize(5)))
                .andExpect(jsonPath("$.actionsRequired", hasSize(8)));
        mvc.perform(get("/api/v1/groups/recent").header("Authorization", bearer(actor)))
                .andExpect(status().isOk()).andExpect(jsonPath("$", hasSize(5)));
    }

    @Test
    void actionableItemsRespectCurrentUserAndCompletedStateAndFinanceMatchesLedger() throws Exception {
        UUID group = group("home finance", GroupStatus.ACTIVE, actor, actor, Instant.now());
        membership(group, peer);
        UUID hidden = group("other group", GroupStatus.ACTIVE, peer, peer, Instant.now());
        Instant now = Instant.now();
        UUID responded = activity(group, "responded", "CONFIRMED", now.plusSeconds(7200));
        UUID actionable = activity(group, "actionable", "CONFIRMED", now.plusSeconds(3600));
        activity(hidden, "hidden", "CONFIRMED", now.plusSeconds(3600));
        jdbc.update("INSERT INTO activity_participants(id,activity_id,user_id,rsvp_status,status_updated_at) VALUES (?,?,?,'GOING',CURRENT_TIMESTAMP)",
                UUID.randomUUID(), responded, actor);
        UUID poll = UUID.randomUUID();
        jdbc.update("INSERT INTO polls(id,activity_id,question) VALUES (?,?,?)", poll, actionable, "Choose date");
        jdbc.update("INSERT INTO poll_options(id,poll_id,text,sort_order) VALUES (?,?,?,0)", UUID.randomUUID(), poll, "Monday");
        UUID votedPoll = UUID.randomUUID();
        jdbc.update("INSERT INTO polls(id,activity_id,question) VALUES (?,?,?)", votedPoll, actionable, "Already voted");
        jdbc.update("INSERT INTO poll_options(id,poll_id,text,sort_order) VALUES (?,?,?,0)", UUID.randomUUID(), votedPoll, "Yes");
        jdbc.update("INSERT INTO poll_votes(id,poll_id,user_id) VALUES (?,?,?)", UUID.randomUUID(), votedPoll, actor);
        UUID task = task(actionable, actor, "Due task", "TODO", now.plusSeconds(3600));
        task(actionable, actor, "Done task", "DONE", now.plusSeconds(3600));
        UUID settlement = UUID.randomUUID();
        jdbc.update("""
                INSERT INTO settlements(id,group_id,from_user_id,to_user_id,amount,created_by,declaration_type)
                VALUES (?,?,?,?,? ,?,'I_PAID')
                """, settlement, group, peer, actor, new BigDecimal("10.00"), peer);
        UUID ownSettlement = UUID.randomUUID();
        jdbc.update("""
                INSERT INTO settlements(id,group_id,from_user_id,to_user_id,amount,created_by,declaration_type)
                VALUES (?,?,?,?,? ,?,'I_PAID')
                """, ownSettlement, group, actor, peer, new BigDecimal("10.00"), actor);

        UUID expense = UUID.randomUUID();
        jdbc.update("""
                INSERT INTO expenses(id,group_id,paid_by,created_by,title,total_amount,split_type,occurred_at)
                VALUES (?,?,?,?,? ,?,'CUSTOM_AMOUNT',CURRENT_TIMESTAMP)
                """, expense, group, peer, peer, "Dinner", new BigDecimal("100.00"));
        jdbc.update("INSERT INTO expense_shares(id,expense_id,user_id,amount) VALUES (?,?,?,?)",
                UUID.randomUUID(), expense, actor, new BigDecimal("100.00"));
        UUID completed = UUID.randomUUID();
        jdbc.update("""
                INSERT INTO settlements(id,group_id,from_user_id,to_user_id,amount,status,created_by,declaration_type,completed_at)
                VALUES (?,?,?,?,?,'COMPLETED',?,'I_PAID',CURRENT_TIMESTAMP)
                """, completed, group, actor, peer, new BigDecimal("40.00"), actor);
        assertEquals(new BigDecimal("60.00"), expenses.myBalances(group, actor).totalOwedByMe());

        mvc.perform(get("/api/v1/home").header("Authorization", bearer(actor)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.financeSummary.totalOwedByMe").value("60.00"))
                .andExpect(jsonPath("$.financeSummary.totalOwedToMe").value("0.00"))
                .andExpect(jsonPath("$.financeSummary.groups[0].groupId").value(group.toString()))
                .andExpect(jsonPath("$.actionsRequired", hasSize(4)))
                .andExpect(jsonPath("$.actionsRequired[0].type").value("SETTLEMENT_CONFIRMATION"))
                .andExpect(jsonPath("$.actionsRequired[0].targetId").value(settlement.toString()))
                .andExpect(jsonPath("$.actionsRequired[1].type").value("TASK_DUE"))
                .andExpect(jsonPath("$.actionsRequired[1].targetId").value(task.toString()))
                .andExpect(jsonPath("$.actionsRequired[2].type").value("RSVP_REQUIRED"))
                .andExpect(jsonPath("$.actionsRequired[3].type").value("POLL_VOTE_REQUIRED"))
                .andExpect(jsonPath("$.actionsRequired[3].targetId").value(poll.toString()));
        var home = mvc.perform(get("/api/v1/home").header("Authorization", bearer(actor)))
                .andReturn().getResponse().getContentAsString();
        var actions = mvc.perform(get("/api/v1/me/actions-required").header("Authorization", bearer(actor)))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        assertEquals(mapper.readTree(home).get("actionsRequired"), mapper.readTree(actions));
    }

    @Test
    void recentUpdatesUseRecipientInboxOrderAndHideStalePrivateTargets() throws Exception {
        UUID visible = group("visible updates", GroupStatus.ACTIVE, actor, actor, Instant.now());
        UUID stale = group("stale updates", GroupStatus.ACTIVE, peer, peer, Instant.now());
        memberships.save(new GroupMembershipEntity(UUID.randomUUID(), stale, actor,
                GroupRole.MEMBER, GroupMembershipStatus.KICKED, Instant.now(), Instant.now()));
        Instant base = Instant.now().minusSeconds(100);
        notification(actor, visible, "older", base.plusSeconds(1));
        notification(actor, stale, "stale", base.plusSeconds(2));
        notification(peer, visible, "other recipient", base.plusSeconds(3));
        notification(actor, visible, "newer", base.plusSeconds(4));

        mvc.perform(get("/api/v1/home").header("Authorization", bearer(actor)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.recentUpdates", hasSize(2)))
                .andExpect(jsonPath("$.recentUpdates[0].title").value("newer"))
                .andExpect(jsonPath("$.recentUpdates[0].target.actionable").value(true))
                .andExpect(jsonPath("$.recentUpdates[1].title").value("older"));
    }

    @Test
    void recentUpdatesAreBoundedToFiveNewestVisibleInboxItems() throws Exception {
        UUID visible = group("many updates", GroupStatus.ACTIVE, actor, actor, Instant.now());
        Instant base = Instant.now().minusSeconds(100);
        for (int index = 0; index < 7; index++) {
            notification(actor, visible, "update-" + index, base.plusSeconds(index));
        }
        mvc.perform(get("/api/v1/home").header("Authorization", bearer(actor)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.recentUpdates", hasSize(5)))
                .andExpect(jsonPath("$.recentUpdates[0].title").value("update-6"))
                .andExpect(jsonPath("$.recentUpdates[4].title").value("update-2"));
    }

    private UUID user(String label) {
        UUID id = UUID.randomUUID();
        String name = label + "-" + id.toString().substring(0, 8);
        Instant now = Instant.now();
        users.save(new UserEntity(id, name + "@example.test", name, name, UserStatus.ACTIVE, now, now));
        return id;
    }

    private UUID group(String name, GroupStatus status, UUID creator, UUID member, Instant updated) {
        UUID id = UUID.randomUUID();
        groups.save(new GroupEntity(id, name, null, null, status, creator, updated.minusSeconds(10), updated));
        membership(id, member);
        return id;
    }

    private void membership(UUID group, UUID member) {
        memberships.save(new GroupMembershipEntity(UUID.randomUUID(), group, member,
                GroupRole.MEMBER, GroupMembershipStatus.ACTIVE, Instant.now(), null));
    }

    private UUID activity(UUID group, String title, String status, Instant start) {
        UUID id = UUID.randomUUID();
        jdbc.update("""
                INSERT INTO activities(id,group_id,title,status,start_at,timezone)
                VALUES (?,?,?,?,?,'UTC')
                """, id, group, title, status, Timestamp.from(start));
        return id;
    }

    private UUID task(UUID activity, UUID assignee, String title, String status, Instant due) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO tasks(id,activity_id,title,status,due_at) VALUES (?,?,?,?,?)",
                id, activity, title, status, Timestamp.from(due));
        jdbc.update("INSERT INTO task_assignees(id,task_id,user_id) VALUES (?,?,?)", UUID.randomUUID(), id, assignee);
        return id;
    }

    private void notification(UUID recipient, UUID group, String title, Instant at) {
        jdbc.update("""
                INSERT INTO notifications(id,user_id,group_id,category,title,body,data,created_at)
                VALUES (?,?,?,'GROUP',?,'Update',?::jsonb,?)
                """, UUID.randomUUID(), recipient, group, title,
                "{\"targetType\":\"GROUP\",\"targetId\":\"" + group + "\",\"route\":\"/groups/info\"}",
                Timestamp.from(at));
    }

    private String bearer(UUID user) { return "Bearer " + jwt.generateAccessToken(user); }
}
