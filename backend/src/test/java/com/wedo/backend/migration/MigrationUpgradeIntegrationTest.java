package com.wedo.backend.migration;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.UUID;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.testcontainers.containers.PostgreSQLContainer;

class MigrationUpgradeIntegrationTest {
    @Test
    void upgradesPreSocialSchemaWithoutLosingExistingActivityPoll() {
        // Disposable database only: never attach to the shared QA datasource.
        try (var postgres = new PostgreSQLContainer<>("postgres:17-alpine")) {
            postgres.start();
            var source = new DriverManagerDataSource(postgres.getJdbcUrl(), postgres.getUsername(), postgres.getPassword());
            var before = Flyway.configure().dataSource(source).locations("classpath:db/migration").target("12").load();
            before.migrate();
            var jdbc = new JdbcTemplate(source);
            UUID user = UUID.randomUUID(), group = UUID.randomUUID(), activity = UUID.randomUUID(), poll = UUID.randomUUID();
            jdbc.update("INSERT INTO users(id,email,status) VALUES (?,?,'ACTIVE')", user, user + "@upgrade.invalid");
            jdbc.update("INSERT INTO groups(id,name,created_by) VALUES (?,'Upgrade fixture',?)", group, user);
            jdbc.update("INSERT INTO activities(id,group_id,created_by,title,start_at,timezone) VALUES (?,?,?,'Retained activity',now(),'Asia/Ho_Chi_Minh')", activity, group, user);
            jdbc.update("INSERT INTO polls(id,activity_id,created_by,question) VALUES (?,?,?,'Retained question')", poll, activity, user);
            var current = Flyway.configure().dataSource(source).locations("classpath:db/migration").load();
            current.migrate();
            current.validate();
            assertThat(current.info().current().getVersion().getVersion()).isEqualTo("20");
            assertThat(jdbc.queryForObject("SELECT group_id FROM polls WHERE id=?", UUID.class, poll)).isEqualTo(group);
            assertThat(jdbc.queryForObject("SELECT question FROM polls WHERE id=?", String.class, poll)).isEqualTo("Retained question");
            assertThat(jdbc.queryForObject("SELECT title FROM activities WHERE id=?", String.class, activity)).isEqualTo("Retained activity");
            assertThat(jdbc.queryForObject("SELECT count(*) FROM users WHERE id=?", Integer.class, user)).isEqualTo(1);
            // V0 bootstrap is a migration too: V0 through V20 means 21 entries.
            assertThat(jdbc.queryForObject("SELECT count(*) FROM flyway_schema_history WHERE success", Integer.class)).isEqualTo(21);
        }
    }
}
