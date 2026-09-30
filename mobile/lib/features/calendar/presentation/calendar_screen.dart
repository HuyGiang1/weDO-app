import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
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

  const CalendarScreen({
    super.key,
    required this.repository,
    required this.groups,
    required this.onOpenActivity,
    required this.onGroups,
    required this.onChat,
    required this.onProfile,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
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

  Future<List<GroupSummary>> _loadGroups() async =>
      (await widget.groups.listGroups(size: 100)).items;

  Future<void> _loadActivities() async {
    setState(() {
      _loading = true;
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
      if (!mounted) return;
      setState(() {
        _activities = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
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
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Calendar'),
      backgroundColor: AppColors.background,
      actions: [
        IconButton(
          tooltip: 'Refresh calendar',
          onPressed: _loadActivities,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    bottomNavigationBar: GroupsBottomNavigation(
      currentIndex: 3,
      onTap: (index) {
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
                      tooltip: 'Previous month',
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
                      tooltip: 'Next month',
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
                          hint: const Text('All groups'),
                          underline: const SizedBox.shrink(),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All groups'),
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
                      hint: 'RSVP',
                      values: const {
                        'GOING': 'Going',
                        'MAYBE': 'Maybe',
                        'NOT_GOING': 'Not going',
                        'NO_RESPONSE': 'No response',
                      },
                      onChanged: (value) => _changeFilter(rsvp: value),
                    ),
                    _filterDropdown(
                      key: const Key('calendar_status_filter'),
                      value: _status,
                      hint: 'Status',
                      values: const {
                        'PLANNING': 'Planning',
                        'CONFIRMED': 'Confirmed',
                        'IN_PROGRESS': 'In progress',
                        'COMPLETED': 'Completed',
                        'CANCELLED': 'Cancelled',
                      },
                      onChanged: (value) => _changeFilter(status: value),
                    ),
                    if (_groupId != null || _rsvp != null || _status != null)
                      TextButton.icon(
                        key: const Key('calendar_clear_filters'),
                        onPressed: _resetFilters,
                        icon: const Icon(Icons.filter_alt_off_outlined),
                        label: const Text('Clear filters'),
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
      DropdownMenuItem<String?>(value: null, child: Text('All $hint')),
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
            for (final label in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(color: AppColors.onSurfaceVariant),
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
                  ? const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    )
                  : null,
              child: Text(
                '$day',
                style: TextStyle(color: selected ? Colors.white : null),
              ),
            ),
            if (hasActivities)
              const SizedBox(
                height: 3,
                child: Icon(Icons.circle, size: 4, color: AppColors.primary),
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
            const Text('Calendar could not be loaded.'),
            TextButton.icon(
              onPressed: _loadActivities,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
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
      return const Center(child: Text('No activities for this date.'));
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
              '${item.groupName} | ${TimeOfDay.fromDateTime(item.startAt.toLocal()).format(context)} | ${item.status.wire}',
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
