import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/journey/presentation/journey_screens.dart';
import 'journey_test.dart' as fixture;

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('Stop coordinator and notes have separate outlines $brightness', (t) async {
      await t.binding.setSurfaceSize(const Size(320, 1000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(MaterialApp(
        theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
        builder: (_, child) => MediaQuery(data: const MediaQueryData(size: Size(320, 1000), textScaler: TextScaler.linear(1.5)), child: child!),
        home: StopComposer(api: fixture.Api(), activity: 'a', initial: fixture.stopFixture()),
      ));
      await t.pumpAndSettle();
      Finder field(String label) => find.byWidgetPredicate((w) => w is InputDecorator && w.decoration.labelText == label);
      double offset() => t.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;
      await t.scrollUntilVisible(field('Người điều phối (tùy chọn)'), 100, scrollable: find.byType(Scrollable).first);
      await t.pumpAndSettle();
      final bottom = t.getRect(field('Người điều phối (tùy chọn)')).bottom + offset();
      await t.scrollUntilVisible(field('Ghi chú'), 100, scrollable: find.byType(Scrollable).first);
      await t.pumpAndSettle();
      expect(t.getRect(field('Ghi chú')).top + offset() - bottom, greaterThanOrEqualTo(16));
      expect(t.takeException(), isNull);
    });
  }
}
