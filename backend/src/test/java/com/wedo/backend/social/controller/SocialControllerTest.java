package com.wedo.backend.social.controller;

import com.wedo.backend.common.dto.PagedResponse;
import com.wedo.backend.security.AuthenticatedUserPrincipal;
import com.wedo.backend.social.dto.BlockedUserResponse;
import com.wedo.backend.social.dto.FriendRequestResponse;
import com.wedo.backend.social.dto.FriendResponse;
import com.wedo.backend.social.dto.RelationshipState;
import com.wedo.backend.social.dto.SocialUserSummaryDto;
import com.wedo.backend.social.entity.FriendRequestStatus;
import com.wedo.backend.social.service.BlockService;
import com.wedo.backend.social.service.FriendRequestService;
import com.wedo.backend.social.service.FriendshipService;
import com.wedo.backend.social.service.RelationshipService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.core.MethodParameter;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableHandlerMethodArgumentResolver;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.bind.support.WebDataBinderFactory;
import org.springframework.web.context.request.NativeWebRequest;
import org.springframework.web.method.support.HandlerMethodArgumentResolver;
import org.springframework.web.method.support.ModelAndViewContainer;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@ExtendWith(MockitoExtension.class)
class SocialControllerTest {

    @Mock
    private FriendRequestService friendRequestService;

    @Mock
    private FriendshipService friendshipService;

    @Mock
    private BlockService blockService;

    @Mock
    private RelationshipService relationshipService;

    private MockMvc mockMvcFriendRequest;
    private MockMvc mockMvcFriendship;
    private MockMvc mockMvcBlock;
    private MockMvc mockMvcRelationship;

    private UUID currentUserId;

    @BeforeEach
    void setUp() {
        currentUserId = UUID.randomUUID();

        HandlerMethodArgumentResolver authResolver = new HandlerMethodArgumentResolver() {
            @Override
            public boolean supportsParameter(MethodParameter parameter) {
                return parameter.getParameterType().equals(AuthenticatedUserPrincipal.class);
            }

            @Override
            public Object resolveArgument(MethodParameter parameter, ModelAndViewContainer mavContainer, NativeWebRequest webRequest, WebDataBinderFactory binderFactory) {
                return new AuthenticatedUserPrincipal(currentUserId);
            }
        };

        PageableHandlerMethodArgumentResolver pageableResolver = new PageableHandlerMethodArgumentResolver();

        mockMvcFriendRequest = MockMvcBuilders
                .standaloneSetup(new FriendRequestController(friendRequestService))
                .setCustomArgumentResolvers(authResolver, pageableResolver)
                .build();

        mockMvcFriendship = MockMvcBuilders
                .standaloneSetup(new FriendshipController(friendshipService))
                .setCustomArgumentResolvers(authResolver, pageableResolver)
                .build();

        mockMvcBlock = MockMvcBuilders
                .standaloneSetup(new BlockController(blockService))
                .setCustomArgumentResolvers(authResolver, pageableResolver)
                .build();

        mockMvcRelationship = MockMvcBuilders
                .standaloneSetup(new RelationshipController(relationshipService))
                .setCustomArgumentResolvers(authResolver, pageableResolver)
                .build();
    }

    @Test
    @DisplayName("SOCIAL-01: POST /api/v1/users/{userId}/friend-requests should return 201 Created")
    void social01_sendFriendRequest() throws Exception {
        UUID targetId = UUID.randomUUID();
        UUID reqId = UUID.randomUUID();
        FriendRequestResponse response = new FriendRequestResponse(
                reqId,
                new SocialUserSummaryDto(currentUserId, "me", "My Name", null),
                new SocialUserSummaryDto(targetId, "target", "Target Name", null),
                FriendRequestStatus.PENDING,
                Instant.now(),
                null
        );

        when(friendRequestService.sendFriendRequest(currentUserId, targetId)).thenReturn(response);

        mockMvcFriendRequest.perform(post("/api/v1/users/{userId}/friend-requests", targetId))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(reqId.toString()))
                .andExpect(jsonPath("$.status").value("PENDING"));

        verify(friendRequestService).sendFriendRequest(currentUserId, targetId);
    }

    @Test
    @DisplayName("SOCIAL-02: GET /api/v1/me/friend-requests?direction=received should return 200 OK")
    void social02_getReceivedFriendRequests() throws Exception {
        PagedResponse<FriendRequestResponse> pagedResponse = new PagedResponse<>(List.of(), 0, 30, 0, 0, false);
        when(friendRequestService.getReceivedRequests(eq(currentUserId), any(Pageable.class))).thenReturn(pagedResponse);

        mockMvcFriendRequest.perform(get("/api/v1/me/friend-requests").param("direction", "received"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.page").value(0))
                .andExpect(jsonPath("$.items").isArray());

        verify(friendRequestService).getReceivedRequests(eq(currentUserId), any(Pageable.class));
    }

    @Test
    @DisplayName("SOCIAL-03: GET /api/v1/me/friend-requests?direction=sent should return 200 OK")
    void social03_getSentFriendRequests() throws Exception {
        PagedResponse<FriendRequestResponse> pagedResponse = new PagedResponse<>(List.of(), 0, 30, 0, 0, false);
        when(friendRequestService.getSentRequests(eq(currentUserId), any(Pageable.class))).thenReturn(pagedResponse);

        mockMvcFriendRequest.perform(get("/api/v1/me/friend-requests").param("direction", "sent"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.page").value(0))
                .andExpect(jsonPath("$.items").isArray());

        verify(friendRequestService).getSentRequests(eq(currentUserId), any(Pageable.class));
    }

    @Test
    @DisplayName("SOCIAL-04: POST /api/v1/friend-requests/{requestId}/accept should return 200 OK")
    void social04_acceptFriendRequest() throws Exception {
        UUID reqId = UUID.randomUUID();
        FriendRequestResponse response = new FriendRequestResponse(
                reqId,
                new SocialUserSummaryDto(UUID.randomUUID(), "sender", "Sender", null),
                new SocialUserSummaryDto(currentUserId, "me", "Me", null),
                FriendRequestStatus.ACCEPTED,
                Instant.now(),
                Instant.now()
        );

        when(friendRequestService.acceptFriendRequest(currentUserId, reqId)).thenReturn(response);

        mockMvcFriendRequest.perform(post("/api/v1/friend-requests/{requestId}/accept", reqId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("ACCEPTED"));

        verify(friendRequestService).acceptFriendRequest(currentUserId, reqId);
    }

    @Test
    @DisplayName("SOCIAL-05: POST /api/v1/friend-requests/{requestId}/decline should return 204 No Content")
    void social05_declineFriendRequest() throws Exception {
        UUID reqId = UUID.randomUUID();

        mockMvcFriendRequest.perform(post("/api/v1/friend-requests/{requestId}/decline", reqId))
                .andExpect(status().isNoContent());

        verify(friendRequestService).declineFriendRequest(currentUserId, reqId);
    }

    @Test
    @DisplayName("SOCIAL-06: POST /api/v1/friend-requests/{requestId}/cancel should return 204 No Content")
    void social06_cancelFriendRequest() throws Exception {
        UUID reqId = UUID.randomUUID();

        mockMvcFriendRequest.perform(post("/api/v1/friend-requests/{requestId}/cancel", reqId))
                .andExpect(status().isNoContent());

        verify(friendRequestService).cancelFriendRequest(currentUserId, reqId);
    }

    @Test
    @DisplayName("SOCIAL-07: GET /api/v1/me/friends should return 200 OK with PagedResponse")
    void social07_getFriends() throws Exception {
        PagedResponse<FriendResponse> pagedResponse = new PagedResponse<>(List.of(), 0, 30, 0, 0, false);
        when(friendshipService.getFriends(eq(currentUserId), any(Pageable.class))).thenReturn(pagedResponse);

        mockMvcFriendship.perform(get("/api/v1/me/friends"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items").isArray());

        verify(friendshipService).getFriends(eq(currentUserId), any(Pageable.class));
    }

    @Test
    @DisplayName("SOCIAL-08: DELETE /api/v1/friends/{userId} should return 204 No Content")
    void social08_unfriend() throws Exception {
        UUID targetId = UUID.randomUUID();

        mockMvcFriendship.perform(delete("/api/v1/friends/{userId}", targetId))
                .andExpect(status().isNoContent());

        verify(friendshipService).unfriend(currentUserId, targetId);
    }

    @Test
    @DisplayName("SOCIAL-09: POST /api/v1/users/{userId}/block should return 204 No Content")
    void social09_blockUser() throws Exception {
        UUID targetId = UUID.randomUUID();

        mockMvcBlock.perform(post("/api/v1/users/{userId}/block", targetId))
                .andExpect(status().isNoContent());

        verify(blockService).blockUser(currentUserId, targetId);
    }

    @Test
    @DisplayName("SOCIAL-10: DELETE /api/v1/users/{userId}/block should return 204 No Content")
    void social10_unblockUser() throws Exception {
        UUID targetId = UUID.randomUUID();

        mockMvcBlock.perform(delete("/api/v1/users/{userId}/block", targetId))
                .andExpect(status().isNoContent());

        verify(blockService).unblockUser(currentUserId, targetId);
    }

    @Test
    @DisplayName("SOCIAL-11: GET /api/v1/me/blocked-users should return 200 OK")
    void social11_getBlockedUsers() throws Exception {
        PagedResponse<BlockedUserResponse> pagedResponse = new PagedResponse<>(List.of(), 0, 30, 0, 0, false);
        when(blockService.getBlockedUsers(eq(currentUserId), any(Pageable.class))).thenReturn(pagedResponse);

        mockMvcBlock.perform(get("/api/v1/me/blocked-users"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items").isArray());

        verify(blockService).getBlockedUsers(eq(currentUserId), any(Pageable.class));
    }

    @Test
    @DisplayName("Relationship State: GET /api/v1/users/{userId}/relationship should return 200 OK with state")
    void getRelationshipState() throws Exception {
        UUID targetId = UUID.randomUUID();
        when(relationshipService.getRelationshipState(currentUserId, targetId)).thenReturn(RelationshipState.FRIENDS);

        mockMvcRelationship.perform(get("/api/v1/users/{userId}/relationship", targetId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.targetUserId").value(targetId.toString()))
                .andExpect(jsonPath("$.state").value("FRIENDS"));

        verify(relationshipService).getRelationshipState(currentUserId, targetId);
    }
}
