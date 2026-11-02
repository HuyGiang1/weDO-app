package com.wedo.backend.media.controller;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.media.service.MediaUploadAdmissionGuard;
import com.wedo.backend.security.jwt.JwtService;
import com.wedo.backend.user.entity.*;
import com.wedo.backend.user.repository.UserRepository;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.*;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.env.MockEnvironment;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;

@AutoConfigureMockMvc
@Import(StagingMediaAdmissionIntegrationTest.AdmissionConfig.class)
class StagingMediaAdmissionIntegrationTest extends AbstractPostgresIntegrationTest {
    static final UUID ALLOWED=UUID.randomUUID(),OTHER=UUID.randomUUID();
    @TestConfiguration(proxyBeanMethods=false)
    static class AdmissionConfig {
        @Bean @Primary MediaUploadAdmissionGuard testStagingGuard() {
            var e=new MockEnvironment().withProperty("wedo.staging.media-upload.enabled","true")
                    .withProperty("wedo.staging.media-upload.allowed-user-ids",ALLOWED.toString());
            e.setActiveProfiles("staging");return new MediaUploadAdmissionGuard(e);
        }
    }
    @Autowired MockMvc mvc;
    @Autowired JdbcTemplate db;
    @Autowired UserRepository users;
    @Autowired JwtService jwt;
    @BeforeEach void init(){
        for(var id:new UUID[]{ALLOWED,OTHER})if(!users.existsById(id)){
            var now=Instant.now();users.save(new UserEntity(id,"synthetic-"+id+"@example.invalid",null,"Synthetic",UserStatus.ACTIVE,now,now));
        }
        db.update("DELETE FROM staging_media_upload_reservations WHERE user_id IN (?,?)",ALLOWED,OTHER);
        db.update("UPDATE staging_media_upload_control SET enabled=true WHERE id=1");
    }
    String bearer(UUID user){return "Bearer "+jwt.generateAccessToken(user);}
    String body(long size){return "{\"category\":\"AVATAR\",\"fileName\":\"synthetic.png\",\"contentType\":\"image/png\",\"fileSize\":"+size+"}";}
    long count(){return db.queryForObject("SELECT count(*) FROM staging_media_upload_reservations WHERE user_id IN (?,?)",Long.class,ALLOWED,OTHER);}
    @Test void authenticatedAdmissionUsesPersistentReservationBeforeReturningTarget() throws Exception {
        mvc.perform(post("/api/v1/uploads/presign").header("Authorization",bearer(ALLOWED)).contentType(MediaType.APPLICATION_JSON).content(body(32)))
                .andExpect(status().isOk()).andExpect(jsonPath("$.storageKey").value(org.hamcrest.Matchers.startsWith("avatar/"+ALLOWED+"/")));
        assertEquals(1,count());
    }
    @Test void sixthAdmissionIs429AndNoSixthReservation() throws Exception {
        for(int i=0;i<5;i++)mvc.perform(post("/api/v1/uploads/presign").header("Authorization",bearer(ALLOWED)).contentType(MediaType.APPLICATION_JSON).content(body(32))).andExpect(status().isOk());
        mvc.perform(post("/api/v1/uploads/presign").header("Authorization",bearer(ALLOWED)).contentType(MediaType.APPLICATION_JSON).content(body(32)))
                .andExpect(status().isTooManyRequests()).andExpect(jsonPath("$.code").value("STAGING_MEDIA_RATE_LIMIT"));
        assertEquals(5,count());
    }
    @Test void otherAccountDeniedBeforeReservation() throws Exception {
        mvc.perform(post("/api/v1/uploads/presign").header("Authorization",bearer(OTHER)).contentType(MediaType.APPLICATION_JSON).content(body(32)))
                .andExpect(status().isForbidden()).andExpect(jsonPath("$.code").value("STAGING_MEDIA_UPLOAD_NOT_ALLOWED"));
        assertEquals(0,count());
    }
    @Test void quotaCountsOtherUsersAndOldUnknownUploads() throws Exception {
        for(int i=0;i<8;i++)db.update("INSERT INTO staging_media_upload_reservations VALUES (?,?,?,?,clock_timestamp()-interval '1 day')",
                UUID.randomUUID(),OTHER,"synthetic/"+UUID.randomUUID(),(i==7?10L:20L)*1024*1024);
        mvc.perform(post("/api/v1/uploads/presign").header("Authorization",bearer(ALLOWED)).contentType(MediaType.APPLICATION_JSON).content(body(1)))
                .andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("STAGING_MEDIA_QUOTA_EXCEEDED"));
        assertEquals(8,count());
    }
    @Test void oversizedAndUnauthorizedContextDoNotConsumeBudget() throws Exception {
        mvc.perform(post("/api/v1/uploads/presign").header("Authorization",bearer(ALLOWED)).contentType(MediaType.APPLICATION_JSON).content(body(5*1024*1024+1)))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("STAGING_MEDIA_FILE_TOO_LARGE"));
        mvc.perform(post("/api/v1/uploads/presign").header("Authorization",bearer(ALLOWED)).contentType(MediaType.APPLICATION_JSON)
                .content("{\"category\":\"GROUP_AVATAR\",\"fileName\":\"synthetic.png\",\"contentType\":\"image/png\",\"fileSize\":32,\"contextId\":\""+UUID.randomUUID()+"\"}"))
                .andExpect(status().isNotFound());
        assertEquals(0,count());
    }
    @Test void legacyDiskUploadCannotBypassBudgetAndTextReadsRemainUsable() throws Exception {
        mvc.perform(multipart("/api/v1/media/avatar").file(new MockMultipartFile("file","synthetic.png","image/png",new byte[]{1,2,3}))
                .header("Authorization",bearer(ALLOWED))).andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("STAGING_MEDIA_PRESIGN_REQUIRED"));
        mvc.perform(get("/api/v1/me").header("Authorization",bearer(ALLOWED))).andExpect(status().isOk());
        assertEquals(0,count());
    }
    @Test void operatorCanCloseMediaWithoutRestartAndCoreReadsRemainUsable() throws Exception {
        db.update("UPDATE staging_media_upload_control SET enabled=false WHERE id=1");
        mvc.perform(post("/api/v1/uploads/presign").header("Authorization",bearer(ALLOWED)).contentType(MediaType.APPLICATION_JSON).content(body(32)))
                .andExpect(status().isForbidden()).andExpect(jsonPath("$.code").value("STAGING_MEDIA_UPLOAD_DISABLED"));
        mvc.perform(get("/api/v1/me").header("Authorization",bearer(ALLOWED))).andExpect(status().isOk());
        assertEquals(0,count());
    }
}
