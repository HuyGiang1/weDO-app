import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/journey/presentation/journey_screens.dart';
import 'journey_test.dart' as fixture;

void main() {
  for (final task in [false, true]) {
    for (final brightness in Brightness.values) {
      testWidgets('capture fields do not overlap task=$task $brightness', (t) async {
        await t.binding.setSurfaceSize(const Size(320, 850));
        addTearDown(() => t.binding.setSurfaceSize(null));
        await t.pumpWidget(MaterialApp(
          theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
          builder: (_, child) => MediaQuery(
            data: MediaQueryData(size: const Size(320, 850), textScaler: TextScaler.linear(1.5)),
            child: child!,
          ),
          home: JourneyCapture(api: fixture.Api(), group: 'g',
            task: task ? 't' : null, activity: task ? null : 'a', stop: task ? null : 's'),
        ));
        await t.pumpAndSettle();
        final cameraActions = find.ancestor(of: find.text('Mở camera'), matching: find.byType(Wrap)).first;
        await t.ensureVisible(find.byType(TextField));
        await t.pumpAndSettle();
        expect(t.getRect(find.byType(TextField)).top - t.getRect(cameraActions).bottom, greaterThanOrEqualTo(16));
        await t.enterText(find.byType(TextField), 'Ghi chú minh chứng');
        await t.pump();
        expect(t.takeException(), isNull);
        expect(find.text('Ghi chú minh chứng'), findsOneWidget);
      });
    }
  }
}
