import 'package:flutter/material.dart';
import '../../../../core/realtime/realtime_binding.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../social/data/models/social_models.dart';
import '../../../social/data/social_failure.dart';
import '../../../social/data/social_repository.dart';
import '../../../social/presentation/utils/social_error_localizer.dart';
import '../../../social/presentation/widgets/social_action_button.dart';
import '../../../social/presentation/widgets/social_confirmation_dialog.dart';
import '../../data/profile_models.dart';
import '../widgets/profile_ui.dart';

class PublicUserProfileScreen extends StatefulWidget {
  final String userId;
  final Future<PublicUserProfile> Function(String userId) loadPublicProfile;
  final VoidCallback? onMessage;
  final SocialRepository? socialRepository;

  const PublicUserProfileScreen({
    super.key,
    required this.userId,
    required this.loadPublicProfile,
    this.onMessage,
    this.socialRepository,
  });

  @override
  State<PublicUserProfileScreen> createState() =>
      _PublicUserProfileScreenState();
}

class _PublicUserProfileScreenState extends State<PublicUserProfileScreen> with RealtimeBinding<PublicUserProfileScreen> {
  @override
  String? get realtimeScope => 'user:self';
  @override
  String get realtimePrefix => 'FRIEND_';
  @override
  Future<void> reloadRealtime() async { await _loadRelationship(); }

  late Future<PublicUserProfile> _future;
  RelationshipState? _relationshipState;
  String? _pendingRequestId;
  bool _socialLoading = false;
  int _relationshipGeneration = 0;

  @override
  void initState() {
    super.initState();
    _future = widget.loadPublicProfile(widget.userId);
    _loadRelationship();
  }

  void _retry() {
    final next = widget.loadPublicProfile(widget.userId);
    setState(() {
      _future = next;
    });
    _loadRelationship();
  }

  Future<void> _loadRelationship() async {
    final repo = widget.socialRepository;
    if (repo == null) return;
    final generation = ++_relationshipGeneration;
    setState(() => _socialLoading = true);
    try {
      final status = await repo.getRelationship(widget.userId);
      String? reqId;
      if (status.state == RelationshipState.pendingSent) {
        final sent = await repo.getSentFriendRequests(page: 0, size: 50);
        for (final item in sent.items) {
          if (item.receiver.id == widget.userId) {
            reqId = item.id;
            break;
          }
        }
      } else if (status.state == RelationshipState.pendingReceived) {
        final received = await repo.getReceivedFriendRequests(
          page: 0,
          size: 50,
        );
        for (final item in received.items) {
          if (item.sender.id == widget.userId) {
            reqId = item.id;
            break;
          }
        }
      }
      if (!mounted || generation != _relationshipGeneration) return;
      setState(() {
        _relationshipState = status.state;
        _pendingRequestId = reqId;
        _socialLoading = false;
      });
    } catch (_) {
      if (!mounted || generation != _relationshipGeneration) return;
      setState(() => _socialLoading = false);
    }
  }

  Future<void> _runSocialAction(
    Future<void> Function(SocialRepository repo) work, {
    String? successMessage,
    RelationshipState? completedState,
  }) async {
    final repo = widget.socialRepository;
    if (repo == null || _socialLoading) return;
    ++_relationshipGeneration;
    setState(() => _socialLoading = true);
    try {
      await work(repo);
      if (!mounted) return;
      // The successful mutation defines this local transition even if the
      // subsequent read is offline. Never retain an old pending request ID.
      if (completedState != null) {
        setState(() {
          _relationshipState = completedState;
          if (completedState != RelationshipState.pendingSent &&
              completedState != RelationshipState.pendingReceived) {
            _pendingRequestId = null;
          }
        });
      }
      if (successMessage != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(successMessage)));
      }
      await _loadRelationship();
    } on SocialException catch (e) {
      if (!mounted) return;
      setState(() => _socialLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SocialErrorLocalizer.localize(e.failure))),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _socialLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể thực hiện thao tác lúc này.')),
      );
    }
  }

  Future<void> _handleAddFriend() => _runSocialAction(
    (repo) async {
      final req = await repo.sendFriendRequest(widget.userId);
      _pendingRequestId = req.id;
    },
    successMessage: 'Đã gửi lời mời kết bạn.',
    completedState: RelationshipState.pendingSent,
  );

  Future<void> _handleCancelRequest() async {
    final reqId = _pendingRequestId;
    if (reqId == null) {
      await _loadRelationship();
      return;
    }
    await _runSocialAction(
      (repo) => repo.cancelFriendRequest(reqId),
      successMessage: 'Đã hủy lời mời kết bạn.',
      completedState: RelationshipState.none,
    );
  }

  Future<void> _handleAcceptRequest() async {
    final reqId = _pendingRequestId;
    if (reqId == null) {
      await _loadRelationship();
      return;
    }
    await _runSocialAction(
      (repo) => repo.acceptFriendRequest(reqId),
      successMessage: 'Đã chấp nhận lời mời kết bạn!',
      completedState: RelationshipState.friends,
    );
  }

  Future<void> _handleDeclineRequest() async {
    final reqId = _pendingRequestId;
    if (reqId == null) {
      await _loadRelationship();
      return;
    }
    await _runSocialAction(
      (repo) => repo.declineFriendRequest(reqId),
      successMessage: 'Đã từ chối lời mời kết bạn.',
      completedState: RelationshipState.none,
    );
  }

  Future<void> _handleUnfriend(String displayTitle) async {
    final confirmed = await SocialConfirmationDialog.show(
      context,
      title: 'Hủy kết bạn',
      message: 'Bạn có chắc muốn hủy kết bạn với $displayTitle?',
      confirmLabel: 'Hủy kết bạn',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    await _runSocialAction(
      (repo) => repo.unfriend(widget.userId),
      successMessage: 'Đã hủy kết bạn.',
      completedState: RelationshipState.none,
    );
  }

  Future<void> _handleBlock(String displayTitle) async {
    final confirmed = await SocialConfirmationDialog.show(
      context,
      title: 'Chặn người dùng',
      message: 'Bạn có chắc muốn chặn $displayTitle?',
      confirmLabel: 'Chặn',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    await _runSocialAction(
      (repo) => repo.blockUser(widget.userId),
      successMessage: 'Đã chặn người dùng.',
    );
  }

  Future<void> _handleUnblock() => _runSocialAction(
    (repo) => repo.unblockUser(widget.userId),
    successMessage: 'Đã bỏ chặn người dùng.',
  );

  @override
  Widget build(BuildContext context) {
    final canBlock =
        widget.socialRepository != null &&
        _relationshipState != null &&
        _relationshipState != RelationshipState.self &&
        _relationshipState != RelationshipState.blocked;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ'),
        actions: [
          if (canBlock)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'block') {
                  final profile = await _future.catchError(
                    (_) => PublicUserProfile(
                      id: widget.userId,
                      username: 'người dùng này',
                    ),
                  );
                  if (!mounted) return;
                  final name = profile.displayName?.trim().isNotEmpty == true
                      ? profile.displayName!.trim()
                      : profile.username;
                  await _handleBlock(name);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'block',
                  child: Text('Chặn người dùng'),
                ),
              ],
            ),
        ],
      ),
      body: FutureBuilder<PublicUserProfile>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Không thể tải hồ sơ này.'),
                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton(
                    onPressed: _retry,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }
          final profile = snapshot.data!;
          final displayName = profile.displayName?.trim();
          final title = displayName == null || displayName.isEmpty
              ? profile.username
              : displayName;
          final bio = profile.bio?.trim();
          final showMessageButton =
              widget.onMessage != null &&
              _relationshipState != RelationshipState.self &&
              _relationshipState != RelationshipState.blocked &&
              _relationshipState != RelationshipState.blockedBy;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSpacing.maxContentWidth,
                  ),
                  child: Column(
                    children: [
                      ProfileAvatar(
                        label: title,
                        avatarStorageKey: profile.avatarStorageKey,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        title,
                        style: AppTextStyles.of(context).headline,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '@${profile.username}',
                        style: AppTextStyles.of(context).bodyMedium,
                      ),
                      if (widget.socialRepository != null &&
                          (_relationshipState != null || _socialLoading)) ...[
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SocialActionButton(
                              state:
                                  _relationshipState ?? RelationshipState.none,
                              isLoading: _socialLoading,
                              onAddFriend: _handleAddFriend,
                              onCancelRequest: _handleCancelRequest,
                              onAccept: _handleAcceptRequest,
                              onDecline: _handleDeclineRequest,
                              onUnfriend: () => _handleUnfriend(title),
                              onUnblock: _handleUnblock,
                            ),
                            if (showMessageButton)
                              FilledButton.icon(
                                onPressed: widget.onMessage,
                                icon: const Icon(Icons.chat_bubble_outline),
                                label: const Text('Nhắn tin'),
                              ),
                          ],
                        ),
                      ] else if (showMessageButton) ...[
                        const SizedBox(height: AppSpacing.md),
                        FilledButton.icon(
                          onPressed: widget.onMessage,
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Nhắn tin'),
                        ),
                      ],
                      if (bio != null && bio.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        ProfileSurface(
                          child: Text(
                            bio,
                            style: AppTextStyles.of(context).bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
