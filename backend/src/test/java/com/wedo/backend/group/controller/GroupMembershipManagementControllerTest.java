package com.wedo.backend.group.controller;

import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.group.entity.*;
import com.wedo.backend.group.repository.*;
import com.wedo.backend.security.jwt.JwtService;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@AutoConfigureMockMvc
class GroupMembershipManagementControllerTest extends AbstractPostgresIntegrationTest {
    private static final Instant NOW = Instant.parse("2020-01-01T00:00:00Z");
    @Autowired MockMvc mvc; @Autowired JwtService jwt; @Autowired UserRepository users;
    @Autowired GroupRepository groups; @Autowired GroupSettingsRepository settings; @Autowired GroupMembershipRepository memberships;
    @Autowired GroupActivityLogRepository logs;

    @Test void ownerPromotesAndDemotesAndInvalidTransitionsAreConflicts() throws Exception {
        UUID owner=user(), member=user(), admin=user(), id=group(owner, GroupStatus.ACTIVE); add(id,owner,GroupRole.OWNER,GroupMembershipStatus.ACTIVE); add(id,member,GroupRole.MEMBER,GroupMembershipStatus.ACTIVE); add(id,admin,GroupRole.ADMIN,GroupMembershipStatus.ACTIVE);
        mvc.perform(post("/api/v1/groups/{id}/members/{u}/promote-admin",id,member).header("Authorization",bearer(owner))).andExpect(status().isOk()).andExpect(jsonPath("$.role").value("ADMIN"));
        mvc.perform(post("/api/v1/groups/{id}/members/{u}/promote-admin",id,member).header("Authorization",bearer(owner))).andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("INVALID_GROUP_ROLE_TRANSITION"));
        mvc.perform(post("/api/v1/groups/{id}/members/{u}/demote-admin",id,admin).header("Authorization",bearer(owner))).andExpect(status().isOk()).andExpect(jsonPath("$.role").value("MEMBER"));
        mvc.perform(post("/api/v1/groups/{id}/members/{u}/demote-admin",id,admin).header("Authorization",bearer(owner))).andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("INVALID_GROUP_ROLE_TRANSITION"));
    }

    @Test void kickAndLeavePreserveHistoryAndLogs() throws Exception {
        UUID owner=user(), member=user(), admin=user(), id=group(owner, GroupStatus.ACTIVE); add(id,owner,GroupRole.OWNER,GroupMembershipStatus.ACTIVE); add(id,member,GroupRole.MEMBER,GroupMembershipStatus.ACTIVE); add(id,admin,GroupRole.ADMIN,GroupMembershipStatus.ACTIVE);
        mvc.perform(post("/api/v1/groups/{id}/members/{u}/kick",id,member).header("Authorization",bearer(owner))).andExpect(status().isNoContent());
        GroupMembershipEntity kicked=memberships.findByGroupIdAndUserIdAndStatus(id,member,GroupMembershipStatus.KICKED).getFirst(); assertNotNull(kicked.getEndedAt());
        assertTrue(logs.findByGroupId(id).stream().anyMatch(l->l.getAction()==GroupActivityAction.GROUP_MEMBER_KICKED && member.equals(l.getTargetUserId())));
        mvc.perform(post("/api/v1/groups/{id}/leave",id).header("Authorization",bearer(admin))).andExpect(status().isNoContent());
        assertEquals(GroupMembershipStatus.LEFT,memberships.findByGroupIdAndUserIdAndStatus(id,admin,GroupMembershipStatus.LEFT).getFirst().getStatus());
        mvc.perform(post("/api/v1/groups/{id}/leave",id).header("Authorization",bearer(owner))).andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("TRANSFER_OWNERSHIP_REQUIRED"));
    }

    @Test void permissionsTargetScopingLifecycleAndTransferAreEnforced() throws Exception {
        UUID owner=user(), admin=user(), member=user(), outsider=user(), id=group(owner, GroupStatus.ACTIVE); add(id,owner,GroupRole.OWNER,GroupMembershipStatus.ACTIVE); add(id,admin,GroupRole.ADMIN,GroupMembershipStatus.ACTIVE); add(id,member,GroupRole.MEMBER,GroupMembershipStatus.ACTIVE);
        mvc.perform(post("/api/v1/groups/{id}/members/{u}/kick",id,admin).header("Authorization",bearer(admin))).andExpect(status().isForbidden());
        mvc.perform(post("/api/v1/groups/{id}/members/{u}/kick",id,owner).header("Authorization",bearer(owner))).andExpect(status().isForbidden());
        mvc.perform(post("/api/v1/groups/{id}/members/{u}/kick",id,outsider).header("Authorization",bearer(owner))).andExpect(status().isNotFound()).andExpect(jsonPath("$.code").value("GROUP_MEMBER_NOT_FOUND"));
        mvc.perform(post("/api/v1/groups/{id}/transfer-ownership",id).header("Authorization",bearer(owner)).contentType(MediaType.APPLICATION_JSON).content("{\"newOwnerUserId\":\""+member+"\"}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.ownerUserId").value(member.toString())).andExpect(jsonPath("$.callerRole").value("ADMIN"));
        assertEquals(1,memberships.countByGroupIdAndRoleAndStatus(id,GroupRole.OWNER,GroupMembershipStatus.ACTIVE));
        assertTrue(logs.findByGroupId(id).stream().anyMatch(l->l.getAction()==GroupActivityAction.GROUP_OWNERSHIP_TRANSFERRED && member.equals(l.getTargetUserId())));
        UUID archived=group(owner,GroupStatus.ARCHIVED); add(archived,owner,GroupRole.OWNER,GroupMembershipStatus.ACTIVE);
        mvc.perform(post("/api/v1/groups/{id}/leave",archived).header("Authorization",bearer(owner))).andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("GROUP_ARCHIVED"));
    }

    private UUID user(){ UUID id=UUID.randomUUID(); users.saveAndFlush(new UserEntity(id,"m."+id+"@e.com","m_"+id.toString().substring(0,8),"M",UserStatus.ACTIVE,NOW,NOW)); return id; }
    private UUID group(UUID owner,GroupStatus s){ UUID id=UUID.randomUUID(); groups.saveAndFlush(new GroupEntity(id,"G",null,null,s,owner,NOW,NOW)); settings.saveAndFlush(GroupSettingsEntity.createDefault(id,NOW)); return id; }
    private void add(UUID g,UUID u,GroupRole r,GroupMembershipStatus s){ memberships.saveAndFlush(new GroupMembershipEntity(UUID.randomUUID(),g,u,r,s,NOW,s==GroupMembershipStatus.ACTIVE?null:NOW)); }
    private String bearer(UUID id){return "Bearer "+jwt.generateAccessToken(id);}
}
