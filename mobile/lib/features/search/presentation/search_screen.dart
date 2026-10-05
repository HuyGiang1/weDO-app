import 'dart:async';

import 'package:flutter/material.dart';

import '../../groups/data/group_repository.dart';
import '../../groups/presentation/widgets/group_widgets.dart';
import '../../profile/data/profile_repository.dart';
import '../../social/presentation/widgets/user_avatar.dart';
import '../application/search_controller.dart' as search;
import '../data/search_models.dart';

class SearchScreen extends StatefulWidget {
  final search.SearchController controller;
  final ProfileRepository profileRepository;
  final GroupRepository groupRepository;
  final ValueChanged<SearchPerson> onOpenPerson;
  final ValueChanged<SearchGroup> onOpenGroup;
  final ValueChanged<SearchActivity> onOpenActivity;
  final ValueChanged<SearchConversation> onOpenConversation;

  const SearchScreen({
    super.key,
    required this.controller,
    required this.profileRepository,
    required this.groupRepository,
    required this.onOpenPerson,
    required this.onOpenGroup,
    required this.onOpenActivity,
    required this.onOpenConversation,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _tabs = <String>[
    'Tất cả',
    'Mọi người',
    'Nhóm',
    'Hoạt động',
    'Trò chuyện',
  ];
  final _query = TextEditingController();
  final _scroll = ScrollController();
  final _avatarKeys = <String, Future<String?>>{};
  Timer? _debounce;
  int _tab = 0;

  SearchCategory? get _category => switch (_tab) {
    1 => SearchCategory.people,
    2 => SearchCategory.groups,
    3 => SearchCategory.activities,
    4 => SearchCategory.conversations,
    _ => null,
  };

  @override
  void initState() {
    super.initState();
    _query.addListener(_scheduleSearch);
    _scroll.addListener(_maybeLoadMore);
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    final value = _query.text.trim();
    widget.controller.prepare(value, _category);
    if (value.length < 2) {
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      widget.controller.search(value, _category);
    });
  }

  void _selectTab(int index) {
    if (_tab == index) return;
    setState(() => _tab = index);
    _scheduleSearch();
  }

  void _maybeLoadMore() {
    if (_scroll.position.extentAfter < 360) {
      unawaited(widget.controller.loadMore());
    }
  }

  Future<String?> _avatarKey(String id, bool isGroup) =>
      _avatarKeys.putIfAbsent(id, () async {
        try {
          if (isGroup) {
            return (await widget.groupRepository.getGroup(id)).avatarStorageKey;
          }
          return (await widget.profileRepository.getPublicProfile(id))
              .avatarStorageKey;
        } catch (_) {
          return null;
        }
      });

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _scroll.dispose();
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tìm kiếm')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: TextField(
            controller: _query,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Tìm người, nhóm, hoạt động, trò chuyện',
              suffixIcon: _query.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xóa tìm kiếm',
                      onPressed: _query.clear,
                      icon: const Icon(Icons.close),
                    ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: List.generate(
                _tabs.length,
                (index) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: ChoiceChip(
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      labelPadding: EdgeInsets.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 6,
                      ),
                      label: SizedBox(
                        width: double.infinity,
                        child: Text(
                          _tabs[index],
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      selected: _tab == index,
                      onSelected: (_) => _selectTab(index),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) => _buildResults(),
          ),
        ),
      ],
    ),
  );

  Widget _buildResults() {
    final state = widget.controller;
    if (_query.text.trim().length < 2) {
      return const Center(child: Text('Nhập ít nhất 2 ký tự'));
    }
    if (state.loading && state.response == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.response == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Không thể tìm kiếm lúc này'),
            TextButton(
              onPressed: _scheduleSearch,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }
    final response = state.response;
    if (response == null) return const SizedBox.shrink();
    final children = <Widget>[];
    if (_category == null || _category == SearchCategory.people) {
      _addSection<SearchPerson>(
        children,
        'Mọi người',
        response.people,
        _personTile,
        () => _selectTab(1),
      );
    }
    if (_category == null || _category == SearchCategory.groups) {
      _addSection<SearchGroup>(
        children,
        'Nhóm',
        response.groups,
        _groupTile,
        () => _selectTab(2),
      );
    }
    if (_category == null || _category == SearchCategory.activities) {
      _addSection<SearchActivity>(
        children,
        'Hoạt động',
        response.activities,
        _activityTile,
        () => _selectTab(3),
      );
    }
    if (_category == null || _category == SearchCategory.conversations) {
      _addSection<SearchConversation>(
        children,
        'Trò chuyện',
        response.conversations,
        _conversationTile,
        () => _selectTab(4),
      );
    }
    if (children.isEmpty) {
      return const Center(child: Text('Không tìm thấy kết quả'));
    }
    if (state.loadingMore) {
      children.add(
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return ListView(controller: _scroll, children: children);
  }

  void _addSection<T>(
    List<Widget> children,
    String title,
    SearchSection<T>? section,
    Widget Function(T item) tile,
    VoidCallback showAll,
  ) {
    if (section == null || section.items.isEmpty) return;
    children.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (_category == null && section.hasMore)
              TextButton(onPressed: showAll, child: const Text('Xem tất cả')),
          ],
        ),
      ),
    );
    children.addAll(section.items.map(tile));
  }

  Widget _personTile(SearchPerson value) => FutureBuilder<String?>(
    future: value.avatarAvailable ? _avatarKey(value.id, false) : null,
    builder: (context, snapshot) => ListTile(
      leading: UserAvatar(
        displayName: value.displayName ?? value.username ?? '?',
        avatarStorageKey: snapshot.data,
      ),
      title: Text(value.displayName ?? value.username ?? 'Người dùng'),
      subtitle: value.username == null ? null : Text('@${value.username}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => widget.onOpenPerson(value),
    ),
  );

  Widget _groupTile(SearchGroup value) => FutureBuilder<String?>(
    future: value.avatarAvailable ? _avatarKey(value.id, true) : null,
    builder: (context, snapshot) => ListTile(
      leading: GroupAvatar(
        name: value.name,
        radius: 22,
        avatarStorageKey: snapshot.data,
      ),
      title: Text(value.name),
      subtitle: Text(value.status.name),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => widget.onOpenGroup(value),
    ),
  );

  Widget _activityTile(SearchActivity value) => ListTile(
    leading: const CircleAvatar(child: Icon(Icons.event_outlined)),
    title: Text(value.title),
    subtitle: Text(value.location?.name ?? value.status.name),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => widget.onOpenActivity(value),
  );

  Widget _conversationTile(SearchConversation value) => ListTile(
    leading: CircleAvatar(
      child: Icon(
        value.kind == 'GROUP' ? Icons.groups_outlined : Icons.person_outline,
      ),
    ),
    title: Text(value.title),
    subtitle: Text(
      value.matchedTextSnippet,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => widget.onOpenConversation(value),
  );
}
