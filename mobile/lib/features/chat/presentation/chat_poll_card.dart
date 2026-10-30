import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/realtime/realtime_binding.dart';
import '../../../core/realtime/reliable_read.dart';
import '../../poll/data/poll_models.dart';
import '../../poll/data/poll_api.dart';
import '../../social/presentation/widgets/user_avatar.dart';
import '../../poll/data/poll_repository.dart';
import '../../poll/data/poll_failure.dart';
import '../../poll/presentation/poll_deadline.dart';
import '../../poll/presentation/screens/poll_screens.dart';

/// A resource-local projection. Votes never reload Chat history or its images.
class ChatPollCard extends StatefulWidget {
  final String pollId;
  final PollRepository repository;
  final bool readOnly;
  const ChatPollCard({
    super.key,
    required this.pollId,
    required this.repository,
    this.readOnly = false,
  });
  @override
  State<ChatPollCard> createState() => _ChatPollCardState();
}

class _ChatPollCardState extends State<ChatPollCard>
    with RealtimeBinding<ChatPollCard> {
  final _read = ReliableRead<Poll>();
  final _selected = <String>{};
  bool _busy = false, _dirty = false;
  String? _voteCommandId, _voteSelection;
  late final _deadline = PollDeadlineRefresh(reloadRealtime);
  @override
  String? get realtimeScope => null;
  @override
  String get realtimePrefix => 'POLL_';
  @override
  String get realtimeAggregateId => widget.pollId;
  @override
  bool get realtimeReadNeedsRecovery => _read.failure?.retainData == true;
  @override
  void onRealtimeAccessLost() {
    _selected.clear();
    _read.denyAccess();
  }

  @override
  void initState() {
    super.initState();
    reloadRealtime();
  }

  void _received(Poll poll) {
    bindRealtimeResource(poll.realtimeScope);
    _deadline.schedule(poll.status == PollStatus.open ? [poll.deadlineAt] : []);
    if (!_dirty) {
      _selected
        ..clear()
        ..addAll(poll.callerOptionIds);
    }
  }

  @override
  Future<void> reloadRealtime() =>
      _read.load(() => widget.repository.get(widget.pollId), onData: _received);
  @override
  void dispose() {
    _deadline.dispose();
    _read.dispose();
    super.dispose();
  }

  Future<void> _mutate(Poll poll, {bool close = false}) async {
    if (_busy || widget.readOnly || _read.failure != null) return;
    if (!close && (!poll.permissions.canVote || _selected.isEmpty)) return;
    if (close && !poll.permissions.canClose) return;
    final generation = _read.generation;
    setState(() => _busy = true);
    try {
      final selection = (_selected.toList()..sort()).join(',');
      if (_voteSelection != selection || _voteCommandId == null) {
        _voteSelection = selection;
        _voteCommandId = PollApi.newCommandId();
      }
      final next = close
          ? await widget.repository.close(poll.id)
          : await widget.repository.vote(
              poll.id,
              _selected.toList(),
              clientRequestId: _voteCommandId,
            );
      _voteCommandId = null;
      if (!mounted || !_read.isCurrent(generation)) return;
      _dirty = false;
      _received(next);
      _read.accept(next); // Invalidates an older in-flight authoritative read.
    } on ApiException catch (error) {
      if (!mounted || !_read.isCurrent(generation)) return;
      if ([401, 403, 404].contains(error.statusCode)) _read.denyAccess();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(votePollFailureMessage(error))));
      if (error.statusCode == 409) await reloadRealtime();
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'Chat Poll',
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: ValueListenableBuilder(
        valueListenable: _read,
        builder: (context, snapshot, _) {
          final poll = snapshot.data;
          if (poll == null) {
            return TextButton(
              onPressed: reloadRealtime,
              child: Text(_read.failure?.message ?? 'Đang tải bình chọn…'),
            );
          }
          final allowed =
              !widget.readOnly &&
              !_busy &&
              _read.failure == null &&
              poll.permissions.canVote;
          final total = poll.options.fold<int>(
            0,
            (sum, option) => sum + option.voteCount,
          );
          final showResults =
              poll.resultsVisible &&
              (poll.callerOptionIds.isNotEmpty ||
                  poll.status == PollStatus.closed);
          final colors = Theme.of(context).colorScheme;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.poll_outlined, size: 16, color: colors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'BÌNH CHỌN',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: .8,
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                    ),
                  ),
                  const Spacer(),
                  if (poll.voteVisibility == VoteVisibility.anonymous)
                    Icon(
                      Icons.visibility_off_outlined,
                      size: 14,
                      color: colors.onSurfaceVariant,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                poll.question,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: colors.onSurface,
                ),
              ),
              Text(
                poll.status == PollStatus.closed
                    ? 'Bình chọn đã đóng'
                    : 'Bình chọn đang mở',
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              ),
              if (poll.voteVisibility == VoteVisibility.anonymous)
                const Text('Bình chọn ẩn danh'),
              if (poll.deadlineAt != null)
                Text(
                  'Hạn: ${_date(poll.deadlineAt!)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 8),
              if (_read.failure != null)
                TextButton(
                  onPressed: reloadRealtime,
                  child: Text(
                    'Dữ liệu chưa được cập nhật. ${_read.failure!.message}',
                  ),
                ),
              for (final option in poll.options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: showResults && total > 0
                                  ? option.voteCount / total
                                  : 0,
                              heightFactor: 1,
                              child: ColoredBox(
                                color: colors.primary.withValues(alpha: .09),
                              ),
                            ),
                          ),
                        ),
                      ),
                      CheckboxListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: _selected.contains(option.id)
                                ? colors.primary
                                : colors.outlineVariant,
                          ),
                        ),
                        title: Text(
                          option.text,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.onSurface,
                          ),
                        ),
                        value: _selected.contains(option.id),
                        subtitle: showResults
                            ? Text(
                                '${option.voteCount} phiếu',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: colors.onSurfaceVariant,
                                ),
                              )
                            : null,
                        onChanged: allowed && !option.disabled
                            ? (selected) => setState(() {
                                _dirty = true;
                                if (poll.type == PollType.singleChoice) {
                                  _selected.clear();
                                }
                                if (selected == true) {
                                  _selected.add(option.id);
                                } else {
                                  _selected.remove(option.id);
                                }
                              })
                            : null,
                      ),
                    ],
                  ),
                ),
              InkWell(
                onTap:
                    poll.permissions.canViewVoters &&
                        poll.voteVisibility == VoteVisibility.public &&
                        _read.failure == null
                    ? () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PollVotersScreen(
                            poll: poll,
                            repository: widget.repository,
                          ),
                        ),
                      )
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      if (poll.voteVisibility == VoteVisibility.public &&
                          poll.permissions.canViewVoters)
                        for (final person in poll.participantPreview.take(3))
                          Padding(
                            padding: const EdgeInsets.only(right: 3),
                            child: UserAvatar(
                              displayName: person.displayName,
                              avatarStorageKey: person.avatarStorageKey,
                              radius: 10,
                            ),
                          ),
                      Flexible(
                        child: Text(
                          '${poll.participantCount} người đã bình chọn',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (poll.permissions.canViewVoters)
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: colors.onSurfaceVariant,
                        ),
                    ],
                  ),
                ),
              ),
              if (showResults && poll.type == PollType.multipleChoice)
                Text(
                  '$total lượt chọn',
                  style: TextStyle(
                    fontSize: 10,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              if (!poll.resultsVisible)
                const Text('Kết quả chưa được hiển thị.'),
              if (poll.permissions.canVote)
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: allowed && _selected.isNotEmpty
                      ? () => _mutate(poll)
                      : null,
                  child: Text(
                    _busy
                        ? 'Đang gửi…'
                        : poll.callerOptionIds.isEmpty
                        ? 'Bình chọn'
                        : 'Đổi bình chọn',
                  ),
                ),
              Wrap(
                children: [
                  TextButton(
                    onPressed: _read.failure == null
                        ? () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PollDetailScreen(
                                pollId: poll.id,
                                repository: widget.repository,
                              ),
                            ),
                          )
                        : null,
                    child: const Text(
                      'Xem chi tiết',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                  if (poll.resultsVisible)
                    TextButton(
                      onPressed: _read.failure == null
                          ? () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PollResultsScreen(
                                  poll: poll,
                                  repository: widget.repository,
                                ),
                              ),
                            )
                          : null,
                      child: const Text('Kết quả'),
                    ),
                  if (poll.permissions.canClose)
                    TextButton(
                      onPressed:
                          !widget.readOnly && !_busy && _read.failure == null
                          ? () => _mutate(poll, close: true)
                          : null,
                      child: const Text('Đóng bình chọn'),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    ),
  );

  String _date(DateTime value) {
    final d = value.toLocal();
    return '${d.day}/${d.month} ${d.hour.toString().padLeft(2, "0")}:${d.minute.toString().padLeft(2, "0")}';
  }
}
