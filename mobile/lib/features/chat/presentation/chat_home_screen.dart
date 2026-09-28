import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../groups/presentation/widgets/group_widgets.dart';
import '../../social/presentation/widgets/user_avatar.dart';
import '../data/chat_models.dart';
import '../data/chat_repository.dart';
import 'chat_formatters.dart';

class ChatHomeScreen extends StatefulWidget {
  final ChatRepository repository;
  final VoidCallback onGroups;
  final ValueChanged<ChatConversation> onOpenConversation;

  const ChatHomeScreen({
    super.key,
    required this.repository,
    required this.onGroups,
    required this.onOpenConversation,
  });

  @override
  State<ChatHomeScreen> createState() => _ChatHomeScreenState();
}

class _ChatHomeScreenState extends State<ChatHomeScreen> {
  late Future<List<ChatConversation>> _conversations;

  @override
  void initState() {
    super.initState();
    _conversations = widget.repository.conversations();
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
              final preview = conversation.lastMessagePreview?.trim();
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 5,
                ),
                leading: isGroup
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
