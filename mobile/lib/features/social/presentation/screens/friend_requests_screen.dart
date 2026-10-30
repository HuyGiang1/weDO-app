import 'package:flutter/material.dart';
import '../../../../core/realtime/realtime_binding.dart';

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
    with SingleTickerProviderStateMixin, RealtimeBinding<FriendRequestsScreen> {
  @override
  String? get realtimeScope => 'user:self';
  @override
  String get realtimePrefix => 'FRIEND_';
  @override
  Future<void> reloadRealtime() async { await Future.wait([widget.controller.loadReceived(refresh: true), widget.controller.loadSent(refresh: true)]); }

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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 64.0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.of(context).canPop()
            ? Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  tooltip: 'Quay lại',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              )
            : null,
        title: Text(
          'Lời mời kết bạn',
          style: AppTextStyles.of(context).headline.copyWith(
            fontSize: 24.0,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48.0),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  width: 1.0,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
              indicatorColor: Theme.of(context).colorScheme.primary,
              indicatorWeight: 2.0,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelStyle: AppTextStyles.of(context).label.copyWith(
                fontSize: 14.0,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: AppTextStyles.of(context).label.copyWith(
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
          return Center(
            child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
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
            color: Theme.of(context).colorScheme.primary,
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
          color: Theme.of(context).colorScheme.primary,
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
                return Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Center(
                    child: SizedBox(
                      width: 24.0,
                      height: 24.0,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                );
              }

              final item = state.items[index];
              final isActionPending = _activeActionRequestId == item.id;

              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12.0),

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
                            style: AppTextStyles.of(context).label.copyWith(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            '@${item.sender.username}',
                            style: AppTextStyles.of(context).bodyMedium.copyWith(
                              fontSize: 14.0,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    if (isActionPending)
                      SizedBox(
                        width: 24.0,
                        height: 24.0,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton(
                            onPressed: () => _handleDecline(item),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
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
                              style: AppTextStyles.of(context).label.copyWith(
                                fontSize: 14.0,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          FilledButton(
                            onPressed: () => _handleAccept(item),
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              elevation: 1.0,
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 8.0,
                              ),
                            ),
                            child: Text(
                              'Chấp nhận',
                              style: AppTextStyles.of(context).label.copyWith(
                                fontSize: 14.0,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onPrimary,
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
          return Center(
            child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
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
            color: Theme.of(context).colorScheme.primary,
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
          color: Theme.of(context).colorScheme.primary,
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
                return Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Center(
                    child: SizedBox(
                      width: 24.0,
                      height: 24.0,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                );
              }

              final item = state.items[index];
              final isCanceling = _cancelingRequestId == item.id;

              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12.0),

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
                            style: AppTextStyles.of(context).label.copyWith(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            '@${item.receiver.username}',
                            style: AppTextStyles.of(context).bodyMedium.copyWith(
                              fontSize: 14.0,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    if (isCanceling)
                      SizedBox(
                        width: 24.0,
                        height: 24.0,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    else
                      OutlinedButton(
                        onPressed: () => _handleCancel(item),
                        style: OutlinedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.surfaceContainer, // primary/10
                          foregroundColor: Theme.of(context).colorScheme.primary,
                          side: BorderSide.none,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                        ),
                        child: Text(
                          'Hủy',
                          style: AppTextStyles.of(context).label.copyWith(
                            fontSize: 14.0,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
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
