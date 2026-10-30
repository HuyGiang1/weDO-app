// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/realtime/realtime_binding.dart';

import '../../../../core/utils/date_time_formatter.dart';
import '../../../social/presentation/widgets/user_avatar.dart';
import '../../data/discussion_models.dart';
import '../../data/discussion_repository.dart';

class ActivityDiscussionSection extends StatefulWidget {
  final String activityId;
  final DiscussionRepository repository;
  const ActivityDiscussionSection({
    super.key,
    required this.activityId,
    required this.repository,
  });
  @override
  State<ActivityDiscussionSection> createState() =>
      _ActivityDiscussionSectionState();
}

class _ActivityDiscussionSectionState extends State<ActivityDiscussionSection> with RealtimeBinding<ActivityDiscussionSection> {
  @override
  String? get realtimeScope => 'activity:${widget.activityId}';
  @override
  String get realtimePrefix => 'DISCUSSION_';
  @override
  Future<void> reloadRealtime() => _load();
  @override
  void onRealtimeAccessLost() {
    if (!mounted) return;
    _request++;
    setState(() {
      _discussion = null;
      _accessDenied = true;
      _canComment = false;
      _readOnly = true;
      _loadError = 'Bạn không có quyền xem thảo luận.';
    });
  }

  // Own the result/error immediately; never publish an unattached Future.error.
  // Local reloads and realtime reloads share the same latest-request guard.
  Future<void> _load() async {
    final request = ++_request;
    try {
      final data = await widget.repository.list(widget.activityId);
      if (!mounted || request != _request) return;
      setState(() {
        _discussion = data;
        _accessDenied = false;
        _loadError = null;
        _canComment = data.permissions.canComment;
        _readOnly = data.permissions.readOnly;
      });
    } on ApiException catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        if (error.statusCode == 401 || error.statusCode == 403) {
          _accessDenied = true;
          _discussion = null;
          _canComment = false;
          _readOnly = true;
          _loadError = error.statusCode == 401
              ? 'Cần đăng nhập lại để xem thảo luận.'
              : 'Bạn không có quyền xem thảo luận.';
        } else {
          if (_accessDenied) return;
          _loadError = _discussion == null
              ? 'Không thể tải bình luận. Thử lại'
              : 'Không thể cập nhật bình luận. Đang hiển thị dữ liệu trước đó. Thử lại';
        }
      });
    } catch (error, stack) {
      // RealtimeBinding catches callback failures; explicitly report unexpected
      // parsing/programming errors rather than disguising them as connectivity.
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'Discussion',
        context: ErrorDescription('while loading authoritative Discussion state'),
      ));
    }
  }
  ActivityDiscussion? _discussion;
  String? _loadError;
  int _request = 0;
  bool _accessDenied = false;
  final _composer = TextEditingController();
  bool _sending = false;
  bool _canComment = false;
  bool _readOnly = true;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _request++;
    _composer.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ActivityDiscussionSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activityId != widget.activityId || oldWidget.repository != widget.repository) {
      _discussion = null;
      _accessDenied = false;
      _loadError = null;
      _canComment = false;
      _readOnly = true;
      refreshRealtimeBindings();
      _reload();
    }
  }

  void _reload() { if (mounted) _load(); }
  Future<void> _add() async {
    final content = _composer.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.repository.add(widget.activityId, content);
      _composer.clear();
      _reload();
    } catch (_) {
      _message('Không thể gửi bình luận.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _reply(ActivityComment comment) async {
    final controller = TextEditingController();
    final content = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Phản hồi'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Gửi phản hồi'),
            ),
          ],
        ),
      ),
    );
    if (content == null || content.isEmpty) return;
    try {
      await widget.repository.reply(comment.id, content);
      _reload();
    } catch (_) {
      _message('Không thể gửi phản hồi.');
    }
  }

  Future<void> _edit(ActivityComment comment) async {
    final controller = TextEditingController(text: comment.content);
    final content = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chỉnh sửa bình luận'),
        content: TextField(controller: controller, maxLines: 4),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (content == null || content.isEmpty) return;
    try {
      await widget.repository.update(comment.id, content);
      _reload();
    } catch (_) {
      _message('Không thể chỉnh sửa bình luận.');
    }
  }

  Future<void> _delete(ActivityComment comment) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa bình luận?'),
        content: const Text('Bình luận sẽ không còn hiển thị nội dung.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.repository.delete(comment.id);
      _reload();
    } catch (_) {
      _message('Không thể xóa bình luận.');
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 24),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),

    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Thảo luận',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (_loadError != null)
          TextButton(onPressed: _reload, child: Text(_loadError!)),
        Builder(
          builder: (context) {
            final discussion = _discussion;
            if (discussion == null && _loadError == null)
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              );
            if (discussion == null) return const SizedBox.shrink();
            final comments = discussion.comments;
            final roots = comments
                .where((comment) => comment.parentCommentId == null)
                .toList();
            if (roots.isEmpty)
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'Chưa có bình luận nào.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              );
            return Column(
              children: roots
                  .map(
                    (comment) => DiscussionCommentTile(
                      comment: comment,
                      replies: comments
                          .where((reply) => reply.parentCommentId == comment.id)
                          .toList(),
                      onReply: comment.permissions.canReply
                          ? () => _reply(comment)
                          : null,
                      onEdit: comment.permissions.canEdit
                          ? () => _edit(comment)
                          : null,
                      onDelete: comment.permissions.canDelete
                          ? () => _delete(comment)
                          : null,
                      onEditReply: _edit,
                      onDeleteReply: _delete,
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const Divider(height: 28),
        if (_readOnly)
          Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'Thảo luận chỉ có thể xem ở trạng thái hiện tại.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _composer,
                enabled: _canComment,
                maxLines: 3,
                minLines: 1,
                decoration: const InputDecoration(hintText: 'Viết bình luận'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Gửi bình luận',
              onPressed: _canComment && !_sending ? _add : null,
              icon: Icon(Icons.send, color: Theme.of(context).colorScheme.primary),
            ),
          ],
        ),
      ],
    ),
  );
}

class DiscussionCommentTile extends StatelessWidget {
  final ActivityComment comment;
  final List<ActivityComment> replies;
  final VoidCallback? onReply, onEdit, onDelete;
  final ValueChanged<ActivityComment>? onEditReply, onDeleteReply;
  const DiscussionCommentTile({
    super.key,
    required this.comment,
    required this.replies,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    this.onEditReply,
    this.onDeleteReply,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            UserAvatar(
              displayName: comment.author?.name ?? 'Member',
              avatarStorageKey: comment.author?.avatarStorageKey,
              radius: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comment.deleted
                        ? 'Bình luận đã bị xóa'
                        : comment.author?.name ?? 'Member',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    AppDateTimeFormatter.formatRelativeTime(comment.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (!comment.deleted)
              if (onEdit != null || onDelete != null)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit?.call();
                    if (value == 'delete') onDelete?.call();
                  },
                  itemBuilder: (_) => [
                    if (onEdit != null)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Chỉnh sửa'),
                      ),
                    if (onDelete != null)
                      const PopupMenuItem(value: 'delete', child: Text('Xóa')),
                  ],
                ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          comment.deleted ? 'Nội dung không còn khả dụng.' : comment.content,
          style: TextStyle(
            color: comment.deleted
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        if (!comment.deleted)
          if (onReply != null)
            TextButton(onPressed: onReply, child: const Text('Phản hồi')),
        ...replies.map(
          (reply) => Padding(
            padding: const EdgeInsets.only(left: 28, top: 8),
            child: DiscussionCommentTile(
              comment: reply,
              replies: const [],
              onReply: null,
              onEdit: reply.permissions.canEdit && onEditReply != null
                  ? () => onEditReply!(reply)
                  : null,
              onDelete: reply.permissions.canDelete && onDeleteReply != null
                  ? () => onDeleteReply!(reply)
                  : null,
            ),
          ),
        ),
      ],
    ),
  );
}
