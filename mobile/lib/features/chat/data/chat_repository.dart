import 'dart:typed_data';

import '../../../core/network/api_exception.dart';
import '../../media/data/media_upload_service.dart';
import 'chat_api.dart';
import 'chat_models.dart';
import 'chat_realtime_client.dart';

class ChatRepository {
  static ChatRealtimeClient defaultRealtimeClient =
      const NoopChatRealtimeClient();
  static MediaUploadService? defaultMediaUploadService;

  final ChatApi api;
  final ChatRealtimeClient realtimeClient;
  final MediaUploadService? mediaUploadService;
  ChatRepository(
    this.api, {
    ChatRealtimeClient? realtimeClient,
    MediaUploadService? mediaUploadService,
  }) : realtimeClient = realtimeClient ?? defaultRealtimeClient,
       mediaUploadService = mediaUploadService ?? defaultMediaUploadService;
  Future<ChatConversation> openGroup(String id) => api.openGroup(id);
  Future<ChatDirectOpen> openDirect(String userId) => api.openDirect(userId);
  Future<List<ChatMessageRequest>> messageRequests() => api.messageRequests();
  Future<void> acceptRequest(String id) => api.acceptRequest(id);
  Future<void> declineRequest(String id) => api.declineRequest(id);
  Future<List<ChatConversation>> conversations() => api.conversations();
  Future<ChatMessagePage> history(
    String id, {
    int? beforeSequence,
    int limit = 30,
  }) => api.history(id, beforeSequence: beforeSequence, limit: limit);
  Future<ChatMessage> send(
    String id,
    String content, {
    String? clientMessageId,
    List<String> attachmentStorageKeys = const [],
  }) => api.send(
    id,
    content,
    clientMessageId: clientMessageId,
    attachmentStorageKeys: attachmentStorageKeys,
  );
  Future<String> uploadChatImage({
    required String conversationId,
    required String fileName,
    required String contentType,
    required Uint8List bytes,
  }) {
    final service = mediaUploadService;
    if (service == null) throw StateError('Media upload is unavailable');
    return service.uploadImage(
      category: 'CHAT_IMAGE',
      contextId: conversationId,
      fileName: fileName,
      contentType: contentType,
      bytes: bytes,
    );
  }

  Future<ChatMessage> edit(String id, String content) => api.edit(id, content);
  Future<ChatMessage> unsend(String id) => api.unsend(id);
  Future<void> deleteForMe(String id) => api.deleteForMe(id);
  Future<ChatMessage> react(String id, String emoji) => api.react(id, emoji);
  Future<List<ChatReactionDetail>> reactionDetails(String id) =>
      api.reactionDetails(id);
  Future<void> markRead(String id, int sequence) => api.markRead(id, sequence);
  Future<void> pin(String id) => api.pin(id);
  Future<void> unpin(String id) => api.unpin(id);
  Future<List<ChatMessage>> pins(String id) => api.pins(id);
  Future<List<ChatMessage>> search(String id, String query) =>
      api.search(id, query);
  String failureMessage(Object error) {
    if (error is ApiException) {
      return switch (error.code) {
        'GROUP_ARCHIVED' => 'Nhóm đã lưu trữ. Bạn chỉ có thể xem tin nhắn.',
        'ACCESS_DENIED' ||
        'USER_BLOCKED' => 'Bạn không thể thực hiện thao tác này.',
        'RESOURCE_NOT_FOUND' ||
        'GROUP_NOT_FOUND' => 'Không tìm thấy cuộc trò chuyện.',
        _ => 'Không thể tải cuộc trò chuyện. Vui lòng thử lại.',
      };
    }
    return 'Không thể kết nối. Vui lòng thử lại.';
  }
}
