import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/utils/date_time_formatter.dart';
import '../../application/activity_controllers.dart';
import '../../data/activity_failure.dart';
import '../../data/activity_models.dart';

Color _statusColor(ActivityStatus status) => switch (status) {
  ActivityStatus.planning => AppColors.primary,
  ActivityStatus.confirmed => AppColors.secondary,
  ActivityStatus.inProgress => const Color(0xFFE65100),
  ActivityStatus.completed => AppColors.onSurfaceVariant,
  ActivityStatus.cancelled => AppColors.error,
};

Color _statusBgColor(ActivityStatus status) => switch (status) {
  ActivityStatus.planning => AppColors.primaryFixed,
  ActivityStatus.confirmed => const Color(0xFFE0F2F1),
  ActivityStatus.inProgress => const Color(0xFFFFF3E0),
  ActivityStatus.completed => AppColors.surfaceContainer,
  ActivityStatus.cancelled => AppColors.errorContainer,
};

Color _rsvpColor(ActivityRsvpStatus rsvp) => switch (rsvp) {
  ActivityRsvpStatus.going => const Color(0xFF006B5F),
  ActivityRsvpStatus.maybe => const Color(0xFFA15100),
  ActivityRsvpStatus.notGoing ||
  ActivityRsvpStatus.noResponse => AppColors.onSurfaceVariant,
  ActivityRsvpStatus.waitlist => AppColors.primary,
};

Color _rsvpBgColor(ActivityRsvpStatus rsvp) => switch (rsvp) {
  ActivityRsvpStatus.going => const Color(0xFFE0F2F1),
  ActivityRsvpStatus.maybe => const Color(0xFFFFF3E0),
  ActivityRsvpStatus.notGoing ||
  ActivityRsvpStatus.noResponse => AppColors.surfaceContainer,
  ActivityRsvpStatus.waitlist => AppColors.primaryFixed,
};

String _statusVietnamese(ActivityStatus status) => switch (status) {
  ActivityStatus.planning => AppStrings.statusPlanning,
  ActivityStatus.confirmed => AppStrings.statusConfirmed,
  ActivityStatus.inProgress => AppStrings.statusInProgress,
  ActivityStatus.completed => AppStrings.statusCompleted,
  ActivityStatus.cancelled => AppStrings.statusCancelled,
};

String _rsvpVietnamese(ActivityRsvpStatus rsvp) => switch (rsvp) {
  ActivityRsvpStatus.going => AppStrings.rsvpGoing,
  ActivityRsvpStatus.maybe => AppStrings.rsvpInterested,
  ActivityRsvpStatus.notGoing => AppStrings.rsvpNotGoing,
  ActivityRsvpStatus.waitlist => 'Danh sách chờ',
  ActivityRsvpStatus.noResponse => 'Chưa phản hồi',
};

class ActivityListRuntimeScreen extends StatefulWidget {
  final String groupId;
  final ActivityListController controller;
  final ValueChanged<String> onOpen;

  const ActivityListRuntimeScreen({
    super.key,
    required this.groupId,
    required this.controller,
    required this.onOpen,
  });

  @override
  State<ActivityListRuntimeScreen> createState() =>
      _ActivityListRuntimeScreenState();
}

class _ActivityListRuntimeScreenState extends State<ActivityListRuntimeScreen> {
  ActivityStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    widget.controller.load(widget.groupId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Hoạt động',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            tooltip: AppStrings.createActivity,
            onPressed: () => Navigator.of(context)
                .push(
                  MaterialPageRoute<String?>(
                    builder: (_) => ActivityCreateRuntimeScreen(
                      groupId: widget.groupId,
                      controller: widget.controller,
                    ),
                  ),
                )
                .then((newId) {
                  if (newId != null) widget.onOpen(newId);
                }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text(AppStrings.createActivity),
        onPressed: () => Navigator.of(context)
            .push(
              MaterialPageRoute<String?>(
                builder: (_) => ActivityCreateRuntimeScreen(
                  groupId: widget.groupId,
                  controller: widget.controller,
                ),
              ),
            )
            .then((newId) {
              if (newId != null) widget.onOpen(newId);
            }),
      ),
      body: SafeArea(
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: const Text('Tất cả'),
                      selected: _selectedStatus == null,
                      onSelected: (_) => setState(() => _selectedStatus = null),
                    ),
                  ),
                  for (final status in ActivityStatus.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(_statusVietnamese(status)),
                        selected: _selectedStatus == status,
                        onSelected: (selected) => setState(
                          () => _selectedStatus = selected ? status : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<ActivityListState>(
                valueListenable: widget.controller,
                builder: (_, state, _) {
                  if (state.phase == ActivityLoadPhase.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.phase == ActivityLoadPhase.error) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 48,
                              color: AppColors.error,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Không thể tải danh sách hoạt động.',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  widget.controller.load(widget.groupId),
                              icon: const Icon(Icons.refresh),
                              label: const Text(AppStrings.retry),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  if (state.phase == ActivityLoadPhase.empty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.event_available,
                              size: 56,
                              color: AppColors.outline,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Chưa có hoạt động nào',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Hãy bắt đầu lên kế hoạch vui vẻ cùng nhóm bạn!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () => Navigator.of(context)
                                  .push(
                                    MaterialPageRoute<String?>(
                                      builder: (_) =>
                                          ActivityCreateRuntimeScreen(
                                            groupId: widget.groupId,
                                            controller: widget.controller,
                                          ),
                                    ),
                                  )
                                  .then((newId) {
                                    if (newId != null) widget.onOpen(newId);
                                  }),
                              icon: const Icon(Icons.add),
                              label: const Text(AppStrings.createActivity),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final filtered = _selectedStatus == null
                      ? state.items
                      : state.items
                            .where((a) => a.status == _selectedStatus)
                            .toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('Không có hoạt động nào trong mục này.'),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () => widget.controller.load(widget.groupId),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, index) {
                        final item = filtered[index];
                        final scheduleText =
                            AppDateTimeFormatter.formatActivitySchedule(
                              startAt: item.startAt,
                              endAt: item.endAt,
                            );
                        final capacityText = item.maxParticipants == null
                            ? '${item.goingCount} người tham gia'
                            : '${item.goingCount} / ${item.maxParticipants} người tham gia';

                        return Card(
                          color: AppColors.surfaceContainerLowest,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(
                              color: AppColors.outlineVariant,
                              width: 0.8,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => widget.onOpen(item.id),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _statusBgColor(item.status),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          _statusVietnamese(item.status),
                                          style: TextStyle(
                                            color: _statusColor(item.status),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (item.callerRsvpStatus !=
                                          ActivityRsvpStatus.noResponse)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _rsvpBgColor(
                                              item.callerRsvpStatus,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            _rsvpVietnamese(
                                              item.callerRsvpStatus,
                                            ),
                                            style: TextStyle(
                                              color: _rsvpColor(
                                                item.callerRsvpStatus,
                                              ),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.schedule,
                                        size: 16,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        scheduleText,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (item.locationName != null &&
                                      item.locationName!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on_outlined,
                                          size: 16,
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            item.locationName!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        capacityText,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      if (item.waitlistCount > 0)
                                        Text(
                                          '${item.waitlistCount} đang chờ',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.onSurfaceVariant,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ActivityCreateRuntimeScreen extends StatefulWidget {
  final String groupId;
  final ActivityListController controller;

  const ActivityCreateRuntimeScreen({
    super.key,
    required this.groupId,
    required this.controller,
  });

  @override
  State<ActivityCreateRuntimeScreen> createState() =>
      _ActivityCreateRuntimeScreenState();
}

class _ActivityCreateRuntimeScreenState
    extends State<ActivityCreateRuntimeScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _capacity = TextEditingController();
  final _locationName = TextEditingController();
  final _locationAddress = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();

  bool _scheduled = false;
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  bool _hasEndTime = false;
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _endTime = const TimeOfDay(hour: 11, minute: 0);

  bool _hasLocation = false;
  String _locationType = 'PHYSICAL';
  bool _limitedCapacity = false;
  bool _submitting = false;

  String _pad2(int n) => n.toString().padLeft(2, '0');

  void _onStartDateChanged(DateTime picked) {
    setState(() {
      final wasSameDay =
          _startDate.year == _endDate.year &&
          _startDate.month == _endDate.month &&
          _startDate.day == _endDate.day;
      _startDate = picked;
      if (wasSameDay || _endDate.isBefore(_startDate)) {
        _endDate = picked;
      }
    });
  }

  DateTime _buildStart() {
    return DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    ).toUtc();
  }

  DateTime? _buildEnd() {
    if (!_hasEndTime) return null;
    return DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      _endTime.hour,
      _endTime.minute,
    ).toUtc();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    DateTime? start;
    DateTime? end;
    String? timezone;

    if (_scheduled) {
      start = _buildStart();
      end = _buildEnd();
      timezone = 'Asia/Ho_Chi_Minh';

      if (end != null && !end.isAfter(start)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thời gian kết thúc phải sau thời gian bắt đầu.'),
          ),
        );
        return;
      }
    }

    final hasLocationData =
        _hasLocation &&
        (_locationName.text.trim().isNotEmpty ||
            _locationAddress.text.trim().isNotEmpty ||
            _latitude.text.trim().isNotEmpty ||
            _longitude.text.trim().isNotEmpty);

    final lat = double.tryParse(_latitude.text.trim());
    final lng = double.tryParse(_longitude.text.trim());
    final capacity = _limitedCapacity
        ? int.tryParse(_capacity.text.trim())
        : null;

    setState(() => _submitting = true);
    final detail = await widget.controller.create(
      widget.groupId,
      ActivityDraft(
        title: _title.text.trim(),
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        timezone: timezone,
        startAt: start,
        endAt: end,
        location: hasLocationData
            ? ActivityLocation(
                type: _locationType,
                name: _locationName.text.trim().isEmpty
                    ? null
                    : _locationName.text.trim(),
                address: _locationAddress.text.trim().isEmpty
                    ? null
                    : _locationAddress.text.trim(),
                latitude: lat,
                longitude: lng,
              )
            : null,
        maxParticipants: capacity,
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (detail != null) {
      Navigator.of(context).pop(detail.id);
    } else {
      final failure = widget.controller.value.failure;
      final msg = switch (failure?.type) {
        ActivityFailureType.validation =>
          'Dữ liệu không hợp lệ. Vui lòng kiểm tra lại.',
        ActivityFailureType.invalidTime =>
          'Thời gian bắt đầu hoặc kết thúc không hợp lệ.',
        ActivityFailureType.invalidCapacity =>
          'Số người tham gia tối đa không hợp lệ.',
        ActivityFailureType.permission =>
          'Bạn không có quyền tạo hoạt động trong nhóm này.',
        _ => 'Không thể tạo hoạt động. Vui lòng thử lại.',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _capacity.dispose();
    _locationName.dispose();
    _locationAddress.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          AppStrings.createActivity,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            // Basic Info Card
            _card(
              title: 'Thông tin hoạt động',
              icon: Icons.edit_note,
              children: [
                TextFormField(
                  key: const Key('activity-title'),
                  controller: _title,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: '${AppStrings.activityTitleLabel} *',
                    hintText: AppStrings.activityTitleHint,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Vui lòng nhập tên hoạt động'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('activity-description'),
                  controller: _description,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: AppStrings.activityDescLabel,
                    hintText: AppStrings.activityDescHint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Schedule Card with Switch
            _card(
              title: 'Thời gian',
              icon: Icons.calendar_month,
              children: [
                SwitchListTile(
                  key: const Key('activity-schedule-switch'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    AppStrings.scheduleSwitch,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _scheduled
                        ? 'Có thời gian cụ thể'
                        : '${AppStrings.unscheduled} (thảo luận sau)',
                    style: TextStyle(
                      color: _scheduled
                          ? AppColors.primary
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                  value: _scheduled,
                  onChanged: (v) => setState(() {
                    _scheduled = v;
                    if (v && _endDate.isBefore(_startDate)) {
                      _endDate = _startDate;
                    }
                  }),
                ),
                if (_scheduled) ...[
                  const Divider(height: 20),
                  const Text(
                    'Bắt đầu',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('activity-start-date-button'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.event, size: 18),
                          label: Text(
                            AppDateTimeFormatter.formatDate(_startDate),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _startDate,
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 1),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (picked != null) _onStartDateChanged(picked);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('activity-start-time-button'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.schedule, size: 18),
                          label: Text(
                            '${_pad2(_startTime.hour)}:${_pad2(_startTime.minute)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _startTime,
                            );
                            if (picked != null) {
                              setState(() => _startTime = picked);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    key: const Key('activity-end-time-switch'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Thêm thời gian kết thúc',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    value: _hasEndTime,
                    onChanged: (v) => setState(() {
                      _hasEndTime = v;
                      if (v && _endDate.isBefore(_startDate)) {
                        _endDate = _startDate;
                      }
                    }),
                  ),
                  if (_hasEndTime) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Kết thúc',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('activity-end-date-button'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.event_available, size: 18),
                            label: Text(
                              AppDateTimeFormatter.formatDate(_endDate),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _endDate.isBefore(_startDate)
                                    ? _startDate
                                    : _endDate,
                                firstDate: _startDate,
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (picked != null) {
                                setState(() => _endDate = picked);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('activity-end-time-button'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(
                              Icons.timer_off_outlined,
                              size: 18,
                            ),
                            label: Text(
                              '${_pad2(_endTime.hour)}:${_pad2(_endTime.minute)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _endTime,
                              );
                              if (picked != null) {
                                setState(() => _endTime = picked);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Location Card with Switch
            _card(
              title: 'Địa điểm',
              icon: Icons.location_on,
              children: [
                SwitchListTile(
                  key: const Key('activity-location-switch'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    AppStrings.locationSwitch,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _hasLocation ? 'Đã bật địa điểm' : 'Chưa đặt địa điểm',
                  ),
                  value: _hasLocation,
                  onChanged: (v) => setState(() => _hasLocation = v),
                ),
                if (_hasLocation) ...[
                  const Divider(height: 20),
                  TextFormField(
                    key: const Key('activity-location-name'),
                    controller: _locationName,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      labelText: 'Tên địa điểm / Sân / Quán',
                      hintText: 'Ví dụ: Sân cầu lông ABC, Quán trà sữa...',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('activity-location-address'),
                    controller: _locationAddress,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Địa chỉ chi tiết (tùy chọn)',
                      hintText: 'Số nhà, ngõ, đường, quận/huyện...',
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Progressive Disclosure: Advanced Options Card
            Card(
              color: AppColors.surfaceContainerLowest,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(
                  color: AppColors.outlineVariant,
                  width: 0.8,
                ),
              ),
              child: Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  leading: const Icon(
                    Icons.tune,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  title: const Text(
                    AppStrings.advancedOptions,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  subtitle: const Text(
                    'Số lượng người tham gia và định dạng nâng cao',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    const Divider(
                      height: 1,
                      color: AppColors.surfaceContainerHigh,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      key: const Key('activity-capacity-switch'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Giới hạn số người tham gia'),
                      subtitle: Text(
                        _limitedCapacity
                            ? 'Có giới hạn'
                            : AppStrings.unlimitedCapacity,
                      ),
                      value: _limitedCapacity,
                      onChanged: (v) => setState(() => _limitedCapacity = v),
                    ),
                    if (_limitedCapacity) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        key: const Key('activity-capacity'),
                        controller: _capacity,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '${AppStrings.maxParticipantsLabel} *',
                          hintText: 'Ví dụ: 8, 12...',
                        ),
                        validator: (value) {
                          if (!_limitedCapacity) return null;
                          if (value == null || value.trim().isEmpty) {
                            return 'Vui lòng nhập số người tối đa';
                          }
                          final count = int.tryParse(value.trim());
                          if (count == null || count <= 0) {
                            return 'Số người phải lớn hơn 0';
                          }
                          return null;
                        },
                      ),
                    ],
                    if (_hasLocation) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: const Key('activity-location-type'),
                        initialValue: _locationType,
                        decoration: const InputDecoration(
                          labelText: 'Loại địa điểm',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'PHYSICAL',
                            child: Text('Trực tiếp / Ngoài đời'),
                          ),
                          DropdownMenuItem(
                            value: 'ONLINE',
                            child: Text('Trực tuyến / Online'),
                          ),
                          DropdownMenuItem(
                            value: 'TBD',
                            child: Text('Chưa xác định'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _locationType = value!),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: const Key('activity-location-lat'),
                              controller: _latitude,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Vĩ độ (tùy chọn)',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              key: const Key('activity-location-lng'),
                              controller: _longitude,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Kinh độ (tùy chọn)',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              height: 48,
              child: FilledButton(
                key: const Key('activity-submit'),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        AppStrings.createActivity,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      color: AppColors.surfaceContainerLowest,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.outlineVariant, width: 0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class ActivityDetailRuntimeScreen extends StatefulWidget {
  final String activityId;
  final ActivityDetailController controller;

  const ActivityDetailRuntimeScreen({
    super.key,
    required this.activityId,
    required this.controller,
  });

  @override
  State<ActivityDetailRuntimeScreen> createState() =>
      _ActivityDetailRuntimeScreenState();
}

class _ActivityDetailRuntimeScreenState
    extends State<ActivityDetailRuntimeScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.load(widget.activityId);
  }

  Future<void> _handleCancel() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy hoạt động'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bạn có chắc chắn muốn hủy hoạt động này không?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Lý do (không bắt buộc)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Quay lại'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hủy hoạt động'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final reason = reasonController.text.trim().isEmpty
          ? null
          : reasonController.text.trim();
      final success = await widget.controller.cancel(
        widget.activityId,
        reason: reason,
      );
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể hủy hoạt động.')),
        );
      }
    }
  }

  Future<void> _handleRsvp(
    ActivityDetail detail,
    ActivityRsvpStatus status,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await widget.controller.rsvp(detail.id, status);
    if (!ok && mounted && widget.controller.value.failure != null) {
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.participationUpdateFailed)),
      );
    }
  }

  Future<void> _handleConfirm(String activityId) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await widget.controller.confirm(activityId);
    if (!ok && mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Không thể xác nhận hoạt động.')),
      );
    }
  }

  Future<void> _handleComplete(String activityId) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await widget.controller.complete(activityId);
    if (!ok && mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Không thể hoàn thành hoạt động.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Chi tiết hoạt động',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => widget.controller.load(widget.activityId),
          ),
        ],
      ),
      body: ValueListenableBuilder<ActivityDetailState>(
        valueListenable: widget.controller,
        builder: (context, state, _) {
          final detail = state.detail;
          if (state.loading && detail == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (detail == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 12),
                    const Text('Không thể tải chi tiết hoạt động.'),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () =>
                          widget.controller.load(widget.activityId),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }

          final scheduleText = AppDateTimeFormatter.formatActivitySchedule(
            startAt: detail.startAt,
            endAt: detail.endAt,
          );
          final capacitySummary = detail.maxParticipants == null
              ? '${detail.goingCount} người tham gia (Không giới hạn)'
              : '${detail.goingCount} / ${detail.maxParticipants} người tham gia';

          return RefreshIndicator(
            onRefresh: () => widget.controller.load(widget.activityId),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                // Header & Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _statusBgColor(detail.status),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _statusVietnamese(detail.status),
                        style: TextStyle(
                          color: _statusColor(detail.status),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (detail.callerRsvpStatus !=
                        ActivityRsvpStatus.noResponse)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _rsvpBgColor(detail.callerRsvpStatus),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${AppStrings.participationStatus}: ${_rsvpVietnamese(detail.callerRsvpStatus)}',
                          style: TextStyle(
                            color: _rsvpColor(detail.callerRsvpStatus),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  detail.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                  ),
                ),
                if (detail.description != null &&
                    detail.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    detail.description!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Creator & Schedule Card
                _surfaceCard(
                  children: [
                    _infoRow(
                      Icons.person_outline,
                      'Tổ chức bởi ${detail.creator.displayName ?? detail.creator.username ?? detail.creator.userId}',
                    ),
                    const Divider(height: 20),
                    _infoRow(Icons.calendar_today_outlined, scheduleText),
                    if (detail.timezone != null) ...[
                      const SizedBox(height: 8),
                      _infoRow(
                        Icons.schedule_outlined,
                        'Múi giờ: ${detail.timezone}',
                      ),
                    ],
                    if (detail.location != null) ...[
                      const Divider(height: 20),
                      _infoRow(
                        Icons.location_on_outlined,
                        [
                          if (detail.location!.name != null)
                            detail.location!.name!,
                          if (detail.location!.address != null)
                            detail.location!.address!,
                          if (detail.location!.latitude != null &&
                              detail.location!.longitude != null)
                            '(${detail.location!.latitude}, ${detail.location!.longitude})',
                        ].join('\n'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // Capacity & Progress Card
                _surfaceCard(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Số lượng tham gia',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            capacitySummary,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (detail.maxParticipants != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (detail.goingCount / detail.maxParticipants!)
                              .clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: AppColors.surfaceContainer,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          detail.maxParticipants == null
                              ? 'Mở cho tất cả thành viên'
                              : 'Còn ${(detail.maxParticipants! - detail.goingCount).clamp(0, detail.maxParticipants!)} chỗ',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.secondary,
                          ),
                        ),
                        Text(
                          'Danh sách chờ: ${detail.waitlistCount} người',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Waitlist Alert Card (if caller is in waitlist)
                if (detail.callerRsvpStatus == ActivityRsvpStatus.waitlist)
                  Card(
                    key: const ValueKey('waitlist-state'),
                    color: AppColors.primaryFixed,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.hourglass_top,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        "Bạn đang trong danh sách chờ${detail.callerWaitlistPosition == null ? '' : ' (#${detail.callerWaitlistPosition})'}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      subtitle: const Text(
                        'Bạn sẽ được tự động tham gia nếu có vị trí trống.',
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: AppColors.primary,
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ActivityWaitlistRuntimeScreen(
                            detail: detail,
                            onChangeRsvp: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (detail.callerRsvpStatus == ActivityRsvpStatus.waitlist)
                  const SizedBox(height: 16),

                // RSVP Selection Card
                _surfaceCard(
                  children: [
                    if (detail.permissions.canRsvp) ...[
                      const Text(
                        'Bạn có tham gia không?',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Chọn trạng thái tham gia của bạn:',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final status in [
                            ActivityRsvpStatus.going,
                            ActivityRsvpStatus.maybe,
                            ActivityRsvpStatus.notGoing,
                          ])
                            ChoiceChip(
                              label: Text(_rsvpVietnamese(status)),
                              selected: detail.callerRsvpStatus == status,
                              onSelected: (_) => _handleRsvp(detail, status),
                            ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Icon(
                            detail.status == ActivityStatus.cancelled
                                ? Icons.cancel_outlined
                                : Icons.lock_outline,
                            size: 20,
                            color: AppColors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              detail.status == ActivityStatus.completed
                                  ? 'Hoạt động đã kết thúc.'
                                  : detail.status == ActivityStatus.cancelled
                                  ? 'Hoạt động đã bị hủy.'
                                  : 'Đăng ký tham gia đã đóng.',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (detail.callerRsvpStatus !=
                          ActivityRsvpStatus.noResponse) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Trạng thái của bạn: ${_rsvpVietnamese(detail.callerRsvpStatus)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // Participants Preview Card
                _surfaceCard(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.primaryFixed,
                        child: Icon(
                          Icons.people_outline,
                          color: AppColors.primary,
                        ),
                      ),
                      title: const Text(
                        'Người tham gia',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${state.participants.length} người đã đăng ký',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ActivityParticipantsRuntimeScreen(
                            participants: state.participants,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Management Actions Card (if any permission flag is true)
                if (detail.permissions.canEdit ||
                    detail.permissions.canConfirm ||
                    detail.permissions.canComplete ||
                    detail.permissions.canCancel) ...[
                  _surfaceCard(
                    children: [
                      const Text(
                        'Quản trị hoạt động',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (detail.permissions.canEdit)
                            OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ActivityEditRuntimeScreen(
                                    detail: detail,
                                    controller: widget.controller,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.edit),
                              label: const Text('Chỉnh sửa'),
                            ),
                          if (detail.permissions.canConfirm)
                            ElevatedButton.icon(
                              onPressed: () => _handleConfirm(detail.id),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Xác nhận'),
                            ),
                          if (detail.permissions.canComplete)
                            ElevatedButton.icon(
                              onPressed: () => _handleComplete(detail.id),
                              icon: const Icon(Icons.done_all),
                              label: const Text('Hoàn thành'),
                            ),
                          if (detail.permissions.canCancel)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                              ),
                              onPressed: _handleCancel,
                              icon: const Icon(Icons.cancel_outlined),
                              label: const Text('Hủy'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _surfaceCard({required List<Widget> children}) {
    return Card(
      color: AppColors.surfaceContainerLowest,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.outlineVariant, width: 0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.onSurface,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class ActivityEditRuntimeScreen extends StatefulWidget {
  final ActivityDetail detail;
  final ActivityDetailController controller;

  const ActivityEditRuntimeScreen({
    super.key,
    required this.detail,
    required this.controller,
  });

  @override
  State<ActivityEditRuntimeScreen> createState() =>
      _ActivityEditRuntimeScreenState();
}

class _ActivityEditRuntimeScreenState extends State<ActivityEditRuntimeScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title = TextEditingController(
    text: widget.detail.title,
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.detail.description ?? '',
  );
  late final TextEditingController _capacity = TextEditingController(
    text: widget.detail.maxParticipants?.toString() ?? '',
  );
  late final TextEditingController _locationName = TextEditingController(
    text: widget.detail.location?.name ?? '',
  );
  late final TextEditingController _locationAddress = TextEditingController(
    text: widget.detail.location?.address ?? '',
  );
  late final TextEditingController _latitude = TextEditingController(
    text: widget.detail.location?.latitude?.toString() ?? '',
  );
  late final TextEditingController _longitude = TextEditingController(
    text: widget.detail.location?.longitude?.toString() ?? '',
  );

  late bool _scheduled = widget.detail.startAt != null;
  late DateTime _startDate =
      widget.detail.startAt?.toLocal() ??
      DateTime.now().add(const Duration(days: 1));
  late TimeOfDay _startTime = widget.detail.startAt != null
      ? TimeOfDay(
          hour: widget.detail.startAt!.toLocal().hour,
          minute: widget.detail.startAt!.toLocal().minute,
        )
      : const TimeOfDay(hour: 9, minute: 0);
  late bool _hasEndTime = widget.detail.endAt != null;
  late DateTime _endDate = widget.detail.endAt?.toLocal() ?? _startDate;
  late TimeOfDay _endTime = widget.detail.endAt != null
      ? TimeOfDay(
          hour: widget.detail.endAt!.toLocal().hour,
          minute: widget.detail.endAt!.toLocal().minute,
        )
      : TimeOfDay(hour: (_startTime.hour + 2) % 24, minute: _startTime.minute);

  late bool _hasLocation = widget.detail.location != null;
  late String _locationType = widget.detail.location?.type ?? 'PHYSICAL';
  late bool _limitedCapacity = widget.detail.maxParticipants != null;
  bool _saving = false;

  String _pad2(int value) => value.toString().padLeft(2, '0');

  void _onStartDateChanged(DateTime picked) {
    setState(() {
      final wasSameDay =
          _startDate.year == _endDate.year &&
          _startDate.month == _endDate.month &&
          _startDate.day == _endDate.day;
      _startDate = picked;
      if (wasSameDay || _endDate.isBefore(_startDate)) {
        _endDate = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;

    DateTime? start;
    DateTime? end;
    String? timezone;

    if (_scheduled) {
      start = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        _startTime.hour,
        _startTime.minute,
      ).toUtc();
      if (_hasEndTime) {
        end = DateTime(
          _endDate.year,
          _endDate.month,
          _endDate.day,
          _endTime.hour,
          _endTime.minute,
        ).toUtc();
        if (!end.isAfter(start)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thời gian kết thúc phải sau thời gian bắt đầu.'),
            ),
          );
          return;
        }
      }
      timezone = widget.detail.timezone ?? 'Asia/Ho_Chi_Minh';
    }

    final capacity = _limitedCapacity
        ? int.tryParse(_capacity.text.trim())
        : null;
    final lat = double.tryParse(_latitude.text.trim());
    final lng = double.tryParse(_longitude.text.trim());

    final hasLocationData =
        _hasLocation &&
        (_locationName.text.trim().isNotEmpty ||
            _locationAddress.text.trim().isNotEmpty ||
            lat != null ||
            lng != null);

    final loc = hasLocationData
        ? ActivityLocation(
            type: _locationType,
            name: _locationName.text.trim().isEmpty
                ? null
                : _locationName.text.trim(),
            address: _locationAddress.text.trim().isEmpty
                ? null
                : _locationAddress.text.trim(),
            latitude: lat,
            longitude: lng,
          )
        : null;

    final request = activityPatchFor(
      original: widget.detail,
      title: _title.text.trim(),
      description: _description.text.trim(),
      startAt: start,
      endAt: end,
      timezone: timezone,
      location: loc,
      maxParticipants: capacity,
    );

    if (request.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _saving = true);
    final success = await widget.controller.update(widget.detail.id, request);
    if (!mounted) return;
    setState(() => _saving = false);

    if (success) {
      Navigator.of(context).pop();
    } else {
      final failure = widget.controller.value.failure;
      final msg = switch (failure?.type) {
        ActivityFailureType.validation =>
          'Dữ liệu không hợp lệ. Vui lòng kiểm tra lại.',
        ActivityFailureType.invalidTime =>
          'Thời gian bắt đầu hoặc kết thúc không hợp lệ.',
        ActivityFailureType.alreadyStarted =>
          'Hoạt động đã bắt đầu; một số thông tin không thể thay đổi.',
        ActivityFailureType.alreadyCompleted => 'Hoạt động đã kết thúc.',
        ActivityFailureType.closed => 'Hoạt động đã đóng.',
        _ => 'Không thể lưu thay đổi hoạt động.',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _capacity.dispose();
    _locationName.dispose();
    _locationAddress.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmedOrInProgress =
        widget.detail.status == ActivityStatus.confirmed ||
        widget.detail.status == ActivityStatus.inProgress;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Chỉnh sửa hoạt động',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            if (isConfirmedOrInProgress)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFB74D)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFFE65100)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hoạt động đang ở trạng thái ${_statusVietnamese(widget.detail.status)}. Một số thay đổi về lịch trình hoặc địa điểm có thể bị máy chủ giới hạn.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFE65100),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            _card(
              title: 'Thông tin hoạt động',
              icon: Icons.edit_note,
              children: [
                TextFormField(
                  controller: _title,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Tên hoạt động *',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Vui lòng nhập tên hoạt động'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả (không bắt buộc)',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _card(
              title: 'Thời gian',
              icon: Icons.calendar_month,
              children: [
                SwitchListTile(
                  key: const Key('activity-edit-schedule-switch'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    AppStrings.scheduleSwitch,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _scheduled
                        ? 'Có thời gian cụ thể'
                        : '${AppStrings.unscheduled} (thảo luận sau)',
                    style: TextStyle(
                      color: _scheduled
                          ? AppColors.primary
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                  value: _scheduled,
                  onChanged: (v) => setState(() {
                    _scheduled = v;
                    if (v && _endDate.isBefore(_startDate)) {
                      _endDate = _startDate;
                    }
                  }),
                ),
                if (_scheduled) ...[
                  const Divider(height: 20),
                  const Text(
                    'Bắt đầu',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('activity-edit-start-date-button'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.event, size: 18),
                          label: Text(
                            AppDateTimeFormatter.formatDate(_startDate),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _startDate,
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 365),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (picked != null) _onStartDateChanged(picked);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('activity-edit-start-time-button'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.schedule, size: 18),
                          label: Text(
                            '${_pad2(_startTime.hour)}:${_pad2(_startTime.minute)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _startTime,
                            );
                            if (picked != null) {
                              setState(() => _startTime = picked);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    key: const Key('activity-edit-end-time-switch'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Thêm thời gian kết thúc',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    value: _hasEndTime,
                    onChanged: (v) => setState(() {
                      _hasEndTime = v;
                      if (v && _endDate.isBefore(_startDate)) {
                        _endDate = _startDate;
                      }
                    }),
                  ),
                  if (_hasEndTime) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Kết thúc',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('activity-edit-end-date-button'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.event_available, size: 18),
                            label: Text(
                              AppDateTimeFormatter.formatDate(_endDate),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _endDate.isBefore(_startDate)
                                    ? _startDate
                                    : _endDate,
                                firstDate: _startDate,
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (picked != null) {
                                setState(() => _endDate = picked);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('activity-edit-end-time-button'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(
                              Icons.timer_off_outlined,
                              size: 18,
                            ),
                            label: Text(
                              '${_pad2(_endTime.hour)}:${_pad2(_endTime.minute)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _endTime,
                              );
                              if (picked != null) {
                                setState(() => _endTime = picked);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
            const SizedBox(height: 16),
            _card(
              title: 'Địa điểm',
              icon: Icons.location_on,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    AppStrings.locationSwitch,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _hasLocation ? 'Đã bật địa điểm' : 'Chưa đặt địa điểm',
                  ),
                  value: _hasLocation,
                  onChanged: (v) => setState(() => _hasLocation = v),
                ),
                if (_hasLocation) ...[
                  const Divider(height: 20),
                  TextFormField(
                    controller: _locationName,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      labelText: 'Tên địa điểm / Sân / Quán',
                      hintText: 'Ví dụ: Sân cầu lông ABC, Quán trà sữa...',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _locationAddress,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Địa chỉ chi tiết (tùy chọn)',
                      hintText: 'Số nhà, ngõ, đường, quận/huyện...',
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Card(
              color: AppColors.surfaceContainerLowest,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(
                  color: AppColors.outlineVariant,
                  width: 0.8,
                ),
              ),
              child: Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  leading: const Icon(
                    Icons.tune,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  title: const Text(
                    AppStrings.advancedOptions,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  subtitle: const Text(
                    'Số lượng người tham gia và định dạng nâng cao',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    const Divider(
                      height: 1,
                      color: AppColors.surfaceContainerHigh,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Giới hạn số người tham gia'),
                      subtitle: Text(
                        _limitedCapacity
                            ? 'Có giới hạn'
                            : AppStrings.unlimitedCapacity,
                      ),
                      value: _limitedCapacity,
                      onChanged: (v) => setState(() => _limitedCapacity = v),
                    ),
                    if (_limitedCapacity) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _capacity,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '${AppStrings.maxParticipantsLabel} *',
                          hintText: 'Ví dụ: 8, 12...',
                        ),
                        validator: (value) {
                          if (!_limitedCapacity) return null;
                          if (value == null || value.trim().isEmpty) {
                            return 'Vui lòng nhập số người tối đa';
                          }
                          final count = int.tryParse(value.trim());
                          if (count == null || count <= 0) {
                            return 'Số người phải lớn hơn 0';
                          }
                          return null;
                        },
                      ),
                    ],
                    if (_hasLocation) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _locationType,
                        decoration: const InputDecoration(
                          labelText: 'Loại địa điểm',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'PHYSICAL',
                            child: Text('Trực tiếp (Tại sân/quán)'),
                          ),
                          DropdownMenuItem(
                            value: 'ONLINE',
                            child: Text('Trực tuyến (Online)'),
                          ),
                          DropdownMenuItem(
                            value: 'TBD',
                            child: Text('Chưa xác định'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _locationType = v ?? 'PHYSICAL'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Lưu thay đổi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      color: AppColors.surfaceContainerLowest,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.outlineVariant, width: 0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class ActivityParticipantsRuntimeScreen extends StatefulWidget {
  final List<ActivityParticipant> participants;

  const ActivityParticipantsRuntimeScreen({
    super.key,
    required this.participants,
  });

  @override
  State<ActivityParticipantsRuntimeScreen> createState() =>
      _ActivityParticipantsRuntimeScreenState();
}

class _ActivityParticipantsRuntimeScreenState
    extends State<ActivityParticipantsRuntimeScreen> {
  ActivityRsvpStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final displayed = _filter == null
        ? widget.participants
        : widget.participants.where((p) => p.rsvpStatus == _filter).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Người tham gia',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: const Text('Tất cả'),
                      selected: _filter == null,
                      onSelected: (_) => setState(() => _filter = null),
                    ),
                  ),
                  for (final status in [
                    ActivityRsvpStatus.going,
                    ActivityRsvpStatus.maybe,
                    ActivityRsvpStatus.waitlist,
                    ActivityRsvpStatus.notGoing,
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(_rsvpVietnamese(status)),
                        selected: _filter == status,
                        onSelected: (selected) =>
                            setState(() => _filter = selected ? status : null),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: displayed.isEmpty
                  ? const Center(
                      child: Text('Chưa có người tham gia trong mục này.'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: displayed.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final p = displayed[index];
                        final name = p.displayName ?? p.username ?? p.userId;
                        final initials = name.isNotEmpty
                            ? name[0].toUpperCase()
                            : '?';

                        return Card(
                          color: AppColors.surfaceContainerLowest,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                              color: AppColors.outlineVariant,
                              width: 0.6,
                            ),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primaryFixed,
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: p.username != null
                                ? Text('@${p.username!}')
                                : null,
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _rsvpBgColor(p.rsvpStatus),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                p.rsvpStatus == ActivityRsvpStatus.waitlist &&
                                        p.waitlistSequence != null
                                    ? 'CHỜ · #${p.waitlistSequence}'
                                    : _rsvpVietnamese(p.rsvpStatus),
                                style: TextStyle(
                                  color: _rsvpColor(p.rsvpStatus),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class ActivityWaitlistRuntimeScreen extends StatelessWidget {
  final ActivityDetail detail;
  final VoidCallback? onChangeRsvp;

  const ActivityWaitlistRuntimeScreen({
    super.key,
    required this.detail,
    this.onChangeRsvp,
  });

  @override
  Widget build(BuildContext context) {
    final position = detail.callerWaitlistPosition ?? 1;
    final capacityLabel = detail.maxParticipants == null
        ? '${detail.goingCount} người tham gia'
        : '${detail.goingCount} / ${detail.maxParticipants} người tham gia';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Danh sách chờ'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.primaryFixed,
                child: Icon(
                  Icons.hourglass_top,
                  color: AppColors.primary,
                  size: 44,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Bạn đang trong danh sách chờ',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                detail.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Bạn đang ở vị trí #$position trong hàng đợi',
                key: const ValueKey('queue-position'),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              Card(
                color: AppColors.surfaceContainerLowest,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(
                    color: AppColors.outlineVariant,
                    width: 0.8,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        capacityLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Khi một người tham gia thay đổi trạng thái, thành viên đăng ký sớm nhất trong danh sách chờ sẽ được tự động tham gia.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: onChangeRsvp ?? () => Navigator.of(context).pop(),
                  child: const Text(
                    AppStrings.changeParticipationStatus,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
