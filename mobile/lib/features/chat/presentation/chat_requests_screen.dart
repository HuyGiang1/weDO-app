import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../data/chat_models.dart';
import '../data/chat_repository.dart';

class ChatRequestsScreen extends StatefulWidget {
  final ChatRepository repository;
  final ValueChanged<String> onOpenDirect;
  const ChatRequestsScreen({
    super.key,
    required this.repository,
    required this.onOpenDirect,
  });
  @override
  State<ChatRequestsScreen> createState() => _ChatRequestsScreenState();
}

class _ChatRequestsScreenState extends State<ChatRequestsScreen> {
  bool _loading = true;
  Object? _error;
  List<ChatMessageRequest> _requests = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final requests = await widget.repository.messageRequests();
      if (!mounted) return;
      setState(() => _requests = requests);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resolve(String requestId, String senderId, bool accept) async {
    try {
      if (accept) {
        await widget.repository.acceptRequest(requestId);
        if (!mounted) return;
        widget.onOpenDirect(senderId);
      } else {
        await widget.repository.declineRequest(requestId);
      }
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.repository.failureMessage(error))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Lời mời trò chuyện'),
      backgroundColor: AppColors.background,
      actions: [
        IconButton(
          tooltip: 'Tải lại',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: TextButton(
              onPressed: _load,
              child: const Text('Không thể tải lời mời. Thử lại'),
            ),
          )
        : _requests.isEmpty
        ? const Center(child: Text('Chưa có lời mời trò chuyện'))
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _requests.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final request = _requests[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                leading: CircleAvatar(
                  child: Text(
                    request.sender.displayName.isEmpty
                        ? '?'
                        : request.sender.displayName.characters.first
                              .toUpperCase(),
                  ),
                ),
                title: Text(request.sender.displayName),
                subtitle: Text('${request.messageCount} tin nhắn'),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: 'Từ chối',
                      onPressed: () =>
                          _resolve(request.id, request.sender.id, false),
                      icon: const Icon(Icons.close),
                    ),
                    IconButton(
                      tooltip: 'Chấp nhận',
                      onPressed: () =>
                          _resolve(request.id, request.sender.id, true),
                      icon: const Icon(
                        Icons.check_circle_outline,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
  );
}
