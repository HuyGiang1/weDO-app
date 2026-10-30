import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/navigation/main_tabs.dart';
import 'package:mobile/app/navigation/page_transitions.dart';

void main() {
  late GlobalKey<NavigatorState> nav;
  Future<void> mount(
    WidgetTester t, {
    TargetPlatform platform = TargetPlatform.android,
    bool reduced = false,
  }) async {
    nav = GlobalKey<NavigatorState>();
    await t.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        theme: ThemeData(
          platform: platform,
          pageTransitionsTheme: appPageTransitions,
        ),
        builder: (_, child) => MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: child!,
        ),
        home: const Scaffold(body: Text('root')),
      ),
    );
    await t.pumpAndSettle();
  }

  MaterialPageRoute<void> push(String name) {
    final route = MaterialPageRoute<void>(
      settings: RouteSettings(name: name),
      builder: (_) => Scaffold(key: ValueKey(name), body: Text(name)),
    );
    nav.currentState!.push(route);
    return route;
  }

  double opacity(WidgetTester t, String name) => t
      .widget<FadeTransition>(
        find
            .ancestor(
              of: find.byKey(ValueKey(name)),
              matching: find.byType(FadeTransition),
            )
            .first,
      )
      .opacity
      .value;

  for (final platform in TargetPlatform.values) {
    testWidgets(
      '$platform push/pop are 120ms opacity only without geometry movement',
      (t) async {
        await mount(t, platform: platform);
        final route = push('detail');
        expect(route.transitionDuration, const Duration(milliseconds: 120));
        expect(
          route.reverseTransitionDuration,
          const Duration(milliseconds: 120),
        );
        await t.pump();
        await t.pump(const Duration(milliseconds: 60));
        final before = t.getRect(find.byKey(const ValueKey('detail')));
        expect(opacity(t, 'detail'), inExclusiveRange(0, 1));
        await t.pumpAndSettle();
        expect(t.getRect(find.byKey(const ValueKey('detail'))), before);
        nav.currentState!.pop();
        await t.pump();
        await t.pump(const Duration(milliseconds: 60));
        expect(opacity(t, 'detail'), inExclusiveRange(0, 1));
        expect(t.getRect(find.byKey(const ValueKey('detail'))), before);
        await t.pumpAndSettle();
        expect(find.text('root'), findsOneWidget);
      },
    );
  }
  testWidgets('reduced motion renders the detail immediately without a fade', (
    t,
  ) async {
    await mount(t, reduced: true);
    push('detail');
    await t.pump();
    await t.pump();
    expect(find.byKey(const ValueKey('detail')), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('detail')),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
    await t.pumpAndSettle();
  });
  testWidgets(
    'nested feature routes share the policy and system back retains stack',
    (t) async {
      await mount(t);
      for (final name in [
        'Group',
        'Activity',
        'Stop',
        'Camera',
        'Chat',
        'Poll',
        'Community',
        'Post',
        'Moments',
        'Album',
        'Fullscreen',
      ]) {
        final route = push(name);
        await t.pumpAndSettle();
        expect(route.transitionDuration, const Duration(milliseconds: 120));
        expect(opacity(t, name), 1);
      }
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('Album'), findsOneWidget);
      expect(find.text('Fullscreen'), findsNothing);
    },
  );
  testWidgets('iOS edge gesture fades without translating and commits pop', (
    t,
  ) async {
    await mount(t, platform: TargetPlatform.iOS);
    push('detail');
    await t.pumpAndSettle();
    final before = t.getRect(find.byKey(const ValueKey('detail')));
    final gesture = await t.startGesture(const Offset(1, 250));
    await gesture.moveBy(const Offset(550, 0));
    await t.pump();
    expect(t.getRect(find.byKey(const ValueKey('detail'))), before);
    await gesture.up();
    await t.pumpAndSettle();
    expect(find.text('root'), findsOneWidget);
  });
  testWidgets('iOS canceled edge gesture keeps the same detail instance', (
    t,
  ) async {
    await mount(t, platform: TargetPlatform.iOS);
    final route = push('detail');
    await t.pumpAndSettle();
    final element = t.element(find.byKey(const ValueKey('detail')));
    final gesture = await t.startGesture(const Offset(1, 250));
    await gesture.moveBy(const Offset(150, 0));
    await t.pump();
    await gesture.moveBy(const Offset(-145, 0));
    await gesture.up();
    await t.pumpAndSettle();
    expect(route.isCurrent, isTrue);
    expect(t.element(find.byKey(const ValueKey('detail'))), same(element));
  });
  testWidgets(
    'Android predictive back cancellation and commit preserve fade-only geometry',
    (t) async {
      await mount(t);
      push('detail');
      await t.pumpAndSettle();
      Future<void> event(String name, [double? progress]) async {
        await t.binding.defaultBinaryMessenger.handlePlatformMessage(
          'flutter/backgesture',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall(
              name,
              progress == null
                  ? null
                  : {
                      'touchOffset': [5.0, 250.0],
                      'progress': progress,
                      'swipeEdge': 0,
                    },
            ),
          ),
          (ByteData? _) {},
        );
        await t.pump();
      }

      final before = t.getRect(find.byKey(const ValueKey('detail')));
      await event('startBackGesture', 0);
      await event('updateBackGestureProgress', .4);
      expect(opacity(t, 'detail'), closeTo(.6, .01));
      expect(t.getRect(find.byKey(const ValueKey('detail'))), before);
      await event('cancelBackGesture');
      await t.pumpAndSettle();
      expect(find.text('detail'), findsOneWidget);
      await event('startBackGesture', 0);
      await event('updateBackGestureProgress', .8);
      await event('commitBackGesture');
      await t.pumpAndSettle();
      expect(find.text('root'), findsOneWidget);
    },
  );
  testWidgets('dialogs and bottom sheets keep their own modal routes', (
    t,
  ) async {
    await mount(t);
    showDialog<void>(
      context: nav.currentContext!,
      builder: (_) => const AlertDialog(content: Text('dialog')),
    );
    await t.pumpAndSettle();
    expect(ModalRoute.of(t.element(find.text('dialog'))), isA<DialogRoute>());
    nav.currentState!.pop();
    await t.pumpAndSettle();
    showModalBottomSheet<void>(
      context: nav.currentContext!,
      builder: (_) => const Text('sheet'),
    );
    await t.pumpAndSettle();
    expect(
      ModalRoute.of(t.element(find.text('sheet'))),
      isA<ModalBottomSheetRoute>(),
    );
    nav.currentState!.pop();
    await t.pumpAndSettle();
  });
  testWidgets(
    'lazy tabs switch immediately and preserve state/scroll without duplicate instances',
    (t) async {
      final created = <String, int>{};
      final disposed = <String, int>{};
      nav = GlobalKey<NavigatorState>();
      await t.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          theme: ThemeData(pageTransitionsTheme: appPageTransitions),
          initialRoute: '/home',
          onGenerateInitialRoutes: (_) => [
            MainTabRoute(
              settings: const RouteSettings(name: '/home'),
              tabBuilder: (_) =>
                  _Tab(name: '/home', created: created, disposed: disposed),
            ),
          ],
          onGenerateRoute: (s) => MainTabRoute(
            settings: s,
            tabBuilder: (_) =>
                _Tab(name: s.name!, created: created, disposed: disposed),
          ),
        ),
      );
      await t.pumpAndSettle();
      final homeState = t.state<_TabState>(find.byType(_Tab));
      expect(
        ModalRoute.of(t.element(find.byType(_Tab)))!.transitionDuration,
        Duration.zero,
      );
      await t.enterText(find.byType(TextField), 'Bản nháp được giữ nguyên');
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      await t.drag(find.byType(ListView), const Offset(0, -350));
      await t.pumpAndSettle();
      final offset = homeState.scroll.offset;
      expect(offset, greaterThan(0));
      for (final tab in [
        '/community',
        '/chat',
        '/calendar',
        '/profile',
        '/home',
      ]) {
        selectRetainedTab(
          t.element(find.byType(_Tab)),
          RouteSettings(name: tab),
        );
        await t.pump();
        expect(t.widget<_Tab>(find.byType(_Tab)).name, tab);
        expect(nav.currentState!.canPop(), isFalse);
      }
      expect(t.state(find.byType(_Tab)), same(homeState));
      expect(homeState.scroll.offset, offset);
      expect(homeState.draft.text, 'Bản nháp được giữ nguyên');
      expect(created.values, everyElement(1));
      expect(disposed, isEmpty);
      nav.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('detail')),
        ),
      );
      await t.pumpAndSettle();
      selectRetainedTab(
        t.element(find.text('detail')),
        const RouteSettings(name: '/chat'),
      );
      await t.pumpAndSettle();
      expect(find.text('/chat 0'), findsOneWidget);
      expect(created['/chat'], 1);
      await t.pumpWidget(const SizedBox());
      expect(disposed.values, everyElement(1));
    },
  );
}

class _Tab extends StatefulWidget {
  final String name;
  final Map<String, int> created, disposed;
  const _Tab({
    required this.name,
    required this.created,
    required this.disposed,
  });
  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  final scroll = ScrollController();
  final draft = TextEditingController();
  @override
  void initState() {
    super.initState();
    widget.created.update(widget.name, (n) => n + 1, ifAbsent: () => 1);
  }

  @override
  void dispose() {
    widget.disposed.update(widget.name, (n) => n + 1, ifAbsent: () => 1);
    scroll.dispose();
    draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(
      controller: scroll,
      children: [
        TextField(controller: draft),
        for (int i = 0; i < 80; i++)
          SizedBox(height: 50, child: Text('${widget.name} $i')),
      ],
    ),
  );
}
