import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/community/presentation/recruitment_screen.dart';
import 'recruitment_test.dart' as fixture;

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('recruitment composer separates guidance and all outlined controls $brightness', (t) async {
      await t.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final adapter = fixture.Adapter();
      final api = fixture.TestApi(Dio(BaseOptions(baseUrl: 'https://fixture'))..httpClientAdapter = adapter);
      await t.pumpWidget(MaterialApp(
        theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
        builder: (_, child) => MediaQuery(
          data: const MediaQueryData(size: Size(320, 900), textScaler: TextScaler.linear(1.5)), child: child!),
        home: RecruitmentComposer(api: api),
      ));
      await t.pumpAndSettle();
      Finder field(String label) => find.byWidgetPredicate((w) => w is InputDecorator && w.decoration.labelText == label);
      final guide = find.textContaining('Chủ nhóm hoặc quản trị viên');
      expect(t.getRect(field('Nhóm tuyển thành viên')).top - t.getRect(guide).bottom, greaterThanOrEqualTo(16));
      await t.tap(find.text('Nhóm tuyển thành viên'));
      await t.pumpAndSettle();
      await t.tap(find.text('R6 QA group').last);
      await t.pumpAndSettle();
      final labels = ['Nhóm tuyển thành viên', 'Hoạt động (không bắt buộc)', 'Bạn đang tìm ai?', 'Số người cần tuyển', 'Khu vực chung', 'Sở thích (cách nhau bằng dấu phẩy)', 'Ai có thể xem?'];
      double offset() => t.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;
      var previousBottom = t.getRect(field(labels.first)).bottom + offset();
      for (var i = 1; i < labels.length; i++) {
        await t.scrollUntilVisible(field(labels[i]), 120, scrollable: find.byType(Scrollable).first);
        await t.pumpAndSettle();
        expect(t.getRect(field(labels[i])).top + offset() - previousBottom, greaterThanOrEqualTo(16));
        previousBottom = t.getRect(field(labels[i])).bottom + offset();
      }
      expect(adapter.created, isNull);
      expect(t.takeException(), isNull);
    });
  }
}
