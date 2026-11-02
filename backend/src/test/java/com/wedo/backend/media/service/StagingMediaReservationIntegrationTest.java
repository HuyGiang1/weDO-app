package com.wedo.backend.media.service;

import static org.junit.jupiter.api.Assertions.*;
import com.wedo.backend.common.error.*;
import java.util.UUID;
import java.util.concurrent.*;
import javax.sql.DataSource;
import org.junit.jupiter.api.*;
import org.springframework.context.annotation.*;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.*;
import org.springframework.jdbc.datasource.init.ScriptUtils;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.EnableTransactionManagement;
import org.springframework.transaction.support.TransactionTemplate;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.*;

/** Real PostgreSQL, own labelled disposable database; no QA/container reuse. */
@Testcontainers
class StagingMediaReservationIntegrationTest {
    @Container static final PostgreSQLContainer<?> PG=new PostgreSQLContainer<>("postgres:17-alpine")
            .withDatabaseName("wedo_d6_media_test").withLabel("org.wedo.purpose","d6-media-budget-test");
    static AnnotationConfigApplicationContext context;
    static JdbcTemplate db;
    static StagingMediaReservationService ledger;
    static final UUID A=UUID.randomUUID(),B=UUID.randomUUID();
    @Configuration(proxyBeanMethods=false) @EnableTransactionManagement
    static class Config {
        @Bean DataSource dataSource(){return new DriverManagerDataSource(PG.getJdbcUrl(),PG.getUsername(),PG.getPassword());}
        @Bean JdbcTemplate jdbc(DataSource d){return new JdbcTemplate(d);}
        @Bean PlatformTransactionManager tx(DataSource d){return new DataSourceTransactionManager(d);}
        @Bean StagingMediaReservationService ledger(JdbcTemplate j){return new StagingMediaReservationService(j);}
    }
    @BeforeAll static void init() throws Exception {
        context=new AnnotationConfigApplicationContext(Config.class);db=context.getBean(JdbcTemplate.class);
        ledger=context.getBean(StagingMediaReservationService.class);
        assertTrue(org.springframework.aop.support.AopUtils.isAopProxy(ledger));
        db.execute("CREATE TABLE users(id UUID PRIMARY KEY)");
        try(var connection=context.getBean(DataSource.class).getConnection()) {
            ScriptUtils.executeSqlScript(connection,new ClassPathResource("db/migration/V21__staging_media_upload_reservations.sql"));
        }
        db.update("INSERT INTO users VALUES (?),(?)",A,B);
    }
    @BeforeEach void clear(){
        db.execute("TRUNCATE staging_media_upload_reservations");
        db.update("UPDATE staging_media_upload_control SET enabled=true WHERE id=1");
    }
    @AfterAll static void close(){if(context!=null)context.close();}
    void reserve(UUID who,long bytes,long cap){ledger.reserve(who,"synthetic/"+UUID.randomUUID(),bytes,cap,5,600);}
    long used(){return db.queryForObject("SELECT coalesce(sum(reserved_bytes),0) FROM staging_media_upload_reservations",Long.class);}
    long count(){return db.queryForObject("SELECT count(*) FROM staging_media_upload_reservations",Long.class);}
    @Test void exactGlobalBudgetAndRejectedAdmissionDoesNotIssueAnotherReservation(){
        reserve(A,100,150);reserve(B,50,150);
        assertEquals(ErrorCode.STAGING_MEDIA_QUOTA_EXCEEDED,assertThrows(BusinessException.class,()->reserve(A,1,150)).errorCode());
        assertEquals(150,used());assertEquals(2,count());
    }
    @Test void runtimeCloseAndReopenDoesNotResetExistingReservations(){
        reserve(A,50,50);
        db.update("UPDATE staging_media_upload_control SET enabled=false WHERE id=1");
        assertEquals(ErrorCode.STAGING_MEDIA_UPLOAD_DISABLED,assertThrows(BusinessException.class,()->reserve(B,1,50)).errorCode());
        assertEquals(50,used());
        db.update("UPDATE staging_media_upload_control SET enabled=true WHERE id=1");
        assertEquals(ErrorCode.STAGING_MEDIA_QUOTA_EXCEEDED,assertThrows(BusinessException.class,()->reserve(B,1,50)).errorCode());
    }
    @Test void rollingRatePerUserAndOtherUserIndependent(){
        for(int i=0;i<5;i++)reserve(A,1,1000);
        assertEquals(ErrorCode.STAGING_MEDIA_RATE_LIMIT,assertThrows(BusinessException.class,()->reserve(A,1,1000)).errorCode());
        reserve(B,1,1000);assertEquals(6,count());
    }
    @Test void rateWindowExpiresButQuotaDoesNotReset(){
        for(int i=0;i<5;i++)reserve(A,1,6);
        db.execute("UPDATE staging_media_upload_reservations SET created_at=clock_timestamp()-interval '601 seconds'");
        reserve(A,1,6);assertEquals(6,used());
        assertEquals(ErrorCode.STAGING_MEDIA_QUOTA_EXCEEDED,assertThrows(BusinessException.class,()->reserve(B,1,6)).errorCode());
    }
    @Test void reservationSurvivesLaterCallerRollbackAndUnknownUpload(){
        var tx=new TransactionTemplate(context.getBean(PlatformTransactionManager.class));
        assertThrows(IllegalStateException.class,()->tx.executeWithoutResult(s->{reserve(A,32,100);throw new IllegalStateException("Synthetic downstream failure");}));
        assertEquals(32,used());assertEquals(1,count());
    }
    @Test void duplicateKeyCannotReserveTwice(){
        String key="synthetic/"+UUID.randomUUID();ledger.reserve(A,key,32,100,5,600);
        assertThrows(org.springframework.dao.DataIntegrityViolationException.class,()->ledger.reserve(A,key,32,100,5,600));
        assertEquals(32,used());assertEquals(1,count());
    }
    @Test void independentServiceInstancesSharePersistentBudget(){
        reserve(A,100,100);
        try(var second=new AnnotationConfigApplicationContext(Config.class)){
            assertEquals(ErrorCode.STAGING_MEDIA_QUOTA_EXCEEDED,assertThrows(BusinessException.class,
                    ()->second.getBean(StagingMediaReservationService.class).reserve(B,"synthetic/"+UUID.randomUUID(),1,100,5,600)).errorCode());
        }
    }
    @Test void concurrentAdmissionsCannotOversubscribeQuota() throws Exception {
        var pool=Executors.newFixedThreadPool(2);var start=new CountDownLatch(1);
        try {
            Callable<Boolean> attempt=()->{start.await();try{reserve(UUID.randomUUID().getLeastSignificantBits()%2==0?A:B,80,100);return true;}
                catch(BusinessException e){assertEquals(ErrorCode.STAGING_MEDIA_QUOTA_EXCEEDED,e.errorCode());return false;}};
            var one=pool.submit(attempt);var two=pool.submit(attempt);start.countDown();
            assertNotEquals(one.get(15,TimeUnit.SECONDS),two.get(15,TimeUnit.SECONDS));assertEquals(80,used());assertEquals(1,count());
        } finally {pool.shutdownNow();}
    }
    @Test void concurrentAdmissionsCannotOversubscribeRate() throws Exception {
        for(int i=0;i<4;i++)reserve(A,1,100);
        var pool=Executors.newFixedThreadPool(2);var start=new CountDownLatch(1);
        try {
            Callable<Boolean> attempt=()->{start.await();try{reserve(A,1,100);return true;}
                catch(BusinessException e){assertEquals(ErrorCode.STAGING_MEDIA_RATE_LIMIT,e.errorCode());return false;}};
            var one=pool.submit(attempt);var two=pool.submit(attempt);start.countDown();
            assertNotEquals(one.get(15,TimeUnit.SECONDS),two.get(15,TimeUnit.SECONDS));assertEquals(5,count());
        } finally {pool.shutdownNow();}
    }
}
