package com.wedo.backend.notification.push;

import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.AndroidNotification;
import com.google.firebase.messaging.AndroidConfig.Priority;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.MessagingErrorCode;
import com.google.firebase.messaging.Notification;
import org.springframework.stereotype.Component;

/** Sends one committed notification to one Firebase registration token. */
@Component
public class FcmPushGateway implements PushGateway {

    private final FirebaseMessaging firebaseMessaging;

    public FcmPushGateway(FirebaseMessaging firebaseMessaging) {
        this.firebaseMessaging = firebaseMessaging;
    }

    @Override
    @SuppressWarnings("deprecation")
    public PushDeliveryResult sendPush(PushMessage push) {
        AndroidConfig.Builder androidConfig = AndroidConfig.builder()
                .setPriority(push.critical() || "HIGH".equalsIgnoreCase(push.priority())
                        ? Priority.HIGH
                        : Priority.NORMAL)
                .setNotification(AndroidNotification.builder()
                        .setChannelId("wedo_notifications")
                        .build());
        if (push.collapseKey() != null && !push.collapseKey().isBlank()) {
            androidConfig.setCollapseKey(push.collapseKey());
        }

        Message message = Message.builder()
                .setToken(push.pushToken())
                .setNotification(Notification.builder()
                        .setTitle(push.title())
                        .setBody(push.body())
                        .build())
                .putAllData(push.data())
                .setAndroidConfig(androidConfig.build())
                .build();

        try {
            String messageId = firebaseMessaging.send(message);
            return PushDeliveryResult.gatewayAccepted(messageId);
        } catch (FirebaseMessagingException ex) {
            MessagingErrorCode code = ex.getMessagingErrorCode();
            String codeName = code == null ? "FIREBASE_SEND_FAILED" : code.name();
            if (code == MessagingErrorCode.UNREGISTERED || code == MessagingErrorCode.INVALID_ARGUMENT) {
                return PushDeliveryResult.invalidToken(codeName, "Firebase rejected the registration token.");
            }
            if (code == MessagingErrorCode.INTERNAL
                    || code == MessagingErrorCode.UNAVAILABLE
                    || code == MessagingErrorCode.QUOTA_EXCEEDED) {
                return PushDeliveryResult.transientFailure(codeName, "Firebase temporarily rejected the send.");
            }
            return PushDeliveryResult.providerFailed(codeName, "Firebase rejected the send request.");
        } catch (RuntimeException ex) {
            return PushDeliveryResult.providerFailed("FIREBASE_CLIENT_FAILURE", "Firebase Messaging client failed.");
        }
    }
}
