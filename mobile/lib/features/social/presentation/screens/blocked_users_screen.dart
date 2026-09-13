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
      appBar: AppBar(
        title: const Text('Người dùng đã chặn'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        elevation: 0.5,
      ),
      body: ValueListenableBuilder<SocialListState<BlockedUser>>(
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
              onRefresh: () => widget.controller.loadBlockedUsers(refresh: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: const SocialEmptyState(
                      icon: Icons.block_rounded,
                      title: 'Không có người dùng bị chặn',
                      subtitle: 'Danh sách những người bạn đã chặn sẽ xuất hiện tại đây.',
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => widget.controller.loadBlockedUsers(refresh: true),
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

                final item = state.items[index];
                final isUnblocking = _unblockingUserId == item.blockedUser.id;

                return ListTile(
                  leading: UserAvatar(
                    displayName: item.blockedUser.displayName,
                    avatarStorageKey: item.blockedUser.avatarStorageKey,
                  ),
                  title: Text(
                    item.blockedUser.displayName,
                    style: AppTextStyles.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '@${item.blockedUser.username}',
                    style: AppTextStyles.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: isUnblocking
                      ? const SizedBox(
                          width: 24.0,
                          height: 24.0,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            color: AppColors.primary,
                          ),
                        )
                      : OutlinedButton(
                          onPressed: () => _handleUnblock(item),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.outlineVariant),
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                          ),
                          child: const Text('Bỏ chặn'),
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
