import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/routes.dart';
import '../../../app/navigation/app_bottom_navigation.dart';
import '../../../app/navigation/tab_chrome.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/realtime/realtime_binding.dart';
import '../../../core/realtime/realtime_sync.dart';
import '../../../core/realtime/reliable_read.dart';
import '../../moments/data/moment_models.dart';
import '../../moments/data/moments_api.dart';
import '../../moments/presentation/memory_media.dart';
import '../../moments/presentation/memories_screen.dart'
    show memoryNotice, memoryConfirm;
import '../../social/presentation/widgets/user_avatar.dart';
import '../data/community_api.dart';
import '../data/recruitment_api.dart';
import 'recruitment_screen.dart';
import '../data/moderation_api.dart';
import 'moderation_screen.dart';

String communityTime(DateTime value) {
  final age = DateTime.now().difference(value);
  if (age.inMinutes < 1) return 'Vừa xong';
  if (age.inHours < 1) return '${age.inMinutes} phút trước';
  if (age.inDays < 1) return '${age.inHours} giờ trước';
  final d = value.toLocal();
  return '${d.day}/${d.month}/${d.year}';
}

/// Shrink-wrapped resource read; never places Expanded inside a scrolling card.
class CommunityRead<T> extends StatelessWidget {
  final bool bounded;
  final ReliableRead<T> read;
  final VoidCallback retry;
  final Widget Function(T, bool) content;
  const CommunityRead({
    super.key,
    required this.read,
    required this.retry,
    required this.content,
    this.bounded = false,
  });
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: read,
    builder: (context, s, _) => Column(
      mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (read.failure != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh),
              label: Text(read.failure!.message),
            ),
          ),
        if (s.hasData)
          if (bounded)
            Expanded(child: content(s.requireData, read.failure == null))
          else
            content(s.requireData, read.failure == null)
        else if (s.connectionState == ConnectionState.waiting)
          const Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
      ],
    ),
  );
}

class CommunityScreen extends StatefulWidget {
  final CommunityApi api;
  final String? author;
  final bool rootTab;
  const CommunityScreen({super.key, required this.api, this.author, this.rootTab = false});
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _FeedSnapshot {
  final List<CommunityPost> posts;
  final String? next;
  final int pages;
  final double offset;
  final bool newPosts, expired;
  const _FeedSnapshot(this.posts, this.next, this.pages, this.offset, this.newPosts, this.expired);
}

class _CommunityScreenState extends State<CommunityScreen>
    with RealtimeBinding<CommunityScreen> {
  final read = ReliableRead<List<CommunityPost>>();
  final scroll = ScrollController();
  final _localChrome = TabChromeController();
  bool _userScroll = false;
  double _travel = 0;
  int _scrollSign = 0;
  bool get _immersive => widget.rootTab && widget.author == null;
  TabChromeController get _chrome => TabChromeScope.maybeOf(context) ?? _localChrome;

  bool _onFeedScroll(ScrollNotification event) {
    if (!_immersive || event.depth != 0 || MediaQuery.accessibleNavigationOf(context)) return false;
    if (event is ScrollStartNotification) {
      _userScroll = event.dragDetails != null;
      _travel = 0; _scrollSign = 0;
    }
    if (_userScroll && event.metrics.pixels <= event.metrics.minScrollExtent + 1) {
      _chrome.request(true); _travel = 0;
    } else if (_userScroll && event is ScrollUpdateNotification) {
      final delta = event.scrollDelta ?? 0;
      if (delta != 0) {
        final sign = delta > 0 ? 1 : -1;
        if (sign != _scrollSign) { _travel = 0; _scrollSign = sign; }
        _travel += delta.abs();
        if (_travel >= 24) { _chrome.request(sign < 0); _travel = 0; }
      }
    }
    if (event is ScrollEndNotification) { _userScroll = false; _travel = 0; }
    return false;
  }

  void _search() {
    _chrome.show();
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _CommunitySearchHub(api: widget.api, viewer: viewer)));
  }

  String? viewer, next;
  String mode = 'FOR_YOU';
  bool newPosts = false, more = false, cursorExpired = false;
  final _feeds = <String, _FeedSnapshot>{};
  final _changedPostIds = <String>{};
  List<String>? _policyVisibleIds;
  int loadedPages = 1;
  RealtimeSync? policySync;
  void Function()? unwatchPolicy;
  @override
  String? get realtimeScope => viewer == null ? null : 'community:$viewer';
  @override
  String get realtimePrefix => 'COMMUNITY_';
  @override
  bool get realtimeReadNeedsRecovery => read.failure?.retainData == true;
  @override
  void onRealtimeAccessLost() {
    _feeds.clear(); _policyVisibleIds = null; _changedPostIds.clear();
    read.denyAccess();
  }
  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    bindPolicy();
  }

  void bindPolicy() {
    final sync = RealtimeHost.maybeOf(context);
    if (policySync == sync && unwatchPolicy != null) return;
    unwatchPolicy?.call();
    policySync = sync;
    if (viewer != null && sync != null) {
      unwatchPolicy = sync.watch(
        'community:$viewer',
        'COMMUNITY_',
        () {},
        onChange: (event) {
          if (event == null) return;
          if (event.eventType == 'COMMUNITY_POLICY_CHANGED') {
            // Cached tabs must never restore a previously protected card.
            _policyVisibleIds = read.value.data?.map((p) => p.id).toList();
            _feeds.clear();
            read.reset();
          } else {
            _changedPostIds.add(event.aggregateId);
          }
        },
      );
    }
  }

  @override
  Future<void> reloadRealtime() async {
    final types = takeRealtimeEventTypes();
    if (types.isNotEmpty &&
        types.every(
          (t) =>
              t == 'COMMUNITY_POST_CREATED' ||
              t == 'COMMUNITY_RECRUITMENT_CREATED',
        ) &&
        read.value.hasData) {
      _changedPostIds.clear();
      if (mounted) setState(() => newPosts = true);
      return;
    }
    final ids = Set<String>.of(_changedPostIds);
    _changedPostIds.clear();
    // Existing binding marks reconnect/resubscribe with '*', not a post ID.
    final resync = types.isEmpty || types.contains('*');
    await refreshVisible(changed: resync ? null : ids, discoverMissed: resync);
  }

  // Revalidate visible IDs without replacing accepted order/cursor. A resync
  // probes discovery only for the update indicator; policy grants reconcile it.
  Future<void> refreshVisible({Set<String>? changed, List<CommunityPost>? snapshot, bool discoverMissed = false}) async {
    final old = snapshot ?? read.value.data ?? <CommunityPost>[];
    final policyIds = _policyVisibleIds;
    _policyVisibleIds = null;
    if (old.isEmpty && policyIds == null) { await refresh(); return; }
    final ids = policyIds ?? old.map((p) => p.id).toList();
    final existing = {for (final p in old) p.id: p};
    final selectedMode = widget.author == null ? mode : 'PROFILE';
    String? policyCursor;
    int policyPages = 0;
    bool unseen = false;
    await read.load(() async {
      final targets = ids.where((id) => policyIds != null || changed == null || changed.contains(id)).toList();
      final updated = <String, CommunityPost>{};
      // Bounded REST batches; no ranking/cursor reset, no new transport.
      for (int start = 0; start < targets.length; start += 20) {
        final batch = targets.sublist(start, (start + 20).clamp(0, targets.length));
        final values = await widget.api.refreshPosts(selectedMode, batch, author: widget.author);
        for (final p in values) { updated[p.id] = p; }
      }
      final discovered = <CommunityPost>[];
      if (policyIds != null) {
        // A block/visibility change can also grant access (unblock/unhide/join).
        // Reconcile discovery once, then append newly eligible IDs rather than
        // reshuffling retained cards. Reaction/comment/reconnect skips this.
        for (int page = 0; page < loadedPages; page++) {
          if (!mounted) return <CommunityPost>[];
          final fresh = await widget.api.posts(selectedMode, author: widget.author, before: policyCursor);
          discovered.addAll(fresh.items);
          policyCursor = fresh.next; policyPages++;
          if (policyCursor == null) break;
        }
      }
      final result = <CommunityPost>[];
      final targeted = targets.toSet();
      for (final id in ids) {
        final p = targeted.contains(id) ? updated[id] : existing[id];
        if (p != null) result.add(p);
      }
      final retained = result.map((p) => p.id).toSet();
      for (final p in discovered) { if (retained.add(p.id)) result.add(p); }
      if (discoverMissed && policyIds == null && widget.author == null) {
        final head = await widget.api.posts(selectedMode);
        unseen = head.items.any((p) => !retained.contains(p.id));
      }
      return result;
    }, onData: (_) {
      if (unseen && mounted) setState(() => newPosts = true);
      if (policyIds != null && mounted) {
        setState(() { next = policyCursor; loadedPages = policyPages; cursorExpired = false; });
      }
    });
  }

  void selectFeed(String selected) {
    if (selected == mode) return;
    final data = read.value.data;
    if (data != null && read.failure == null) {
      _feeds[mode] = _FeedSnapshot(data, next, loadedPages,
          scroll.hasClients ? scroll.offset : 0, newPosts, cursorExpired);
    }
    final cached = _feeds[selected];
    read.reset(); _policyVisibleIds = null; _changedPostIds.clear();
    setState(() {
      mode = selected; more = false;
      next = cached?.next; loadedPages = cached?.pages ?? 1;
      newPosts = cached?.newPosts ?? false; cursorExpired = cached?.expired ?? false;
    });
    if (cached == null) {
      refresh();
    } else {
      // Revalidate before showing cached protected DTOs on a tab return.
      refreshVisible(snapshot: cached.posts).then((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && mode == selected && scroll.hasClients) {
            scroll.jumpTo(cached.offset.clamp(0, scroll.position.maxScrollExtent));
          }
        });
      });
    }
  }

  Future<void> refresh({bool older = false}) async {
    final old = read.value.data ?? <CommunityPost>[];
    String? cursor;
    int fetchedPages = 0;
    bool expired = false;
    await read.load(
      () async {
        if (viewer == null) {
          final id = await widget.api.viewer();
          if (!mounted) return <CommunityPost>[];
          setState(() => viewer = id);
          refreshRealtimeBindings();
          bindPolicy();
        }
        final items = <CommunityPost>[];
        cursor = older ? next : null;
        for (int page = 0; page < (older ? 1 : loadedPages); page++) {
          MemoryPage<CommunityPost> p;
          try {
            p = await widget.api.posts(
              widget.author == null ? mode : 'PROFILE',
              author: widget.author,
              before: cursor,
            );
          } on ApiException catch (e) {
            if (!older || e.code != 'COMMUNITY_FEED_CURSOR_INVALID') rethrow;
            expired = true; cursor = null;
            return old;
          }
          if (!mounted) return <CommunityPost>[];
          fetchedPages++;
          items.addAll(p.items);
          cursor = p.next;
          if (cursor == null) break;
        }
        return {
          for (final p in [...(older ? old : <CommunityPost>[]), ...items])
            p.id: p,
        }.values.toList();
      },
      onData: (_) {
        if (mounted) {
          setState(() {
            next = cursor;
            loadedPages = older ? loadedPages + 1 : fetchedPages;
            cursorExpired = expired;
            newPosts = expired;
          });
        }
      },
    );
  }

  Future<void> compose() async {
    if (viewer == null) return;
    final type = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Bài viết'),
              onTap: () => Navigator.pop(c, 'GENERAL'),
            ),
            ListTile(
              leading: const Icon(Icons.group_add_outlined),
              title: const Text('Tìm thành viên'),
              onTap: () => Navigator.pop(c, 'LOOKING_FOR_MEMBERS'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || type == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => type == 'GENERAL'
            ? CommunityComposer(api: widget.api, viewer: viewer!)
            : RecruitmentComposer(api: RecruitmentApi(widget.api.dio)),
      ),
    );
    if (mounted) await refresh();
  }

  @override
  void dispose() {
    unwatchPolicy?.call();
    read.dispose();
    scroll.dispose();
    _localChrome.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final header = AppBar(
      primary: !_immersive,
      title: Text(widget.author == null ? 'Cộng đồng' : 'Bài viết'),
      actions: [
        if (widget.author == null) IconButton(tooltip: 'Tìm kiếm Cộng đồng', onPressed: _search, icon: const Icon(Icons.search_outlined)),
        IconButton(
          tooltip: 'Quyền riêng tư & an toàn',
          icon: const Icon(Icons.shield_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  CommunitySafetyScreen(api: ModerationApi(widget.api.dio)),
            ),
          ),
        ),
        if (viewer != null)
          IconButton(
            tooltip: 'Bài viết của tôi',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    CommunityScreen(api: widget.api, author: viewer),
              ),
            ),
            icon: const Icon(Icons.person_outline),
          ),
        IconButton(
          tooltip: 'Đăng bài',
          onPressed: viewer == null ? null : compose,
          icon: const Icon(Icons.edit_outlined),
        ),
      ],
    );
    final controls = <Widget>[
if (widget.author == null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'FOR_YOU', label: Text('Dành cho bạn')),
                ButtonSegment(value: 'FRIENDS', label: Text('Bạn bè')),
              ],
              selected: {mode},
              onSelectionChanged: (v) {
                selectFeed(v.first);
              },
            ),
          ),
        if (widget.author == null)
          TextButton.icon(
            onPressed: viewer == null
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RecruitmentDiscovery(
                        api: RecruitmentApi(widget.api.dio),
                        viewer: viewer!,
                      ),
                    ),
                  ),
            icon: const Icon(Icons.people_outline),
            label: const Text('Tìm người đồng hành'),
          ),
        if (newPosts)
          TextButton(
            onPressed: () => refresh(),
            child: Text(cursorExpired ? 'Phiên danh sách đã hết hạn · Tải lại' : 'Có bài viết mới · Xem cập nhật'),
          ),
    ];
    final feed = Expanded(
          child: CommunityRead(
            bounded: true,
            read: read,
            retry: () => refresh(),
            content: (posts, enabled) => posts.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Chưa có bài viết phù hợp. Chia sẻ điều thú vị đầu tiên nhé!',
                      ),
                    ),
                  )
                : NotificationListener<ScrollNotification>(onNotification: _onFeedScroll, child: RefreshIndicator(onRefresh: refresh, child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    controller: scroll,
                    key: PageStorageKey('community-$mode-${widget.author}'),
                    padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + MediaQuery.viewPaddingOf(context).bottom),
                    itemCount: posts.length + (next != null ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == posts.length) {
                        return TextButton(
                          onPressed: enabled && !more
                              ? () async {
                                  setState(() => more = true);
                                  await refresh(older: true);
                                  if (mounted) setState(() => more = false);
                                }
                              : null,
                          child: Text(more ? 'Đang tải…' : 'Xem bài cũ hơn'),
                        );
                      }
                      return AbsorbPointer(
                        absorbing: !enabled,
                        child: CommunityCard(
                          key: ValueKey(posts[i].id),
                          api: widget.api,
                          initial: posts[i],
                          viewer: viewer!,
                          onRemoved: () {
                            _feeds.clear();
                            refreshVisible(changed: {posts[i].id});
                          },
                        ),
                      );
                    },
                  ))),
          ),
        );
    if (!_immersive) return Scaffold(appBar: header, body: Column(children: [...controls, feed]));
    return ValueListenableBuilder(
      valueListenable: read,
      builder: (context, snapshot, _) {
        final unavailable = !snapshot.hasData || snapshot.requireData.isEmpty;
        return Scaffold(
          bottomNavigationBar: AppBottomNavigation(selectedIndex: 0, chrome: _chrome, forceChromeVisible: unavailable),
          body: SafeArea(bottom: false, child: Stack(children: [
            Column(children: [
              TabChromeRegion(controller: _chrome, forceVisible: unavailable, child: Column(children: [SizedBox(height: kToolbarHeight, child: header), ...controls])),
              feed,
            ]),
            Positioned(right: 12, bottom: 12 + MediaQuery.viewPaddingOf(context).bottom, child: ValueListenableBuilder<bool>(
              valueListenable: _chrome,
              builder: (context, visible, _) => visible || unavailable || MediaQuery.accessibleNavigationOf(context)
                ? const SizedBox.shrink()
                : IconButton.filledTonal(tooltip: 'Hiện điều hướng', onPressed: _chrome.show, icon: const Icon(Icons.keyboard_arrow_up)),
            )),
          ])),
        );
      },
    );
  }

}

/// Navigation to supported existing searches; never filters the live feed locally.
class _CommunitySearchHub extends StatelessWidget {
  final CommunityApi api;
  final String? viewer;
  const _CommunitySearchHub({required this.api, required this.viewer});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tìm kiếm Cộng đồng')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      Text('Bạn muốn tìm gì?', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      ListTile(leading: const Icon(Icons.person_search_outlined), title: const Text('Mọi người và nội dung của bạn'), subtitle: const Text('Tìm người, nhóm, hoạt động và trò chuyện'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.of(context).pushNamed(AppRoutes.search)),
      const Divider(),
      ListTile(leading: const Icon(Icons.group_add_outlined), title: const Text('Tin tuyển thành viên'), subtitle: const Text('Tìm theo từ khóa, sở thích, khu vực và thời gian'), trailing: const Icon(Icons.chevron_right), enabled: viewer != null, onTap: viewer == null ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RecruitmentDiscovery(api: RecruitmentApi(api.dio), viewer: viewer!)))),
    ]),
  );
}

class CommunityComposer extends StatefulWidget {
  final CommunityApi api;
  final String viewer;
  final CommunityPost? initial;
  final Future<List<XFile>> Function()? pickImages;
  const CommunityComposer({
    super.key,
    required this.api,
    required this.viewer,
    this.initial,
    this.pickImages,
  });
  @override
  State<CommunityComposer> createState() => _CommunityComposerState();
}

class _CommunityComposerState extends State<CommunityComposer>
    with RealtimeBinding<CommunityComposer> {
  final text = TextEditingController();
  final id = MomentsApi.commandId();
  final files = <XFile>[];
  final uploaded = <String, String>{};
  List<(String, String)> groups = [];
  String visibility = 'PUBLIC';
  String? group;
  bool busy = false, blocked = false, groupsReady = false;
  double progress = 0;
  int generation = 0;
  @override
  String get realtimeScope =>
      widget.initial == null ? 'user:self' : 'post:${widget.initial!.id}';
  @override
  String get realtimePrefix => widget.initial == null ? 'GROUP_' : 'COMMUNITY_';
  @override
  void onRealtimeAccessLost() {
    generation++;
    if (mounted) {
      setState(() {
        blocked = true;
        files.clear();
        uploaded.clear();
        text.clear();
        groups.clear();
        group = null;
      });
    }
  }

  @override
  Future<void> reloadRealtime() async {
    final g = ++generation;
    if (mounted) {
      setState(() {
        groupsReady = false;
        groups = [];
      });
    }
    try {
      if (widget.initial != null) await widget.api.post(widget.initial!.id);
      final list = await widget.api.writableGroups();
      if (mounted && g == generation) {
        setState(() {
          groups = list;
          groupsReady = true;
          if (group != null && !groups.any((v) => v.$1 == group)) group = null;
        });
      }
    } on ApiException catch (e) {
      if ([401, 403, 404].contains(e.statusCode)) onRealtimeAccessLost();
    }
  }

  @override
  void initState() {
    super.initState();
    text.text = widget.initial?.caption ?? '';
    visibility = widget.initial?.visibility ?? 'PUBLIC';
    group = widget.initial?.groupId;
    reloadRealtime();
  }

  Future<void> pick() async {
    try {
      final picked =
          await (widget.pickImages?.call() ?? ImagePicker().pickMultiImage());
      if (!mounted || blocked) return;
      if (files.length + picked.length > 8) {
        memoryNotice(
          context,
          const ApiException(statusCode: 400, message: 'Tối đa 8 ảnh mỗi bài.'),
        );
        return;
      }
      setState(() => files.addAll(picked));
    } catch (e) {
      if (mounted) memoryNotice(context, e);
    }
  }

  Future<void> save() async {
    if (busy || blocked) return;
    if (text.text.trim().isEmpty &&
        files.isEmpty &&
        (widget.initial?.media.isEmpty ?? true)) {
      return;
    }
    if (visibility == 'GROUP_ONLY' && (!groupsReady || group == null)) {
      memoryNotice(
        context,
        const ApiException(
          statusCode: 400,
          message: 'Chọn nhóm bạn đang tham gia.',
        ),
      );
      return;
    }
    setState(() => busy = true);
    final g = generation;
    try {
      final keys = <String>[];
      for (int i = 0; i < files.length; i++) {
        final file = files[i], cache = '$i:${files[i].path}:${files[i].name}';
        final key =
            uploaded[cache] ??
            await widget.api.uploadPhoto(
              widget.viewer,
              file,
              progress: (sent, total) {
                if (mounted && g == generation) {
                  setState(
                    () => progress =
                        (i + (total == 0 ? 0 : sent / total)) / files.length,
                  );
                }
              },
            );
        if (!mounted || g != generation || blocked) return;
        uploaded[cache] = key;
        keys.add(key);
      }
      if (!mounted || g != generation || blocked) return;
      if (widget.initial == null) {
        await widget.api.publish(
          id,
          text.text.trim(),
          visibility,
          visibility == 'GROUP_ONLY' ? group : null,
          keys,
        );
      } else {
        await widget.api.updatePost(
          widget.initial!,
          text.text.trim(),
          visibility,
          visibility == 'GROUP_ONLY' ? group : null,
        );
      }
      if (mounted && g == generation) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) memoryNotice(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    generation++;
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.initial == null ? 'Chia sẻ với cộng đồng' : 'Sửa bài viết',
      ),
      actions: [
        IconButton(
          tooltip: 'Ẩn bàn phím',
          onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
          icon: const Icon(Icons.keyboard_hide_outlined),
        ),
      ],
    ),
    body: blocked
        ? const Center(child: Text('Bạn không còn quyền truy cập bài viết.'))
        : ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                controller: text,
                enabled: !busy,
                maxLength: 5000,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: 'Bạn muốn chia sẻ điều gì?',

                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: visibility,
                decoration: const InputDecoration(labelText: 'Ai có thể xem?'),
                items: [
                  for (final e in communityVisibility.entries)
                    DropdownMenuItem(
                      value: e.key,
                      enabled: e.key != 'GROUP_ONLY' || groupsReady,
                      child: Text(e.value),
                    ),
                ],
                onChanged: busy ? null : (v) => setState(() => visibility = v!),
              ),
              if (visibility == 'GROUP_ONLY')
                DropdownButtonFormField<String>(
                  initialValue: group,
                  decoration: const InputDecoration(
                    labelText: 'Nhóm sở hữu bài viết',
                  ),
                  items: [
                    for (final g in groups)
                      DropdownMenuItem(value: g.$1, child: Text(g.$2)),
                  ],
                  onChanged: busy ? null : (v) => setState(() => group = v),
                ),
              if (!groupsReady)
                TextButton(
                  onPressed: busy ? null : reloadRealtime,
                  child: const Text('Tải lại danh sách nhóm'),
                ),
              if (widget.initial == null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: busy ? null : pick,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Chọn ảnh'),
                ),
                for (final f in files)
                  ListTile(
                    leading: const Icon(Icons.image_outlined),
                    title: Text(f.name),
                    trailing: IconButton(
                      tooltip: 'Bỏ ảnh',
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              files.remove(f);
                              uploaded.clear();
                            }),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                const Text('Tối đa 8 ảnh JPG/PNG/WebP · 10 MB mỗi ảnh'),
              ],
              if (busy)
                LinearProgressIndicator(value: progress > 0 ? progress : null),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: busy ? null : save,
                child: Text(busy ? 'Đang lưu…' : 'Đăng bài'),
              ),
            ],
          ),
  );
}

class CommunityCard extends StatefulWidget {
  final CommunityApi api;
  final CommunityPost initial;
  final String viewer;
  final bool detail;
  final VoidCallback? onRemoved;
  const CommunityCard({
    super.key,
    required this.api,
    required this.initial,
    required this.viewer,
    this.detail = false,
    this.onRemoved,
  });
  @override
  State<CommunityCard> createState() => _CommunityCardState();
}

class _CommunityCardState extends State<CommunityCard>
    with RealtimeBinding<CommunityCard> {
  final read = ReliableRead<CommunityPost>();
  final comments = ReliableRead<List<MemoryComment>>();
  final input = TextEditingController();
  String? commentNext, commentCommand;
  bool busy = false;
  int commentPages = 1;
  @override
  String get realtimeScope => 'post:${widget.initial.id}';
  @override
  String get realtimePrefix => 'COMMUNITY_';
  @override
  bool get realtimeReadNeedsRecovery =>
      read.failure?.retainData == true || comments.failure?.retainData == true;
  @override
  void onRealtimeAccessLost() {
    read.denyAccess();
    comments.denyAccess();
    input.clear();
  }

  @override
  void initState() {
    super.initState();
    read.accept(widget.initial);
    reloadRealtime();
  }

  @override
  Future<void> reloadRealtime() async {
    await read.load(() => widget.api.post(widget.initial.id));
    if (read.failure?.accessDenied == true) {
      comments.denyAccess();
      input.clear();
      return;
    }
    if (widget.detail) await loadComments();
  }

  Future<void> loadComments({bool older = false}) async {
    final old = comments.value.data ?? <MemoryComment>[];
    String? next;
    int fetched = 0;
    await comments.load(
      () async {
        final items = <MemoryComment>[];
        next = older ? commentNext : null;
        for (int page = 0; page < (older ? 1 : commentPages); page++) {
          final p = await widget.api.postComments(
            widget.initial.id,
            before: next,
          );
          if (!mounted) return <MemoryComment>[];
          fetched++;
          items.addAll(p.items);
          next = p.next;
          if (next == null) break;
        }
        return {
          for (final c in [...(older ? old : <MemoryComment>[]), ...items])
            c.id: c,
        }.values.toList();
      },
      onData: (_) {
        commentNext = next;
        commentPages = older ? commentPages + 1 : fetched;
      },
    );
    if (comments.failure?.accessDenied == true) read.denyAccess();
  }

  Future<void> act(Future<void> Function() operation) async {
    if (busy || read.failure != null) return;
    setState(() => busy = true);
    try {
      await operation();
    } catch (e) {
      if (mounted) {
        if (e is ApiException && [401, 403, 404].contains(e.statusCode)) {
          onRealtimeAccessLost();
        }
        memoryNotice(context, e);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> menu(String action, CommunityPost p) async {
    if (action == 'profile') {
      await Navigator.of(context)
          .pushNamed(AppRoutes.publicUserProfile, arguments: p.author.id);
      return;
    }
    if (action == 'posts') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CommunityScreen(api: widget.api, author: p.author.id),
        ),
      );
      return;
    }
    if (action == 'block') {
      if (!await memoryConfirm(
        context,
        'Chặn người này? Quan hệ bạn bè sẽ kết thúc; lịch sử nhóm vẫn được giữ.',
      )) {
        return;
      }
      if (!mounted) return;
      await act(() async {
        await ModerationApi(widget.api.dio).block(p.author.id);
        if (mounted) {
          onRealtimeAccessLost();
          widget.onRemoved?.call();
        }
      });
      return;
    }
    if (action == 'reportUser') {
      final reason = await chooseReportReason(context);
      if (reason == null || !mounted) return;
      await act(() async {
        await ModerationApi(widget.api.dio).reportUser(p.author.id, reason);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã gửi báo cáo người dùng.')),
          );
        }
      });
      return;
    }
    if (action == 'edit') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CommunityComposer(
            api: widget.api,
            viewer: widget.viewer,
            initial: p,
          ),
        ),
      );
      if (mounted) await reloadRealtime();
      return;
    }
    if (action == 'delete' && !await memoryConfirm(context, 'Xóa bài viết?')) {
      return;
    }
    if (!mounted) return;
    await act(() async {
      if (action == 'delete') {
        await widget.api.remove(p.id);
      } else if (action == 'hide') {
        await widget.api.hide(p.id);
      } else if (action.startsWith('report:')) {
        await widget.api.report(p.id, action.substring(7));
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Đã gửi báo cáo.')));
        }
        return;
      }
      if (mounted) {
        onRealtimeAccessLost();
        widget.onRemoved?.call();
      }
    });
  }

  void detail(CommunityPost p) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: const Text('Bài viết'),
          actions: [
            IconButton(
              tooltip: 'Ẩn bàn phím',
              onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
              icon: const Icon(Icons.keyboard_hide_outlined),
            ),
          ],
        ),
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: CommunityCard(
            api: widget.api,
            initial: p,
            viewer: widget.viewer,
            detail: true,
          ),
        ),
      ),
    ),
  );
  @override
  void dispose() {
    read.dispose();
    comments.dispose();
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CommunityRead(
    read: read,
    retry: reloadRealtime,
    content: (p, current) {
      final enabled = current && !busy && p.permissions.interact;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InkWell(
                  onTap: () => menu('profile', p),
                  child: UserAvatar(
                    displayName: p.author.name,
                    avatarStorageKey: p.author.avatar,
                    radius: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => menu('profile', p),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.author.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${communityTime(p.created)} · ${communityVisibility[p.visibility]}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  enabled: current && !busy,
                  tooltip: 'Tùy chọn bài viết',
                  onSelected: (v) => menu(v, p),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'posts',
                      child: Text('Bài viết của người này'),
                    ),
                    if (p.permissions.edit)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Sửa bài viết'),
                      ),
                    if (p.permissions.delete)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Xóa bài viết'),
                      ),
                    if (p.author.id != widget.viewer)
                      const PopupMenuItem(
                        value: 'block',
                        child: Text('Chặn người này'),
                      ),
                    if (p.author.id != widget.viewer)
                      const PopupMenuItem(
                        value: 'reportUser',
                        child: Text('Báo cáo người dùng'),
                      ),
                    const PopupMenuItem(
                      value: 'report:SCAM',
                      child: Text('Báo cáo: lừa đảo'),
                    ),
                    const PopupMenuItem(
                      value: 'hide',
                      child: Text('Ẩn khỏi bảng tin'),
                    ),
                    const PopupMenuItem(
                      value: 'report:SPAM',
                      child: Text('Báo cáo: nội dung rác'),
                    ),
                    const PopupMenuItem(
                      value: 'report:HARASSMENT',
                      child: Text('Báo cáo: quấy rối'),
                    ),
                    const PopupMenuItem(
                      value: 'report:INAPPROPRIATE_CONTENT',
                      child: Text('Báo cáo: không phù hợp'),
                    ),
                    const PopupMenuItem(
                      value: 'report:OTHER',
                      child: Text('Báo cáo: lý do khác'),
                    ),
                  ],
                ),
              ],
            ),
            if (p.caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  p.caption,
                  maxLines: widget.detail ? null : 6,
                  overflow: widget.detail ? null : TextOverflow.ellipsis,
                ),
              ),
            if (p.recruitment != null)
              RecruitmentSnippet(api: widget.api, post: p),
            if (p.media.isNotEmpty)
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: p.media.length == 1 ? 1 : 2,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                children: [
                  for (final m in p.media)
                    InkWell(
                      key: ValueKey(m.id),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CommunityImage(
                            api: widget.api,
                            post: p.id,
                            media: m,
                            items: p.media,
                          ),
                        ),
                      ),
                      child: MemoryMediaView(
                        key: ValueKey('community-image-${m.id}'),
                        media: m,
                        api: widget.api,
                      ),
                    ),
                ],
              ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: enabled
                      ? () => act(() async {
                          final g = read.generation;
                          final next = await widget.api.reactionTo(
                            p.id,
                            p.reaction == null ? '❤️' : null,
                          );
                          if (mounted && read.isCurrent(g)) read.accept(next);
                        })
                      : null,
                  icon: Icon(
                    p.reaction == null ? Icons.favorite_border : Icons.favorite,
                  ),
                  label: Text('${p.reactions} cảm xúc'),
                ),
                TextButton.icon(
                  onPressed: () => detail(p),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: Text('${p.comments} bình luận'),
                ),
              ],
            ),
            if (!widget.detail)
              TextButton(
                onPressed: () => detail(p),
                child: const Text('Xem bài viết'),
              ),
            if (widget.detail) ...[
              CommunityRead(
                read: comments,
                retry: () => loadComments(),
                content: (list, current) => Column(
                  children: [
                    for (final c in list)
                      ListTile(
                        leading: UserAvatar(
                          displayName: c.author.name,
                          avatarStorageKey: c.author.avatar,
                          radius: 16,
                        ),
                        title: Text(c.author.name),
                        subtitle: Text(
                          '${c.text}\n${communityTime(c.createdAt)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Báo cáo bình luận',
                              icon: const Icon(Icons.flag_outlined, size: 18),
                              onPressed: enabled && current
                                  ? () async {
                                      final reason = await chooseReportReason(
                                        context,
                                      );
                                      if (reason == null || !mounted) return;
                                      await act(() async {
                                        await ModerationApi(widget.api.dio)
                                            .reportComment(c.id, reason);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Đã gửi báo cáo bình luận.',
                                                  ),
                                                ),
                                              );
                                        }
                                      });
                                    }
                                  : null,
                            ),
                            if (c.canDelete)
                              IconButton(
                                tooltip: 'Xóa bình luận',
                                onPressed: enabled && current
                                    ? () => act(() async {
                                        await widget.api.removeComment(
                                          p.id,
                                          c.id,
                                        );
                                        if (mounted) await reloadRealtime();
                                      })
                                    : null,
                                icon: const Icon(Icons.close, size: 18),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (commentNext != null)
                TextButton(
                  onPressed: () => loadComments(older: true),
                  child: const Text('Bình luận cũ hơn'),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      controller: input,
                      enabled: enabled,
                      maxLength: 2000,
                      minLines: 1,
                      maxLines: 4,
                      onChanged: (_) => commentCommand = null,
                      decoration: const InputDecoration(
                        hintText: 'Viết bình luận…',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Gửi bình luận',
                    onPressed: enabled
                        ? () => act(() async {
                            if (input.text.trim().isEmpty) return;
                            commentCommand ??= MomentsApi.commandId();
                            final g = read.generation;
                            await widget.api.addPostComment(
                              p.id,
                              commentCommand!,
                              input.text.trim(),
                            );
                            if (!mounted || !read.isCurrent(g)) return;
                            input.clear();
                            commentCommand = null;
                            await reloadRealtime();
                          })
                        : null,
                    icon: const Icon(Icons.send_outlined),
                  ),
                ],
              ),
            ],
            const Divider(height: 24),
          ],
        ),
      );
    },
  );
}

class CommunityImage extends StatelessWidget {
  final CommunityApi api;
  final String post;
  final MemoryMedia media;
  final List<MemoryMedia>? items;
  const CommunityImage({
    super.key,
    required this.api,
    required this.post,
    required this.media,
    this.items,
  });
  @override
  Widget build(BuildContext context) => MemoryGallery(
    media: media,
    items: items ?? [media],
    api: api,
    scope: 'post:$post',
    prefix: 'COMMUNITY_',
    aggregateId: post,
  );
}
