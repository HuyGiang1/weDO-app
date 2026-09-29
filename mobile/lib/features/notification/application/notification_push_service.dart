import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../core/storage/secure_storage_service.dart';
import '../data/notification_failure.dart';

class FcmPushEvent {
  const FcmPushEvent({
    this.notificationId,
    this.title,
    this.body,
    this.data = const <String, String>{},
  });

  final String? notificationId;
  final String? title;
  final String? body;
  final Map<String, String> data;

  factory FcmPushEvent.fromData({
    required Map<String, dynamic> data,
    String? title,
    String? body,
  }) {
    return FcmPushEvent(
      notificationId: data['notificationId']?.toString(),
      title: title,
      body: body,
      data: Map<String, String>.unmodifiable(
        data.map(
          (String key, dynamic value) => MapEntry(key, value.toString()),
        ),
      ),
    );
  }

  factory FcmPushEvent.fromRemoteMessage(RemoteMessage message) {
    return FcmPushEvent.fromData(
      data: message.data,
      title: message.notification?.title,
      body: message.notification?.body,
    );
  }
}

abstract interface class PushMessagingClient {
  Future<bool> requestPermissionIfNeeded({required bool previouslyRequested});
  Future<String?> getToken();
  Stream<String> get onTokenRefresh;
  Stream<FcmPushEvent> get onForegroundMessage;
  Stream<FcmPushEvent> get onMessageOpenedApp;
  Future<FcmPushEvent?> getInitialMessage();
}

class FirebasePushMessagingClient implements PushMessagingClient {
  FirebasePushMessagingClient(this._messaging);

  final FirebaseMessaging _messaging;

  @override
  Future<bool> requestPermissionIfNeeded({
    required bool previouslyRequested,
  }) async {
    NotificationSettings settings = await _messaging.getNotificationSettings();
    final bool shouldAsk =
        settings.authorizationStatus == AuthorizationStatus.notDetermined ||
        (settings.authorizationStatus == AuthorizationStatus.denied &&
            !previouslyRequested);
    if (shouldAsk) {
      settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> getToken() => _messaging.getToken();

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<FcmPushEvent> get onForegroundMessage =>
      FirebaseMessaging.onMessage.map(FcmPushEvent.fromRemoteMessage);

  @override
  Stream<FcmPushEvent> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp.map(FcmPushEvent.fromRemoteMessage);

  @override
  Future<FcmPushEvent?> getInitialMessage() async {
    final RemoteMessage? message = await _messaging.getInitialMessage();
    return message == null ? null : FcmPushEvent.fromRemoteMessage(message);
  }
}

typedef RegisterNotificationDevice = Future<void> Function({
  required String deviceId,
  required String pushToken,
});
typedef DeactivateNotificationDevice = Future<void> Function(String deviceId);
typedef NotificationPushCallback = Future<void> Function(FcmPushEvent event);

class NotificationPushService {
  NotificationPushService({
    required this.messaging,
    required this.storage,
    required this.registerDevice,
    required this.deactivateDevice,
    required this.onForegroundMessage,
    required this.onNotificationTap,
  });

  final PushMessagingClient messaging;
  final SecureStorageService storage;
  final RegisterNotificationDevice registerDevice;
  final DeactivateNotificationDevice deactivateDevice;
  final NotificationPushCallback onForegroundMessage;
  final NotificationPushCallback onNotificationTap;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<FcmPushEvent>? _foregroundSubscription;
  StreamSubscription<FcmPushEvent>? _tapSubscription;
  FcmPushEvent? _pendingTap;
  final Set<String> _handledTapIds = <String>{};
  bool _authenticated = false;
  bool _appReady = false;
  String? _deviceId;
  bool _started = false;
  int _sessionGeneration = 0;

  Future<void> start({required bool authenticated}) async {
    if (_started) return;
    _started = true;
    _tokenSubscription = messaging.onTokenRefresh.listen((String token) {
      if (_authenticated) unawaited(_register(token));
    });
    _foregroundSubscription = messaging.onForegroundMessage.listen((event) {
      if (_authenticated) unawaited(onForegroundMessage(event));
    });
    _tapSubscription = messaging.onMessageOpenedApp.listen(_handleTap);
    _pendingTap = await messaging.getInitialMessage();
    await setAuthenticated(authenticated);
  }

  Future<void> setAuthenticated(bool authenticated) async {
    if (_authenticated != authenticated) {
      _sessionGeneration++;
      if (!authenticated) {
        _pendingTap = null;
        _handledTapIds.clear();
      }
    }
    _authenticated = authenticated;
    final int generation = _sessionGeneration;
    if (kDebugMode) {
      debugPrint('FCM sync: authenticated=$authenticated');
    }
    if (authenticated) {
      final bool permissionRequested = await storage
          .hasRequestedNotificationPermission();
      final bool permissionGranted = await messaging.requestPermissionIfNeeded(
        previouslyRequested: permissionRequested,
      );
      if (kDebugMode) {
        debugPrint('FCM sync: permissionGranted=$permissionGranted');
      }
      if (!permissionRequested) {
        await storage.markNotificationPermissionRequested();
      }
      final String? token = await messaging.getToken();
      if (!_isCurrentSession(generation)) return;
      if (kDebugMode) {
        debugPrint('FCM sync: tokenAvailable=${token?.isNotEmpty == true}');
      }
      await _register(token);
      if (!_isCurrentSession(generation)) return;
      await _deliverPendingTap();
    }
  }

  Future<void> deactivateForLogout() async {
    _sessionGeneration++;
    _authenticated = false;
    _pendingTap = null;
    _handledTapIds.clear();
    final String deviceId =
        _deviceId ?? await storage.getOrCreateNotificationDeviceId();
    try {
      await deactivateDevice(deviceId);
    } catch (_) {
      // Local session invalidation and pending-action clearing must still win.
    }
  }

  Future<void> markAppReady() async {
    _appReady = true;
    await _deliverPendingTap();
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _tapSubscription?.cancel();
  }

  Future<void> _register(String? token) async {
    if (token == null || token.trim().isEmpty || !_authenticated) return;
    try {
      _deviceId ??= await storage.getOrCreateNotificationDeviceId();
      await registerDevice(deviceId: _deviceId!, pushToken: token);
      if (kDebugMode) {
        debugPrint('FCM sync: device registration succeeded');
      }
    } catch (error) {
      if (kDebugMode) {
        if (error is NotificationFailure) {
          debugPrint(
            'FCM sync: device registration failed (code=${error.code}, status=${error.statusCode})',
          );
        } else {
          debugPrint(
            'FCM sync: device registration failed (${error.runtimeType})',
          );
        }
      }
      // Push registration must not block login or normal app usage.
    }
  }

  void _handleTap(FcmPushEvent event) {
    if (!_authenticated) return;
    final String? id = event.notificationId;
    if (id != null && id.isNotEmpty && _handledTapIds.contains(id)) return;
    if (kDebugMode) {
      debugPrint(
        'FCM tap: opened-app event, notificationIdPresent=${event.notificationId?.isNotEmpty == true}',
      );
    }
    _pendingTap = event;
    unawaited(_deliverPendingTap());
  }

  Future<void> _deliverPendingTap() async {
    if (!_appReady || !_authenticated || _pendingTap == null) return;
    final FcmPushEvent event = _pendingTap!;
    _pendingTap = null;
    final String? id = event.notificationId;
    if (id != null && id.isNotEmpty && !_handledTapIds.add(id)) return;
    if (kDebugMode) {
      debugPrint('FCM tap: dispatching to notification router');
    }
    await onNotificationTap(event);
  }

  bool _isCurrentSession(int generation) =>
      _authenticated && generation == _sessionGeneration;
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}
