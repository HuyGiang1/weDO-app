import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../application/social_controllers.dart';
import '../../application/social_state.dart';
import '../../data/models/social_models.dart';
import '../utils/social_error_localizer.dart';
import '../widgets/social_confirmation_dialog.dart';
import '../widgets/social_empty_state.dart';
import '../widgets/social_error_view.dart';
import '../widgets/user_avatar.dart';

/// Screen displaying user's active friends with pagination, pull-to-refresh, and unfriend action.
class FriendsScreen extends StatefulWidget {
  final FriendsController controller;
  final VoidCallback? onOpenFriendRequests;
  final VoidCallback? onOpenBlockedUsers;

  const FriendsScreen({
    super.key,
    required this.controller,
    this.onOpenFriendRequests,
    this.onOpenBlockedUsers,
  });

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final ScrollController _scrollController = ScrollController();
  String? _unfriendingUserId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    widget.controller.loadFriends();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      widget.controller.loadMoreFriends();
    }
  }

  Future<void> _handleUnfriend(Friend item) async {
    final confirmed = await SocialConfirmationDialog.show(
      context,
      title: 'Hủy kết bạn',
      message: 'Bạn có chắc muốn hủy kết bạn với ${item.friend.displayName}?',
      confirmLabel: 'Hủy kết bạn',
      isDestructive: true,
    );

    if (!confirmed || !mounted) return;

    setState(() => _unfriendingUserId = item.friend.id);
    final ok = await widget.controller.unfriend(item.friend.id);
    if (!mounted) return;
    setState(() => _unfriendingUserId = null);

    final messenger = ScaffoldMessenger.of(context);
    if (ok) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Đã hủy kết bạn với ${item.friend.displayName}.'),
        ),
      );
    } else {
      final failure = widget.controller.actionState.value.failure;
      if (failure != null) {
        messenger.showSnackBar(
          SnackBar(content: Text(SocialErrorLocalizer.localize(failure))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bạn bè'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        elevation: 0.5,
        actions: [
          if (widget.onOpenFriendRequests != null)
            IconButton(
              icon: const Icon(Icons.person_add_rounded),
              tooltip: 'Lời mời kết bạn',
              onPressed: widget.onOpenFriendRequests,
            ),
          if (widget.onOpenBlockedUsers != null)
            IconButton(
              icon: const Icon(Icons.block_rounded),
              tooltip: 'Đã chặn',
              onPressed: widget.onOpenBlockedUsers,
            ),
        ],
      ),
      body: ValueListenableBuilder<SocialListState<Friend>>(
        valueListenable: widget.controller.friends,
        builder: (context, state, _) {
          if (state.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (state.isError) {
            return SocialErrorView(
              message: state.failure != null
                  ? SocialErrorLocalizer.localize(state.failure!)
                  : 'Đã có lỗi xảy ra khi tải danh sách bạn bè.',
              onRetry: () => widget.controller.loadFriends(refresh: true),
            );
          }

          if (state.isEmpty || state.items.isEmpty) {
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => widget.controller.loadFriends(refresh: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: const SocialEmptyState(
                      icon: Icons.people_outline_rounded,
                      title: 'Chưa có bạn bè nào',
                      subtitle: 'Hãy kết nối với bạn bè để trò chuyện và tham gia hoạt động.',
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => widget.controller.loadFriends(refresh: true),
            child: ListView.separated(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: state.items.length + (state.hasNext ? 1 : 0),
              separatorBuilder: (context, index) => const Divider(
                height: 1.0,
                indent: 72.0,
                endIndent: AppSpacing.md,
              ),
              itemBuilder: (context, index) {
                if (index >= state.items.length) {
                  if (state.isErrorMore) {
                    return Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Center(
                        child: TextButton(
                          onPressed: widget.controller.loadMoreFriends,
                          child: const Text('Tải thêm thất bại. Thử lại'),
                        ),
                      ),
                    );
                  }
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Center(
                      child: SizedBox(
                        width: 24.0,
                        height: 24.0,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  );
                }

                final item = state.items[index];
                final isUnfriending = _unfriendingUserId == item.friend.id;

                return ListTile(
                  leading: UserAvatar(
                    displayName: item.friend.displayName,
                    avatarStorageKey: item.friend.avatarStorageKey,
                  ),
                  title: Text(
                    item.friend.displayName,
                    style: AppTextStyles.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '@${item.friend.username}',
                    style: AppTextStyles.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: isUnfriending
                      ? const SizedBox(
                          width: 24.0,
                          height: 24.0,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            color: AppColors.primary,
                          ),
                        )
                      : OutlinedButton(
                          onPressed: () => _handleUnfriend(item),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.outlineVariant),
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                          ),
                          child: const Text('Hủy kết bạn'),
                        ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
