package com.wedo.backend.notification;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.MessagingErrorCode;
import com.wedo.backend.notification.push.FcmPushGateway;
import com.wedo.backend.notification.push.PushGateway.PushDeliveryStatus;
import com.wedo.backend.notification.push.PushGateway.PushMessage;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class FcmPushGatewayTest {

    private FirebaseMessaging messaging;
    private FcmPushGateway gateway;

    @BeforeEach
    void setUp() {
        messaging = mock(FirebaseMessaging.class);
        gateway = new FcmPushGateway(messaging);
    }

    @Test
    void firebaseMessageIdMeansGatewayAcceptedNotDeviceDelivery() throws Exception {
        when(messaging.send(any(Message.class))).thenReturn("projects/project/messages/message-id");

        var result = gateway.sendPush(pushMessage());

        assertThat(result.status()).isEqualTo(PushDeliveryStatus.GATEWAY_ACCEPTED);
        assertThat(result.providerMessageId()).isEqualTo("projects/project/messages/message-id");
        verify(messaging).send(any(Message.class));
    }

    @Test
    void unregisteredAndInvalidArgumentTokensAreClassifiedForDeactivation() throws Exception {
        FirebaseMessagingException error = mock(FirebaseMessagingException.class);
        when(error.getMessagingErrorCode()).thenReturn(MessagingErrorCode.UNREGISTERED);
        doThrow(error).when(messaging).send(any(Message.class));

        var result = gateway.sendPush(pushMessage());

        assertThat(result.status()).isEqualTo(PushDeliveryStatus.INVALID_TOKEN);
        assertThat(result.errorCode()).isEqualTo("UNREGISTERED");
    }

    @Test
    void unavailableFirebaseIsClassifiedAsTransient() throws Exception {
        FirebaseMessagingException error = mock(FirebaseMessagingException.class);
        when(error.getMessagingErrorCode()).thenReturn(MessagingErrorCode.UNAVAILABLE);
        doThrow(error).when(messaging).send(any(Message.class));

        var result = gateway.sendPush(pushMessage());

        assertThat(result.status()).isEqualTo(PushDeliveryStatus.TRANSIENT_FAILURE);
        assertThat(result.errorCode()).isEqualTo("UNAVAILABLE");
    }

    @Test
    void otherFirebaseAndClientFailuresRemainProviderFailures() throws Exception {
        FirebaseMessagingException error = mock(FirebaseMessagingException.class);
        when(error.getMessagingErrorCode()).thenReturn(MessagingErrorCode.SENDER_ID_MISMATCH);
        doThrow(error).when(messaging).send(any(Message.class));

        var result = gateway.sendPush(pushMessage());

        assertThat(result.status()).isEqualTo(PushDeliveryStatus.PROVIDER_FAILED);
    }

    private PushMessage pushMessage() {
        return new PushMessage(
                UUID.randomUUID(), UUID.randomUUID(), "device", "ANDROID", "registration-token",
                "ACTIVITY", "NORMAL", false, "Activity update", "A new activity update is available.",
                null, Map.of("notificationId", "notification-id")
        );
    }
}
