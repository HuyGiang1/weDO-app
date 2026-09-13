package com.wedo.backend.social.service;

import com.wedo.backend.common.dto.PagedResponse;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.social.dto.FriendRequestResponse;
import com.wedo.backend.social.entity.FriendRequestEntity;
import com.wedo.backend.social.entity.FriendRequestStatus;
import com.wedo.backend.social.entity.FriendshipEntity;
import com.wedo.backend.social.repository.FriendRequestRepository;
import com.wedo.backend.social.repository.FriendshipRepository;
import com.wedo.backend.social.repository.UserBlockRepository;
import com.wedo.backend.user.entity.FriendRequestPolicy;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserPrivacySettingsEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserPrivacySettingsRepository;
import com.wedo.backend.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

import java.time.Duration;
import java.time.Instant;
import java.util.Collections;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class FriendRequestServiceTest {

    @Mock
    private FriendRequestRepository friendRequestRepository;

    @Mock
    private FriendshipRepository friendshipRepository;

    @Mock
    private UserBlockRepository userBlockRepository;

    @Mock
    private UserRepository userRepository;

    @Mock
    private UserPrivacySettingsRepository userPrivacySettingsRepository;

    @Mock
    private MutualGroupChecker mutualGroupChecker;

    @InjectMocks
    private FriendRequestService friendRequestService;

    private UUID senderId;
    private UUID receiverId;
    private UserEntity senderUser;
    private UserEntity receiverUser;

    @BeforeEach
    void setUp() {
        senderId = UUID.randomUUID();
        receiverId = UUID.randomUUID();

        senderUser = new UserEntity(senderId, "sender@example.com", "sender_user", "Sender Display", UserStatus.ACTIVE, Instant.now(), Instant.now());
        receiverUser = new UserEntity(receiverId, "receiver@example.com", "receiver_user", "Receiver Display", UserStatus.ACTIVE, Instant.now(), Instant.now());
    }

    @Nested
    @DisplayName("Send Friend Request Tests")
    class SendFriendRequestTests {

        @Test
        @DisplayName("Should throw CANNOT_FRIEND_SELF when sender equals target user")
        void sendRequest_selfRequest_throwsCannotFriendSelf() {
            assertThatThrownBy(() -> friendRequestService.sendFriendRequest(senderId, senderId))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.CANNOT_FRIEND_SELF));

            verify(friendRequestRepository, never()).saveAndFlush(any());
        }

        @Test
        @DisplayName("Should throw RESOURCE_NOT_FOUND when target user does not exist or is inactive")
        void sendRequest_targetNotFound_throwsResourceNotFound() {
            when(userRepository.findById(senderId)).thenReturn(Optional.of(senderUser));
            when(userRepository.findById(receiverId)).thenReturn(Optional.empty());

            assertThatThrownBy(() -> friendRequestService.sendFriendRequest(senderId, receiverId))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.RESOURCE_NOT_FOUND));
        }

        @Test
        @DisplayName("Should throw USER_BLOCKED when sender or receiver is blocked by the other")
        void sendRequest_blockedUser_throwsUserBlocked() {
            when(userRepository.findById(senderId)).thenReturn(Optional.of(senderUser));
            when(userRepository.findById(receiverId)).thenReturn(Optional.of(receiverUser));
            when(userBlockRepository.existsBlockBetween(senderId, receiverId)).thenReturn(true);

            assertThatThrownBy(() -> friendRequestService.sendFriendRequest(senderId, receiverId))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.USER_BLOCKED));
        }

        @Test
        @DisplayName("Should throw ALREADY_FRIENDS when users already have active friendship")
        void sendRequest_alreadyFriends_throwsAlreadyFriends() {
            when(userRepository.findById(senderId)).thenReturn(Optional.of(senderUser));
            when(userRepository.findById(receiverId)).thenReturn(Optional.of(receiverUser));
            when(userBlockRepository.existsBlockBetween(senderId, receiverId)).thenReturn(false);
            when(friendshipRepository.existsActiveBetween(senderId, receiverId)).thenReturn(true);

            assertThatThrownBy(() -> friendRequestService.sendFriendRequest(senderId, receiverId))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.ALREADY_FRIENDS));
        }

        @Test
        @DisplayName("Should throw FRIEND_REQUEST_ALREADY_PENDING when pending request exists in either direction")
        void sendRequest_pendingExists_throwsFriendRequestAlreadyPending() {
            when(userRepository.findById(senderId)).thenReturn(Optional.of(senderUser));
            when(userRepository.findById(receiverId)).thenReturn(Optional.of(receiverUser));
            when(userBlockRepository.existsBlockBetween(senderId, receiverId)).thenReturn(false);
            when(friendshipRepository.existsActiveBetween(senderId, receiverId)).thenReturn(false);
            when(friendRequestRepository.existsPendingBetween(senderId, receiverId)).thenReturn(true);

            assertThatThrownBy(() -> friendRequestService.sendFriendRequest(senderId, receiverId))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.FRIEND_REQUEST_ALREADY_PENDING));
        }

        @Test
        @DisplayName("Should throw FRIEND_REQUEST_NOT_ALLOWED when receiver privacy policy is NONE")
        void sendRequest_privacyPolicyNone_throwsFriendRequestNotAllowed() {
            when(userRepository.findById(senderId)).thenReturn(Optional.of(senderUser));
            when(userRepository.findById(receiverId)).thenReturn(Optional.of(receiverUser));
            when(userBlockRepository.existsBlockBetween(senderId, receiverId)).thenReturn(false);
            when(friendshipRepository.existsActiveBetween(senderId, receiverId)).thenReturn(false);
            when(friendRequestRepository.existsPendingBetween(senderId, receiverId)).thenReturn(false);

            UserPrivacySettingsEntity privacy = UserPrivacySettingsEntity.createDefault(receiverId, Instant.now());
            privacy.setFriendRequestPolicy(FriendRequestPolicy.NONE);
            when(userPrivacySettingsRepository.findById(receiverId)).thenReturn(Optional.of(privacy));

            assertThatThrownBy(() -> friendRequestService.sendFriendRequest(senderId, receiverId))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.FRIEND_REQUEST_NOT_ALLOWED));
        }

        @Test
        @DisplayName("Should throw FRIEND_REQUEST_NOT_ALLOWED when privacy policy is MUTUAL_GROUPS but users share no active groups")
        void sendRequest_mutualGroupsPolicyNoMutualGroup_throwsFriendRequestNotAllowed() {
            when(userRepository.findById(senderId)).thenReturn(Optional.of(senderUser));
            when(userRepository.findById(receiverId)).thenReturn(Optional.of(receiverUser));
            when(userBlockRepository.existsBlockBetween(senderId, receiverId)).thenReturn(false);
            when(friendshipRepository.existsActiveBetween(senderId, receiverId)).thenReturn(false);
            when(friendRequestRepository.existsPendingBetween(senderId, receiverId)).thenReturn(false);

            UserPrivacySettingsEntity privacy = UserPrivacySettingsEntity.createDefault(receiverId, Instant.now());
            privacy.setFriendRequestPolicy(FriendRequestPolicy.MUTUAL_GROUPS);
            when(userPrivacySettingsRepository.findById(receiverId)).thenReturn(Optional.of(privacy));
            when(mutualGroupChecker.haveMutualActiveGroup(senderId, receiverId)).thenReturn(false);

            assertThatThrownBy(() -> friendRequestService.sendFriendRequest(senderId, receiverId))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.FRIEND_REQUEST_NOT_ALLOWED));
        }

        @Test
        @DisplayName("Should throw FRIEND_REQUEST_COOLDOWN_ACTIVE when previous request was DECLINED within last 24h")
        void sendRequest_declinedCooldownActive_throwsCooldownActive() {
            when(userRepository.findById(senderId)).thenReturn(Optional.of(senderUser));
            when(userRepository.findById(receiverId)).thenReturn(Optional.of(receiverUser));
            when(userBlockRepository.existsBlockBetween(senderId, receiverId)).thenReturn(false);
            when(friendshipRepository.existsActiveBetween(senderId, receiverId)).thenReturn(false);
            when(friendRequestRepository.existsPendingBetween(senderId, receiverId)).thenReturn(false);

            UserPrivacySettingsEntity privacy = UserPrivacySettingsEntity.createDefault(receiverId, Instant.now());
            privacy.setFriendRequestPolicy(FriendRequestPolicy.EVERYONE);
            when(userPrivacySettingsRepository.findById(receiverId)).thenReturn(Optional.of(privacy));

            FriendRequestEntity declinedReq = new FriendRequestEntity(
                    UUID.randomUUID(), senderId, receiverId, FriendRequestStatus.DECLINED,
                    Instant.now().minus(Duration.ofHours(2)),
                    Instant.now().minus(Duration.ofHours(2)) // Responded 2h ago (< 24h)
            );
            when(friendRequestRepository.findDeclinedRequests(senderId, receiverId)).thenReturn(List.of(declinedReq));

            assertThatThrownBy(() -> friendRequestService.sendFriendRequest(senderId, receiverId))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.FRIEND_REQUEST_COOLDOWN_ACTIVE));
        }

        @Test
        @DisplayName("Should succeed when previous declined request is older than 24h")
        void sendRequest_declinedCooldownExpired_succeeds() {
            when(userRepository.findById(senderId)).thenReturn(Optional.of(senderUser));
            when(userRepository.findById(receiverId)).thenReturn(Optional.of(receiverUser));
            when(userBlockRepository.existsBlockBetween(senderId, receiverId)).thenReturn(false);
            when(friendshipRepository.existsActiveBetween(senderId, receiverId)).thenReturn(false);
            when(friendRequestRepository.existsPendingBetween(senderId, receiverId)).thenReturn(false);

            UserPrivacySettingsEntity privacy = UserPrivacySettingsEntity.createDefault(receiverId, Instant.now());
            privacy.setFriendRequestPolicy(FriendRequestPolicy.EVERYONE);
            when(userPrivacySettingsRepository.findById(receiverId)).thenReturn(Optional.of(privacy));

            FriendRequestEntity oldDeclined = new FriendRequestEntity(
                    UUID.randomUUID(), senderId, receiverId, FriendRequestStatus.DECLINED,
                    Instant.now().minus(Duration.ofHours(30)),
                    Instant.now().minus(Duration.ofHours(25)) // Responded 25h ago (> 24h)
            );
            when(friendRequestRepository.findDeclinedRequests(senderId, receiverId)).thenReturn(List.of(oldDeclined));

            FriendRequestResponse response = friendRequestService.sendFriendRequest(senderId, receiverId);

            assertThat(response).isNotNull();
            assertThat(response.status()).isEqualTo(FriendRequestStatus.PENDING);
            assertThat(response.sender().id()).isEqualTo(senderId);
            assertThat(response.receiver().id()).isEqualTo(receiverId);

            verify(friendRequestRepository).saveAndFlush(any());
        }

        @Test
        @DisplayName("Should handle concurrent insert race condition and throw FRIEND_REQUEST_ALREADY_PENDING")
        void sendRequest_concurrentRace_throwsFriendRequestAlreadyPending() {
            when(userRepository.findById(senderId)).thenReturn(Optional.of(senderUser));
            when(userRepository.findById(receiverId)).thenReturn(Optional.of(receiverUser));
            when(userBlockRepository.existsBlockBetween(senderId, receiverId)).thenReturn(false);
            when(friendshipRepository.existsActiveBetween(senderId, receiverId)).thenReturn(false);
            when(friendRequestRepository.existsPendingBetween(senderId, receiverId)).thenReturn(false);

            UserPrivacySettingsEntity privacy = UserPrivacySettingsEntity.createDefault(receiverId, Instant.now());
            when(userPrivacySettingsRepository.findById(receiverId)).thenReturn(Optional.of(privacy));
            when(friendRequestRepository.findDeclinedRequests(senderId, receiverId)).thenReturn(Collections.emptyList());

            when(friendRequestRepository.saveAndFlush(any())).thenThrow(new DataIntegrityViolationException("uq_friend_requests_pending_pair"));

            assertThatThrownBy(() -> friendRequestService.sendFriendRequest(senderId, receiverId))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.FRIEND_REQUEST_ALREADY_PENDING));
        }
    }

    @Nested
    @DisplayName("Accept Friend Request Tests")
    class AcceptFriendRequestTests {

        private UUID requestId;
        private FriendRequestEntity pendingRequest;

        @BeforeEach
        void setUp() {
            requestId = UUID.randomUUID();
            pendingRequest = FriendRequestEntity.createPending(requestId, senderId, receiverId, Instant.now());
        }

        @Test
        @DisplayName("Should successfully accept request, update status to ACCEPTED, and create ACTIVE canonical friendship")
        void acceptRequest_valid_createsFriendship() {
            when(friendRequestRepository.findById(requestId)).thenReturn(Optional.of(pendingRequest));
            when(userBlockRepository.existsBlockBetween(senderId, receiverId)).thenReturn(false);
            when(friendshipRepository.existsActiveBetween(senderId, receiverId)).thenReturn(false);
            when(friendRequestRepository.updateStatusAtomically(eq(requestId), eq(FriendRequestStatus.PENDING), eq(FriendRequestStatus.ACCEPTED), any())).thenReturn(1);
            when(userRepository.findById(senderId)).thenReturn(Optional.of(senderUser));
            when(userRepository.findById(receiverId)).thenReturn(Optional.of(receiverUser));

            FriendRequestResponse response = friendRequestService.acceptFriendRequest(receiverId, requestId);

            assertThat(response).isNotNull();
            assertThat(response.status()).isEqualTo(FriendRequestStatus.ACCEPTED);

            ArgumentCaptor<FriendshipEntity> captor = ArgumentCaptor.forClass(FriendshipEntity.class);
            verify(friendshipRepository).saveAndFlush(captor.capture());

            FriendshipEntity createdFriendship = captor.getValue();
            assertThat(createdFriendship.getStatus()).isEqualTo(com.wedo.backend.social.entity.FriendshipStatus.ACTIVE);
            assertThat(createdFriendship.getUserId1().compareTo(createdFriendship.getUserId2())).isLessThan(0);
        }

        @Test
        @DisplayName("Should throw ACCESS_DENIED when caller is not the request receiver")
        void acceptRequest_callerNotReceiver_throwsAccessDenied() {
            when(friendRequestRepository.findById(requestId)).thenReturn(Optional.of(pendingRequest));

            assertThatThrownBy(() -> friendRequestService.acceptFriendRequest(senderId, requestId))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.ACCESS_DENIED));

            verify(friendshipRepository, never()).saveAndFlush(any());
        }

        @Test
        @DisplayName("Should throw CONFLICT when request status is not PENDING")
        void acceptRequest_nonPendingStatus_throwsConflict() {
            pendingRequest.setStatus(FriendRequestStatus.DECLINED);
            when(friendRequestRepository.findById(requestId)).thenReturn(Optional.of(pendingRequest));

            assertThatThrownBy(() -> friendRequestService.acceptFriendRequest(receiverId, requestId))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.CONFLICT));
        }

        @Test
        @DisplayName("Should throw USER_BLOCKED when block exists between users during accept")
        void acceptRequest_blockedUser_throwsUserBlocked() {
            when(friendRequestRepository.findById(requestId)).thenReturn(Optional.of(pendingRequest));
            when(userBlockRepository.existsBlockBetween(senderId, receiverId)).thenReturn(true);

            assertThatThrownBy(() -> friendRequestService.acceptFriendRequest(receiverId, requestId))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.USER_BLOCKED));
        }
    }

    @Nested
    @DisplayName("Decline and Cancel Friend Request Tests")
    class DeclineAndCancelTests {

        private UUID requestId;
        private FriendRequestEntity pendingRequest;

        @BeforeEach
        void setUp() {
            requestId = UUID.randomUUID();
            pendingRequest = FriendRequestEntity.createPending(requestId, senderId, receiverId, Instant.now());
        }

        @Test
        @DisplayName("Should decline request when caller is receiver and transition to DECLINED")
        void declineRequest_valid_succeeds() {
            when(friendRequestRepository.findById(requestId)).thenReturn(Optional.of(pendingRequest));
            when(friendRequestRepository.updateStatusAtomically(eq(requestId), eq(FriendRequestStatus.PENDING), eq(FriendRequestStatus.DECLINED), any())).thenReturn(1);

            friendRequestService.declineFriendRequest(receiverId, requestId);

            verify(friendRequestRepository).updateStatusAtomically(eq(requestId), eq(FriendRequestStatus.PENDING), eq(FriendRequestStatus.DECLINED), any());
        }

        @Test
        @DisplayName("Should throw ACCESS_DENIED when caller declines request addressed to another user")
        void declineRequest_wrongCaller_throwsAccessDenied() {
            when(friendRequestRepository.findById(requestId)).thenReturn(Optional.of(pendingRequest));

            assertThatThrownBy(() -> friendRequestService.declineFriendRequest(senderId, requestId))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.ACCESS_DENIED));
        }

        @Test
        @DisplayName("Should cancel request when caller is sender and transition to CANCELLED")
        void cancelRequest_valid_succeeds() {
            when(friendRequestRepository.findById(requestId)).thenReturn(Optional.of(pendingRequest));
            when(friendRequestRepository.updateStatusAtomically(eq(requestId), eq(FriendRequestStatus.PENDING), eq(FriendRequestStatus.CANCELLED), any())).thenReturn(1);

            friendRequestService.cancelFriendRequest(senderId, requestId);

            verify(friendRequestRepository).updateStatusAtomically(eq(requestId), eq(FriendRequestStatus.PENDING), eq(FriendRequestStatus.CANCELLED), any());
        }

        @Test
        @DisplayName("Should throw ACCESS_DENIED when receiver attempts to cancel request instead of sender")
        void cancelRequest_wrongCaller_throwsAccessDenied() {
            when(friendRequestRepository.findById(requestId)).thenReturn(Optional.of(pendingRequest));

            assertThatThrownBy(() -> friendRequestService.cancelFriendRequest(receiverId, requestId))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.ACCESS_DENIED));
        }
    }

    @Nested
    @DisplayName("Listing Requests Tests")
    class ListingRequestsTests {

        @Test
        @DisplayName("Should return paginated received requests")
        void getReceivedRequests_returnsPagedResponse() {
            Pageable pageable = PageRequest.of(0, 10);
            FriendRequestEntity req = FriendRequestEntity.createPending(UUID.randomUUID(), senderId, receiverId, Instant.now());
            Page<FriendRequestEntity> page = new PageImpl<>(List.of(req), pageable, 1);

            when(friendRequestRepository.findByReceiverIdAndStatusOrderByCreatedAtDesc(receiverId, FriendRequestStatus.PENDING, pageable))
                    .thenReturn(page);
            when(userRepository.findAllById(any())).thenReturn(List.of(senderUser, receiverUser));

            PagedResponse<FriendRequestResponse> response = friendRequestService.getReceivedRequests(receiverId, pageable);

            assertThat(response.items()).hasSize(1);
            assertThat(response.items().get(0).sender().username()).isEqualTo("sender_user");
            assertThat(response.items().get(0).receiver().username()).isEqualTo("receiver_user");
        }

        @Test
        @DisplayName("Should return paginated sent requests")
        void getSentRequests_returnsPagedResponse() {
            Pageable pageable = PageRequest.of(0, 10);
            FriendRequestEntity req = FriendRequestEntity.createPending(UUID.randomUUID(), senderId, receiverId, Instant.now());
            Page<FriendRequestEntity> page = new PageImpl<>(List.of(req), pageable, 1);

            when(friendRequestRepository.findBySenderIdAndStatusOrderByCreatedAtDesc(senderId, FriendRequestStatus.PENDING, pageable))
                    .thenReturn(page);
            when(userRepository.findAllById(any())).thenReturn(List.of(senderUser, receiverUser));

            PagedResponse<FriendRequestResponse> response = friendRequestService.getSentRequests(senderId, pageable);

            assertThat(response.items()).hasSize(1);
            assertThat(response.items().get(0).sender().username()).isEqualTo("sender_user");
        }
    }
}
