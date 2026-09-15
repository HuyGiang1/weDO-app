import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/activity/presentation/activity_presentation_models.dart';
import 'package:mobile/features/activity/presentation/screens/activity_screens.dart';

void main() {
  final card = ActivityCardData(
    id: 'activity-1',
    title: 'Fixture activity',
    scheduleLabel: 'Sep 12, 19:00',
    locationLabel: 'Fixture venue',
    lifecycle: ActivityLifecycle.planning,
    callerRsvp: ActivityRsvp.going,
    capacityLabel: '2 / 10 going',
  );

  group('ActivityListScreen', () {
    testWidgets('renders injected cards and forwards lifecycle filters', (
      tester,
    ) async {
      ActivityLifecycle? selected;
      String? opened;
      await _pump(
        tester,
        ActivityListScreen(
          state: ActivityListVisualState.data,
          activities: [card],
          onFilterChanged: (value) => selected = value,
          onOpenActivity: (value) => opened = value,
        ),
      );
      expect(find.text('Fixture activity'), findsOneWidget);
      expect(find.text('GOING'), findsOneWidget);
      await tester.tap(find.text('CONFIRMED'));
      await tester.tap(find.text('Fixture activity'));
      expect(selected, ActivityLifecycle.confirmed);
      expect(opened, 'activity-1');
    });

    testWidgets('renders loading, empty, and retryable error states', (
      tester,
    ) async {
      await _pump(
        tester,
        const ActivityListScreen(state: ActivityListVisualState.loading),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await _pump(
        tester,
        const ActivityListScreen(state: ActivityListVisualState.empty),
      );
      expect(find.text('No activities yet'), findsOneWidget);
      var retries = 0;
      await _pump(
        tester,
        ActivityListScreen(
          state: ActivityListVisualState.error,
          onRetry: () => retries++,
        ),
      );
      await tester.tap(find.text('Try again'));
      expect(retries, 1);
    });
  });

  group('ActivityDetailScreen', () {
    testWidgets(
      'renders core sections, RSVP choices, and independent management actions',
      (tester) async {
        ActivityRsvp? rsvp;
        await _pump(
          tester,
          ActivityDetailScreen(
            data: _detail(),
            managementActions: const ActivityManagementActions(
              canEdit: true,
              canCancel: true,
            ),
            onRsvp: (value) => rsvp = value,
          ),
        );
        expect(find.text('Fixture activity'), findsOneWidget);
        expect(find.text('Are you going?'), findsOneWidget);
        expect(find.text('Participants'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('Edit'), 200);
        expect(find.text('Edit'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Confirm'), findsNothing);
        await tester.tap(find.text('MAYBE'));
        expect(rsvp, ActivityRsvp.maybe);
      },
    );

    testWidgets(
      'shows a server-provided waitlist state without a WAITLIST selector',
      (tester) async {
        await _pump(
          tester,
          ActivityDetailScreen(
            data: _detail(rsvp: ActivityRsvp.waitlist, position: 3),
          ),
        );
        expect(find.byKey(const ValueKey('waitlist-state')), findsOneWidget);
        expect(find.textContaining('#3'), findsOneWidget);
        expect(find.widgetWithText(ChoiceChip, 'WAITLIST'), findsNothing);
      },
    );
  });

  group('CreateActivityScreen', () {
    testWidgets(
      'renders required field structure, capacity mode, and submit seam',
      (tester) async {
        ActivityDraft? submitted;
        await _pump(
          tester,
          CreateActivityScreen(
            initialDraft: _draft(),
            onSubmit: (draft) => submitted = draft,
          ),
        );
        expect(find.text('Title *'), findsOneWidget);
        expect(find.text('Timezone *'), findsOneWidget);
        expect(find.text('Location type'), findsOneWidget);
        final submit = find.widgetWithText(FilledButton, 'Create Activity');
        await tester.tap(submit);
        expect(submitted?.title, 'Existing title');
        expect(submitted?.maxParticipants, 10);
      },
    );
  });

  group('EditActivityScreen', () {
    testWidgets('renders editable and lifecycle-locked presentation states', (
      tester,
    ) async {
      await _pump(
        tester,
        EditActivityScreen(
          initialDraft: _draft(),
          state: ActivityEditState.editable,
        ),
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).first).enabled,
        isTrue,
      );
      await _pump(
        tester,
        EditActivityScreen(
          initialDraft: _draft(),
          state: ActivityEditState.lifecycleLocked,
        ),
      );
      expect(
        find.text('Some fields are locked by the current activity lifecycle.'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).first).enabled,
        isFalse,
      );
      final save = find.widgetWithText(FilledButton, 'Save Changes');
      await tester.drag(_listScrollable(), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
    });
  });

  group('ActivityParticipantsScreen', () {
    testWidgets('groups safe public identity by RSVP status', (tester) async {
      await _pump(
        tester,
        ActivityParticipantsScreen(
          participants: [
            const ActivityParticipantData(
              userId: 'a',
              displayName: 'Safe Person',
              username: 'safe_person',
              rsvp: ActivityRsvp.going,
            ),
            const ActivityParticipantData(
              userId: 'b',
              displayName: 'Queued Person',
              username: 'queued_person',
              rsvp: ActivityRsvp.waitlist,
              waitlistPosition: 2,
            ),
          ],
        ),
      );
      expect(find.text('Safe Person'), findsOneWidget);
      expect(find.text('@safe_person'), findsOneWidget);
      expect(find.text('WAITLIST · #2'), findsOneWidget);
      expect(find.textContaining('email'), findsNothing);
      await tester.tap(find.widgetWithText(FilterChip, 'WAITLIST'));
      await tester.pumpAndSettle();
      expect(find.text('Queued Person'), findsOneWidget);
      expect(find.text('Safe Person'), findsNothing);
    });
  });

  group('ActivityWaitlistScreen', () {
    testWidgets(
      'renders injected queue position and only exposes change RSVP',
      (tester) async {
        var changed = 0;
        await _pump(
          tester,
          ActivityWaitlistScreen(
            data: const ActivityWaitlistData(
              activityTitle: 'Fixture activity',
              queuePosition: 2,
              capacityLabel: '10 / 10 spots filled',
            ),
            onChangeRsvp: () => changed++,
          ),
        );
        expect(find.byKey(const ValueKey('queue-position')), findsOneWidget);
        expect(find.text("You're #2 in line"), findsOneWidget);
        expect(find.text('Change RSVP'), findsOneWidget);
        expect(find.widgetWithText(ChoiceChip, 'WAITLIST'), findsNothing);
        await tester.tap(find.text('Change RSVP'));
        expect(changed, 1);
      },
    );
  });
}

Future<void> _pump(WidgetTester tester, Widget child) =>
    tester.pumpWidget(MaterialApp(home: child));

Finder _listScrollable() => find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;

ActivityDetailData _detail({
  ActivityRsvp rsvp = ActivityRsvp.going,
  int? position,
}) => ActivityDetailData(
  id: 'activity-1',
  title: 'Fixture activity',
  description: 'Fixture description',
  lifecycle: ActivityLifecycle.confirmed,
  creator: const ActivityCreator(
    displayName: 'Safe Creator',
    username: 'safe_creator',
  ),
  dateLabel: 'Sep 12',
  timeLabel: '19:00',
  timezone: 'Asia/Ho_Chi_Minh',
  location: const ActivityLocation(type: 'PHYSICAL', name: 'Fixture venue'),
  capacityLabel: '2 / 10 going',
  callerRsvp: rsvp,
  participantPreviewCount: 2,
  waitlistPosition: position,
);

ActivityDraft _draft() => const ActivityDraft(
  title: 'Existing title',
  description: 'Existing description',
  timezone: 'Asia/Ho_Chi_Minh',
  maxParticipants: 10,
);
