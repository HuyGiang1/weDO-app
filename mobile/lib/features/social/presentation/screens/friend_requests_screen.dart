import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../application/social_controllers.dart';
import '../../application/social_state.dart';
import '../../data/models/social_models.dart';
import '../utils/social_error_localizer.dart';
import '../widgets/social_empty_state.dart';
import '../widgets/social_error_view.dart';
import '../widgets/user_avatar.dart';

/// Screen displaying incoming and outgoing friend requests with pagination and pull-to-refresh.
class FriendRequestsScreen extends StatefulWidget {
  final FriendRequestsController controller;

  const FriendRequestsScreen({
    super.key,
    required this.controller,
  });

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    widget.controller.loadReceived();
    widget.controller.loadSent();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lời mời kết bạn'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        elevation: 0.5,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.onSurfaceVariant,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3.0,
          tabs: const [
            Tab(text: 'Đã nhận'),
            Tab(text: 'Đã gửi'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ReceivedRequestsView(controller: widget.controller),
          _SentRequestsView(controller: widget.controller),
        ],
      ),
    );
  }
}

class _ReceivedRequestsView extends StatefulWidget {
  final FriendRequestsController controller;

  const _ReceivedRequestsView({required this.controller});

  @override
  State<_ReceivedRequestsView> createState() => _ReceivedRequestsViewState();
}

class _ReceivedRequestsViewState extends State<_ReceivedRequestsView> {
  final ScrollController _scrollController = ScrollController();
  String? _activeActionRequestId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      widget.controller.loadMoreReceived();
    }
  }

  Future<void> _handleAccept(FriendRequest request) async {
    setState(() => _activeActionRequestId = request.id);
    final ok = await widget.controller.accept(request.id);
    if (!mounted) return;
    setState(() => _activeActionRequestId = null);

    final messenger = ScaffoldMessenger.of(context);
    if (ok) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Đã kết bạn với ${request.sender.displayName}',
          ),
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

  Future<void> _handleDecline(FriendRequest request) async {
    setState(() => _activeActionRequestId = request.id);
    final ok = await widget.controller.decline(request.id);
    if (!mounted) return;
    setState(() => _activeActionRequestId = null);

    final messenger = ScaffoldMessenger.of(context);
    if (ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Đã từ chối lời mời kết bạn.')),
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
    return ValueListenableBuilder<SocialListState<FriendRequest>>(
      valueListenable: widget.controller.receivedRequests,
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
                : 'Đã có lỗi xảy ra khi tải lời mời.',
            onRetry: () => widget.controller.loadReceived(refresh: true),
          );
        }

        if (state.isEmpty || state.items.isEmpty) {
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => widget.controller.loadReceived(refresh: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: const SocialEmptyState(
                    icon: Icons.person_add_disabled_rounded,
                    title: 'Không có lời mời kết bạn nào',
                    subtitle: 'Khi có ai đó gửi lời mời, bạn sẽ thấy ở đây.',
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => widget.controller.loadReceived(refresh: true),
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
                        onPressed: widget.controller.loadMoreReceived,
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
              final isActionPending = _activeActionRequestId == item.id;

              return ListTile(
                leading: UserAvatar(
                  displayName: item.sender.displayName,
                  avatarStorageKey: item.sender.avatarStorageKey,
                ),
                title: Text(
                  item.sender.displayName,
                  style: AppTextStyles.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '@${item.sender.username}',
                  style: AppTextStyles.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: isActionPending
                    ? const SizedBox(
                        width: 24.0,
                        height: 24.0,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          color: AppColors.primary,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FilledButton(
                            onPressed: () => _handleAccept(item),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                              ),
                            ),
                            child: const Text('Chấp nhận'),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          OutlinedButton(
                            onPressed: () => _handleDecline(item),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.onSurfaceVariant,
                              side: const BorderSide(
                                color: AppColors.outlineVariant,
                              ),
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                              ),
                            ),
                            child: const Text('Từ chối'),
                          ),
                        ],
                      ),
              );
            },
          ),
        );
      },
    );
  }
}

class _SentRequestsView extends StatefulWidget {
  final FriendRequestsController controller;

  const _SentRequestsView({required this.controller});

  @override
  State<_SentRequestsView> createState() => _SentRequestsViewState();
}

class _SentRequestsViewState extends State<_SentRequestsView> {
  final ScrollController _scrollController = ScrollController();
  String? _activeActionRequestId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      widget.controller.loadMoreSent();
    }
  }

  Future<void> _handleCancel(FriendRequest request) async {
    setState(() => _activeActionRequestId = request.id);
    final ok = await widget.controller.cancel(request.id);
    if (!mounted) return;
    setState(() => _activeActionRequestId = null);

    final messenger = ScaffoldMessenger.of(context);
    if (ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Đã hủy lời mời kết bạn.')),
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
    return ValueListenableBuilder<SocialListState<FriendRequest>>(
      valueListenable: widget.controller.sentRequests,
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
                : 'Đã có lỗi xảy ra khi tải danh sách.',
            onRetry: () => widget.controller.loadSent(refresh: true),
          );
        }

        if (state.isEmpty || state.items.isEmpty) {
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => widget.controller.loadSent(refresh: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: const SocialEmptyState(
                    icon: Icons.outgoing_mail,
                    title: 'Chưa gửi lời mời nào',
                    subtitle: 'Những lời mời bạn đã gửi sẽ hiển thị tại đây.',
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => widget.controller.loadSent(refresh: true),
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
                        onPressed: widget.controller.loadMoreSent,
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
              final isActionPending = _activeActionRequestId == item.id;

              return ListTile(
                leading: UserAvatar(
                  displayName: item.receiver.displayName,
                  avatarStorageKey: item.receiver.avatarStorageKey,
                ),
                title: Text(
                  item.receiver.displayName,
                  style: AppTextStyles.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '@${item.receiver.username}',
                  style: AppTextStyles.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: isActionPending
                    ? const SizedBox(
                        width: 24.0,
                        height: 24.0,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          color: AppColors.primary,
                        ),
                      )
                    : OutlinedButton(
                        onPressed: () => _handleCancel(item),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.onSurfaceVariant,
                          side: const BorderSide(
                            color: AppColors.outlineVariant,
                          ),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                          ),
                        ),
                        child: const Text('Hủy'),
                      ),
              );
            },
          ),
        );
      },
    );
  }
}
