import 'package:flutter/material.dart';
import '../../../core/realtime/realtime_binding.dart';
import '../../../core/realtime/reliable_read.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/l10n/domain_labels.dart';

import '../../activity/data/activity_models.dart';
import '../../groups/data/group_repository.dart';
import '../../groups/data/models/group_models.dart';
import '../../groups/presentation/widgets/group_widgets.dart';
import '../data/calendar_repository.dart';
import '../data/calendar_models.dart';

class CalendarScreen extends StatefulWidget {
  final CalendarRepository repository;
  final GroupRepository groups;
  final ValueChanged<String> onOpenActivity;
  final VoidCallback onGroups, onChat, onProfile;
  final VoidCallback? onHome;

  const CalendarScreen({
    super.key,
    required this.repository,
    required this.groups,
    required this.onOpenActivity,
    required this.onGroups,
    required this.onChat,
    required this.onProfile,
    this.onHome,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> with RealtimeBinding<CalendarScreen> {
  @override
  String get realtimeScope => 'user:self';
  @override
  String get realtimePrefix => 'CALENDAR_';
  @override
  Set<String> get realtimeAdditionalPrefixes => const {'GROUP_'};
  @override
  Future<void> reloadRealtime() async {
    final types = takeRealtimeEventTypes();
    final accessChanged = types.contains('CALENDAR_ACCESS_CHANGED') || types.any((type) =>
        type.startsWith('GROUP_') && type != 'GROUP_UPDATED' && type != 'GROUP_LIST_CHANGED');
    if (accessChanged) {
      _loadGeneration++;
      setState(() { _activities = const []; _groupId = null; });
    }
    if (accessChanged || types.isEmpty || types.contains('*') || types.any((type) => type.startsWith('GROUP_'))) {
      final groups = _loadGroups();
      setState(() { _groups = groups; });
      try { await groups; } catch (error) {
        if (mounted) setState(() { _error = error; _loading = false; });
        return;
      }
    }
    if (!mounted) return;
    await _loadActivities(silent: true);
  }
  @override
  bool get realtimeReadNeedsRecovery => _error != null && ReadFailure.fromError(_error!)?.retainData == true;
  @override
  void onRealtimeAccessLost() {
    _loadGeneration++; _groupsGeneration++;
    setState(() { _activities = const []; _groups = Future.value(const []); _groupId = null;
      _error = const ApiException(statusCode: 403); _loading = false; });
  }
  int _loadGeneration = 0;
  int _groupsGeneration = 0;
  static const Object _unchanged = Object();

  late DateTime _month;
  late DateTime _selectedDay;
  late Future<List<GroupSummary>> _groups;
  List<CalendarActivity> _activities = const [];
  bool _loading = true;
  Object? _error;
  bool _agenda = false;
  String? _groupId, _status, _rsvp;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
    _groups = _loadGroups();
    _loadActivities();
  }

  Future<List<GroupSummary>> _loadGroups() async {
    final generation = ++_groupsGeneration;
    final groups = (await widget.groups.listGroups(size: 100)).items;
    if (mounted && generation == _groupsGeneration && _groupId != null &&
        !groups.any((group) => group.id == _groupId)) {
      setState(() => _groupId = null);
    }
    return groups;
  }

  Future<void> _loadActivities({bool silent = false}) async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = !silent;
      _error = null;
    });
    final from = DateTime(_month.year, _month.month);
    final to = DateTime(
      _month.year,
      _month.month + 1,
    ).subtract(const Duration(microseconds: 1));
    try {
      final result = await widget.repository.activities(
        from: from,
        to: to,
        groupId: _groupId,
        status: _status,
        rsvp: _rsvp,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _activities = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = error;
        _activities = const [];
        _loading = false;
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _selectedDay = DateTime(_month.year, _month.month, 1);
    });
    _loadActivities();
  }

  void _changeFilter({
    Object? groupId = _unchanged,
    Object? status = _unchanged,
    Object? rsvp = _unchanged,
  }) {
    setState(() {
      if (!identical(groupId, _unchanged)) _groupId = groupId as String?;
      if (!identical(status, _unchanged)) _status = status as String?;
      if (!identical(rsvp, _unchanged)) _rsvp = rsvp as String?;
    });
    _loadActivities();
  }

  void _resetFilters() {
    setState(() {
      _groupId = null;
      _status = null;
      _rsvp = null;
    });
    _loadActivities();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    appBar: AppBar(
      title: const Text('Lịch'),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      actions: [
        IconButton(
          tooltip: 'Làm mới lịch',
          onPressed: _loadActivities,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    bottomNavigationBar: GroupsBottomNavigation(
      currentIndex: 3,
      onTap: (index) {
        if (index == 0) widget.onHome?.call();
        if (index == 1) widget.onGroups();
        if (index == 2) widget.onChat();
        if (index == 4) widget.onProfile();
      },
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Tháng trước',
                      onPressed: () => _changeMonth(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        '${_month.year}-${_month.month.toString().padLeft(2, '0')}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tháng sau',
                      onPressed: () => _changeMonth(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          icon: Icon(Icons.calendar_view_month),
                        ),
                        ButtonSegment(
                          value: true,
                          icon: Icon(Icons.view_agenda_outlined),
                        ),
                      ],
                      selected: {_agenda},
                      onSelectionChanged: (value) {
                        setState(() => _agenda = value.first);
                        _loadActivities();
                      },
                    ),
                  ],
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 0,
                  children: [
                    FutureBuilder<List<GroupSummary>>(
                      future: _groups,
                      builder: (context, snapshot) {
                        final groups = snapshot.data ?? const <GroupSummary>[];
                        return DropdownButton<String?>(
                          key: const Key('calendar_group_filter'),
                          value: _groupId,
                          hint: const Text('Tất cả nhóm'),
                          underline: const SizedBox.shrink(),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Tất cả nhóm'),
                            ),
                            ...groups.map(
                              (g) => DropdownMenuItem(
                                value: g.id,
                                child: Text(g.name),
                              ),
                            ),
                          ],
                          onChanged: (value) => _changeFilter(groupId: value),
                        );
                      },
                    ),
                    _filterDropdown(
                      key: const Key('calendar_rsvp_filter'),
                      value: _rsvp,
                      hint: 'Mọi phản hồi',
                      values: const {
                        'GOING': 'Tham gia',
                        'MAYBE': 'Có thể tham gia',
                        'NOT_GOING': 'Không tham gia',
                        'NO_RESPONSE': 'Chưa phản hồi',
                      },
                      onChanged: (value) => _changeFilter(rsvp: value),
                    ),
                    _filterDropdown(
                      key: const Key('calendar_status_filter'),
                      value: _status,
                      hint: 'Mọi trạng thái',
                      values: {for (final status in ActivityStatus.values) status.wire: status.label},
                      onChanged: (value) => _changeFilter(status: value),
                    ),
                    if (_groupId != null || _rsvp != null || _status != null)
                      TextButton.icon(
                        key: const Key('calendar_clear_filters'),
                        onPressed: _resetFilters,
                        icon: const Icon(Icons.filter_alt_off_outlined),
                        label: const Text('Xóa bộ lọc'),
                      ),
                  ],
                ),
                if (!_agenda) _monthGrid(),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _content()),
        ],
      ),
    ),
  );

  Widget _filterDropdown({
    Key? key,
    required String? value,
    required String hint,
    required Map<String, String> values,
    required ValueChanged<String?> onChanged,
  }) => DropdownButton<String?>(
    key: key,
    value: value,
    hint: Text(hint),
    underline: const SizedBox.shrink(),
    items: [
      DropdownMenuItem<String?>(value: null, child: Text(hint)),
      ...values.entries.map(
        (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
      ),
    ],
    onChanged: onChanged,
  );

  Widget _monthGrid() {
    final first = DateTime(_month.year, _month.month);
    final offset = first.weekday - 1;
    final count = DateTime(_month.year, _month.month + 1, 0).day;
    final weeks = ((offset + count) / 7).ceil();
    return Column(
      children: [
        Row(
          children: [
            for (final label in ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'])
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
          ],
        ),
        for (var week = 0; week < weeks; week++)
          Row(
            children: [
              for (var day = 0; day < 7; day++)
                Expanded(child: _dayCell(week * 7 + day - offset + 1, count)),
            ],
          ),
      ],
    );
  }

  Widget _dayCell(int day, int count) {
    if (day < 1 || day > count) return const SizedBox(height: 40);
    final date = DateTime(_month.year, _month.month, day);
    final hasActivities = _activities.any(
      (a) => _sameDay(a.startAt.toLocal(), date),
    );
    final selected = _sameDay(date, _selectedDay);
    return SizedBox(
      height: 40,
      child: InkWell(
        onTap: () {
          setState(() => _selectedDay = date);
          if (!_agenda) return;
          _loadActivities();
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: selected
                  ? BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    )
                  : null,
              child: Text(
                '$day',
                style: TextStyle(color: selected ? Theme.of(context).colorScheme.onPrimary : null),
              ),
            ),
            if (hasActivities)
              SizedBox(
                height: 3,
                child: Icon(Icons.circle, size: 4, color: Theme.of(context).colorScheme.primary),
              ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Không thể tải lịch.'),
            TextButton.icon(
              onPressed: _loadActivities,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }
    final items = _agenda
        ? _activities
        : _activities
              .where((a) => _sameDay(a.startAt.toLocal(), _selectedDay))
              .toList();
    if (items.isEmpty) {
      return const Center(child: Text('Không có hoạt động trong ngày này.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            key: Key('calendar_activity_${item.id}'),
            title: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${item.groupName} | ${TimeOfDay.fromDateTime(item.startAt.toLocal()).format(context)} | ${item.status.label}',
            ),
            leading: Icon(
              item.reminderEnabled
                  ? Icons.notifications_active_outlined
                  : Icons.event_outlined,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => widget.onOpenActivity(item.id),
          ),
        );
      },
    );
  }

  bool _sameDay(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}
