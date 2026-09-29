import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/storage/secure_key_value_store.dart';
import 'package:mobile/core/storage/secure_storage_service.dart';
import 'package:mobile/features/notification/application/notification_push_service.dart';

void main() {
  late _FakeMessaging messaging;
  late _MemorySecureStore store;
  late SecureStorageService storage;
  late List<(String, String)> registrations;
  late List<String> deactivations;
  late List<FcmPushEvent> foreground;
  late List<FcmPushEvent> taps;
  late NotificationPushService service;

  setUp(() {
    messaging = _FakeMessaging();
    store = _MemorySecureStore();
    storage = SecureStorageService(store: store);
    registrations = <(String, String)>[];
    deactivations = <String>[];
    foreground = <FcmPushEvent>[];
    taps = <FcmPushEvent>[];
    service = NotificationPushService(
      messaging: messaging,
      storage: storage,
      registerDevice: ({required deviceId, required pushToken}) async {
        registrations.add((deviceId, pushToken));
      },
      deactivateDevice: (deviceId) async => deactivations.add(deviceId),
      onForegroundMessage: (event) async => foreground.add(event),
      onNotificationTap: (event) async => taps.add(event),
    );
  });

  tearDown(() async {
    await service.dispose();
    await messaging.close();
  });

  test(
    'authenticated startup registers token with stable installation id',
    () async {
      await service.start(authenticated: true);

      expect(registrations, hasLength(1));
      expect(registrations.single.$2, 'registration-test-token');
      expect(registrations.single.$1, matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(messaging.permissionChecks, <bool>[false]);
      expect(await storage.hasRequestedNotificationPermission(), isTrue);

      await service.setAuthenticated(true);
      expect(registrations, hasLength(2));
      expect(registrations.last.$1, registrations.first.$1);
      expect(messaging.permissionChecks, <bool>[false, true]);
    },
  );

  test(
    'token refresh re-registers and logout deactivates same device id',
    () async {
      await service.start(authenticated: true);
      final String deviceId = registrations.single.$1;

      messaging.tokenRefreshes.add('rotated-registration-token');
      await Future<void>.delayed(Duration.zero);
      expect(registrations.last, (deviceId, 'rotated-registration-token'));

      await service.deactivateForLogout();
      expect(deactivations, <String>[deviceId]);
    },
  );

  test(
    'cold-start tap waits for authenticated session and navigator readiness',
    () async {
      const FcmPushEvent event = FcmPushEvent(notificationId: 'notification-1');
      messaging.initialMessage = event;
      await service.start(authenticated: false);
      expect(taps, isEmpty);

      await service.setAuthenticated(true);
      expect(taps, isEmpty);

      await service.markAppReady();
      expect(taps, <FcmPushEvent>[event]);
    },
  );

  test(
    'foreground messages are forwarded only for an authenticated user',
    () async {
      const FcmPushEvent event = FcmPushEvent(
        notificationId: 'notification-foreground',
        title: 'Activity update',
      );
      await service.start(authenticated: false);
      messaging.foregroundMessages.add(event);
      await Future<void>.delayed(Duration.zero);
      expect(foreground, isEmpty);

      await service.setAuthenticated(true);
      messaging.foregroundMessages.add(event);
      await Future<void>.delayed(Duration.zero);
      expect(foreground, <FcmPushEvent>[event]);
    },
  );

  test('push event retains action data and stringifies Firebase values', () {
    final FcmPushEvent event = FcmPushEvent.fromData(
      data: <String, dynamic>{
        'notificationId': 'n-1',
        'targetType': 'CONVERSATION',
        'targetId': 'conversation-1',
        'groupId': 'group-1',
        'conversationId': 'conversation-1',
        'route': '/groups/chat',
      },
      title: 'Chat',
    );

    expect(event.notificationId, 'n-1');
    expect(event.data['targetType'], 'CONVERSATION');
    expect(event.data['targetId'], 'conversation-1');
    expect(event.data['groupId'], 'group-1');
    expect(event.data['conversationId'], 'conversation-1');
    expect(event.data['route'], '/groups/chat');
    expect(() => event.data['targetType'] = 'GROUP', throwsUnsupportedError);
  });

  test('opened-app tap waits for readiness and dispatches once', () async {
    const FcmPushEvent event = FcmPushEvent(
      notificationId: 'notification-live',
      data: <String, String>{'targetType': 'ACTIVITY'},
    );
    await service.start(authenticated: true);
    messaging.openedMessages.add(event);
    messaging.openedMessages.add(event);
    await Future<void>.delayed(Duration.zero);
    expect(taps, isEmpty);

    await service.markAppReady();
    expect(taps, <FcmPushEvent>[event]);
  });

  test(
    'logout clears a cold-start action before another account is ready',
    () async {
      const FcmPushEvent event = FcmPushEvent(
        notificationId: 'private-old-user',
      );
      messaging.initialMessage = event;
      await service.start(authenticated: false);
      await service.deactivateForLogout();
      await service.setAuthenticated(true);
      await service.markAppReady();

      expect(taps, isEmpty);
    },
  );

  test('opened-app taps received while signed out are ignored', () async {
    await service.start(authenticated: false);
    messaging.openedMessages.add(
      const FcmPushEvent(notificationId: 'signed-out-tap'),
    );
    await Future<void>.delayed(Duration.zero);
    await service.setAuthenticated(true);
    await service.markAppReady();

    expect(taps, isEmpty);
  });

  test(
    'logout after authentication clears a queued action across account change',
    () async {
      messaging.initialMessage = const FcmPushEvent(
        notificationId: 'account-one-notification',
      );
      await service.start(authenticated: false);
      await service.setAuthenticated(true);
      await service.setAuthenticated(false);
      await service.setAuthenticated(true);
      await service.markAppReady();

      expect(taps, isEmpty);
    },
  );

  test(
    'already-read and repeated taps still resolve through one callback',
    () async {
      const FcmPushEvent event = FcmPushEvent(
        notificationId: 'read-notification',
      );
      await service.start(authenticated: true);
      await service.markAppReady();
      messaging.openedMessages.add(event);
      await Future<void>.delayed(Duration.zero);
      messaging.openedMessages.add(event);
      await Future<void>.delayed(Duration.zero);

      expect(taps, <FcmPushEvent>[event]);
    },
  );

  test(
    'logout clears tap deduplication state for a later signed-in session',
    () async {
      const FcmPushEvent event = FcmPushEvent(
        notificationId: 'notification-again',
      );
      await service.start(authenticated: true);
      await service.markAppReady();
      messaging.openedMessages.add(event);
      await Future<void>.delayed(Duration.zero);
      await service.deactivateForLogout();
      await service.setAuthenticated(true);
      messaging.openedMessages.add(event);
      await Future<void>.delayed(Duration.zero);

      expect(taps, <FcmPushEvent>[event, event]);
    },
  );
}

class _FakeMessaging implements PushMessagingClient {
  final StreamController<String> tokenRefreshes =
      StreamController<String>.broadcast();
  final StreamController<FcmPushEvent> foregroundMessages =
      StreamController<FcmPushEvent>.broadcast();
  final StreamController<FcmPushEvent> openedMessages =
      StreamController<FcmPushEvent>.broadcast();
  final List<bool> permissionChecks = <bool>[];
  String? token = 'registration-test-token';
  FcmPushEvent? initialMessage;

  @override
  Stream<String> get onTokenRefresh => tokenRefreshes.stream;

  @override
  Stream<FcmPushEvent> get onForegroundMessage => foregroundMessages.stream;

  @override
  Stream<FcmPushEvent> get onMessageOpenedApp => openedMessages.stream;

  @override
  Future<FcmPushEvent?> getInitialMessage() async => initialMessage;

  @override
  Future<String?> getToken() async => token;

  @override
  Future<bool> requestPermissionIfNeeded({
    required bool previouslyRequested,
  }) async {
    permissionChecks.add(previouslyRequested);
    return true;
  }

  Future<void> close() async {
    await tokenRefreshes.close();
    await foregroundMessages.close();
    await openedMessages.close();
  }
}

class _MemorySecureStore implements SecureKeyValueStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
