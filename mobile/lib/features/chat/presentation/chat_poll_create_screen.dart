import 'package:flutter/material.dart';

import 'dart:math';

import '../../../core/realtime/reliable_read.dart';
import '../../activity/data/activity_api.dart';
import '../../activity/data/activity_models.dart';
import '../../poll/data/poll_api.dart';
import '../../poll/data/poll_repository.dart';
import '../../poll/presentation/screens/poll_screens.dart';
import '../data/chat_api.dart';
import '../data/chat_models.dart';

/// Group ownership is canonical; linking an existing Activity is optional.
class ChatPollCreateScreen extends StatefulWidget {
  final String conversationId, groupId;
  final ChatApi api;
  const ChatPollCreateScreen({
    super.key,
    required this.conversationId,
    required this.groupId,
    required this.api,
  });
  @override
  State<ChatPollCreateScreen> createState() => _ChatPollCreateScreenState();
}

class _ChatPollCreateScreenState extends State<ChatPollCreateScreen> {
  final _read = ReliableRead<List<ActivitySummary>>();
  bool _selecting = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() => _read.load(() async {
    final api = ActivityApi(widget.api.dio);
    final activities = <ActivitySummary>[];
    var page = 0;
    while (true) {
      final result = await api.list(widget.groupId, page: page++);
      activities.addAll(result.items);
      if (!result.hasNext) break;
    }
    return activities
        .where(
          (a) =>
              a.status != ActivityStatus.completed &&
              a.status != ActivityStatus.cancelled,
        )
        .toList();
  });
  @override
  void dispose() {
    _read.dispose();
    super.dispose();
  }

  Future<void> _select(ActivitySummary? activity) async {
    if (_selecting) return;
    _selecting = true;
    final bytes = List.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final id =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    // One UUID per form; retry reuses it after an uncertain network response.
    ChatMessage? created;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreatePollScreen(
          activityId: activity?.id ?? '',
          repository: PollRepository(PollApi(widget.api.dio)),
          allowMultipleChoiceControl: true,
          onCreate: (draft) async {
            created = await widget.api.createPoll(
              widget.conversationId,
              activity?.id,
              id,
              draft.toJson(),
            );
          },
        ),
      ),
    );
    _selecting = false;
    if (mounted && created != null) Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tạo bình chọn trong nhóm')),
    body: Column(
      children: [
        ListTile(
          title: const Text('Chỉ trong nhóm'),
          subtitle: const Text('Không cần tạo hoặc chọn hoạt động'),
          onTap: () => _select(null),
        ),
        Expanded(
          child: ReliableReadBuilder<List<ActivitySummary>>(
            read: _read,
            onRetry: _load,
            builder: (context, snapshot) => !snapshot.hasData
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Hoặc liên kết một hoạt động có sẵn. Bình chọn vẫn dùng chung một lịch sử và kết quả.',
                        ),
                      ),
                      for (final activity in snapshot.requireData)
                        ListTile(
                          title: Text(activity.title),
                          onTap: () => _select(activity),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    ),
  );
}
