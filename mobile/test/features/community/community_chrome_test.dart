import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/navigation/main_tabs.dart';
import 'package:mobile/app/navigation/app_bottom_navigation.dart';
import 'package:mobile/app/navigation/tab_chrome.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/community/data/community_api.dart';
import 'package:mobile/features/community/presentation/community_screen.dart';

import 'community_test.dart' as fixture;

void main() {
  late _CountingAdapter adapter;
  Future<void> mount(
    WidgetTester t, {
    bool empty = false,
    bool reduced = false,
    bool accessible = false,
  }) async {
    await t.binding.setSurfaceSize(const Size(360, 780));
    adapter = _CountingAdapter()
      ..many = true
      ..hidden = empty;
    final api = CommunityApi(
      Dio(BaseOptions(baseUrl: 'https://fixture'))..httpClientAdapter = adapter,
    );
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduced,
            accessibleNavigation: accessible,
          ),
          child: child!,
        ),
        onGenerateInitialRoutes: (_) => [
          MainTabRoute(
            settings: const RouteSettings(name: '/community'),
            tabBuilder: (_) => CommunityScreen(api: api, rootTab: true),
          ),
        ],
        onGenerateRoute: (s) => s.name == '/search'
            ? MaterialPageRoute<void>(
                builder: (_) =>
                    const Scaffold(body: Text('Existing search destination')),
              )
            : MainTabRoute(
                settings: s,
                tabBuilder: (_) => const Scaffold(
                  body: Text('Home'),
                  bottomNavigationBar: AppBottomNavigation(selectedIndex: 1),
                ),
              ),
      ),
    );
    await t.pumpAndSettle();
    addTearDown(() async {
      await t.pumpWidget(const SizedBox());
      await t.binding.setSurfaceSize(null);
    });
  }

  TabChromeController chrome(WidgetTester t) =>
      TabChromeScope.maybeOf(t.element(find.byType(CommunityScreen)))!;
  double viewport(WidgetTester t) => t.getSize(find.byType(ListView)).height;
  void protocol(
    WidgetTester t, {
    required double delta,
    bool start = false,
    bool user = true,
    double pixels = 200,
  }) {
    final context = t.element(find.byType(ListView));
    final metrics = FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: 5000,
      pixels: pixels,
      viewportDimension: 500,
      axisDirection: AxisDirection.down,
      devicePixelRatio: 1,
    );
    if (start) {
      ScrollStartNotification(
        metrics: metrics,
        context: context,
        dragDetails: user ? DragStartDetails() : null,
      ).dispatch(context);
    }
    ScrollUpdateNotification(
      metrics: metrics,
      context: context,
      scrollDelta: delta,
      dragDetails: user
          ? DragUpdateDetails(
              globalPosition: Offset.zero,
              delta: Offset(0, -delta),
              primaryDelta: -delta,
            )
          : null,
    ).dispatch(context);
  }

  testWidgets(
    'real drag hides/reveals both bars, reclaims viewport and preserves feed/card state',
    (t) async {
      await mount(t);
      final state = t.state(find.byType(CommunityScreen));
      final first = t.state(find.byType(CommunityCard).first);
      final initialHeight = viewport(t);
      final reads = Map<String, int>.of(adapter.detailReads);
      await t.drag(find.byType(ListView), const Offset(0, -180));
      await t.pumpAndSettle();
      expect(chrome(t).value, isFalse);
      expect(viewport(t), greaterThan(initialHeight + 100));
      for (final region in find.byType(TabChromeRegion).evaluate()) {
        expect(t.getSize(find.byWidget(region.widget)).height, 0);
      }
      expect(t.state(find.byType(CommunityScreen)), same(state));
      expect(t.state(find.byType(CommunityCard).first), same(first));
      expect(adapter.feeds, 1);
      for (final entry in reads.entries) {
        expect(adapter.detailReads[entry.key], entry.value, reason: entry.key);
      }
      await t.drag(find.byType(ListView), const Offset(0, 90));
      await t.pumpAndSettle();
      expect(chrome(t).value, isTrue);
      expect(viewport(t), initialHeight);
      expect(adapter.feeds, 1);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'hysteresis ignores tiny deltas and programmatic restoration, top and recovery reveal',
    (t) async {
      await mount(t);
      protocol(t, delta: 8, start: true);
      await t.pumpAndSettle();
      expect(chrome(t).value, isTrue);
      protocol(t, delta: 8);
      await t.pumpAndSettle();
      expect(chrome(t).value, isTrue);
      protocol(t, delta: 8);
      await t.pumpAndSettle();
      expect(chrome(t).value, isFalse);
      await t.tap(find.byTooltip('Hiện điều hướng'));
      await t.pumpAndSettle();
      expect(chrome(t).value, isTrue);
      protocol(t, delta: 200, start: true, user: false);
      await t.pumpAndSettle();
      expect(chrome(t).value, isTrue);
      protocol(t, delta: 50, start: true);
      await t.pumpAndSettle();
      expect(chrome(t).value, isFalse);
      protocol(t, delta: -2, pixels: 0);
      await t.pumpAndSettle();
      expect(chrome(t).value, isTrue);
      expect(adapter.feeds, 1);
    },
  );

  testWidgets(
    'leaving hidden Community normalizes shell and returns without duplicate reads or lost offset',
    (t) async {
      await mount(t);
      final state = t.state(find.byType(CommunityScreen));
      await t.drag(find.byType(ListView), const Offset(0, -260));
      await t.pumpAndSettle();
      final offset = t
          .widget<ListView>(find.byType(ListView))
          .controller!
          .offset;
      final controller = chrome(t);
      expect(controller.value, isFalse);
      selectRetainedTab(
        t.element(find.byType(CommunityScreen)),
        const RouteSettings(name: '/home'),
      );
      await t.pumpAndSettle();
      expect(controller.value, isTrue);
      expect(
        t.getSize(find.byType(BottomNavigationBar)).height,
        greaterThan(0),
      );
      await t.tap(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.text('Cộng đồng'),
        ),
      );
      await t.pumpAndSettle();
      expect(t.state(find.byType(CommunityScreen)), same(state));
      expect(chrome(t).value, isTrue);
      expect(
        t.widget<ListView>(find.byType(ListView)).controller!.offset,
        offset,
      );
      expect(find.byType(CommunityScreen, skipOffstage: false), findsOneWidget);
      expect(adapter.feeds, 1);
    },
  );

  testWidgets(
    'search hub routes to supported search and returns to same feed',
    (t) async {
      await mount(t);
      final state = t.state(find.byType(CommunityScreen));
      t.widget<ListView>(find.byType(ListView)).controller!.jumpTo(160);
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Tìm kiếm Cộng đồng'));
      await t.pumpAndSettle();
      expect(find.text('Tin tuyển thành viên'), findsOneWidget);
      await t.tap(find.text('Mọi người và nội dung của bạn'));
      await t.pumpAndSettle();
      expect(find.text('Existing search destination'), findsOneWidget);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(t.state(find.byType(CommunityScreen)), same(state));
      expect(t.widget<ListView>(find.byType(ListView)).controller!.offset, 160);
      expect(adapter.feeds, 1);
    },
  );

  testWidgets('empty feed always has navigation and search', (t) async {
    await mount(t, empty: true);
    chrome(t).request(false);
    await t.pumpAndSettle();
    for (final region in find.byType(TabChromeRegion).evaluate()) {
      expect(t.getSize(find.byWidget(region.widget)).height, greaterThan(0));
    }
    expect(find.byTooltip('Tìm kiếm Cộng đồng').hitTestable(), findsOneWidget);
  });

  testWidgets(
    'reduced motion collapses without animation, accessible navigation retains bars',
    (t) async {
      await mount(t, reduced: true);
      protocol(t, delta: 50, start: true);
      await t.pump();
      await t.pump();
      expect(chrome(t).value, isFalse);
      for (final align in t.widgetList<AnimatedAlign>(
        find.byType(AnimatedAlign),
      )) {
        expect(align.duration, Duration.zero);
      }
      await t.pumpWidget(const SizedBox());
      await mount(t, accessible: true);
      protocol(t, delta: 100, start: true);
      await t.pumpAndSettle();
      expect(chrome(t).value, isTrue);
    },
  );

  testWidgets(
    'pull-to-refresh and pagination keep canonical reads and navigation recovery',
    (t) async {
      await mount(t);
      await t.drag(find.byType(ListView), const Offset(0, 400));
      await t.pumpAndSettle();
      expect(adapter.feeds, 2);
      expect(chrome(t).value, isTrue);
      adapter.paginated = true;
      // Another explicit user refresh exposes the existing cursor control.
      await t.drag(find.byType(ListView), const Offset(0, 400));
      await t.pumpAndSettle();
      final before = adapter.feeds;
      await t.scrollUntilVisible(
        find.text('Xem bài cũ hơn'),
        500,
        maxScrolls: 30,
      );
      await t.tap(find.text('Xem bài cũ hơn'));
      await t.pumpAndSettle();
      expect(adapter.feeds, before + 1);
      expect(adapter.cursors, ['p']);
      await t.tap(find.byTooltip('Hiện điều hướng'));
      await t.pumpAndSettle();
      expect(chrome(t).value, isTrue);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'For You and Friends retain existing reads while chrome only changes presentation',
    (t) async {
      await mount(t);
      await t.tap(find.text('Bạn bè'));
      await t.pumpAndSettle();
      expect(adapter.modes.last, 'FRIENDS');
      final count = adapter.feeds;
      await t.drag(find.byType(ListView), const Offset(0, -160));
      await t.pumpAndSettle();
      expect(chrome(t).value, isFalse);
      await t.tap(find.byTooltip('Hiện điều hướng'));
      await t.pumpAndSettle();
      expect(adapter.feeds, count);
    },
  );
}

class _CountingAdapter extends fixture.FakeAdapter {
  final detailReads = <String, int>{};
  @override
  Future<ResponseBody> fetch(
    RequestOptions r,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) {
    if (r.method == 'GET' &&
        RegExp(r'^/api/v1/community/posts/[^/]+$').hasMatch(r.path)) {
      detailReads.update(r.path, (count) => count + 1, ifAbsent: () => 1);
    }
    return super.fetch(r, body, cancel);
  }
}
