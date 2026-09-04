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
						      'user_presence_snapshots'
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
				"user_presence_snapshots"
		);
	}

}
