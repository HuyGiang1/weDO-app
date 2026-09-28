import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import 'chat_models.dart';

class ChatApi {
  final Dio dio;
  ChatApi(this.dio);

  Future<T> _object<T>(
    Future<Response<dynamic>> Function() call,
    T Function(Map<String, dynamic>) parse,
  ) async {
    try {
      final data = (await call()).data;
      if (data is! Map) throw const FormatException('Expected object response');
      return parse(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<T>> _list<T>(
    Future<Response<dynamic>> Function() call,
    T Function(Map<String, dynamic>) parse,
  ) async {
    try {
      final data = (await call()).data;
      if (data is! List) throw const FormatException('Expected list response');
      return data
          .map((e) => parse(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> _empty(Future<Response<dynamic>> Function() call) async {
    try {
      await call();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<ChatConversation> openGroup(String groupId) => _object(
    () =>
        dio.post('/api/v1/groups/${Uri.encodeComponent(groupId)}/conversation'),
    ChatConversation.fromJson,
  );
  Future<ChatDirectOpen> openDirect(String userId) async {
    try {
      final response = await dio.post(
        '/api/v1/direct-conversations',
        data: {'userId': userId},
      );
      final data = response.data;
      if (data is! Map || data['conversation'] is! Map) {
        throw const FormatException('Expected direct conversation response');
      }
      final json = Map<String, dynamic>.from(data);
      return ChatDirectOpen(
        ChatConversation.fromJson(
          Map<String, dynamic>.from(json['conversation'] as Map),
        ),
        json['accessStatus'] as String? ?? 'OPEN',
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<ChatMessageRequest>> messageRequests() => _list(
    () => dio.get('/api/v1/message-requests'),
    ChatMessageRequest.fromJson,
  );
  Future<void> acceptRequest(String id) => _empty(
    () =>
        dio.post('/api/v1/message-requests/${Uri.encodeComponent(id)}/accept'),
  );
  Future<void> declineRequest(String id) => _empty(
    () =>
        dio.post('/api/v1/message-requests/${Uri.encodeComponent(id)}/decline'),
  );

  Future<List<ChatConversation>> conversations() =>
      _list(() => dio.get('/api/v1/conversations'), ChatConversation.fromJson);
  Future<ChatMessagePage> history(
    String conversationId, {
    int? beforeSequence,
    int limit = 30,
  }) => _object(
    () => dio.get(
      '/api/v1/conversations/${Uri.encodeComponent(conversationId)}/messages',
      queryParameters: {'beforeSequence': beforeSequence, 'limit': limit},
    ),
    ChatMessagePage.fromJson,
  );
  Future<ChatMessage> send(
    String conversationId,
    String content, {
    String? replyToMessageId,
  }) => _object(
    () => dio.post(
      '/api/v1/conversations/${Uri.encodeComponent(conversationId)}/messages',
      data: {'content': content, 'replyToMessageId': replyToMessageId},
    ),
    ChatMessage.fromJson,
  );
  Future<ChatMessage> edit(String messageId, String content) => _object(
    () => dio.patch(
      '/api/v1/messages/${Uri.encodeComponent(messageId)}',
      data: {'content': content},
    ),
    ChatMessage.fromJson,
  );
  Future<ChatMessage> unsend(String messageId) => _object(
    () => dio.post('/api/v1/messages/${Uri.encodeComponent(messageId)}/unsend'),
    ChatMessage.fromJson,
  );
  Future<void> deleteForMe(String messageId) => _empty(
    () => dio.delete('/api/v1/messages/${Uri.encodeComponent(messageId)}/me'),
  );
  Future<ChatMessage> react(String messageId, String emoji) => _object(
    () => dio.put(
      '/api/v1/messages/${Uri.encodeComponent(messageId)}/reaction',
      data: {'emoji': emoji},
    ),
    ChatMessage.fromJson,
  );
  Future<List<ChatReactionDetail>> reactionDetails(String messageId) => _list(
    () =>
        dio.get('/api/v1/messages/${Uri.encodeComponent(messageId)}/reactions'),
    ChatReactionDetail.fromJson,
  );
  Future<void> markRead(String conversationId, int sequence) => _empty(
    () => dio.put(
      '/api/v1/conversations/${Uri.encodeComponent(conversationId)}/read-state',
      data: {'lastReadSequence': sequence},
    ),
  );

  Future<void> pin(String messageId) => _empty(
    () => dio.post('/api/v1/messages/${Uri.encodeComponent(messageId)}/pin'),
  );
  Future<void> unpin(String messageId) => _empty(
    () => dio.delete('/api/v1/messages/${Uri.encodeComponent(messageId)}/pin'),
  );
  Future<List<ChatMessage>> pins(String conversationId) => _list(
    () => dio.get(
      '/api/v1/conversations/${Uri.encodeComponent(conversationId)}/pins',
    ),
    ChatMessage.fromJson,
  );
  Future<List<ChatMessage>> search(
    String conversationId,
    String query,
  ) => _list(
    () => dio.get(
      '/api/v1/conversations/${Uri.encodeComponent(conversationId)}/messages/search',
      queryParameters: {'q': query},
    ),
    ChatMessage.fromJson,
  );
}
