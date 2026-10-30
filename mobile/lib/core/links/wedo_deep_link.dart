import 'dart:async';

import 'package:flutter/services.dart';

/// Canonical host and URL builders for weDO deep links & QR payloads.
abstract final class WeDoLinkConfig {
  static const String canonicalHost = 'wedo-3304c.web.app';
  static const Set<String> trustedHttpsHosts = <String>{
    'wedo-3304c.web.app',
    'wedo-3304c.firebaseapp.com',
  };

  static String groupInviteUrl(String inviteCode) =>
      'https://$canonicalHost/inv/${inviteCode.trim()}';

  static String friendProfileUrl(String userId) =>
      'https://$canonicalHost/u/${userId.trim()}';
}

sealed class WeDoDeepLink {
  final String rawUrl;
  const WeDoDeepLink({required this.rawUrl});

  static final RegExp _inviteCodePattern = RegExp(r'^[A-Za-z0-9_-]{4,32}$');
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Parses a canonical HTTPS or `wedo://` deep link into a typed destination.
  /// Returns `null` for untrusted hosts, malformed paths, or URLs with query/fragment parameters.
  static WeDoDeepLink? parse(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final Uri? uri = Uri.tryParse(trimmed);
    if (uri == null ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty) {
      return null;
    }

    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final segments = uri.pathSegments;

    if (scheme == 'https') {
      if (!WeDoLinkConfig.trustedHttpsHosts.contains(host)) {
        return null;
      }
      if (segments.length != 2) {
        return null;
      }
      final kind = segments[0];
      final target = segments[1];
      if (kind == 'inv' && _inviteCodePattern.hasMatch(target)) {
        return WeDoGroupInviteLink(inviteCode: target, rawUrl: trimmed);
      }
      if (kind == 'u' && _uuidPattern.hasMatch(target)) {
        return WeDoFriendProfileLink(
          userId: target,
          canonicalDeepLink: WeDoLinkConfig.friendProfileUrl(target),
          rawUrl: trimmed,
        );
      }
      return null;
    }

    if (scheme == 'wedo') {
      if (segments.length != 1) {
        return null;
      }
      final target = segments[0];
      if (host == 'inv' && _inviteCodePattern.hasMatch(target)) {
        return WeDoGroupInviteLink(inviteCode: target, rawUrl: trimmed);
      }
      if ((host == 'u' || host == 'user') && _uuidPattern.hasMatch(target)) {
        return WeDoFriendProfileLink(
          userId: target,
          canonicalDeepLink: WeDoLinkConfig.friendProfileUrl(target),
          rawUrl: trimmed,
        );
      }
      return null;
    }

    return null;
  }

  /// Extracts a case-sensitive invite code from either a raw invite code or a canonical invite URL.
  /// Returns `null` if the input is empty, an untrusted URL, or a non-invite URL.
  static String? extractInviteCodeFromInput(String? rawInput) {
    if (rawInput == null) return null;
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.contains('://') ||
        trimmed.contains('/') ||
        trimmed.contains('.')) {
      final parsed = parse(trimmed);
      if (parsed is WeDoGroupInviteLink) {
        return parsed.inviteCode;
      }
      return null;
    }

    if (_inviteCodePattern.hasMatch(trimmed)) {
      return trimmed;
    }
    return null;
  }
}

final class WeDoGroupInviteLink extends WeDoDeepLink {
  final String inviteCode;

  const WeDoGroupInviteLink({
    required this.inviteCode,
    required super.rawUrl,
  });
}

final class WeDoFriendProfileLink extends WeDoDeepLink {
  final String userId;
  final String canonicalDeepLink;

  const WeDoFriendProfileLink({
    required this.userId,
    required this.canonicalDeepLink,
    required super.rawUrl,
  });
}

/// Suppresses duplicate QR frames or rapid duplicate link dispatches.
class WeDoScanDeduplicator {
  final Duration cooldown;
  String? _lastValue;
  DateTime? _lastAcceptedAt;

  WeDoScanDeduplicator({
    this.cooldown = const Duration(milliseconds: 2500),
  });

  bool shouldProcess(String raw, {DateTime? now}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return false;
    final timestamp = now ?? DateTime.now();
    if (_lastValue == trimmed &&
        _lastAcceptedAt != null &&
        timestamp.difference(_lastAcceptedAt!) < cooldown) {
      return false;
    }
    _lastValue = trimmed;
    _lastAcceptedAt = timestamp;
    return true;
  }

  void reset() {
    _lastValue = null;
    _lastAcceptedAt = null;
  }
}

/// Platform channel bridge for OS share sheet, incoming deep links, and native QR camera scanner.
class WeDoPlatformLinks {
  static const MethodChannel _channel = MethodChannel('wedo/deep_links');

  static Future<bool> Function(String text, {String? subject})?
      debugShareOverride;
  static Future<String?> Function()? debugScanQrOverride;

  static final StreamController<String> _incomingLinksController =
      StreamController<String>.broadcast();
  static bool _listenerInitialized = false;

  static Stream<String> get incomingLinks {
    _ensureInitialized();
    return _incomingLinksController.stream;
  }

  static void _ensureInitialized() {
    if (_listenerInitialized) return;
    _listenerInitialized = true;
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'onDeepLink') {
        final raw = call.arguments;
        if (raw is String && raw.trim().isNotEmpty) {
          _incomingLinksController.add(raw.trim());
        }
      }
    });
  }

  static Future<String?> getInitialLink() async {
    _ensureInitialized();
    try {
      final link = await _channel.invokeMethod<String>('getInitialLink');
      return link?.trim().isNotEmpty == true ? link!.trim() : null;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Future<bool> shareText(String text, {String? subject}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    if (debugShareOverride != null) {
      return debugShareOverride!(trimmed, subject: subject);
    }
    try {
      final ok = await _channel.invokeMethod<bool>('shareText', <String, Object?>{
        'text': trimmed,
        if (subject != null && subject.trim().isNotEmpty)
          'subject': subject.trim(),
      });
      return ok ?? false;
    } on MissingPluginException {
      await Clipboard.setData(ClipboardData(text: trimmed));
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<String?> scanQr() async {
    if (debugScanQrOverride != null) {
      return debugScanQrOverride!();
    }
    final result = await _channel.invokeMethod<String>('scanQr');
    return result?.trim().isNotEmpty == true ? result!.trim() : null;
  }
}
