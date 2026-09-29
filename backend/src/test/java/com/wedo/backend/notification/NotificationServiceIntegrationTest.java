package com.wedo.backend.notification;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.wedo.backend.activity.dto.ChangeRsvpRequest;
import com.wedo.backend.activity.dto.CreateActivityRequest;
import com.wedo.backend.activity.entity.ActivityRsvpStatus;
import com.wedo.backend.activity.service.ActivityRsvpService;
import com.wedo.backend.activity.service.ActivityService;
import com.wedo.backend.chat.realtime.ChatRealtimeCoordinator;
import com.wedo.backend.chat.realtime.ChatRealtimeEvents.ClientCommand;
import com.wedo.backend.chat.service.ChatService;
import com.wedo.backend.common.dto.PagedResponse;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.expense.dto.ExpenseDtos.CreateSettlementRequest;
import com.wedo.backend.expense.dto.ExpenseDtos.ExpenseDetail;
import com.wedo.backend.expense.dto.ExpenseDtos.ExpenseRequest;
import com.wedo.backend.expense.dto.ExpenseDtos.SettlementResponse;
import com.wedo.backend.expense.service.ExpenseService;
import com.wedo.backend.fund.dto.FundDtos.CollectionDetailResponse;
import com.wedo.backend.fund.dto.FundDtos.ContributionResponse;
import com.wedo.backend.fund.dto.FundDtos.CreateCollectionRequest;
import com.wedo.backend.fund.dto.FundDtos.CreateContributionRequest;
import com.wedo.backend.fund.dto.FundDtos.CreateFundRequest;
import com.wedo.backend.fund.dto.FundDtos.FundDetailResponse;
import com.wedo.backend.fund.service.FundService;
import com.wedo.backend.group.entity.GroupEntity;
import com.wedo.backend.group.entity.GroupMembershipEntity;
import com.wedo.backend.group.entity.GroupMembershipStatus;
import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.entity.GroupSettingsEntity;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.group.repository.GroupMembershipRepository;
import com.wedo.backend.group.repository.GroupRepository;
import com.wedo.backend.group.repository.GroupSettingsRepository;
import com.wedo.backend.group.service.GroupAdmissionService;
import com.wedo.backend.notification.dto.NotificationDtos.GroupNotificationSettingsResponse;
import com.wedo.backend.notification.dto.NotificationDtos.MarkAllReadResponse;
import com.wedo.backend.notification.dto.NotificationDtos.NotificationItemResponse;
import com.wedo.backend.notification.dto.NotificationDtos.RegisterDeviceRequest;
import com.wedo.backend.notification.dto.NotificationDtos.UpdateGroupNotificationSettingsRequest;
import com.wedo.backend.notification.dto.NotificationDtos.UpdateUserNotificationSettingsRequest;
import com.wedo.backend.notification.dto.NotificationDtos.UserDeviceResponse;
import com.wedo.backend.notification.dto.NotificationDtos.UserNotificationSettingsResponse;
import com.wedo.backend.notification.event.NotificationDomainEvent;
import com.wedo.backend.notification.push.PushGateway;
import com.wedo.backend.notification.push.PushGateway.PushDeliveryResult;
import com.wedo.backend.notification.push.PushGateway.PushMessage;
import com.wedo.backend.notification.service.NotificationService;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserRepository;
import java.math.BigDecimal;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.web.socket.WebSocketSession;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

@SpringBootTest
@Testcontainers
@Import(NotificationServiceIntegrationTest.FakePushGatewayConfiguration.class)
class NotificationServiceIntegrationTest {

    @Container
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:17-alpine");

    @DynamicPropertySource
    static void registerProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
    }

    @Autowired
    private NotificationService notificationService;

    @Autowired
    private FakeNotificationPushGateway fakePushGateway;

    @Autowired
    private GroupAdmissionService groupAdmissionService;

    @Autowired
    private ActivityService activityService;

    @Autowired
    private ActivityRsvpService activityRsvpService;

    @Autowired
    private ExpenseService expenseService;

    @Autowired
    private FundService fundService;

    @Autowired
    private ChatService chatService;

    @Autowired
    private ChatRealtimeCoordinator chatRealtimeCoordinator;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private GroupRepository groupRepository;

    @Autowired
    private GroupSettingsRepository groupSettingsRepository;

    @Autowired
    private GroupMembershipRepository groupMembershipRepository;

    @Autowired
    private JdbcTemplate jdbc;

    @Autowired
    private ApplicationEventPublisher eventPublisher;

    @Autowired
    private PlatformTransactionManager transactionManager;

    private UUID ownerId;
    private UUID member1Id;
    private UUID member2Id;
    private UUID outsiderId;
    private UUID groupId;

    @TestConfiguration(proxyBeanMethods = false)
    static class FakePushGatewayConfiguration {
        @Bean
        @Primary
        FakeNotificationPushGateway fakeNotificationPushGateway() {
            return new FakeNotificationPushGateway();
        }
    }

    static final class FakeNotificationPushGateway implements PushGateway {
        private final List<PushMessage> recordedMessages = new CopyOnWriteArrayList<>();
        private final Set<String> invalidTokens = java.util.concurrent.ConcurrentHashMap.newKeySet();
        private final AtomicBoolean simulateRuntimeFailure = new AtomicBoolean();

        @Override
        public PushDeliveryResult sendPush(PushMessage message) {
            recordedMessages.add(message);
            if (simulateRuntimeFailure.get()) {
                throw new IllegalStateException("Simulated test gateway failure.");
            }
            if (invalidTokens.contains(message.pushToken())
                    || message.pushToken().startsWith("invalid-token:")) {
                return PushDeliveryResult.invalidToken("UNREGISTERED", "Test token is invalid.");
            }
            return PushDeliveryResult.gatewayAccepted("fake-provider-accepted");
        }

        List<PushMessage> getRecordedMessages() {
            return List.copyOf(recordedMessages);
        }

        void clearRecordedMessages() {
            recordedMessages.clear();
        }

        void clearInvalidTokens() {
            invalidTokens.clear();
        }

        void setSimulateRuntimeFailure(boolean fail) {
            simulateRuntimeFailure.set(fail);
        }
    }

    @BeforeEach
    void setUp() {
        fakePushGateway.clearRecordedMessages();
        fakePushGateway.clearInvalidTokens();
        fakePushGateway.setSimulateRuntimeFailure(false);

        Instant now = Instant.now();
        ownerId = createUser("owner", now);
        member1Id = createUser("member1", now);
        member2Id = createUser("member2", now);
        outsiderId = createUser("outsider", now);

        groupId = UUID.randomUUID();
        groupRepository.save(new GroupEntity(
                groupId,
                "Nhóm Du Lịch M14",
                "Mô tả nhóm",
                null,
                GroupStatus.ACTIVE,
                ownerId,
                now,
                now
        ));
        groupSettingsRepository.save(GroupSettingsEntity.createDefault(groupId, now));
        groupMembershipRepository.save(new GroupMembershipEntity(
                UUID.randomUUID(), groupId, ownerId, GroupRole.OWNER, GroupMembershipStatus.ACTIVE, now, null
        ));
        groupMembershipRepository.save(new GroupMembershipEntity(
                UUID.randomUUID(), groupId, member1Id, GroupRole.MEMBER, GroupMembershipStatus.ACTIVE, now, null
        ));
        groupMembershipRepository.save(new GroupMembershipEntity(
                UUID.randomUUID(), groupId, member2Id, GroupRole.MEMBER, GroupMembershipStatus.ACTIVE, now, null
        ));
    }

    @Test
    void outgoingPushDataMatchesPersistedRecipientNotificationTarget() {
        notificationService.registerDevice(member1Id, new RegisterDeviceRequest(
                "dev-payload",
                "ANDROID",
                "token-payload-" + UUID.randomUUID()
        ));
        UUID conversationId = UUID.randomUUID();
        notificationService.processDomainEvent(new NotificationDomainEvent(
                "PUSH_TARGET:" + UUID.randomUUID(),
                "CHAT_MESSAGE",
                "CHAT",
                "NORMAL",
                false,
                ownerId,
                groupId,
                List.of(member1Id),
                "Tin nháº¯n má»›i",
                "Báº¡n cÃ³ tin nháº¯n má»›i.",
                "CONVERSATION",
                conversationId,
                "/groups/chat",
                Map.of("conversationId", conversationId.toString(), "groupId", groupId.toString()),
                Instant.now()
        ));

        PushMessage push = fakePushGateway.getRecordedMessages().get(0);
        NotificationItemResponse persisted = notificationService.listNotifications(member1Id, 0, 1)
                .items().get(0);
        assertThat(push.data())
                .containsEntry("notificationId", persisted.id().toString())
                .containsEntry("category", "CHAT")
                .containsEntry("action", "OPEN_NOTIFICATION")
                .containsEntry("targetType", persisted.target().targetType())
                .containsEntry("targetId", persisted.target().targetId().toString())
                .containsEntry("route", persisted.target().route())
                .containsEntry("deepLink", persisted.target().route())
                .containsEntry("groupId", groupId.toString())
                .containsEntry("conversationId", conversationId.toString())
                .doesNotContainKeys("eventKey", "pushDecision", "collapseKey");
    }

    @Test
    void notificationCenterListPaginationUnreadCountMarkReadIdempotencyMarkAllReadAndIdorProtection() {
        notificationService.registerDevice(member1Id, new RegisterDeviceRequest("dev-m1", "ANDROID", "token-m1-" + UUID.randomUUID()));

        for (int i = 1; i <= 3; i++) {
            notificationService.processDomainEvent(new NotificationDomainEvent(
                    "TEST_EVENT:" + i + ":" + UUID.randomUUID(),
                    "ACTIVITY_CREATED",
                    "ACTIVITY",
                    "NORMAL",
                    false,
                    ownerId,
                    groupId,
                    List.of(member1Id),
                    "Thông báo #" + i,
                    "Nội dung thông báo #" + i,
                    "GROUP",
                    groupId,
                    "/groups/detail",
                    Map.of("groupId", groupId.toString()),
                    Instant.now().plusMillis(i * 10L)
            ));
        }

        assertThat(notificationService.getUnreadCount(member1Id).unreadCount()).isEqualTo(3L);
        assertThat(notificationService.getUnreadCount(ownerId).unreadCount()).isEqualTo(0L);

        PagedResponse<NotificationItemResponse> page0 = notificationService.listNotifications(member1Id, 0, 2);
        assertThat(page0.items()).hasSize(2);
        assertThat(page0.totalElements()).isEqualTo(3L);
        assertThat(page0.items().get(0).title()).isEqualTo("Thông báo #3");
        assertThat(page0.items().get(0).read()).isFalse();

        UUID firstNotifId = page0.items().get(0).id();

        // Cross-user IDOR attempt must be denied
        assertThatThrownBy(() -> notificationService.markRead(firstNotifId, outsiderId))
                .isInstanceOf(BusinessException.class)
                .extracting(ex -> ((BusinessException) ex).errorCode())
                .isEqualTo(ErrorCode.NOTIFICATION_NOT_FOUND);

        // First mark-read transitions state and decrements unread count
        NotificationItemResponse marked = notificationService.markRead(firstNotifId, member1Id);
        assertThat(marked.read()).isTrue();
        assertThat(marked.readAt()).isNotNull();
        assertThat(notificationService.getUnreadCount(member1Id).unreadCount()).isEqualTo(2L);

        // Second mark-read is idempotent and preserves readAt
        NotificationItemResponse markedAgain = notificationService.markRead(firstNotifId, member1Id);
        assertThat(markedAgain.read()).isTrue();
        assertThat(markedAgain.readAt()).isEqualTo(marked.readAt());
        assertThat(notificationService.getUnreadCount(member1Id).unreadCount()).isEqualTo(2L);

        // Mark-all-read marks remaining 2 notifications for member1 only
        MarkAllReadResponse markAll = notificationService.markAllRead(member1Id);
        assertThat(markAll.markedCount()).isEqualTo(2);
        assertThat(markAll.unreadCount()).isEqualTo(0L);
        assertThat(notificationService.getUnreadCount(member1Id).unreadCount()).isEqualTo(0L);
    }

    @Test
    void userSettingsControlPushOnlyWhileAlwaysPersistingInAppNotifications() {
        notificationService.registerDevice(member1Id, new RegisterDeviceRequest("dev-m1", "ANDROID", "token-settings-" + UUID.randomUUID()));

        UserNotificationSettingsResponse defaults = notificationService.getUserSettings(member1Id);
        assertThat(defaults.pushEnabled()).isTrue();
        assertThat(defaults.financeEnabled()).isTrue();

        // Disable financeEnabled only
        UserNotificationSettingsResponse patched = notificationService.updateUserSettings(
                member1Id,
                new UpdateUserNotificationSettingsRequest(null, null, null, null, null, null, null, false, null)
        );
        assertThat(patched.financeEnabled()).isFalse();
        assertThat(patched.pushEnabled()).isTrue();

        fakePushGateway.clearRecordedMessages();
        expenseService.create(groupId, ownerId, new ExpenseRequest(
                "Ăn tối Đà Lạt",
                new BigDecimal("200000.00"),
                ownerId,
                "EQUAL",
                List.of(ownerId, member1Id),
                null,
                null,
                OffsetDateTime.now(ZoneOffset.UTC),
                "Ghi chú"
        ));

        // In-app notification is still persisted, but push is suppressed by category preference
        PagedResponse<NotificationItemResponse> inbox = notificationService.listNotifications(member1Id, 0, 10);
        assertThat(inbox.items()).isNotEmpty();
        assertThat(inbox.items().get(0).category()).isEqualTo("FINANCE");
        assertThat(persistedPushDecision(inbox.items().get(0).id())).isEqualTo("SUPPRESSED_CATEGORY_DISABLED");
        assertThat(fakePushGateway.getRecordedMessages()).isEmpty();

        // Disable global pushEnabled
        notificationService.updateUserSettings(
                member1Id,
                new UpdateUserNotificationSettingsRequest(false, null, null, null, null, null, null, true, null)
        );
        notificationService.processDomainEvent(new NotificationDomainEvent(
                "GLOBAL_OFF:" + UUID.randomUUID(),
                "ACTIVITY_CREATED",
                "ACTIVITY",
                "NORMAL",
                false,
                ownerId,
                groupId,
                List.of(member1Id),
                "Hoạt động thử nghiệm",
                "Kiểm tra tắt push toàn cục",
                "GROUP",
                groupId,
                "/groups/detail",
                Map.of(),
                Instant.now()
        ));
        PagedResponse<NotificationItemResponse> afterGlobalOff = notificationService.listNotifications(member1Id, 0, 10);
        assertThat(persistedPushDecision(afterGlobalOff.items().get(0).id())).isEqualTo("SUPPRESSED_USER_PUSH_DISABLED");
        assertThat(fakePushGateway.getRecordedMessages()).isEmpty();
    }

    @Test
    void groupMuteSupportsDurationsExpirationUnauthorizedDenialAndCriticalBypass() {
        notificationService.registerDevice(member1Id, new RegisterDeviceRequest("dev-m1", "ANDROID", "token-mute-" + UUID.randomUUID()));

        // Outsider cannot read or update group notification settings
        assertThatThrownBy(() -> notificationService.getGroupSettings(groupId, outsiderId))
                .isInstanceOf(BusinessException.class);
        assertThatThrownBy(() -> notificationService.updateGroupSettings(
                groupId, outsiderId, new UpdateGroupNotificationSettingsRequest(true, "1H", null)))
                .isInstanceOf(BusinessException.class);

        // Test 1h, 8h, 1d, until_unmuted
        for (String duration : List.of("1H", "8H", "1D", "UNTIL_UNMUTED")) {
            GroupNotificationSettingsResponse res = notificationService.updateGroupSettings(
                    groupId, member1Id, new UpdateGroupNotificationSettingsRequest(true, duration, null)
            );
            assertThat(res.muted()).isTrue();
            assertThat(res.effectivelyMuted()).isTrue();
            if ("UNTIL_UNMUTED".equals(duration)) {
                assertThat(res.mutedUntil()).isNull();
            } else {
                assertThat(res.mutedUntil()).isAfter(Instant.now());
            }
        }

        // While muted, noncritical ACTIVITY notification is suppressed from push
        fakePushGateway.clearRecordedMessages();
        activityService.createFoundation(groupId, ownerId, new CreateActivityRequest(
                "Cắm trại săn mây",
                "Mô tả",
                Instant.now().plusSeconds(3600),
                Instant.now().plusSeconds(7200),
                "Asia/Ho_Chi_Minh",
                null,
                10
        ));
        assertThat(fakePushGateway.getRecordedMessages()).isEmpty();
        NotificationItemResponse nonCriticalItem = notificationService.listNotifications(member1Id, 0, 10).items().get(0);
        assertThat(persistedPushDecision(nonCriticalItem.id())).isEqualTo("SUPPRESSED_GROUP_MUTED");

        // While muted, CRITICAL notifications (waitlist promotion, settlement confirmation, contribution confirmation) BYPASS group mute!
        ExpenseDetail expense = expenseService.create(groupId, member1Id, new ExpenseRequest(
                "Vé xe",
                new BigDecimal("100000.00"),
                member1Id,
                "EQUAL",
                List.of(ownerId, member1Id),
                null,
                null,
                OffsetDateTime.now(ZoneOffset.UTC),
                null
        ));
        assertThat(expense).isNotNull();
        SettlementResponse settlement = expenseService.createSettlement(
                groupId, member1Id, new CreateSettlementRequest(ownerId, new BigDecimal("50000.00"), "I_RECEIVED")
        );
        fakePushGateway.clearRecordedMessages();
        expenseService.confirmSettlement(settlement.id(), ownerId);

        assertThat(fakePushGateway.getRecordedMessages()).hasSize(1);
        assertThat(fakePushGateway.getRecordedMessages().get(0).critical()).isTrue();
        assertThat(fakePushGateway.getRecordedMessages().get(0).category()).isEqualTo("FINANCE");

        // Simulate expired mute row in DB and verify server evaluates it as unmuted
        jdbc.update(
                "UPDATE group_notification_settings SET muted = TRUE, muted_until = ? WHERE group_id = ? AND user_id = ?",
                Timestamp.from(Instant.now().minusSeconds(60)),
                groupId,
                member1Id
        );
        GroupNotificationSettingsResponse expiredView = notificationService.getGroupSettings(groupId, member1Id);
        assertThat(expiredView.effectivelyMuted()).isFalse();
        assertThat(expiredView.muteOption()).isEqualTo("EXPIRED");

        fakePushGateway.clearRecordedMessages();
        notificationService.processDomainEvent(new NotificationDomainEvent(
                "AFTER_EXPIRY:" + UUID.randomUUID(),
                "ACTIVITY_CREATED",
                "ACTIVITY",
                "NORMAL",
                false,
                ownerId,
                groupId,
                List.of(member1Id),
                "Hoạt động sau khi hết hạn mute",
                "Push được gửi lại bình thường",
                "GROUP",
                groupId,
                "/groups/detail",
                Map.of(),
                Instant.now()
        ));
        assertThat(fakePushGateway.getRecordedMessages()).hasSize(1);
    }

    @Test
    void deviceTokenLifecycleSupportsMultiDeviceCrossUserTokenTransferDeactivationAndInvalidTokenCleanup() {
        String sharedPhysicalToken = "shared-fcm-token-" + UUID.randomUUID();
        String secondDeviceToken = "second-device-token-" + UUID.randomUUID();
        String staleToken = "invalid-token:" + UUID.randomUUID();

        // Owner registers sharedPhysicalToken first
        UserDeviceResponse ownerDev = notificationService.registerDevice(
                ownerId, new RegisterDeviceRequest("phone-1", "ANDROID", sharedPhysicalToken)
        );
        assertThat(ownerDev.active()).isTrue();

        // Member1 logs in on the same physical device with the same push_token -> V10 index remains satisfied and owner's row is deactivated
        UserDeviceResponse m1Dev1 = notificationService.registerDevice(
                member1Id, new RegisterDeviceRequest("phone-1", "ANDROID", sharedPhysicalToken)
        );
        assertThat(m1Dev1.active()).isTrue();
        assertThat(notificationService.listDevices(ownerId).get(0).active()).isFalse();

        // Member1 also registers a second active device and a stale third device
        notificationService.registerDevice(member1Id, new RegisterDeviceRequest("tablet-2", "IOS", secondDeviceToken));
        notificationService.registerDevice(member1Id, new RegisterDeviceRequest("old-phone-3", "ANDROID", staleToken));

        // Deactivate tablet-2 explicitly
        notificationService.deactivateDevice(member1Id, "tablet-2");

        fakePushGateway.clearRecordedMessages();
        notificationService.processDomainEvent(new NotificationDomainEvent(
                "DEVICE_TEST:" + UUID.randomUUID(),
                "GROUP_INVITATION_CREATED",
                "GROUP",
                "NORMAL",
                false,
                ownerId,
                groupId,
                List.of(member1Id),
                "Kiểm tra thiết bị",
                "Chỉ gửi tới thiết bị active và tự động vô hiệu hóa token hỏng",
                "GROUP",
                groupId,
                "/groups/detail",
                Map.of(),
                Instant.now()
        ));

        // Only the 2 active devices (phone-1 and old-phone-3) were attempted; tablet-2 was skipped
        assertThat(fakePushGateway.getRecordedMessages()).hasSize(2);

        // old-phone-3 had an invalid token, so NotificationService automatically marked it active=false
        Map<String, Boolean> activeByDeviceId = notificationService.listDevices(member1Id).stream()
                .collect(java.util.stream.Collectors.toMap(UserDeviceResponse::deviceId, UserDeviceResponse::active));
        assertThat(activeByDeviceId.get("phone-1")).isTrue();
        assertThat(activeByDeviceId.get("tablet-2")).isFalse();
        assertThat(activeByDeviceId.get("old-phone-3")).isFalse();
    }

    @Test
    void businessTransactionsSucceedEvenWhenPushGatewayThrowsExceptionAndDuplicateEventsAreDeduplicated() {
        notificationService.registerDevice(member1Id, new RegisterDeviceRequest("dev-m1", "ANDROID", "token-fail-" + UUID.randomUUID()));
        fakePushGateway.setSimulateRuntimeFailure(true);

        // Fund creation + collection creation + contribution confirmation must commit cleanly even when FCM throws!
        FundDetailResponse fund = fundService.createFund(groupId, ownerId, new CreateFundRequest("Quỹ M14"));
        CollectionDetailResponse collection = fundService.createCollection(
                fund.fundId(),
                ownerId,
                new CreateCollectionRequest(
                        "Thu quỹ tháng 10",
                        "Đóng quỹ",
                        OffsetDateTime.now(ZoneOffset.UTC).plusDays(5),
                        "EQUAL",
                        new BigDecimal("100000.00"),
                        List.of(member1Id),
                        null
                )
        );
        ContributionResponse sub = fundService.submitContribution(
                collection.collectionId(),
                member1Id,
                new CreateContributionRequest(member1Id, new BigDecimal("100000.00"), null, "Đóng đủ", null)
        );
        ContributionResponse confirmed = fundService.confirmContribution(sub.contributionId(), ownerId);
        assertThat(confirmed.status()).isEqualTo("CONFIRMED");

        // In-app notifications for FUND_COLLECTION_CREATED and FUND_CONTRIBUTION_CONFIRMED are persisted with PROVIDER_FAILED
        List<NotificationItemResponse> items = notificationService.listNotifications(member1Id, 0, 10).items();
        assertThat(items).hasSize(2);
        assertThat(persistedPushDecision(items.get(0).id())).isEqualTo("PROVIDER_FAILED");

        // Duplicate prevention: re-sending the exact same NotificationDomainEvent key is ignored
        fakePushGateway.setSimulateRuntimeFailure(false);
        fakePushGateway.clearRecordedMessages();
        NotificationDomainEvent duplicateEvent = new NotificationDomainEvent(
                "DUP_KEY_123",
                "FUND_COLLECTION_CREATED",
                "FUND",
                "NORMAL",
                false,
                ownerId,
                groupId,
                List.of(member1Id),
                "Sự kiện trùng lặp",
                "Không được gửi 2 lần",
                "FUND",
                fund.fundId(),
                "/groups/fund",
                Map.of(),
                Instant.now()
        );
        notificationService.processDomainEvent(duplicateEvent);
        notificationService.processDomainEvent(duplicateEvent);
        assertThat(fakePushGateway.getRecordedMessages()).hasSize(1);
    }

    @Test
    void concurrentDuplicateEventsPersistExactlyOneInboxRow() throws Exception {
        notificationService.registerDevice(
                member1Id,
                new RegisterDeviceRequest("dev-dedupe", "ANDROID", "test-token-dedupe-" + UUID.randomUUID())
        );
        fakePushGateway.clearRecordedMessages();
        String eventKey = "CONCURRENT_DUPLICATE:" + UUID.randomUUID();
        NotificationDomainEvent event = new NotificationDomainEvent(
                eventKey,
                "GROUP_EVENT",
                "GROUP",
                "NORMAL",
                false,
                ownerId,
                groupId,
                List.of(member1Id),
                "Thông báo kiểm tra trùng lặp",
                "Chỉ một bản ghi được lưu.",
                "GROUP",
                groupId,
                "/groups/detail",
                Map.of(),
                Instant.now()
        );
        CountDownLatch ready = new CountDownLatch(2);
        CountDownLatch start = new CountDownLatch(1);
        ExecutorService executor = Executors.newFixedThreadPool(2);
        try {
            Future<?> first = executor.submit(() -> {
                ready.countDown();
                await(start);
                notificationService.processDomainEvent(event);
            });
            Future<?> second = executor.submit(() -> {
                ready.countDown();
                await(start);
                notificationService.processDomainEvent(event);
            });
            assertThat(ready.await(5, TimeUnit.SECONDS)).isTrue();
            start.countDown();
            first.get(10, TimeUnit.SECONDS);
            second.get(10, TimeUnit.SECONDS);
        } finally {
            executor.shutdownNow();
        }

        Integer rows = jdbc.queryForObject(
                "SELECT count(*) FROM notifications WHERE user_id = ? AND data->>'eventKey' = ?",
                Integer.class,
                member1Id,
                eventKey + ":" + member1Id
        );
        assertThat(rows).isEqualTo(1);
        assertThat(fakePushGateway.getRecordedMessages()).hasSize(1);
        Map<String, Object> targetParams = notificationService.listNotifications(member1Id, 0, 10)
                .items().get(0).target().params();
        assertThat(targetParams).doesNotContainKeys("eventKey", "pushDecision", "collapseKey");
    }

    @Test
    void notificationEventIsNotPersistedWhenOriginatingTransactionRollsBack() {
        String eventKey = "ROLLED_BACK_EVENT:" + UUID.randomUUID();
        new TransactionTemplate(transactionManager).executeWithoutResult(status -> {
            eventPublisher.publishEvent(new NotificationDomainEvent(
                    eventKey,
                    "GROUP_EVENT",
                    "GROUP",
                    "NORMAL",
                    false,
                    ownerId,
                    groupId,
                    List.of(member1Id),
                    "Giao dịch bị hủy",
                    "Không được tạo thông báo.",
                    "GROUP",
                    groupId,
                    "/groups/detail",
                    Map.of(),
                    Instant.now()
            ));
            status.setRollbackOnly();
        });

        Integer rows = jdbc.queryForObject(
                "SELECT count(*) FROM notifications WHERE user_id = ? AND data->>'eventKey' = ?",
                Integer.class,
                member1Id,
                eventKey + ":" + member1Id
        );
        assertThat(rows).isZero();
    }

    @Test
    void openConversationSuppressesChatPushAndStaleTargetsResolveAsNonActionable() throws Exception {
        notificationService.registerDevice(member1Id, new RegisterDeviceRequest("dev-m1", "ANDROID", "token-chat-" + UUID.randomUUID()));
        notificationService.registerDevice(member2Id, new RegisterDeviceRequest("dev-m2", "ANDROID", "token-chat2-" + UUID.randomUUID()));

        var groupConv = chatService.openGroup(groupId, ownerId);
        UUID conversationId = groupConv.id();

        // Simulate member1 actively subscribed to conversationId via WebSocket
        WebSocketSession wsSession = mock(WebSocketSession.class);
        when(wsSession.getId()).thenReturn("ws-session-m1");
        when(wsSession.isOpen()).thenReturn(true);
        chatRealtimeCoordinator.registerSession(wsSession, member1Id);
        chatRealtimeCoordinator.handleClientCommand(
                wsSession,
                "{\"type\":\"SUBSCRIBE\",\"conversationId\":\"" + conversationId + "\"}"
        );
        assertThat(chatRealtimeCoordinator.isUserSubscribedToConversation(member1Id, conversationId)).isTrue();
        assertThat(chatRealtimeCoordinator.isUserSubscribedToConversation(member2Id, conversationId)).isFalse();

        notificationService.processDomainEvent(new NotificationDomainEvent(
                "OUTSIDER_CONVERSATION_TARGET:" + UUID.randomUUID(),
                "CHAT_MESSAGE_CREATED",
                "CHAT",
                "NORMAL",
                false,
                ownerId,
                null,
                List.of(outsiderId),
                "Cuộc trò chuyện riêng",
                "Không được mở bởi người ngoài.",
                "CONVERSATION",
                conversationId,
                "/chat/conversation",
                Map.of("conversationId", conversationId.toString()),
                Instant.now()
        ));
        NotificationItemResponse outsiderTarget = notificationService.listNotifications(outsiderId, 0, 10)
                .items().get(0);
        assertThat(outsiderTarget.target().actionable()).isFalse();

        fakePushGateway.clearRecordedMessages();
        chatService.send(conversationId, ownerId, new com.wedo.backend.chat.dto.ChatRequests.SendMessage(
                "Xin chào cả nhóm!", null, UUID.randomUUID()
        ));

        // member1 (open conversation) has push suppressed; member2 (not viewing conversation) receives push with collapseKey
        NotificationItemResponse m1ChatNotif = notificationService.listNotifications(member1Id, 0, 10).items().get(0);
        assertThat(persistedPushDecision(m1ChatNotif.id())).isEqualTo("SUPPRESSED_OPEN_CONVERSATION");

        NotificationItemResponse m2ChatNotif = notificationService.listNotifications(member2Id, 0, 10).items().get(0);
        assertThat(persistedPushDecision(m2ChatNotif.id())).isEqualTo("GATEWAY_ACCEPTED");
        assertThat(fakePushGateway.getRecordedMessages()).hasSize(1);
        assertThat(fakePushGateway.getRecordedMessages().get(0).userId()).isEqualTo(member2Id);
        assertThat(fakePushGateway.getRecordedMessages().get(0).collapseKey()).isEqualTo("chat:" + conversationId);

        chatRealtimeCoordinator.unregisterSession(wsSession);

        // Stale target check: create an activity, notify member1, then cancel the activity -> target.actionable becomes false
        var act = activityService.createFoundation(groupId, ownerId, new CreateActivityRequest(
                "Chạy bộ hồ Xuân Hương",
                null,
                Instant.now().plusSeconds(3600),
                Instant.now().plusSeconds(7200),
                "Asia/Ho_Chi_Minh",
                null,
                2
        ));
        NotificationItemResponse beforeCancel = notificationService.listNotifications(member1Id, 0, 10).items().get(0);
        assertThat(beforeCancel.target().actionable()).isTrue();

        jdbc.update("UPDATE activities SET status = 'CANCELLED' WHERE id = ?", act.id());
        NotificationItemResponse afterCancel = notificationService.listNotifications(member1Id, 0, 10).items().get(0);
        assertThat(afterCancel.target().actionable()).isFalse();
        assertThat(afterCancel.target().nonActionableReason()).contains("hủy");

        // Waitlist promotion critical notification check
        var capAct = activityService.createFoundation(groupId, ownerId, new CreateActivityRequest(
                "Workshop cà phê giới hạn 1 chỗ",
                null,
                Instant.now().plusSeconds(3600),
                Instant.now().plusSeconds(7200),
                "Asia/Ho_Chi_Minh",
                null,
                1
        ));
        activityRsvpService.changeRsvp(capAct.id(), ownerId, new ChangeRsvpRequest(ActivityRsvpStatus.GOING));
        activityRsvpService.changeRsvp(capAct.id(), member1Id, new ChangeRsvpRequest(ActivityRsvpStatus.GOING)); // Waitlisted
        fakePushGateway.clearRecordedMessages();
        activityRsvpService.changeRsvp(capAct.id(), ownerId, new ChangeRsvpRequest(ActivityRsvpStatus.NOT_GOING)); // Promotes member1!

        NotificationItemResponse promotedNotif = notificationService.listNotifications(member1Id, 0, 10).items().get(0);
        assertThat(promotedNotif.critical()).isTrue();
        assertThat(promotedNotif.priority()).isEqualTo("HIGH");
        assertThat(promotedNotif.title()).contains("danh sách tham gia");
    }

    private UUID createUser(String prefix, Instant now) {
        UUID id = UUID.randomUUID();
        String suffix = id.toString().substring(0, 8);
        userRepository.save(new UserEntity(
                id,
                prefix + "_" + suffix + "@example.com",
                prefix + "_" + suffix,
                prefix.toUpperCase() + " " + suffix,
                UserStatus.ACTIVE,
                now,
                now
        ));
        return id;
    }

    private String persistedPushDecision(UUID notificationId) {
        return jdbc.queryForObject(
                "SELECT data->>'pushDecision' FROM notifications WHERE id = ?",
                String.class,
                notificationId
        );
    }

    private static void await(CountDownLatch latch) {
        try {
            if (!latch.await(5, TimeUnit.SECONDS)) {
                throw new IllegalStateException("Timed out waiting for concurrent test start.");
            }
        } catch (InterruptedException ex) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Concurrent notification test was interrupted.", ex);
        }
    }
}
