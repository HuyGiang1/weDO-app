import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_colors.dart';
import '../../groups/presentation/widgets/group_widgets.dart';
import '../../social/presentation/widgets/user_avatar.dart';
import '../data/chat_models.dart';
import '../data/chat_realtime_event.dart';
import '../data/chat_repository.dart';
import 'chat_formatters.dart';
import 'message_reaction_details_sheet.dart';

const _quickReactions = ['👍', '❤️', '😂', '😮', '😢', '😡'];

class ChatScreen extends StatefulWidget {
  final String? groupId;
  final ChatConversation? initialConversation;
  final ChatRepository repository;
  final VoidCallback? onOpenGroupInfo;
  const ChatScreen({
    super.key,
    required this.groupId,
    this.initialConversation,
    required this.repository,
    this.onOpenGroupInfo,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  ChatConversation? _conversation;
  List<ChatMessage> _messages = [];
  List<ChatReaderState> _readers = [];
  Object? _failure;
  bool _loading = true, _sending = false;
  bool _hasMore = false, _loadingEarlier = false;
  int? _nextBeforeSequence;

  String? _selectedMessageIdForTime;
  Timer? _selectedMessageTimeTimer;

  StreamSubscription<ChatRealtimeEvent>? _realtimeSubscription;
  final Set<String> _seenEventIds = <String>{};
  final Map<String, ChatUser> _typingUsers = <String, ChatUser>{};
  final Map<String, Timer> _typingTimers = <String, Timer>{};
  final Set<String> _onlineUserIds = <String>{};
  DateTime? _lastTypingSentAt;
  bool _wasConnectedOnce = false;

  @override
  void initState() {
    super.initState();
    _composer.addListener(_onComposerChanged);
    _realtimeSubscription = widget.repository.realtimeClient.events.listen(
      _onRealtimeEvent,
    );
    unawaited(widget.repository.realtimeClient.connect());
    _load();
  }

  @override
  void dispose() {
    final conversationId = _conversation?.id;
    if (conversationId != null) {
      widget.repository.realtimeClient.unsubscribeConversation(conversationId);
    }
    _selectedMessageTimeTimer?.cancel();
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    _realtimeSubscription?.cancel();
    _composer.removeListener(_onComposerChanged);
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onComposerChanged() {
    final conversation = _conversation;
    if (conversation == null || conversation.permissions.readOnly) return;
    final text = _composer.text.trim();
    if (text.isEmpty) {
      if (_lastTypingSentAt != null) {
        _lastTypingSentAt = null;
        widget.repository.realtimeClient.sendTypingStop(conversation.id);
      }
      return;
    }
    final now = DateTime.now();
    if (_lastTypingSentAt == null ||
        now.difference(_lastTypingSentAt!) >= const Duration(seconds: 2)) {
      _lastTypingSentAt = now;
      widget.repository.realtimeClient.sendTypingStart(conversation.id);
    }
  }

  void _toggleMessageTime(ChatMessage message) {
    _selectedMessageTimeTimer?.cancel();
    if (_selectedMessageIdForTime == message.id) {
      setState(() => _selectedMessageIdForTime = null);
      return;
    }
    setState(() => _selectedMessageIdForTime = message.id);
    _selectedMessageTimeTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && _selectedMessageIdForTime == message.id) {
        setState(() => _selectedMessageIdForTime = null);
      }
    });
  }

  String? _connectedOwnUserId;

  String? get _knownOwnUserId {
    if (_connectedOwnUserId != null) return _connectedOwnUserId;
    for (final message in _messages) {
      if (message.isMine && message.author != null) {
        return message.author!.id;
      }
    }
    return null;
  }

  void _onRealtimeEvent(ChatRealtimeEvent event) {
    if (!mounted) return;
    if (event.eventId != null && !_seenEventIds.add(event.eventId!)) {
      return;
    }
    if (event.type == ChatRealtimeEventType.connected) {
      if (event.actor?.id != null) {
        _connectedOwnUserId = event.actor!.id;
        _onlineUserIds.remove(_connectedOwnUserId);
      }
      final conversation = _conversation;
      if (conversation != null) {
        widget.repository.realtimeClient.subscribeConversation(conversation.id);
        if (_wasConnectedOnce) {
          unawaited(_load(silent: true));
        }
      }
      _wasConnectedOnce = true;
      return;
    }
    if (event.type == ChatRealtimeEventType.presenceUpdated) {
      final userId = event.presenceUser?.id;
      if (userId != null && userId != _knownOwnUserId) {
        setState(() {
          if (event.online == true) {
            _onlineUserIds.add(userId);
          } else {
            _onlineUserIds.remove(userId);
          }
        });
      }
      return;
    }

    final conversation = _conversation;
    if (conversation == null || event.conversationId != conversation.id) {
      return;
    }

    switch (event.type) {
      case ChatRealtimeEventType.subscribed:
        setState(() {
          _onlineUserIds
            ..clear()
            ..addAll(
              event.onlineUserIds.where((id) => id != _knownOwnUserId),
            );
        });
        break;

      case ChatRealtimeEventType.messageCreated:
        final incoming = event.message;
        if (incoming == null) return;
        final authorId = incoming.author?.id;
        if (authorId != null) {
          _typingTimers.remove(authorId)?.cancel();
          _typingUsers.remove(authorId);
        }
        final ownUserId = _knownOwnUserId;
        final isOwn =
            incoming.isMine || (ownUserId != null && authorId == ownUserId);
        final normalized = _copyMessageForViewer(incoming, isOwn: isOwn);
        final existingIndex = _messages.indexWhere(
          (m) => m.id == normalized.id || m.sequence == normalized.sequence,
        );
        setState(() {
          if (existingIndex >= 0) {
            _messages[existingIndex] = _mergeMessage(
              _messages[existingIndex],
              normalized,
            );
          } else {
            final updated = [..._messages, normalized]
              ..sort((a, b) => a.sequence.compareTo(b.sequence));
            _messages = updated;
          }
        });
        if (!isOwn) {
          unawaited(
            widget.repository.markRead(conversation.id, normalized.sequence),
          );
        }
        break;

      case ChatRealtimeEventType.messageEdited:
      case ChatRealtimeEventType.messageUnsent:
      case ChatRealtimeEventType.messageReactionUpdated:
        final updated = event.message;
        if (updated == null) return;
        setState(() {
          final index = _messages.indexWhere((m) => m.id == updated.id);
          if (index >= 0) {
            _messages[index] = _mergeMessage(_messages[index], updated);
          }
        });
        break;

      case ChatRealtimeEventType.readStateUpdated:
        final readerUser = event.reader;
        final lastReadSeq = event.lastReadSequence;
        if (readerUser == null || lastReadSeq == null) return;
        if (readerUser.userId == _knownOwnUserId) return;
        setState(() {
          final nextReaders = [..._readers];
          final existingIdx = nextReaders.indexWhere(
            (r) => r.userId == readerUser.userId,
          );
          if (existingIdx >= 0) {
            if (lastReadSeq >= nextReaders[existingIdx].lastReadSequence) {
              nextReaders[existingIdx] = ChatReaderState(
                userId: readerUser.userId,
                displayName: readerUser.displayName,
                avatarStorageKey: readerUser.avatarStorageKey,
                lastReadSequence: lastReadSeq,
              );
            }
          } else {
            nextReaders.add(
              ChatReaderState(
                userId: readerUser.userId,
                displayName: readerUser.displayName,
                avatarStorageKey: readerUser.avatarStorageKey,
                lastReadSequence: lastReadSeq,
              ),
            );
          }
          _readers = nextReaders;
        });
        break;

      case ChatRealtimeEventType.typingUpdated:
        final typer = event.typingUser;
        if (typer == null || typer.id == _knownOwnUserId) return;
        _typingTimers.remove(typer.id)?.cancel();
        if (event.typing == true) {
          setState(() => _typingUsers[typer.id] = typer);
          _typingTimers[typer.id] = Timer(const Duration(seconds: 6), () {
            if (mounted) {
              setState(() {
                _typingTimers.remove(typer.id);
                _typingUsers.remove(typer.id);
              });
            }
          });
        } else {
          setState(() => _typingUsers.remove(typer.id));
        }
        break;

      default:
        break;
    }
  }

  ChatMessage _copyMessageForViewer(ChatMessage msg, {required bool isOwn}) {
    if (msg.isMine == isOwn) return msg;
    return ChatMessage(
      id: msg.id,
      sequence: msg.sequence,
      status: msg.status,
      content: msg.content,
      replyToMessageId: msg.replyToMessageId,
      myReaction: msg.myReaction,
      author: msg.author,
      isMine: isOwn,
      createdAt: msg.createdAt,
      editedAt: msg.editedAt,
      unsentAt: msg.unsentAt,
      reactions: msg.reactions,
      permissions: msg.permissions,
    );
  }

  ChatMessage _mergeMessage(ChatMessage existing, ChatMessage incoming) {
    final isOwn = existing.isMine || incoming.isMine;
    final withdrawn = incoming.status == 'UNSENT';
    return ChatMessage(
      id: incoming.id,
      sequence: incoming.sequence,
      status: incoming.status,
      content: incoming.content,
      replyToMessageId: incoming.replyToMessageId,
      myReaction: incoming.myReaction ?? existing.myReaction,
      author: incoming.author ?? existing.author,
      isMine: isOwn,
      createdAt: incoming.createdAt,
      editedAt: incoming.editedAt,
      unsentAt: incoming.unsentAt,
      reactions: incoming.reactions,
      permissions: withdrawn
          ? const ChatPermissions(
              canSend: true,
              canEdit: false,
              canUnsend: false,
              canDeleteForMe: true,
              canReact: false,
              canPin: false,
              readOnly: false,
            )
          : existing.permissions,
    );
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }
    try {
      final conversation =
          widget.initialConversation ??
          _conversation ??
          await widget.repository.openGroup(widget.groupId!);
      widget.repository.realtimeClient.subscribeConversation(conversation.id);
      final page = await widget.repository.history(conversation.id);
      if (!mounted) return;
      setState(() {
        _conversation = conversation;
        _messages = page.messages;
        _readers = page.readers;
        _hasMore = page.hasMore;
        _nextBeforeSequence = page.nextBeforeSequence;
        _failure = null;
      });
      if (page.messages.isNotEmpty) {
        await widget.repository.markRead(
          conversation.id,
          page.messages.last.sequence,
        );
      }
    } catch (error) {
      if (mounted && !silent) setState(() => _failure = error);
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _loadEarlier() async {
    final conversation = _conversation;
    final cursor = _nextBeforeSequence;
    if (conversation == null || cursor == null || _loadingEarlier) return;
    setState(() => _loadingEarlier = true);
    try {
      final page = await widget.repository.history(
        conversation.id,
        beforeSequence: cursor,
      );
      if (!mounted) return;
      setState(() {
        _messages = [...page.messages, ..._messages];
        _readers = page.readers;
        _hasMore = page.hasMore;
        _nextBeforeSequence = page.nextBeforeSequence;
      });
    } catch (error) {
      if (mounted) _notice(widget.repository.failureMessage(error));
    } finally {
      if (mounted) setState(() => _loadingEarlier = false);
    }
  }

  Future<void> _send() async {
    final conversation = _conversation;
    final text = _composer.text.trim();
    if (conversation == null || text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      _lastTypingSentAt = null;
      widget.repository.realtimeClient.sendTypingStop(conversation.id);
      final message = await widget.repository.send(conversation.id, text);
      if (!mounted) return;
      _composer.clear();
      setState(() {
        final existingIdx = _messages.indexWhere((m) => m.id == message.id);
        if (existingIdx >= 0) {
          _messages[existingIdx] = message;
        } else {
          _messages = [..._messages, message]
            ..sort((a, b) => a.sequence.compareTo(b.sequence));
        }
      });
      await widget.repository.markRead(conversation.id, message.sequence);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (error) {
      if (mounted) _notice(widget.repository.failureMessage(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showMessageActions(ChatMessage message) {
    if (message.status != 'ACTIVE') return;
    final actions = <(String, String)>[];
    if (message.content?.isNotEmpty == true) actions.add(('copy', 'Sao chép'));
    if (message.permissions.canEdit) actions.add(('edit', 'Chỉnh sửa'));
    if (message.permissions.canUnsend) {
      actions.add(('unsend', 'Thu hồi tin nhắn'));
    }
    if (message.permissions.canDeleteForMe) {
      actions.add(('delete', 'Xóa tin nhắn'));
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.permissions.canReact) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: _quickReactions
                      .map(
                        (emoji) => Semantics(
                          button: true,
                          label: 'Thả cảm xúc $emoji',
                          child: InkResponse(
                            radius: 25,
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _messageAction(message, 'react:$emoji');
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 26),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const Divider(height: 16),
              ],
              for (final (action, label) in actions)
                ListTile(
                  leading: Icon(_actionIcon(action)),
                  title: Text(label),
                  dense: true,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _messageAction(message, action);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _actionIcon(String action) => switch (action) {
    'copy' => Icons.copy_outlined,
    'edit' => Icons.edit_outlined,
    'unsend' => Icons.undo,
    _ => Icons.delete_outline,
  };

  Future<void> _messageAction(ChatMessage message, String action) async {
    try {
      if (action == 'copy') {
        await Clipboard.setData(ClipboardData(text: message.content ?? ''));
        return;
      }
      if (action == 'edit') {
        final content = await showDialog<String>(
          context: context,
          builder: (context) {
            final controller = TextEditingController(text: message.content);
            return AlertDialog(
              title: const Text('Chỉnh sửa tin nhắn'),
              content: TextField(controller: controller, maxLines: 4),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, controller.text),
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
        if (content == null || content.trim().isEmpty) return;
        final updated = await widget.repository.edit(
          message.id,
          content.trim(),
        );
        _replaceMessage(updated);
        return;
      }
      if (action == 'delete') {
        await widget.repository.deleteForMe(message.id);
        if (mounted) {
          setState(() => _messages.removeWhere((m) => m.id == message.id));
        }
        return;
      }
      if (action == 'unsend') {
        final withdrawn = await widget.repository.unsend(message.id);
        _replaceMessage(withdrawn);
        return;
      }
      if (action.startsWith('react:')) {
        final updated = await widget.repository.react(
          message.id,
          action.substring('react:'.length),
        );
        _replaceMessage(updated);
      }
    } catch (error) {
      if (mounted) _notice(widget.repository.failureMessage(error));
    }
  }

  void _replaceMessage(ChatMessage updated) {
    if (!mounted) return;
    setState(() {
      final index = _messages.indexWhere((message) => message.id == updated.id);
      if (index >= 0) _messages[index] = updated;
    });
  }

  List<ChatReaderState> _readersBelow(int index) {
    final message = _messages[index];
    return _readers.where((reader) {
      if (reader.lastReadSequence < message.sequence) return false;
      return !_messages
          .skip(index + 1)
          .any((later) => later.sequence <= reader.lastReadSequence);
    }).toList();
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  bool get _isPeerOnline {
    final peerId = _conversation?.peer?.id;
    if (peerId != null && _onlineUserIds.contains(peerId)) {
      return true;
    }
    return _onlineUserIds.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final title = _conversation?.title?.trim().isNotEmpty == true
        ? _conversation!.title!
        : _conversation?.peer?.displayName ?? 'Trò chuyện';
    final isGroup = _conversation?.type == 'GROUP';
    final showOnline = _isPeerOnline;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: isGroup
            ? InkWell(
                key: const ValueKey('chat-group-header'),
                borderRadius: BorderRadius.circular(24),
                onTap: widget.onOpenGroupInfo,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GroupAvatar(
                      name: title,
                      avatarStorageKey: _conversation?.avatarStorageKey,
                      radius: 17,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (showOnline)
                            Row(
                              key: const ValueKey('chat-presence-online'),
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: Color(0xFF22C55E),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Đang hoạt động',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (showOnline)
                    Row(
                      key: const ValueKey('chat-presence-online'),
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.circle, size: 8, color: Color(0xFF22C55E)),
                        SizedBox(width: 4),
                        Text(
                          'Đang hoạt động',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
        backgroundColor: AppColors.background,
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            tooltip: 'Tải lại tin nhắn',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading && _conversation == null
                ? const Center(child: CircularProgressIndicator())
                : _failure != null && _conversation == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Không thể tải cuộc trò chuyện.'),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  )
                : _messages.isEmpty
                ? const Center(child: Text('Chưa có tin nhắn'))
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: _messages.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_hasMore && index == 0) {
                        return Center(
                          child: TextButton(
                            onPressed: _loadingEarlier ? null : _loadEarlier,
                            child: Text(
                              _loadingEarlier
                                  ? 'Đang tải…'
                                  : 'Tin nhắn trước đó',
                            ),
                          ),
                        );
                      }
                      final messageIndex = index - (_hasMore ? 1 : 0);
                      final message = _messages[messageIndex];
                      final previous = messageIndex > 0
                          ? _messages[messageIndex - 1]
                          : null;
                      final showSeparator = shouldShowChatTimeSeparator(
                        previous?.createdAt,
                        message.createdAt,
                      );
                      final sameAuthorRun =
                          !showSeparator &&
                          previous != null &&
                          previous.status != 'UNSENT' &&
                          previous.isMine == message.isMine &&
                          previous.author != null &&
                          message.author != null &&
                          previous.author!.id == message.author!.id;
                      return Column(
                        key: ValueKey('chat-item-${message.id}'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showSeparator)
                            _ChatTimeSeparator(
                              key: ValueKey(
                                'chat-time-separator-${message.id}',
                              ),
                              timestamp: message.createdAt,
                            ),
                          _MessageTile(
                            key: ValueKey(message.id),
                            message: message,
                            showAuthor:
                                !message.isMine &&
                                message.status != 'UNSENT' &&
                                !sameAuthorRun,
                            showTapTime:
                                _selectedMessageIdForTime == message.id,
                            readers: _readersBelow(messageIndex),
                            onTapBubble: () => _toggleMessageTime(message),
                            onOpenActions: () => _showMessageActions(message),
                            onOpenReactions: () {
                              if (message.status != 'ACTIVE') return;
                              showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                showDragHandle: true,
                                backgroundColor:
                                    AppColors.surfaceContainerLowest,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(24),
                                  ),
                                ),
                                builder: (_) => MessageReactionDetailsSheet(
                                  messageId: message.id,
                                  repository: widget.repository,
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
          ),
          if (_typingUsers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_typingUsers.values.map((u) => u.displayName).join(', ')} đang nhập...',
                  key: const ValueKey('chat-typing-indicator'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          if (_conversation?.permissions.readOnly == true)
            const SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('Nhóm đã lưu trữ. Tin nhắn chỉ xem được.'),
              ),
            )
          else
            Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                8,
                12,
                MediaQuery.paddingOf(context).bottom + 8,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _composer,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Tin nhắn',
                        filled: true,
                        fillColor: AppColors.surfaceContainerLowest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox.square(
                    dimension: 48,
                    child: IconButton.filled(
                      tooltip: 'Gửi tin nhắn',
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ChatTimeSeparator extends StatelessWidget {
  final DateTime timestamp;

  const _ChatTimeSeparator({super.key, required this.timestamp});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          chatSeparatorLabel(timestamp),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
    ),
  );
}

class _MessageTile extends StatelessWidget {
  final ChatMessage message;
  final bool showAuthor;
  final bool showTapTime;
  final List<ChatReaderState> readers;
  final VoidCallback onTapBubble;
  final VoidCallback onOpenActions;
  final VoidCallback onOpenReactions;

  const _MessageTile({
    super.key,
    required this.message,
    required this.showAuthor,
    required this.showTapTime,
    required this.readers,
    required this.onTapBubble,
    required this.onOpenActions,
    required this.onOpenReactions,
  });

  @override
  Widget build(BuildContext context) {
    final own = message.isMine;
    final withdrawn = message.status == 'UNSENT';
    final name = message.author?.displayName.trim().isNotEmpty == true
        ? message.author!.displayName
        : 'Người dùng';
    final reactionBadge = !withdrawn && message.reactions.isNotEmpty;
    final visibleReactions = message.reactions.take(2).toList();
    final reactionCount = message.reactions.fold<int>(
      0,
      (total, reaction) => total + reaction.count,
    );
    final reactionSummarySpans = <InlineSpan>[
      for (var index = 0; index < visibleReactions.length; index++) ...[
        if (index > 0) const TextSpan(text: ' '),
        TextSpan(
          text: visibleReactions[index].emoji,
          style: const TextStyle(fontSize: 14, height: 1),
        ),
      ],
      TextSpan(
        text: ' $reactionCount',
        style: const TextStyle(fontSize: 11, height: 1),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!withdrawn && showTapTime)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Center(
              child: Text(
                chatTime(message.createdAt),
                key: ValueKey('chat-tap-timestamp-${message.id}'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        Align(
          key: ValueKey('chat-message-align-${message.id}'),
          alignment: own ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.82,
            ),
            child: Padding(
              padding: EdgeInsets.only(bottom: readers.isEmpty ? 10 : 14),
              child: Column(
                crossAxisAlignment: own
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!own) ...[
                        SizedBox.square(
                          dimension: 32,
                          child: showAuthor && !withdrawn
                              ? UserAvatar(
                                  key: ValueKey(
                                    'chat-message-avatar-${message.id}',
                                  ),
                                  displayName: name,
                                  avatarStorageKey:
                                      message.author?.avatarStorageKey,
                                  radius: 16,
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Column(
                          crossAxisAlignment: own
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            if (showAuthor)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 3,
                                  left: 4,
                                  right: 4,
                                ),
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            GestureDetector(
                              onTap: withdrawn ? null : onTapBubble,
                              onLongPress: withdrawn ? null : onOpenActions,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  // Reserve the hanging badge inside the hit-test bounds.
                                  Padding(
                                    padding: EdgeInsets.only(
                                      right: reactionBadge ? 2 : 0,
                                      bottom: reactionBadge ? 12 : 0,
                                    ),
                                    child: Container(
                                      key: ValueKey(
                                        'chat-message-bubble-${message.id}',
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: withdrawn
                                            ? AppColors.surfaceContainerHigh
                                            : own
                                            ? AppColors.primary
                                            : AppColors.surfaceContainerLowest,
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Text(
                                        withdrawn
                                            ? 'Tin nhắn đã được thu hồi'
                                            : message.content ?? '',
                                        style: TextStyle(
                                          color: own && !withdrawn
                                              ? Colors.white
                                              : AppColors.onSurface,
                                          fontStyle: withdrawn
                                              ? FontStyle.italic
                                              : FontStyle.normal,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (reactionBadge)
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Semantics(
                                        button: true,
                                        label: 'Xem biểu cảm',
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: onOpenReactions,
                                          child: Container(
                                            key: ValueKey(
                                              'chat-reaction-badge-${message.id}',
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 5,
                                            ),
                                            constraints: const BoxConstraints(
                                              minHeight: 18,
                                              maxHeight: 20,
                                              maxWidth: 108,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors
                                                  .surfaceContainerLowest,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: AppColors.outlineVariant,
                                              ),
                                            ),
                                            child: Text.rich(
                                              TextSpan(
                                                children: reactionSummarySpans,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!withdrawn && readers.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(
                        top: reactionBadge ? 5 : 3,
                        right: 0,
                        left: own ? 0 : 40,
                      ),
                      child: _ReaderStack(
                        key: ValueKey('chat-readers-${message.id}'),
                        readers: readers,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReaderStack extends StatelessWidget {
  final List<ChatReaderState> readers;
  const _ReaderStack({super.key, required this.readers});

  @override
  Widget build(BuildContext context) {
    final visible = readers.take(3).toList();
    final extra = readers.length - visible.length;
    return SizedBox(
      height: 18,
      width: 18 + (visible.length - 1) * 13 + (extra > 0 ? 22 : 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: i * 13,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.background, width: 1.5),
                ),
                child: UserAvatar(
                  key: ValueKey('reader-${visible[i].userId}'),
                  displayName: visible[i].displayName,
                  avatarStorageKey: visible[i].avatarStorageKey,
                  radius: 8,
                ),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: visible.length * 13,
              child: Text('+$extra', style: const TextStyle(fontSize: 11)),
            ),
        ],
      ),
    );
  }
}
