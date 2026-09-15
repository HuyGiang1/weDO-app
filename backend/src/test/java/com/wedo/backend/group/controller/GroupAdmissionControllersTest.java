package com.wedo.backend.group.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.wedo.backend.common.dto.PagedResponse;
import com.wedo.backend.common.error.GlobalExceptionHandler;
import com.wedo.backend.group.dto.CreateInvitationRequest;
import com.wedo.backend.group.dto.CreateInviteLinkRequest;
import com.wedo.backend.group.dto.GroupBanResponse;
import com.wedo.backend.group.dto.GroupInvitationResponse;
import com.wedo.backend.group.dto.GroupInviteSummaryResponse;
import com.wedo.backend.group.dto.InviteLinkResponse;
import com.wedo.backend.group.dto.JoinRequestResponse;
import com.wedo.backend.group.entity.GroupInvitationStatus;
import com.wedo.backend.group.entity.GroupJoinPolicy;
import com.wedo.backend.group.entity.GroupJoinRequestStatus;
import com.wedo.backend.group.service.GroupAdmissionService;
import com.wedo.backend.group.service.GroupBanService;
import com.wedo.backend.group.service.GroupLifecycleService;
import com.wedo.backend.security.AuthenticatedUserPrincipal;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.core.MethodParameter;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.bind.support.WebDataBinderFactory;
import org.springframework.web.context.request.NativeWebRequest;
import org.springframework.web.method.support.HandlerMethodArgumentResolver;
import org.springframework.web.method.support.ModelAndViewContainer;

import java.time.Instant;
import java.util.List;
import java.util.Set;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@ExtendWith(MockitoExtension.class)
class GroupAdmissionControllersTest {

    private static final UUID CALLER_USER_ID = UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final Instant NOW = Instant.parse("2026-09-15T12:00:00Z");

    @Mock private GroupAdmissionService admissionService;
    @Mock private GroupBanService banService;
    @Mock private GroupLifecycleService lifecycleService;

    private MockMvc mvc;
    private final ObjectMapper objectMapper = new ObjectMapper().findAndRegisterModules();

    @BeforeEach
    void setUp() {
        HandlerMethodArgumentResolver principalResolver = new HandlerMethodArgumentResolver() {
            @Override
            public boolean supportsParameter(MethodParameter parameter) {
                return parameter.getParameterType().isAssignableFrom(AuthenticatedUserPrincipal.class);
            }
            @Override
            public Object resolveArgument(MethodParameter parameter, ModelAndViewContainer mavContainer, NativeWebRequest webRequest, WebDataBinderFactory binderFactory) {
                return new AuthenticatedUserPrincipal(CALLER_USER_ID);
            }
        };

        mvc = MockMvcBuilders.standaloneSetup(
                        new GroupInvitationController(admissionService),
                        new GroupInviteLinkController(admissionService),
                        new GroupJoinRequestController(admissionService),
                        new GroupBanController(banService),
                        new GroupLifecycleController(lifecycleService)
                )
                .setCustomArgumentResolvers(principalResolver)
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();
    }

    // =========================================================================
    // Group Invitations
    // =========================================================================
    @Test
    void createInvitation_returns201() throws Exception {
        UUID groupId = UUID.randomUUID();
        UUID inviteeId = UUID.randomUUID();
        GroupInvitationResponse response = new GroupInvitationResponse(
                UUID.randomUUID(), groupId, "Group", null, CALLER_USER_ID, "Caller", inviteeId, GroupInvitationStatus.PENDING, NOW, null
        );
        when(admissionService.createInvitation(eq(groupId), eq(CALLER_USER_ID), any())).thenReturn(response);

        mvc.perform(post("/api/v1/groups/{groupId}/invitations", groupId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new CreateInvitationRequest(inviteeId))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.groupId").value(groupId.toString()))
                .andExpect(jsonPath("$.inviteeId").value(inviteeId.toString()))
                .andExpect(jsonPath("$.status").value("PENDING"));
    }

    @Test
    void getMyInvitations_returns200() throws Exception {
        when(admissionService.getMyInvitations(eq(CALLER_USER_ID), eq(0), eq(20), eq(GroupInvitationStatus.PENDING)))
                .thenReturn(new PagedResponse<>(List.of(), 0, 20, 0, 0, false));

        mvc.perform(get("/api/v1/me/group-invitations"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items").isArray());
    }

    @Test
    void acceptInvitation_returns200() throws Exception {
        UUID id = UUID.randomUUID();
        mvc.perform(post("/api/v1/group-invitations/{id}/accept", id))
                .andExpect(status().isOk());
        verify(admissionService).acceptInvitation(id, CALLER_USER_ID);
    }

    @Test
    void declineInvitation_returns204() throws Exception {
        UUID id = UUID.randomUUID();
        mvc.perform(post("/api/v1/group-invitations/{id}/decline", id))
                .andExpect(status().isNoContent());
        verify(admissionService).declineInvitation(id, CALLER_USER_ID);
    }

    @Test
    void cancelInvitation_returns204() throws Exception {
        UUID id = UUID.randomUUID();
        mvc.perform(post("/api/v1/group-invitations/{id}/cancel", id))
                .andExpect(status().isNoContent());
        verify(admissionService).cancelInvitation(id, CALLER_USER_ID);
    }

    // =========================================================================
    // Group Invite Links
    // =========================================================================
    @Test
    void createInviteLink_returns201() throws Exception {
        UUID groupId = UUID.randomUUID();
        InviteLinkResponse response = new InviteLinkResponse(
                UUID.randomUUID(), groupId, "code-123", CALLER_USER_ID, 10, 0, null, false, NOW
        );
        when(admissionService.createInviteLink(eq(groupId), eq(CALLER_USER_ID), any())).thenReturn(response);

        mvc.perform(post("/api/v1/groups/{groupId}/invite-links", groupId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new CreateInviteLinkRequest(null, 10))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.code").value("code-123"));
    }

    @Test
    void resolveInviteCode_returns200() throws Exception {
        GroupInviteSummaryResponse response = new GroupInviteSummaryResponse(
                UUID.randomUUID(), "Safe Group", "Desc", null, 15, GroupJoinPolicy.AUTO_JOIN
        );
        when(admissionService.resolveInviteCode(eq("code-123"), eq(CALLER_USER_ID))).thenReturn(response);

        mvc.perform(get("/api/v1/group-invites/{code}", "code-123"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("Safe Group"))
                .andExpect(jsonPath("$.memberCount").value(15));
    }

    @Test
    void joinViaInviteCode_autoJoin_returns200() throws Exception {
        when(admissionService.joinViaInviteCode(eq("code-123"), eq(CALLER_USER_ID))).thenReturn(null);

        mvc.perform(post("/api/v1/group-invites/{code}/join", "code-123"))
                .andExpect(status().isOk());
    }

    @Test
    void joinViaInviteCode_approvalRequired_returns201() throws Exception {
        UUID groupId = UUID.randomUUID();
        JoinRequestResponse response = new JoinRequestResponse(
                UUID.randomUUID(), groupId, "Group", CALLER_USER_ID, "Caller", null, GroupJoinRequestStatus.PENDING, NOW, null, null
        );
        when(admissionService.joinViaInviteCode(eq("code-123"), eq(CALLER_USER_ID))).thenReturn(response);

        mvc.perform(post("/api/v1/group-invites/{code}/join", "code-123"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("PENDING"));
    }

    // =========================================================================
    // Group Join Requests
    // =========================================================================
    @Test
    void getJoinRequests_returns200() throws Exception {
        UUID groupId = UUID.randomUUID();
        when(admissionService.getJoinRequests(eq(groupId), eq(CALLER_USER_ID), eq(0), eq(20)))
                .thenReturn(new PagedResponse<>(List.of(), 0, 20, 0, 0, false));

        mvc.perform(get("/api/v1/groups/{groupId}/join-requests", groupId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items").isArray());
    }

    @Test
    void approveJoinRequest_returns200() throws Exception {
        UUID reqId = UUID.randomUUID();
        mvc.perform(post("/api/v1/group-join-requests/{id}/approve", reqId))
                .andExpect(status().isOk());
        verify(admissionService).approveJoinRequest(reqId, CALLER_USER_ID);
    }

    @Test
    void rejectJoinRequest_returns204() throws Exception {
        UUID reqId = UUID.randomUUID();
        mvc.perform(post("/api/v1/group-join-requests/{id}/reject", reqId))
                .andExpect(status().isNoContent());
        verify(admissionService).rejectJoinRequest(reqId, CALLER_USER_ID);
    }

    // =========================================================================
    // Group Bans
    // =========================================================================
    @Test
    void banMember_returns204() throws Exception {
        UUID groupId = UUID.randomUUID();
        UUID targetId = UUID.randomUUID();

        mvc.perform(post("/api/v1/groups/{groupId}/members/{userId}/ban", groupId, targetId))
                .andExpect(status().isNoContent());
        verify(banService).banMember(groupId, targetId, CALLER_USER_ID, null);
    }

    @Test
    void getBans_returns200() throws Exception {
        UUID groupId = UUID.randomUUID();
        when(banService.getBans(eq(groupId), eq(CALLER_USER_ID), eq(0), eq(30)))
                .thenReturn(new PagedResponse<>(List.of(), 0, 30, 0, 0, false));

        mvc.perform(get("/api/v1/groups/{groupId}/bans", groupId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items").isArray());
    }

    @Test
    void unbanMember_returns204() throws Exception {
        UUID groupId = UUID.randomUUID();
        UUID targetId = UUID.randomUUID();

        mvc.perform(delete("/api/v1/groups/{groupId}/bans/{userId}", groupId, targetId))
                .andExpect(status().isNoContent());
        verify(banService).unbanMember(groupId, targetId, CALLER_USER_ID);
    }

    // =========================================================================
    // Group Lifecycle
    // =========================================================================
    @Test
    void archiveGroup_returns204() throws Exception {
        UUID groupId = UUID.randomUUID();
        mvc.perform(post("/api/v1/groups/{groupId}/archive", groupId))
                .andExpect(status().isNoContent());
        verify(lifecycleService).archiveGroup(groupId, CALLER_USER_ID);
    }

    @Test
    void restoreGroup_returns204() throws Exception {
        UUID groupId = UUID.randomUUID();
        mvc.perform(post("/api/v1/groups/{groupId}/restore", groupId))
                .andExpect(status().isNoContent());
        verify(lifecycleService).restoreGroup(groupId, CALLER_USER_ID);
    }

    @Test
    void deleteGroup_returns204() throws Exception {
        UUID groupId = UUID.randomUUID();
        mvc.perform(delete("/api/v1/groups/{groupId}", groupId))
                .andExpect(status().isNoContent());
        verify(lifecycleService).deleteGroup(groupId, CALLER_USER_ID);
    }
}
