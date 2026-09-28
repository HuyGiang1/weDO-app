import 'package:flutter/material.dart';

import '../../social/presentation/widgets/user_avatar.dart';
import '../data/chat_models.dart';
import '../data/chat_repository.dart';

class MessageReactionDetailsSheet extends StatefulWidget {
  final String messageId;
  final ChatRepository repository;

  const MessageReactionDetailsSheet({
    super.key,
    required this.messageId,
    required this.repository,
  });

  @override
  State<MessageReactionDetailsSheet> createState() =>
      _MessageReactionDetailsSheetState();
}

class _MessageReactionDetailsSheetState
    extends State<MessageReactionDetailsSheet> {
  late Future<List<ChatReactionDetail>> _details;
  String? _filter;

  @override
  void initState() {
    super.initState();
    _details = widget.repository.reactionDetails(widget.messageId);
  }

  void _reload() {
    setState(() {
      _filter = null;
      _details = widget.repository.reactionDetails(widget.messageId);
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.6,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Biểu cảm',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Tải lại biểu cảm',
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<ChatReactionDetail>>(
              future: _details,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            widget.repository.failureMessage(snapshot.error!),
                          ),
                        ),
                        TextButton(
                          onPressed: _reload,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  );
                }
                final details = snapshot.data ?? const <ChatReactionDetail>[];
                final counts = <String, int>{};
                for (final detail in details) {
                  counts.update(
                    detail.emoji,
                    (count) => count + 1,
                    ifAbsent: () => 1,
                  );
                }
                final visible = details
                    .where(
                      (detail) => _filter == null || detail.emoji == _filter,
                    )
                    .toList();
                return Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          _chip(null, 'Tất cả ${details.length}'),
                          for (final emoji in [
                            '👍',
                            '❤️',
                            '😂',
                            '😮',
                            '😢',
                            '😡',
                          ])
                            if (counts.containsKey(emoji))
                              _chip(emoji, '$emoji ${counts[emoji]}'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: visible.isEmpty
                          ? const Center(child: Text('Chưa có biểu cảm'))
                          : ListView.builder(
                              itemCount: visible.length,
                              itemBuilder: (context, index) {
                                final detail = visible[index];
                                return ListTile(
                                  key: ValueKey('reactor-${detail.userId}'),
                                  leading: UserAvatar(
                                    displayName: detail.displayName,
                                    avatarStorageKey: detail.avatarUrl,
                                    radius: 20,
                                  ),
                                  title: Text(
                                    detail.displayName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Text(
                                    detail.emoji,
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );

  Widget _chip(String? emoji, String label) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _filter == emoji,
      onSelected: (_) => setState(() => _filter = emoji),
    ),
  );
}
