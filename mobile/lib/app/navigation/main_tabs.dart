import 'package:flutter/material.dart';

import 'tab_chrome.dart';

/// A normal Material route; only its root content retains lazy main tabs.
/// Detail routes continue to use the existing single Navigator and auth guards.
class MainTabRoute extends MaterialPageRoute<void> {
  final WidgetBuilder tabBuilder;
  @override
  Duration get transitionDuration => Duration.zero;
  @override
  Duration get reverseTransitionDuration => Duration.zero;
  MainTabRoute({required RouteSettings settings, required this.tabBuilder})
    : super(
        settings: settings,
        builder: (_) =>
            _MainTabs(initialSettings: settings, initialBuilder: tabBuilder),
      );
}

// Navigator identity scopes the registry to the current auth/session boundary.
// No GlobalKey, parallel navigator, or cross-session widget cache is created.
final _hosts = Expando<List<_MainTabsState>>();

bool selectRetainedTab(BuildContext context, RouteSettings settings) {
  final navigator = Navigator.of(context);
  final hosts = _hosts[navigator];
  if (hosts == null || hosts.isEmpty) return false;
  final host = hosts.last;
  if (!host.mounted || !host.select(settings)) return false;
  navigator.popUntil((route) => route == host.route);
  return true;
}

class _MainTabs extends StatefulWidget {
  final RouteSettings initialSettings;
  final WidgetBuilder initialBuilder;
  const _MainTabs({
    required this.initialSettings,
    required this.initialBuilder,
  });
  @override
  State<_MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<_MainTabs> {
  final tabs = <String, Widget>{};
  final chrome = <String, TabChromeController>{};
  late String selected;
  NavigatorState? navigator;
  ModalRoute<dynamic>? route;
  @override
  void initState() {
    super.initState();
    selected = widget.initialSettings.name!;
    chrome[selected] = TabChromeController();
    tabs[selected] = Builder(
      key: ValueKey(selected),
      builder: widget.initialBuilder,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Navigator.of(context);
    if (navigator != next) {
      if (navigator != null) _hosts[navigator!]?.remove(this);
      navigator = next;
      (_hosts[next] ??= []).add(this);
    }
    route = ModalRoute.of(context);
  }

  bool select(RouteSettings settings) {
    final name = settings.name!;
    Widget? page = tabs[name];
    if (page == null) {
      // Go through MaterialApp's existing argument enrichment/auth guard.
      final generated = navigator!.widget.onGenerateRoute?.call(settings);
      if (generated is! MainTabRoute) return false;
      page = Builder(key: ValueKey(name), builder: generated.tabBuilder);
    }
    chrome.putIfAbsent(name, TabChromeController.new);
    for (final entry in chrome.entries) {
      entry.value.activate(entry.key == name);
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      tabs[name] = page!;
      selected = name;
    });
    return true;
  }

  @override
  void dispose() {
    if (navigator != null) _hosts[navigator!]?.remove(this);
    for (final controller in chrome.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IndexedStack(
    index: tabs.keys.toList().indexOf(selected),
    children: [
      for (final entry in tabs.entries)
        TabChromeScope(
          controller: chrome[entry.key]!,
          child: TickerMode(enabled: entry.key == selected, child: entry.value),
        ),
    ],
  );
}
