import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../groups/presentation/widgets/group_widgets.dart';
import '../../social/presentation/widgets/user_avatar.dart';
import '../data/chat_models.dart';
import '../data/chat_realtime_event.dart';
import '../data/chat_repository.dart';
import 'chat_formatters.dart';

class ChatHomeScreen extends StatefulWidget {
  final ChatRepository repository;
  final VoidCallback onGroups;
  final VoidCallback? onCalendar;
  final VoidCallback? onProfile;
  final ValueChanged<ChatConversation> onOpenConversation;

  const ChatHomeScreen({
    super.key,
    required this.repository,
    required this.onGroups,
    this.onCalendar,
    this.onProfile,
    required this.onOpenConversation,
  });

  @override
  State<ChatHomeScreen> createState() => _ChatHomeScreenState();
}

class _ChatHomeScreenState extends State<ChatHomeScreen> {
  late Future<List<ChatConversation>> _conversations;
  StreamSubscription<ChatRealtimeEvent>? _realtimeSubscription;
  final Set<String> _onlineUserIds = <String>{};

  @override
  void initState() {
    super.initState();
    _conversations = widget.repository.conversations();
    unawaited(widget.repository.realtimeClient.connect());
    _realtimeSubscription = widget.repository.realtimeClient.events.listen(
      _onRealtimeEvent,
    );
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }

  void _onRealtimeEvent(ChatRealtimeEvent event) {
    if (!mounted) return;
    if (event.type == ChatRealtimeEventType.presenceUpdated) {
      final userId = event.presenceUser?.id;
      if (userId != null) {
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
    if (event.type == ChatRealtimeEventType.messageCreated ||
        event.type == ChatRealtimeEventType.messageEdited ||
        event.type == ChatRealtimeEventType.messageUnsent ||
        event.type == ChatRealtimeEventType.readStateUpdated ||
        event.type == ChatRealtimeEventType.connected) {
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    final request = widget.repository.conversations();
    setState(() => _conversations = request);
    await request;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Trò chuyện'),
      backgroundColor: AppColors.background,
      actions: [
        IconButton(
          tooltip: 'Tải lại cuộc trò chuyện',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    bottomNavigationBar: GroupsBottomNavigation(
      currentIndex: 2,
      onTap: (index) {
        if (index == 1) widget.onGroups();
        if (index == 3) widget.onCalendar?.call();
        if (index == 4) widget.onProfile?.call();
      },
    ),
    body: FutureBuilder<List<ChatConversation>>(
      future: _conversations,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Không thể tải cuộc trò chuyện.'),
                TextButton(onPressed: _refresh, child: const Text('Thử lại')),
              ],
            ),
          );
        }
        final conversations = snapshot.data ?? const <ChatConversation>[];
        if (conversations.isEmpty) {
          return const Center(child: Text('Chưa có cuộc trò chuyện'));
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            itemCount: conversations.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              final isGroup = conversation.type == 'GROUP';
              final name = isGroup
                  ? (conversation.title?.trim().isNotEmpty == true
                        ? conversation.title!
                        : 'Nhóm')
                  : (conversation.peer?.displayName ?? 'Người dùng');
              final avatarKey = isGroup
                  ? conversation.avatarStorageKey
                  : conversation.peer?.avatarStorageKey;
              final peerOnline =
                  !isGroup &&
                  conversation.peer != null &&
                  _onlineUserIds.contains(conversation.peer!.id);
              final preview = conversation.lastMessagePreview?.trim();
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 5,
                ),
                leading: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    isGroup
                        ? GroupAvatar(
                            name: name,
                            avatarStorageKey: avatarKey,
                            radius: 25,
                          )
                        : UserAvatar(
                            displayName: name,
                            avatarStorageKey: avatarKey,
                            radius: 25,
                          ),
                    if (peerOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          key: ValueKey('chat-home-online-${conversation.id}'),
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  preview == null || preview.isEmpty
                      ? 'Chưa có tin nhắn'
                      : preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: conversation.lastMessageAt == null
                    ? null
                    : Text(
                        chatListTime(conversation.lastMessageAt!),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                onTap: () => widget.onOpenConversation(conversation),
              );
            },
          ),
        );
      },
    ),
  );
}
