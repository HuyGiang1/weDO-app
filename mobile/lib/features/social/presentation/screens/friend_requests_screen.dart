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
/// Faithfully ported from design/friend_requests.html.
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
          'Lời mời kết bạn',
          style: AppTextStyles.headline.copyWith(
            fontSize: 24.0,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48.0),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.surfaceContainerHigh,
                  width: 1.0,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.onSurfaceVariant,
              indicatorColor: AppColors.primary,
              indicatorWeight: 2.0,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelStyle: AppTextStyles.label.copyWith(
                fontSize: 14.0,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: AppTextStyles.label.copyWith(
                fontSize: 14.0,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'Đã nhận'),
                Tab(text: 'Đã gửi'),
              ],
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 672.0),
          child: TabBarView(
            controller: _tabController,
            children: [
              _ReceivedRequestsView(controller: widget.controller),
              _SentRequestsView(controller: widget.controller),
            ],
          ),
        ),
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
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 20.0,
            ),
            itemCount: state.items.length + (state.hasNext ? 1 : 0),
            separatorBuilder: (context, index) => const SizedBox(height: 16.0),
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
                      displayName: item.sender.displayName,
                      avatarStorageKey: item.sender.avatarStorageKey,
                      radius: 24.0,
                    ),
                    const SizedBox(width: 16.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.sender.displayName,
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
                            '@${item.sender.username}',
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
                    const SizedBox(width: 8.0),
                    if (isActionPending)
                      const SizedBox(
                        width: 24.0,
                        height: 24.0,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          color: AppColors.primary,
                        ),
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton(
                            onPressed: () => _handleDecline(item),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.onSurfaceVariant,
                              side: BorderSide.none,
                              backgroundColor: Colors.transparent,
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                                vertical: 8.0,
                              ),
                            ),
                            child: Text(
                              'Từ chối',
                              style: AppTextStyles.label.copyWith(
                                fontSize: 14.0,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          FilledButton(
                            onPressed: () => _handleAccept(item),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.onPrimary,
                              elevation: 1.0,
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 8.0,
                              ),
                            ),
                            child: Text(
                              'Chấp nhận',
                              style: AppTextStyles.label.copyWith(
                                fontSize: 14.0,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onPrimary,
                              ),
                            ),
                          ),
                        ],
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
  String? _cancelingRequestId;

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
    setState(() => _cancelingRequestId = request.id);
    final ok = await widget.controller.cancel(request.id);
    if (!mounted) return;
    setState(() => _cancelingRequestId = null);

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
                : 'Đã có lỗi xảy ra khi tải danh sách đã gửi.',
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
                    icon: Icons.outbox_rounded,
                    title: 'Chưa gửi lời mời nào',
                    subtitle: 'Các lời mời kết bạn bạn đã gửi sẽ xuất hiện ở đây.',
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
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 20.0,
            ),
            itemCount: state.items.length + (state.hasNext ? 1 : 0),
            separatorBuilder: (context, index) => const SizedBox(height: 16.0),
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
              final isCanceling = _cancelingRequestId == item.id;

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
                      displayName: item.receiver.displayName,
                      avatarStorageKey: item.receiver.avatarStorageKey,
                      radius: 24.0,
                    ),
                    const SizedBox(width: 16.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.receiver.displayName,
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
                            '@${item.receiver.username}',
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
                    if (isCanceling)
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
                        onPressed: () => _handleCancel(item),
                        style: OutlinedButton.styleFrom(
                          backgroundColor:
                              const Color(0x1A630ED4), // primary/10
                          foregroundColor: AppColors.primary,
                          side: BorderSide.none,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                        ),
                        child: Text(
                          'Hủy',
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
    );
  }
}
