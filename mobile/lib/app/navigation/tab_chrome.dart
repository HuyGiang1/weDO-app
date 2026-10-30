import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Per-retained-tab presentation state. Never a feed/domain/realtime signal.
class TabChromeController extends ValueNotifier<bool> {
  TabChromeController() : super(true);
  bool _active = true, _disposed = false;
  int _epoch = 0;
  bool? _pending;

  void activate(bool active) {
    _active = active;
    show();
  }

  void show() {
    _epoch++;
    _pending = null;
    if (!_disposed && !value) value = true;
  }

  void request(bool visible) {
    if (_disposed || !_active) return;
    if (_pending != null) {
      _pending = visible;
      return;
    }
    if (value == visible) return;
    if (SchedulerBinding.instance.schedulerPhase !=
        SchedulerPhase.persistentCallbacks) {
      if (value != visible) value = visible;
      return;
    }
    // Scroll layout notifications cannot synchronously relayout the shell.
    _pending = visible;
    final epoch = _epoch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !_active || epoch != _epoch) return;
      final next = _pending;
      _pending = null;
      if (next != null && value != next) value = next;
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    super.dispose();
  }
}

class TabChromeScope extends InheritedWidget {
  final TabChromeController controller;
  const TabChromeScope({
    super.key,
    required this.controller,
    required super.child,
  });
  static TabChromeController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<TabChromeScope>()?.controller;
  @override
  bool updateShouldNotify(TabChromeScope oldWidget) =>
      controller != oldWidget.controller;
}

/// Collapse layout, hit testing and semantics together; no empty bar-sized gap.
class TabChromeRegion extends StatelessWidget {
  final TabChromeController controller;
  final Widget child;
  final bool forceVisible;
  const TabChromeRegion({
    super.key,
    required this.controller,
    required this.child,
    this.forceVisible = false,
  });
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: controller,
    child: child,
    builder: (context, visible, child) {
      final shown =
          forceVisible || visible || MediaQuery.accessibleNavigationOf(context);
      final reduced = MediaQuery.disableAnimationsOf(context);
      return ClipRect(
        child: AnimatedAlign(
          duration: reduced ? Duration.zero : const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          heightFactor: shown ? 1 : 0,
          child: IgnorePointer(
            ignoring: !shown,
            child: ExcludeSemantics(excluding: !shown, child: child!),
          ),
        ),
      );
    },
  );
}
