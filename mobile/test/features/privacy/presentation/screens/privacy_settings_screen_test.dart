import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/privacy/data/privacy_models.dart';
import 'package:mobile/features/privacy/presentation/screens/privacy_settings_screen.dart';

const settings = PrivacySettings(
  discoverByUsername: true,
  discoverByQr: true,
  discoverByEmail: false,
  discoverByPhone: false,
  dmPolicy: DmPolicy.everyone,
  friendRequestPolicy: FriendRequestPolicy.everyone,
  showOnlineStatus: true,
  showLastSeen: true,
);

void main() {
  testWidgets(
    'loads values, tracks a dirty toggle, and saves only its change',
    (tester) async {
      UpdatePrivacySettingsRequest? request;
      await tester.pumpWidget(
        MaterialApp(
          home: PrivacySettingsScreen(
            loadPrivacySettings: () async => settings,
            updatePrivacySettings: (value) async {
              request = value;
              return settings.copyWith(discoverByPhone: true);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    expect(find.text('Searchability'), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );

      final phoneSwitch = find.widgetWithText(
        SwitchListTile,
        'Discover by phone',
      );
      await tester.tap(phoneSwitch);
      await tester.pump();
      final save = find.text('Save privacy settings');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(request!.toJson(), {'discoverByPhone': true});
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
    },
  );

  testWidgets('retains a draft after save failure and exposes initial retry', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacySettingsScreen(
          loadPrivacySettings: () async {
            attempts++;
            if (attempts == 1) throw StateError('offline');
            return settings;
          },
          updatePrivacySettings: (_) async => throw StateError('offline'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to load privacy settings.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SwitchListTile, 'Discover by email'));
    await tester.pump();
    final save = find.text('Save privacy settings');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(
      find.text('Unable to save privacy settings. Please try again.'),
      findsOneWidget,
    );
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('selects an enum policy and saves that field only', (tester) async {
    UpdatePrivacySettingsRequest? request;
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacySettingsScreen(
          loadPrivacySettings: () async => settings,
          updatePrivacySettings: (value) async {
            request = value;
            return settings.copyWith(dmPolicy: DmPolicy.friendsOnly);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dmPolicy = find.byType(DropdownButtonFormField<DmPolicy>);
    await tester.ensureVisible(dmPolicy);
    await tester.tap(dmPolicy);
    await tester.pumpAndSettle();
    await tester.tap(find.text('FRIENDS_ONLY').last);
    await tester.pump();
    final save = find.text('Save privacy settings');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(request!.toJson(), {'dmPolicy': 'FRIENDS_ONLY'});
  });

  testWidgets('disables duplicate save while submitting', (tester) async {
    final completer = Completer<PrivacySettings>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacySettingsScreen(
          loadPrivacySettings: () async => settings,
          updatePrivacySettings: (_) {
            calls++;
            return completer.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final lastSeen = find.widgetWithText(SwitchListTile, 'Show last seen');
    await tester.ensureVisible(lastSeen);
    await tester.tap(lastSeen);
    await tester.pump();
    final save = find.text('Save privacy settings');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    expect(calls, 1);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    completer.complete(settings.copyWith(showLastSeen: false));
  });
}
