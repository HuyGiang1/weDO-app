package com.wedo.backend.performance;

import static org.assertj.core.api.Assertions.assertThat;

import com.wedo.backend.calendar.CalendarService;
import com.wedo.backend.chat.service.ChatService;
import com.wedo.backend.expense.service.ExpenseService;
import com.wedo.backend.fund.service.FundService;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.group.service.GroupService;
import com.wedo.backend.home.HomeService;
import com.wedo.backend.home.HomeQueryRepository;
import com.wedo.backend.notification.service.NotificationService;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.Statement;
import java.time.OffsetDateTime;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.function.Supplier;
import javax.sql.DataSource;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.config.BeanPostProcessor;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

@SpringBootTest(properties = {"logging.level.org.springframework=INFO", "logging.level.org.hibernate=INFO"})
@Import(ReadPerformanceIntegrationTest.MeasurementConfiguration.class)
@ActiveProfiles("test")
@Testcontainers
class ReadPerformanceIntegrationTest {
    @Container static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:17-alpine");
    @DynamicPropertySource static void database(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
    }
    @Autowired JdbcTemplate jdbc;
    @Autowired ChatService chat;
    @Autowired NotificationService notifications;
    @Autowired com.wedo.backend.common.event.PostCommitDelivery delivery;
    @Autowired CalendarService calendar;
    @Autowired ExpenseService expenses;
    @Autowired FundService funds;
    @Autowired HomeService home;
    @Autowired GroupService groups;
    @Autowired HomeQueryRepository homeQueries;

    @Test
    void representativeReadBudgetsAndPlans() throws Exception {
        UUID user = UUID.randomUUID(), peer = UUID.randomUUID(), group = UUID.randomUUID(), conversation = UUID.randomUUID();
        for (UUID id : List.of(user, peer)) jdbc.update(
                "INSERT INTO users(id,email,username,display_name,status) VALUES (?,?,?,?, 'ACTIVE')",
                id, id + "@perf.invalid", "p" + id.toString().replace("-", "").substring(0, 20), "Performance fixture");
        jdbc.update("INSERT INTO groups(id,name,created_by) VALUES (?,'Performance fixture',?)", group, user);
        jdbc.update("INSERT INTO group_settings(group_id) VALUES (?)", group);
        jdbc.update("INSERT INTO group_memberships(id,group_id,user_id,role) VALUES (gen_random_uuid(),?,?,'OWNER'),(gen_random_uuid(),?,?,'MEMBER')", group,user,group,peer);
        jdbc.update("INSERT INTO conversations(id,type) VALUES (?,'GROUP')", conversation);
        jdbc.update("INSERT INTO group_conversations(conversation_id,group_id) VALUES (?,?)", conversation,group);
        jdbc.update("INSERT INTO conversation_sequences(conversation_id,current_sequence) VALUES (?,2000)", conversation);
        jdbc.update("INSERT INTO messages(id,conversation_id,sender_id,sequence,type,content) SELECT gen_random_uuid(),?,?,n,'TEXT','fixture' FROM generate_series(1,2000) n", conversation,peer);
        jdbc.update("INSERT INTO activities(id,group_id,created_by,title,start_at,timezone) SELECT gen_random_uuid(),?,?,'fixture',TIMESTAMPTZ '2030-01-01 00:00:00+00' + n * INTERVAL '1 day','UTC' FROM generate_series(1,1500) n",group,user);
        jdbc.update("INSERT INTO activity_participants(id,activity_id,user_id) SELECT gen_random_uuid(),id,? FROM activities WHERE group_id=?",user,group);
        jdbc.update("INSERT INTO notifications(id,user_id,category,title,body,group_id,data) SELECT gen_random_uuid(),?,'ACTIVITY','fixture','fixture',?,jsonb_build_object('targetType','ACTIVITY','targetId',id::text) FROM activities WHERE group_id=? LIMIT 300",user,group,group);
        jdbc.update("INSERT INTO expenses(id,group_id,paid_by,created_by,title,total_amount,split_type,occurred_at) SELECT gen_random_uuid(),?,?,?,'fixture',100,'EQUAL',now() FROM generate_series(1,300)",group,peer,peer);
        jdbc.update("INSERT INTO expense_shares(id,expense_id,user_id,amount) SELECT gen_random_uuid(),id,?,100 FROM expenses WHERE group_id=?",user,group);
        UUID fund = UUID.randomUUID();
        jdbc.update("INSERT INTO group_funds(id,group_id,created_by) VALUES (?,?,?)",fund,group,user);
        jdbc.update("INSERT INTO fund_collections(id,fund_id,title,created_by) SELECT gen_random_uuid(),?,'fixture',? FROM generate_series(1,30)",fund,user);
        jdbc.update("INSERT INTO fund_collection_obligations(id,collection_id,user_id,amount_due) SELECT gen_random_uuid(),id,?,100 FROM fund_collections WHERE fund_id=?",user,fund);
        jdbc.execute("ANALYZE");

        Measure<?> history1 = measure("chat.history.1", () -> chat.history(conversation,user,null,1));
        Measure<?> history30 = measure("chat.history.30", () -> chat.history(conversation,user,null,30));
        assertThat(history30.count()).isLessThanOrEqualTo(history1.count()+2);
        var page = chat.history(conversation,user,null,30);
        assertThat(page.messages()).hasSize(30);
        assertThat(page.messages().stream().map(m -> m.sequence()).toList()).containsExactlyElementsOf(java.util.stream.LongStream.rangeClosed(1971,2000).boxed().toList());
        Measure<?> inbox1 = measure("notification.1", () -> notifications.listNotifications(user,0,1));
        Measure<?> inbox30 = measure("notification.30", () -> notifications.listNotifications(user,0,30));
        assertThat(inbox30.count()).isLessThanOrEqualTo(inbox1.count()+2);
        assertThat(notifications.listNotifications(user,0,30).items()).hasSize(30).allMatch(n -> n.target().actionable());
        measure("notification.unread", () -> notifications.getUnreadCount(user));
        var chat1 = measure("chat.list", () -> chat.list(user));
        var from = OffsetDateTime.parse("2030-02-01T00:00:00Z");
        var to = OffsetDateTime.parse("2030-03-01T00:00:00Z");
        Measure<?> month = measure("calendar.range", () -> calendar.activities(from,to,null,null,null,user));
        assertThat(calendar.activities(from,to,null,null,null,user)).hasSize(29);
        jdbc.query("SELECT tablename,indexname,indexdef FROM pg_indexes WHERE schemaname='public' AND tablename IN ('messages','message_attachments','message_reactions','message_hidden_users','conversation_read_states','notifications','activities','activity_participants','group_memberships','user_activity_reminders','expenses','expense_shares','settlements','fund_collections','fund_contributions','fund_collection_obligations','fund_transactions') ORDER BY tablename,indexname",
                (org.springframework.jdbc.core.RowCallbackHandler) rs -> System.out.println("INDEX " + rs.getString(1) + " " + rs.getString(2) + " " + rs.getString(3)));
        measure("expense.list", () -> expenses.list(group,user,null,null,null,null,null));
        measure("expense.myBalances", () -> expenses.myBalances(group,user));
        measure("settlement.list", () -> expenses.listSettlements(group,user,null,null,null));
        Measure<?> collections = measure("fund.collections", () -> funds.listCollections(fund,user,null));
        assertThat(collections.count()).isLessThanOrEqualTo(15);
        measure("fund.transactions", () -> funds.listTransactions(fund,user,null,null));
        measure("home.recentGroups", () -> groups.getGroups(user,0,5,GroupStatus.ACTIVE));
        measure("home.finance", () -> expenses.homeBalances(user));
        measure("home.actions", () -> homeQueries.actions(user,Instant.now()));
        measure("home.upcoming", () -> homeQueries.upcoming(user,Instant.now()));
        Measure<?> home1 = measure("home.total", () -> home.get(user));

        explain("chat.history", history30, "FROM messages m LEFT JOIN users");
        explain("notification.inbox", inbox30, "FROM notifications n");
        explain("calendar.range", month, "FROM activities a");
        System.out.println("PERF inboxGrowth=" + (inbox30.count()-inbox1.count()));
        for (int i=0; i<19; i++) {
            UUID extra = UUID.randomUUID(), conv = UUID.randomUUID();
            jdbc.update("INSERT INTO groups(id,name,created_by) VALUES (?,'Additional fixture',?)",extra,user);
            jdbc.update("INSERT INTO group_settings(group_id) VALUES (?)",extra);
            jdbc.update("INSERT INTO group_memberships(id,group_id,user_id,role) VALUES (gen_random_uuid(),?,?,'OWNER')",extra,user);
            jdbc.update("INSERT INTO conversations(id,type) VALUES (?,'GROUP')",conv);
            jdbc.update("INSERT INTO group_conversations(conversation_id,group_id) VALUES (?,?)",conv,extra);
            jdbc.update("INSERT INTO conversation_sequences(conversation_id) VALUES (?)",conv);
            jdbc.update("INSERT INTO activities(id,group_id,title,start_at,timezone) SELECT gen_random_uuid(),?,'irrelevant',TIMESTAMPTZ '2020-01-01 00:00:00+00','UTC' FROM generate_series(1,100)",extra);
        }
        var chat20 = measure("chat.list.20groups", () -> chat.list(user));
        assertThat(chat20.count()).isLessThanOrEqualTo(chat1.count()+2);
        assertThat(chat20.value()).hasSize(20);
        measure("home.finance.20groups", () -> expenses.homeBalances(user));
        Measure<?> home20 = measure("home.total.20groups", () -> home.get(user));
        assertThat(home20.count()).isLessThanOrEqualTo(home1.count()+3);
        assertThat(calendar.activities(from,to,null,null,null,user)).hasSize(29);
        jdbc.update("INSERT INTO settlements(id,group_id,from_user_id,to_user_id,amount,created_by,declaration_type) SELECT gen_random_uuid(),?,?,?,1,?,'I_PAID' FROM generate_series(1,100)",group,user,peer,user);
        jdbc.update("INSERT INTO settlement_status_history(id,settlement_id,to_status,changed_by) SELECT gen_random_uuid(),id,'PENDING',? FROM settlements WHERE group_id=?",user,group);
        var settlements = measure("settlement.list.100", () -> expenses.listSettlements(group,user,null,null,null));
        assertThat(settlements.value()).hasSize(100);
        assertThat(settlements.count()).isLessThanOrEqualTo(10);
        var settlement = settlements.value().get(0);
        assertThat(settlement).isEqualTo(expenses.settlementDetail(settlement.id(),user));
        mixedTargets(user, peer, group, conversation, fund);
        jdbc.update("INSERT INTO fund_contributions(id,fund_id,collection_id,user_id,amount,status,payment_time,confirmed_by,confirmed_at) SELECT gen_random_uuid(),?,id,?,100,'CONFIRMED',now(),?,now() FROM fund_collections WHERE fund_id=?",fund,user,user,fund);
        jdbc.update("INSERT INTO fund_transactions(id,fund_id,transaction_type,direction,amount,reference_type,reference_id,created_by) SELECT gen_random_uuid(),?,'CONTRIBUTION','IN',amount,'FUND_CONTRIBUTION',id,? FROM fund_contributions WHERE fund_id=?",fund,user,fund);
        jdbc.update("INSERT INTO fund_expenses(id,fund_id,title,amount,occurred_at,created_by) SELECT gen_random_uuid(),?,'fixture',5,now(),? FROM generate_series(1,300)",fund,user);
        jdbc.update("INSERT INTO fund_transactions(id,fund_id,transaction_type,direction,amount,reference_type,reference_id,created_by) SELECT gen_random_uuid(),?,'FUND_EXPENSE','OUT',amount,'FUND_EXPENSE',id,? FROM fund_expenses WHERE fund_id=?",fund,user,fund);
        var populated = measure("fund.transactions.330rows", () -> funds.listTransactions(fund,user,null,null));
        assertThat(populated.value()).hasSize(330);
        measure("fund.collections.confirmed", () -> funds.listCollections(fund,user,null));
        measure("chat.send.afterCommit", () -> chat.send(conversation,user,
                new com.wedo.backend.chat.dto.ChatRequests.SendMessage("Performance connection diagnostic",null)));
        org.awaitility.Awaitility.await().atMost(java.time.Duration.ofSeconds(20)).until(delivery::isIdle);
        // Reads after revocation must not reuse authorization from a prior request.
        jdbc.update("UPDATE group_memberships SET status='LEFT',ended_at=now() WHERE group_id=? AND user_id=?",group,user);
        assertThat(notifications.listNotifications(user,0,30).items()).allMatch(n -> !n.target().actionable());
    }

    private void mixedTargets(UUID owner, UUID viewer, UUID group, UUID conversation, UUID fund) {
        UUID activity = jdbc.queryForObject("SELECT id FROM activities WHERE group_id=? ORDER BY id LIMIT 1",UUID.class,group);
        UUID expense = jdbc.queryForObject("SELECT id FROM expenses WHERE group_id=? ORDER BY id LIMIT 1",UUID.class,group);
        UUID poll=UUID.randomUUID(), task=UUID.randomUUID(), invitation=UUID.randomUUID(), settlement=UUID.randomUUID();
        jdbc.update("INSERT INTO polls(id,activity_id,question) VALUES (?,?,'fixture')",poll,activity);
        jdbc.update("INSERT INTO tasks(id,activity_id,title) VALUES (?,?,'fixture')",task,activity);
        jdbc.update("INSERT INTO group_invitations(id,group_id,inviter_id,invitee_id) VALUES (?,?,?,?)",invitation,group,owner,viewer);
        jdbc.update("INSERT INTO settlements(id,group_id,from_user_id,to_user_id,amount,created_by,declaration_type) VALUES (?,?,?,?,1,?,'I_PAID')",settlement,group,owner,viewer,owner);
        List<String> types=List.of("GROUP","ACTIVITY","POLL","TASK","EXPENSE","SETTLEMENT","FUND","CONVERSATION","GROUP_INVITATION");
        List<UUID> targets=List.of(group,activity,poll,task,expense,settlement,fund,conversation,invitation);
        for(int i=0;i<types.size();i++) jdbc.update("INSERT INTO notifications(id,user_id,group_id,category,title,body,data) VALUES (gen_random_uuid(),?,?,'GROUP','mixed','fixture',jsonb_build_object('targetType',?::text,'targetId',?::text))",viewer,group,types.get(i),targets.get(i).toString());
        var small = measure("notification.mixed.9", () -> notifications.listNotifications(viewer,0,100));
        assertThat(small.value().items()).hasSize(9).allMatch(n -> n.target().actionable());
        assertThat(small.value().items().stream().filter(n -> List.of("POLL","TASK").contains(n.target().targetType())).toList())
                .allMatch(n -> n.target().route().equals("/activities/detail") && n.target().params().get("activityId").equals(activity.toString()));
        jdbc.update("INSERT INTO notifications(id,user_id,group_id,category,title,body,data) SELECT gen_random_uuid(),user_id,group_id,category,title,body,data FROM notifications WHERE user_id=?",viewer);
        var large = measure("notification.mixed.18", () -> notifications.listNotifications(viewer,0,100));
        assertThat(large.count()).isLessThanOrEqualTo(small.count()+1);
        assertThat(large.value().items()).hasSize(18);
        jdbc.update("UPDATE activities SET status='CANCELLED' WHERE id=?",activity);
        jdbc.update("UPDATE expenses SET status='CANCELLED' WHERE id=?",expense);
        jdbc.update("UPDATE settlements SET status='CANCELLED' WHERE id=?",settlement);
        jdbc.update("UPDATE group_invitations SET status='DECLINED',responded_at=now() WHERE id=?",invitation);
        var stale = notifications.listNotifications(viewer,0,100).items();
        assertThat(stale.stream().filter(n -> List.of("ACTIVITY","EXPENSE","SETTLEMENT","GROUP_INVITATION").contains(n.target().targetType())).toList()).allMatch(n -> !n.target().actionable());
    }

    private <T> Measure<T> measure(String label, Supplier<T> call) {
        List<Query> queries = new ArrayList<>();
        Counter.queries.set(queries);
        ConnectionStats stats = new ConnectionStats();
        Counter.connections.set(stats);
        try {
            T result = call.get();
            System.out.println("PERF " + label + " statements=" + queries.size()
                    + " connections=" + stats.acquired + " peakHeld=" + stats.peak);
            return new Measure<>(result,List.copyOf(queries));
        } finally { Counter.queries.remove(); Counter.connections.remove(); }
    }

    private void explain(String label, Measure<?> measured, String shape) throws Exception {
        Query query = measured.queries().stream().filter(q -> q.sql().contains(shape)).findFirst().orElseThrow();
        try (Connection connection = jdbc.getDataSource().getConnection();
             PreparedStatement statement = connection.prepareStatement("EXPLAIN (ANALYZE, BUFFERS) " + query.sql())) {
            for (Binding binding : query.bindings()) invoke(statement,binding.method(),binding.args());
            try (var result = statement.executeQuery()) {
                while(result.next()) {
                    String line = result.getString(1);
                    if (!line.contains("Filter:") && !line.contains("Cond:") && !line.contains("Key:"))
                        System.out.println("PLAN " + label + " " + line);
                }
            }
        }
    }

    record Measure<T>(T value, List<Query> queries) { int count() { return queries.size(); } }
    record Binding(Method method, Object[] args) { }
    record Query(String sql, List<Binding> bindings) { }
    static final class Counter {
        static final ThreadLocal<List<Query>> queries = new ThreadLocal<>();
        static final ThreadLocal<ConnectionStats> connections = new ThreadLocal<>();
    }
    static final class ConnectionStats { int acquired, active, peak; }

    // Wrap only this test context. Count JDBC executions, including ORM/JdbcTemplate, not parameter values.
    @TestConfiguration(proxyBeanMethods = false)
    static class MeasurementConfiguration {
        @Bean static BeanPostProcessor countingDataSource() {
            return new BeanPostProcessor() {
                @Override public Object postProcessAfterInitialization(Object bean, String name) {
                    if (!(bean instanceof DataSource)) return bean;
                    return Proxy.newProxyInstance(DataSource.class.getClassLoader(),new Class<?>[]{DataSource.class},(proxy,method,args) -> {
                        Object result = invoke(bean,method,args);
                        return result instanceof Connection connection ? wrapConnection(connection) : result;
                    });
                }
            };
        }
    }
    private static Connection wrapConnection(Connection connection) {
        ConnectionStats stats = Counter.connections.get();
        if (stats != null) { stats.acquired++; stats.peak=Math.max(stats.peak,++stats.active); }
        return (Connection) Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class<?>[]{Connection.class},(proxy,method,args) -> {
            Object result = invoke(connection,method,args);
            if (method.getName().equals("close") && stats != null) stats.active--;
            if (!(result instanceof Statement statement)) return result;
            String sql = args != null && args.length > 0 && args[0] instanceof String s ? s : "";
            List<Binding> bindings = new ArrayList<>();
            Class<?> type = statement instanceof PreparedStatement ? PreparedStatement.class : Statement.class;
            return Proxy.newProxyInstance(type.getClassLoader(),new Class<?>[]{type},(p,m,a) -> {
                if (m.getName().startsWith("set") && a != null && a.length >= 2 && a[0] instanceof Integer)
                    bindings.add(new Binding(m,a.clone()));
                if (m.getName().startsWith("execute") && Counter.queries.get() != null)
                    Counter.queries.get().add(new Query(sql.isEmpty() && a != null && a[0] instanceof String s ? s : sql,List.copyOf(bindings)));
                return invoke(statement,m,a);
            });
        });
    }
    private static Object invoke(Object target, Method method, Object[] args) throws Exception {
        try { return method.invoke(target,args); }
        catch (InvocationTargetException e) {
            if (e.getCause() instanceof Exception exception) throw exception;
            throw e;
        }
    }
}
