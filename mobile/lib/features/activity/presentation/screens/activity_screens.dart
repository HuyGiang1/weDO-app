import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../activity_presentation_models.dart';

const _pagePadding = EdgeInsets.fromLTRB(20, 20, 20, 32);

class ActivityListScreen extends StatelessWidget {
  final ActivityListVisualState state;
  final List<ActivityCardData> activities;
  final ActivityLifecycle? selectedLifecycle;
  final ValueChanged<ActivityLifecycle?>? onFilterChanged;
  final ValueChanged<String>? onOpenActivity;
  final VoidCallback? onCreate;
  final VoidCallback? onRetry;
  const ActivityListScreen({
    super.key,
    required this.state,
    this.activities = const [],
    this.selectedLifecycle,
    this.onFilterChanged,
    this.onOpenActivity,
    this.onCreate,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: Padding(
        padding: _pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: _PageTitle('Activities')),
                FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add),
                  label: const Text('Create Activity'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final lifecycle in ActivityLifecycle.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(lifecycle.label),
                        selected: selectedLifecycle == lifecycle,
                        onSelected: onFilterChanged == null
                            ? null
                            : (selected) =>
                                  onFilterChanged!(selected ? lifecycle : null),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _listBody()),
          ],
        ),
      ),
    ),
  );

  Widget _listBody() => switch (state) {
    ActivityListVisualState.loading => const Center(
      child: CircularProgressIndicator(),
    ),
    ActivityListVisualState.error => Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 44, color: AppColors.error),
          const SizedBox(height: 12),
          const Text('Unable to load activities.'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
    ActivityListVisualState.empty => const Center(child: _EmptyActivities()),
    ActivityListVisualState.data => ListView.separated(
      itemCount: activities.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, index) => _ActivityCard(
        data: activities[index],
        onTap: onOpenActivity == null
            ? null
            : () => onOpenActivity!(activities[index].id),
      ),
    ),
  };
}

class ActivityDetailScreen extends StatelessWidget {
  final ActivityDetailData data;
  final ActivityManagementActions managementActions;
  final ValueChanged<ActivityRsvp>? onRsvp;
  final VoidCallback? onParticipants;
  final VoidCallback? onEdit;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final VoidCallback? onComplete;
  const ActivityDetailScreen({
    super.key,
    required this.data,
    this.managementActions = const ActivityManagementActions(),
    this.onRsvp,
    this.onParticipants,
    this.onEdit,
    this.onConfirm,
    this.onCancel,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(backgroundColor: AppColors.background),
    body: ListView(
      padding: _pagePadding,
      children: [
        _LifecycleBadge(data.lifecycle),
        const SizedBox(height: 12),
        _PageTitle(data.title),
        if (data.description != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(data.description!),
          ),
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (data.creator != null)
                _InfoLine(
                  Icons.person_outline,
                  'Created by ${data.creator!.displayName}',
                ),
              _InfoLine(Icons.calendar_today_outlined, data.dateLabel),
              _InfoLine(
                Icons.schedule_outlined,
                '${data.timeLabel} · ${data.timezone}',
              ),
              if (data.location != null &&
                  data.location!.displayLabel.isNotEmpty)
                _InfoLine(
                  Icons.location_on_outlined,
                  data.location!.displayLabel,
                ),
            ],
          ),
        ),
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you going?',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(data.capacityLabel, key: const ValueKey('capacity-summary')),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final choice in const [
                    ActivityRsvp.going,
                    ActivityRsvp.maybe,
                    ActivityRsvp.notGoing,
                  ])
                    ChoiceChip(
                      label: Text(choice.label),
                      selected: data.callerRsvp == choice,
                      onSelected: onRsvp == null
                          ? null
                          : (_) => onRsvp!(choice),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (data.callerRsvp == ActivityRsvp.waitlist)
          _SurfaceCard(
            child: Text(
              'You are on the waitlist${data.waitlistPosition == null ? '' : ' · #${data.waitlistPosition}'}',
              key: const ValueKey('waitlist-state'),
            ),
          ),
        _SurfaceCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Participants'),
            subtitle: Text(
              '${data.participantPreviewCount} participant${data.participantPreviewCount == 1 ? '' : 's'}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: onParticipants,
          ),
        ),
        if (managementActions.canEdit ||
            managementActions.canConfirm ||
            managementActions.canCancel ||
            managementActions.canComplete)
          _SurfaceCard(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (managementActions.canEdit)
                  OutlinedButton(onPressed: onEdit, child: const Text('Edit')),
                if (managementActions.canConfirm)
                  OutlinedButton(
                    onPressed: onConfirm,
                    child: const Text('Confirm'),
                  ),
                if (managementActions.canCancel)
                  OutlinedButton(
                    onPressed: onCancel,
                    child: const Text('Cancel'),
                  ),
                if (managementActions.canComplete)
                  OutlinedButton(
                    onPressed: onComplete,
                    child: const Text('Complete'),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}

class CreateActivityScreen extends StatelessWidget {
  final ActivityDraft? initialDraft;
  final ValueChanged<ActivityDraft>? onSubmit;
  const CreateActivityScreen({super.key, this.initialDraft, this.onSubmit});
  @override
  Widget build(BuildContext context) => _ActivityFormScreen(
    title: 'Create Activity',
    initialDraft: initialDraft,
    onSubmit: onSubmit,
  );
}

class EditActivityScreen extends StatelessWidget {
  final ActivityDraft initialDraft;
  final ActivityEditState state;
  final ValueChanged<ActivityDraft>? onSubmit;
  const EditActivityScreen({
    super.key,
    required this.initialDraft,
    required this.state,
    this.onSubmit,
  });
  @override
  Widget build(BuildContext context) => _ActivityFormScreen(
    title: 'Edit Activity',
    initialDraft: initialDraft,
    editState: state,
    onSubmit: onSubmit,
  );
}

class ActivityParticipantsScreen extends StatefulWidget {
  final List<ActivityParticipantData> participants;
  const ActivityParticipantsScreen({super.key, required this.participants});
  @override
  State<ActivityParticipantsScreen> createState() =>
      _ActivityParticipantsScreenState();
}

class _ActivityParticipantsScreenState
    extends State<ActivityParticipantsScreen> {
  ActivityRsvp? filter;
  @override
  Widget build(BuildContext context) {
    final displayed = filter == null
        ? widget.participants
        : widget.participants.where((p) => p.rsvp == filter).toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Participants'),
        backgroundColor: AppColors.background,
      ),
      body: Padding(
        padding: _pagePadding,
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final status in ActivityRsvp.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(status.label),
                        selected: filter == status,
                        onSelected: (selected) =>
                            setState(() => filter = selected ? status : null),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  for (final status in ActivityRsvp.values) ...[
                    if (filter == null || filter == status) ...[
                      if (displayed.any((p) => p.rsvp == status))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            status.label,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      for (final participant in displayed.where(
                        (p) => p.rsvp == status,
                      ))
                        _ParticipantTile(participant),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ActivityWaitlistScreen extends StatelessWidget {
  final ActivityWaitlistData data;
  final VoidCallback? onChangeRsvp;
  const ActivityWaitlistScreen({
    super.key,
    required this.data,
    this.onChangeRsvp,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(backgroundColor: AppColors.background),
    body: Padding(
      padding: _pagePadding,
      child: Column(
        children: [
          const Spacer(),
          const CircleAvatar(
            radius: 38,
            backgroundColor: AppColors.primaryFixed,
            child: Icon(
              Icons.hourglass_top,
              color: AppColors.primary,
              size: 38,
            ),
          ),
          const SizedBox(height: 20),
          const _PageTitle("You're on the waitlist", centered: true),
          Text(data.activityTitle),
          const SizedBox(height: 16),
          Text(
            "You're #${data.queuePosition} in line",
            key: const ValueKey('queue-position'),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          _SurfaceCard(
            child: Column(
              children: [
                Text(
                  data.capacityLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Queue position is assigned by the server when activity runtime becomes available.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onChangeRsvp,
              child: const Text('Change RSVP'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ActivityFormScreen extends StatefulWidget {
  final String title;
  final ActivityDraft? initialDraft;
  final ActivityEditState? editState;
  final ValueChanged<ActivityDraft>? onSubmit;
  const _ActivityFormScreen({
    required this.title,
    this.initialDraft,
    this.editState,
    this.onSubmit,
  });
  @override
  State<_ActivityFormScreen> createState() => _ActivityFormScreenState();
}

class _ActivityFormScreenState extends State<_ActivityFormScreen> {
  late final TextEditingController title = TextEditingController(
    text: widget.initialDraft?.title ?? '',
  );
  late final TextEditingController description = TextEditingController(
    text: widget.initialDraft?.description ?? '',
  );
  late final TextEditingController timezone = TextEditingController(
    text: widget.initialDraft?.timezone ?? '',
  );
  late final TextEditingController locationType = TextEditingController(
    text: widget.initialDraft?.location?.type ?? '',
  );
  late final TextEditingController locationName = TextEditingController(
    text: widget.initialDraft?.location?.name ?? '',
  );
  late final TextEditingController address = TextEditingController(
    text: widget.initialDraft?.location?.address ?? '',
  );
  late final TextEditingController maxParticipants = TextEditingController(
    text: widget.initialDraft?.maxParticipants?.toString() ?? '',
  );
  bool limited = false;
  bool get locked =>
      widget.editState == ActivityEditState.readOnly ||
      widget.editState == ActivityEditState.lifecycleLocked;
  @override
  void initState() {
    super.initState();
    limited = widget.initialDraft?.maxParticipants != null;
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    timezone.dispose();
    locationType.dispose();
    locationName.dispose();
    address.dispose();
    maxParticipants.dispose();
    super.dispose();
  }

  void submit() {
    if (title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Title is required.')));
      return;
    }
    widget.onSubmit?.call(
      ActivityDraft(
        title: title.text.trim(),
        description: description.text.trim().isEmpty
            ? null
            : description.text.trim(),
        timezone: timezone.text.trim(),
        location: ActivityLocation(
          type: locationType.text.trim(),
          name: locationName.text.trim().isEmpty
              ? null
              : locationName.text.trim(),
          address: address.text.trim().isEmpty ? null : address.text.trim(),
        ),
        maxParticipants: limited ? int.tryParse(maxParticipants.text) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: Text(widget.title),
      backgroundColor: AppColors.background,
    ),
    body: ListView(
      padding: _pagePadding,
      children: [
        if (widget.editState == ActivityEditState.lifecycleLocked)
          const _LockBanner(),
        _SurfaceCard(
          child: Column(
            children: [
              TextField(
                controller: title,
                enabled: !locked,
                decoration: const InputDecoration(labelText: 'Title *'),
              ),
              TextField(
                controller: description,
                enabled: !locked,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              TextField(
                enabled: !locked,
                decoration: const InputDecoration(
                  labelText: 'Start date & time',
                ),
              ),
              TextField(
                enabled: !locked,
                decoration: const InputDecoration(labelText: 'End date & time'),
              ),
              TextField(
                controller: timezone,
                enabled: !locked,
                decoration: const InputDecoration(labelText: 'Timezone *'),
              ),
            ],
          ),
        ),
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Location',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              TextField(
                controller: locationType,
                enabled: !locked,
                decoration: const InputDecoration(labelText: 'Location type'),
              ),
              TextField(
                controller: locationName,
                enabled: !locked,
                decoration: const InputDecoration(labelText: 'Location name'),
              ),
              TextField(
                controller: address,
                enabled: !locked,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              TextField(
                enabled: !locked,
                decoration: const InputDecoration(
                  labelText: 'Latitude (optional)',
                ),
              ),
              TextField(
                enabled: !locked,
                decoration: const InputDecoration(
                  labelText: 'Longitude (optional)',
                ),
              ),
            ],
          ),
        ),
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Maximum participants',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              RadioGroup<bool>(
                groupValue: limited,
                onChanged: (value) {
                  if (!locked) setState(() => limited = value!);
                },
                child: Column(
                  children: [
                    RadioListTile<bool>(
                      key: const ValueKey('capacity-unlimited'),
                      value: false,
                      enabled: !locked,
                      title: const Text('Unlimited'),
                    ),
                    RadioListTile<bool>(
                      key: const ValueKey('capacity-limited'),
                      value: true,
                      enabled: !locked,
                      title: const Text('Limited'),
                    ),
                  ],
                ),
              ),
              if (limited)
                TextField(
                  controller: maxParticipants,
                  enabled: !locked,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Participant count',
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: FilledButton(
          onPressed: locked ? null : submit,
          child: Text(
            widget.title == 'Create Activity'
                ? 'Create Activity'
                : 'Save Changes',
          ),
        ),
      ),
    ),
  );
}

class _ActivityCard extends StatelessWidget {
  final ActivityCardData data;
  final VoidCallback? onTap;
  const _ActivityCard({required this.data, this.onTap});
  @override
  Widget build(BuildContext context) => _SurfaceCard(
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    data.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ),
                _LifecycleBadge(data.lifecycle),
              ],
            ),
            const SizedBox(height: 6),
            Text(data.scheduleLabel),
            if (data.locationLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(data.locationLabel!),
              ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text(data.capacityLabel), _RsvpBadge(data.callerRsvp)],
            ),
          ],
        ),
      ),
    ),
  );
}

class _ParticipantTile extends StatelessWidget {
  final ActivityParticipantData data;
  const _ParticipantTile(this.data);
  @override
  Widget build(BuildContext context) => _SurfaceCard(
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        child: Text(
          data.displayName.isEmpty ? '?' : data.displayName.characters.first,
        ),
      ),
      title: Text(data.displayName),
      subtitle: Text('@${data.username}'),
      trailing: _RsvpBadge(data.rsvp, position: data.waitlistPosition),
    ),
  );
}

class _PageTitle extends StatelessWidget {
  final String value;
  final bool centered;
  const _PageTitle(this.value, {this.centered = false});
  @override
  Widget build(BuildContext context) => Text(
    value,
    textAlign: centered ? TextAlign.center : TextAlign.start,
    style: const TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      color: AppColors.onSurface,
    ),
  );
}

class _SurfaceCard extends StatelessWidget {
  final Widget child;
  const _SurfaceCard({required this.child});
  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.surfaceContainerLowest,
    elevation: 2,
    shadowColor: AppColors.primaryShadow,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}

class _LifecycleBadge extends StatelessWidget {
  final ActivityLifecycle lifecycle;
  const _LifecycleBadge(this.lifecycle);
  @override
  Widget build(BuildContext context) => Chip(
    label: Text(lifecycle.label),
    visualDensity: VisualDensity.compact,
    backgroundColor: lifecycle == ActivityLifecycle.cancelled
        ? AppColors.errorContainer
        : AppColors.primaryFixed,
    labelStyle: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColors.primary,
    ),
  );
}

class _RsvpBadge extends StatelessWidget {
  final ActivityRsvp rsvp;
  final int? position;
  const _RsvpBadge(this.rsvp, {this.position});
  @override
  Widget build(BuildContext context) => Chip(
    label: Text('${rsvp.label}${position == null ? '' : ' · #$position'}'),
    visualDensity: VisualDensity.compact,
    backgroundColor: activityRsvpColor(rsvp),
    labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
  );
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoLine(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: AppColors.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
      ],
    ),
  );
}

class _EmptyActivities extends StatelessWidget {
  const _EmptyActivities();
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.event_busy, size: 52, color: AppColors.primary),
      const SizedBox(height: 12),
      const Text(
        'No activities yet',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 4),
      const Text(
        'Activities created for this group will appear here.',
        textAlign: TextAlign.center,
      ),
    ],
  );
}

class _LockBanner extends StatelessWidget {
  const _LockBanner();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(bottom: 12),
    child: Material(
      color: AppColors.primaryFixed,
      borderRadius: BorderRadius.all(Radius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.lock_outline, color: AppColors.primary),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Some fields are locked by the current activity lifecycle.',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
