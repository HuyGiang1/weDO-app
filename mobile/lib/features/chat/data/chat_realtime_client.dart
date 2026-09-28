import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'chat_realtime_event.dart';

abstract class ChatRealtimeSocket {
  Stream<dynamic> get stream;
  void add(String data);
  Future<void> close();
}

class IoChatRealtimeSocket implements ChatRealtimeSocket {
  final WebSocket _ws;
  IoChatRealtimeSocket(this._ws);

  @override
  Stream<dynamic> get stream => _ws;

  @override
  void add(String data) => _ws.add(data);

  @override
  Future<void> close() => _ws.close();
}

typedef ChatSocketConnector =
    Future<ChatRealtimeSocket> Function(
      String url,
      Map<String, dynamic> headers,
    );

abstract class ChatRealtimeClient {
  Stream<ChatRealtimeEvent> get events;
  Stream<ChatRealtimeConnectionState> get connectionStates;
  ChatRealtimeConnectionState get currentState;
  Set<String> get subscribedConversationIds;

  Future<void> connect();
  Future<void> disconnect();
  void subscribeConversation(String conversationId);
  void unsubscribeConversation(String conversationId);
  void sendTypingStart(String conversationId);
  void sendTypingStop(String conversationId);
  void sendMarkRead(String conversationId, int lastReadSequence);
  void dispose();
}

class NoopChatRealtimeClient implements ChatRealtimeClient {
  const NoopChatRealtimeClient();

  @override
  Stream<ChatRealtimeEvent> get events => const Stream.empty();

  @override
  Stream<ChatRealtimeConnectionState> get connectionStates =>
      const Stream.empty();

  @override
  ChatRealtimeConnectionState get currentState =>
      ChatRealtimeConnectionState.disconnected;

  @override
  Set<String> get subscribedConversationIds => const {};

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  void subscribeConversation(String conversationId) {}

  @override
  void unsubscribeConversation(String conversationId) {}

  @override
  void sendTypingStart(String conversationId) {}

  @override
  void sendTypingStop(String conversationId) {}

  @override
  void sendMarkRead(String conversationId, int lastReadSequence) {}

  @override
  void dispose() {}
}

class WebSocketChatRealtimeClient implements ChatRealtimeClient {
  final String baseUrl;
  final String? Function() accessTokenProvider;
  final ChatSocketConnector _connector;
  final Duration initialReconnectDelay;

  final _eventController = StreamController<ChatRealtimeEvent>.broadcast();
  final _stateController =
      StreamController<ChatRealtimeConnectionState>.broadcast();
  final Set<String> _subscribedConversations = <String>{};
  final Set<String> _sentSubscribesOnSocket = <String>{};
  final Set<String> _seenEventIds = <String>{};

  ChatRealtimeSocket? _socket;
  StreamSubscription<dynamic>? _socketSubscription;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  ChatRealtimeConnectionState _state = ChatRealtimeConnectionState.disconnected;
  bool _shouldStayConnected = false;
  bool _disposed = false;
  int _reconnectAttempts = 0;

  WebSocketChatRealtimeClient({
    required this.baseUrl,
    required this.accessTokenProvider,
    ChatSocketConnector? connector,
    this.initialReconnectDelay = const Duration(milliseconds: 800),
  }) : _connector = connector ?? _defaultConnector;

  static Future<ChatRealtimeSocket> _defaultConnector(
    String url,
    Map<String, dynamic> headers,
  ) async {
    final ws = await WebSocket.connect(url, headers: headers);
    return IoChatRealtimeSocket(ws);
  }

  @override
  Stream<ChatRealtimeEvent> get events => _eventController.stream;

  @override
  Stream<ChatRealtimeConnectionState> get connectionStates =>
      _stateController.stream;

  @override
  ChatRealtimeConnectionState get currentState => _state;

  @override
  Set<String> get subscribedConversationIds =>
      Set.unmodifiable(_subscribedConversations);

  @override
  Future<void> connect() async {
    if (_disposed) return;
    _shouldStayConnected = true;
    if (_state == ChatRealtimeConnectionState.connected ||
        _state == ChatRealtimeConnectionState.connecting) {
      return;
    }
    await _openSocket(reconnecting: _reconnectAttempts > 0);
  }

  Future<void> _openSocket({required bool reconnecting}) async {
    if (_disposed || !_shouldStayConnected) return;
    final token = accessTokenProvider()?.trim();
    if (token == null || token.isEmpty) {
      _setState(ChatRealtimeConnectionState.disconnected);
      return;
    }

    _setState(
      reconnecting
          ? ChatRealtimeConnectionState.reconnecting
          : ChatRealtimeConnectionState.connecting,
    );

    final wsUrl = _buildWebSocketUrl(baseUrl, token);
    try {
      final socket = await _connector(wsUrl, {
        'Authorization': 'Bearer $token',
      });
      if (_disposed || !_shouldStayConnected) {
        await socket.close();
        return;
      }
      _socket = socket;
      _reconnectAttempts = 0;
      _sentSubscribesOnSocket.clear();
      _setState(ChatRealtimeConnectionState.connected);

      _socketSubscription?.cancel();
      _socketSubscription = socket.stream.listen(
        _onRawFrame,
        onError: (_) => _handleSocketClosed(),
        onDone: _handleSocketClosed,
        cancelOnError: true,
      );

      for (final conversationId in _subscribedConversations) {
        _sendSubscribeFrame(conversationId);
      }

      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(
        const Duration(seconds: 25),
        (_) => _sendJson({'type': 'PING'}),
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  static String _buildWebSocketUrl(String rawBaseUrl, String token) {
    final trimmed = rawBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final wsBase = trimmed.startsWith('https://')
        ? 'wss://${trimmed.substring(8)}'
        : trimmed.startsWith('http://')
        ? 'ws://${trimmed.substring(7)}'
        : trimmed;
    final encodedToken = Uri.encodeQueryComponent(token);
    return '$wsBase/ws?access_token=$encodedToken';
  }

  void _onRawFrame(dynamic data) {
    if (data is! String || data.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(data);
      if (decoded is! Map) return;
      final event = ChatRealtimeEvent.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      if (event.eventId != null) {
        if (!_seenEventIds.add(event.eventId!)) return;
        if (_seenEventIds.length > 2000) {
          _seenEventIds.clear();
          _seenEventIds.add(event.eventId!);
        }
      }
      if (!_eventController.isClosed) {
        _eventController.add(event);
      }
    } catch (_) {
      // Ignore malformed frames without crashing or exposing raw technical text
    }
  }

  void _handleSocketClosed() {
    _heartbeatTimer?.cancel();
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _socket = null;
    _sentSubscribesOnSocket.clear();
    if (_disposed || !_shouldStayConnected) {
      _setState(ChatRealtimeConnectionState.disconnected);
      return;
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || !_shouldStayConnected) return;
    _setState(ChatRealtimeConnectionState.reconnecting);
    _reconnectTimer?.cancel();
    final multiplier = 1 << (_reconnectAttempts.clamp(0, 4));
    _reconnectAttempts++;
    final delay = Duration(
      milliseconds: (initialReconnectDelay.inMilliseconds * multiplier).clamp(
        200,
        10000,
      ),
    );
    _reconnectTimer = Timer(delay, () {
      if (!_disposed && _shouldStayConnected) {
        _openSocket(reconnecting: true);
      }
    });
  }

  @override
  void subscribeConversation(String conversationId) {
    if (conversationId.trim().isEmpty) return;
    _subscribedConversations.add(conversationId);
    if (_state != ChatRealtimeConnectionState.connected &&
        _state != ChatRealtimeConnectionState.connecting) {
      unawaited(connect());
      return;
    }
    if (_state == ChatRealtimeConnectionState.connected) {
      _sendSubscribeFrame(conversationId);
    }
  }

  void _sendSubscribeFrame(String conversationId) {
    if (_sentSubscribesOnSocket.add(conversationId)) {
      _sendJson({'type': 'SUBSCRIBE', 'conversationId': conversationId});
    }
  }

  @override
  void unsubscribeConversation(String conversationId) {
    _subscribedConversations.remove(conversationId);
    _sentSubscribesOnSocket.remove(conversationId);
    if (_state == ChatRealtimeConnectionState.connected) {
      _sendJson({'type': 'UNSUBSCRIBE', 'conversationId': conversationId});
    }
  }

  @override
  void sendTypingStart(String conversationId) {
    if (_state == ChatRealtimeConnectionState.connected) {
      _sendJson({'type': 'TYPING_START', 'conversationId': conversationId});
    }
  }

  @override
  void sendTypingStop(String conversationId) {
    if (_state == ChatRealtimeConnectionState.connected) {
      _sendJson({'type': 'TYPING_STOP', 'conversationId': conversationId});
    }
  }

  @override
  void sendMarkRead(String conversationId, int lastReadSequence) {
    if (_state == ChatRealtimeConnectionState.connected) {
      _sendJson({
        'type': 'MARK_READ',
        'conversationId': conversationId,
        'lastReadSequence': lastReadSequence,
      });
    }
  }

  void _sendJson(Map<String, dynamic> frame) {
    final socket = _socket;
    if (socket == null || _state != ChatRealtimeConnectionState.connected) {
      return;
    }
    try {
      socket.add(jsonEncode(frame));
    } catch (_) {}
  }

  @override
  Future<void> disconnect() async {
    _shouldStayConnected = false;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    final socket = _socket;
    _socket = null;
    _sentSubscribesOnSocket.clear();
    if (socket != null) {
      try {
        await socket.close();
      } catch (_) {}
    }
    _setState(ChatRealtimeConnectionState.disconnected);
  }

  void _setState(ChatRealtimeConnectionState next) {
    if (_state == next) return;
    _state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(disconnect());
    _eventController.close();
    _stateController.close();
  }
}
