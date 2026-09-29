package com.wedo.backend.notification.push;

import java.util.Map;
import java.util.UUID;

public interface PushGateway {

    PushDeliveryResult sendPush(PushMessage message);

    enum PushDeliveryStatus {
        GATEWAY_ACCEPTED,
        INVALID_TOKEN,
        TRANSIENT_FAILURE,
        PROVIDER_FAILED,
        EXTERNAL_CONFIG_BLOCKED
    }

    record PushMessage(
            UUID notificationId,
            UUID userId,
            String deviceId,
            String platform,
            String pushToken,
            String category,
            String priority,
            boolean critical,
            String title,
            String body,
            String collapseKey,
            Map<String, String> data
    ) {
    }

    record PushDeliveryResult(
            PushDeliveryStatus status,
            String providerMessageId,
            String errorCode,
            String errorDetail
    ) {
        public static PushDeliveryResult gatewayAccepted(String providerMessageId) {
            return new PushDeliveryResult(PushDeliveryStatus.GATEWAY_ACCEPTED, providerMessageId, null, null);
        }

        public static PushDeliveryResult invalidToken(String errorCode, String errorDetail) {
            return new PushDeliveryResult(PushDeliveryStatus.INVALID_TOKEN, null, errorCode, errorDetail);
        }

        public static PushDeliveryResult transientFailure(String errorCode, String errorDetail) {
            return new PushDeliveryResult(PushDeliveryStatus.TRANSIENT_FAILURE, null, errorCode, errorDetail);
        }

        public static PushDeliveryResult providerFailed(String errorCode, String errorDetail) {
            return new PushDeliveryResult(PushDeliveryStatus.PROVIDER_FAILED, null, errorCode, errorDetail);
        }

        public static PushDeliveryResult externalConfigBlocked() {
            return new PushDeliveryResult(
                    PushDeliveryStatus.EXTERNAL_CONFIG_BLOCKED,
                    null,
                    "REAL_FCM_EXTERNAL_CONFIG_BLOCKED",
                    "Firebase Admin provider integration and credentials are not configured in this environment."
            );
        }
    }
}
