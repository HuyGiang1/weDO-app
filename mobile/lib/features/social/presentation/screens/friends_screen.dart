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
/// Faithfully styled according to WeDo HTML design system.
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: 64.0,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Bạn bè',
          style: AppTextStyles.headline.copyWith(
            fontSize: 24.0,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        actions: [
          if (widget.onOpenFriendRequests != null)
            IconButton(
              icon: const Icon(Icons.person_add_rounded),
              color: AppColors.onSurfaceVariant,
              tooltip: 'Lời mời kết bạn',
              onPressed: widget.onOpenFriendRequests,
            ),
          if (widget.onOpenBlockedUsers != null)
            IconButton(
              icon: const Icon(Icons.block_rounded),
              color: AppColors.onSurfaceVariant,
              tooltip: 'Đã chặn',
              onPressed: widget.onOpenBlockedUsers,
            ),
          const SizedBox(width: 8.0),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 672.0),
          child: ValueListenableBuilder<SocialListState<Friend>>(
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
                          subtitle:
                              'Hãy kết nối với bạn bè để trò chuyện và tham gia hoạt động.',
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 20.0,
                  ),
                  itemCount: state.items.length + (state.hasNext ? 1 : 0),
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 16.0),
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
                    final isUnfriending =
                        _unfriendingUserId == item.friend.id;

                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(12.0),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.softShadow,
                            blurRadius: 20.0,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          UserAvatar(
                            displayName: item.friend.displayName,
                            avatarStorageKey: item.friend.avatarStorageKey,
                            radius: 24.0,
                          ),
                          const SizedBox(width: 16.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.friend.displayName,
                                  style: AppTextStyles.label.copyWith(
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2.0),
                                Text(
                                  '@${item.friend.username}',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontSize: 14.0,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12.0),
                          if (isUnfriending)
                            const SizedBox(
                              width: 24.0,
                              height: 24.0,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                                color: AppColors.primary,
                              ),
                            )
                          else
                            OutlinedButton(
                              onPressed: () => _handleUnfriend(item),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(
                                  color: AppColors.outlineVariant,
                                ),
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 8.0,
                                ),
                              ),
                              child: Text(
                                'Hủy kết bạn',
                                style: AppTextStyles.label.copyWith(
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
