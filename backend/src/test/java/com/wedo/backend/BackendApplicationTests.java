package com.wedo.backend;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest
@ActiveProfiles("test")
@Testcontainers
class BackendApplicationTests {

	@Container
	static final PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:17-alpine")
			.withDatabaseName("wedo_test")
			.withUsername("wedo")
			.withPassword("wedo_test");

	@DynamicPropertySource
	static void configurePostgres(DynamicPropertyRegistry registry) {
		registry.add("spring.datasource.url", postgres::getJdbcUrl);
		registry.add("spring.datasource.username", postgres::getUsername);
		registry.add("spring.datasource.password", postgres::getPassword);
	}

	@Autowired
	private JdbcTemplate jdbcTemplate;

	@Test
	void contextLoadsAndFlywayMigratesPostgres() {
		assertThat(postgres.isRunning()).isTrue();

		Integer bootstrapMigrations = jdbcTemplate.queryForObject(
				"""
						SELECT count(*)
						FROM flyway_schema_history
						WHERE version = '0'
						  AND description = 'bootstrap'
						  AND success = true
						""",
				Integer.class
		);
		assertThat(bootstrapMigrations).isEqualTo(1);

		Integer v1Migrations = jdbcTemplate.queryForObject(
				"""
						SELECT count(*)
						FROM flyway_schema_history
						WHERE version = '1'
						  AND description = 'identity and auth'
						  AND success = true
						""",
				Integer.class
		);
		assertThat(v1Migrations).isEqualTo(1);

		Integer v2Migrations = jdbcTemplate.queryForObject(
				"""
						SELECT count(*)
						FROM flyway_schema_history
						WHERE version = '2'
						  AND description = 'social'
						  AND success = true
						""",
				Integer.class
		);
		assertThat(v2Migrations).isEqualTo(1);

		Integer v3Migrations = jdbcTemplate.queryForObject(
				"""
						SELECT count(*)
						FROM flyway_schema_history
						WHERE version = '3'
						  AND description = 'groups'
						  AND success = true
						""",
				Integer.class
		);
		assertThat(v3Migrations).isEqualTo(1);

		Integer v4Migrations = jdbcTemplate.queryForObject(
				"""
						SELECT count(*)
						FROM flyway_schema_history
						WHERE version = '4'
						  AND description = 'chat'
						  AND success = true
						""",
				Integer.class
		);
		assertThat(v4Migrations).isEqualTo(1);

		Integer v5Migrations = jdbcTemplate.queryForObject(
				"""
						SELECT count(*)
						FROM flyway_schema_history
						WHERE version = '5'
						  AND description = 'activities'
						  AND success = true
						""",
				Integer.class
		);
		assertThat(v5Migrations).isEqualTo(1);

		Integer v6Migrations = jdbcTemplate.queryForObject(
				"""
						SELECT count(*)
						FROM flyway_schema_history
						WHERE version = '6'
						  AND description = 'poll task discussion'
						  AND success = true
						""",
				Integer.class
		);
		assertThat(v6Migrations).isEqualTo(1);

		Integer v7Migrations = jdbcTemplate.queryForObject(
				"""
						SELECT count(*)
						FROM flyway_schema_history
						WHERE version = '7'
						  AND description = 'finance'
						  AND success = true
						""",
				Integer.class
		);
		assertThat(v7Migrations).isEqualTo(1);

		Integer v8Migrations = jdbcTemplate.queryForObject(
				"""
						SELECT count(*)
						FROM flyway_schema_history
						WHERE version = '8'
						  AND description = 'fund'
						  AND success = true
						""",
				Integer.class
		);
		assertThat(v8Migrations).isEqualTo(1);

		java.util.List<String> tables = jdbcTemplate.queryForList(
				"""
						SELECT table_name
						FROM information_schema.tables
						WHERE table_schema = 'public'
						  AND table_name IN (
						      'users',
						      'user_credentials',
						      'user_privacy_settings',
						      'auth_tokens',
						      'refresh_sessions',
						      'user_devices',
						      'friend_requests',
						      'friendships',
						      'user_blocks',
						      'user_presence_snapshots',
						      'groups',
						      'group_settings',
						      'group_memberships',
						      'group_invitations',
						      'group_invite_links',
						      'group_join_requests',
						      'group_bans',
						      'group_activity_logs',
						      'conversations',
						      'direct_conversations',
						      'group_conversations',
						      'message_requests',
						      'conversation_sequences',
						      'messages',
						      'message_attachments',
						      'message_edit_history',
						      'message_hidden_users',
						      'message_reactions',
						      'conversation_read_states',
						      'message_pins',
						      'activities',
						      'activity_participants',
						      'activity_rsvp_history',
						      'activity_waitlist_sequences',
						      'activity_status_history',
						      'activity_change_logs',
						      'polls',
						      'poll_options',
						      'poll_votes',
						      'poll_vote_choices',
						      'tasks',
						      'task_assignees',
						      'task_status_history',
						      'activity_comments',
						      'expenses',
						      'expense_shares',
						      'expense_change_logs',
						      'settlements',
						      'settlement_status_history',
						      'group_funds',
						      'fund_managers',
						      'fund_collections',
						      'fund_collection_obligations',
						      'fund_contributions',
						      'fund_expenses',
						      'fund_reimbursements',
						      'fund_transactions',
						      'fund_transaction_reversals'
						  )
						""",
				String.class
		);

		assertThat(tables).containsExactlyInAnyOrder(
				"users",
				"user_credentials",
				"user_privacy_settings",
				"auth_tokens",
				"refresh_sessions",
				"user_devices",
				"friend_requests",
				"friendships",
				"user_blocks",
				"user_presence_snapshots",
				"groups",
				"group_settings",
				"group_memberships",
				"group_invitations",
				"group_invite_links",
				"group_join_requests",
				"group_bans",
				"group_activity_logs",
				"conversations",
				"direct_conversations",
				"group_conversations",
				"message_requests",
				"conversation_sequences",
				"messages",
				"message_attachments",
				"message_edit_history",
				"message_hidden_users",
				"message_reactions",
				"conversation_read_states",
				"message_pins",
				"activities",
				"activity_participants",
				"activity_rsvp_history",
				"activity_waitlist_sequences",
				"activity_status_history",
				"activity_change_logs",
				"polls",
				"poll_options",
				"poll_votes",
				"poll_vote_choices",
				"tasks",
				"task_assignees",
				"task_status_history",
				"activity_comments",
				"expenses",
				"expense_shares",
				"expense_change_logs",
				"settlements",
				"settlement_status_history",
				"group_funds",
				"fund_managers",
				"fund_collections",
				"fund_collection_obligations",
				"fund_contributions",
				"fund_expenses",
				"fund_reimbursements",
				"fund_transactions",
				"fund_transaction_reversals"
		);

		// V8 Schema Invariant Checks
		// 1. Partial Unique index for max 1 ACTIVE fund per group
		Integer activeFundIndexCount = jdbcTemplate.queryForObject(
				"""
						SELECT count(*)
						FROM pg_indexes
						WHERE schemaname = 'public'
						  AND tablename = 'group_funds'
						  AND indexname = 'uq_group_funds_active_group'
						  AND indexdef LIKE '%WHERE%status%ACTIVE%'
						""",
				Integer.class
		);
		assertThat(activeFundIndexCount).isEqualTo(1);

		// 2. UNIQUE constraint on fund_managers (fund_id, user_id)
		Integer fundManagerUniqueConstraint = jdbcTemplate.queryForObject(
				"""
						SELECT count(*)
						FROM information_schema.table_constraints
						WHERE table_schema = 'public'
						  AND table_name = 'fund_managers'
						  AND constraint_name = 'uq_fund_managers_fund_user'
						  AND constraint_type = 'UNIQUE'
						""",
				Integer.class
		);
		assertThat(fundManagerUniqueConstraint).isEqualTo(1);

		// 3. UNIQUE constraint on fund_collection_obligations (collection_id, user_id)
		Integer obligationUniqueConstraint = jdbcTemplate.queryForObject(
				"""
						SELECT count(*)
						FROM information_schema.table_constraints
						WHERE table_schema = 'public'
						  AND table_name = 'fund_collection_obligations'
						  AND constraint_name = 'uq_fund_collection_obligations_user'
						  AND constraint_type = 'UNIQUE'
						""",
				Integer.class
		);
		assertThat(obligationUniqueConstraint).isEqualTo(1);

		// 4. Ledger domain reference idempotency index
		Integer ledgerDomainRefIndexCount = jdbcTemplate.queryForObject(
				"""
						SELECT count(*)
						FROM pg_indexes
						WHERE schemaname = 'public'
						  AND tablename = 'fund_transactions'
						  AND indexname = 'uq_fund_transactions_domain_ref'
						""",
				Integer.class
		);
		assertThat(ledgerDomainRefIndexCount).isEqualTo(1);

		// 5. UNIQUE constraints on fund_transaction_reversals (1-to-1 bijection)
		Integer reversalUniqueConstraints = jdbcTemplate.queryForObject(
				"""
						SELECT count(*)
						FROM information_schema.table_constraints
						WHERE table_schema = 'public'
						  AND table_name = 'fund_transaction_reversals'
						  AND constraint_type = 'UNIQUE'
						""",
				Integer.class
		);
		assertThat(reversalUniqueConstraints).isEqualTo(2);
	}

}
