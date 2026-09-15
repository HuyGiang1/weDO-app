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

/// Screen displaying user's blocked users with pagination, pull-to-refresh, and unblock action.
/// Faithfully ported from design/blocked_users.html.
class BlockedUsersScreen extends StatefulWidget {
  final BlockedUsersController controller;

  const BlockedUsersScreen({
    super.key,
    required this.controller,
  });

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final ScrollController _scrollController = ScrollController();
  String? _unblockingUserId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    widget.controller.loadBlockedUsers();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      widget.controller.loadMoreBlockedUsers();
    }
  }

  Future<void> _handleUnblock(BlockedUser item) async {
    final confirmed = await SocialConfirmationDialog.show(
      context,
      title: 'Bỏ chặn người dùng',
      message: 'Bạn có chắc muốn bỏ chặn ${item.blockedUser.displayName}?',
      confirmLabel: 'Bỏ chặn',
      isDestructive: false,
    );

    if (!confirmed || !mounted) return;

    setState(() => _unblockingUserId = item.blockedUser.id);
    final ok = await widget.controller.unblock(item.blockedUser.id);
    if (!mounted) return;
    setState(() => _unblockingUserId = null);

    final messenger = ScaffoldMessenger.of(context);
    if (ok) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Đã bỏ chặn ${item.blockedUser.displayName}.'),
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
        leading: Navigator.of(context).canPop()
            ? Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: AppColors.onSurfaceVariant,
                  tooltip: 'Quay lại',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              )
            : null,
        title: Text(
          'Người dùng đã chặn',
          style: AppTextStyles.headline.copyWith(
            fontSize: 24.0,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 768.0),
          child: ValueListenableBuilder<SocialListState<BlockedUser>>(
            valueListenable: widget.controller.blockedUsers,
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
                      : 'Đã có lỗi xảy ra khi tải danh sách chặn.',
                  onRetry: () => widget.controller.loadBlockedUsers(refresh: true),
                );
              }

              if (state.isEmpty || state.items.isEmpty) {
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () =>
                      widget.controller.loadBlockedUsers(refresh: true),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 24.0,
                    ),
                    children: [
                      _buildInfoAlert(),
                      const SizedBox(height: 32.0),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.45,
                        child: const SocialEmptyState(
                          icon: Icons.person_off_rounded,
                          title: 'Không có người dùng bị chặn',
                          subtitle:
                              'Khi bạn chặn ai đó, họ sẽ xuất hiện tại đây.',
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () =>
                    widget.controller.loadBlockedUsers(refresh: true),
                child: ListView.separated(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 24.0,
                  ),
                  itemCount: state.items.length + 1 + (state.hasNext ? 1 : 0),
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 16.0),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: _buildInfoAlert(),
                      );
                    }

                    final itemIndex = index - 1;
                    if (itemIndex >= state.items.length) {
                      if (state.isErrorMore) {
                        return Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Center(
                            child: TextButton(
                              onPressed: widget.controller.loadMoreBlockedUsers,
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

                    final item = state.items[itemIndex];
                    final isUnblocking =
                        _unblockingUserId == item.blockedUser.id;

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
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          UserAvatar(
                            displayName: item.blockedUser.displayName,
                            avatarStorageKey: item.blockedUser.avatarStorageKey,
                            radius: 24.0,
                          ),
                          const SizedBox(width: 16.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.blockedUser.displayName,
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
                                  '@${item.blockedUser.username}',
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
                          if (isUnblocking)
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
                              onPressed: () => _handleUnblock(item),
                              style: OutlinedButton.styleFrom(
                                backgroundColor:
                                    const Color(0x1A630ED4), // primary/10
                                foregroundColor: AppColors.primary,
                                side: BorderSide.none,
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20.0,
                                  vertical: 10.0,
                                ),
                              ),
                              child: Text(
                                'Bỏ chặn',
                                style: AppTextStyles.label.copyWith(
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
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

  Widget _buildInfoAlert() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12.0),
      ),
      padding: const EdgeInsets.all(20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_rounded,
            size: 24.0,
            color: AppColors.primary,
          ),
          const SizedBox(width: 16.0),
          Expanded(
            child: Text(
              'Người dùng bạn chặn sẽ không thể nhắn tin cho bạn, xem các nhóm hoặc tương tác với nội dung của bạn. Họ sẽ không nhận được thông báo rằng bạn đã chặn họ.',
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 14.0,
                color: AppColors.onSurfaceVariant,
                height: 20.0 / 14.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

