import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/services.dart';

/// All Material page pushes/pops use opacity only. Popup routes stay native.
const appPageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: AppFadeTransitions(),
    TargetPlatform.iOS: AppFadeTransitions(),
    TargetPlatform.macOS: AppFadeTransitions(),
    TargetPlatform.windows: AppFadeTransitions(),
    TargetPlatform.linux: AppFadeTransitions(),
    TargetPlatform.fuchsia: AppFadeTransitions(),
  },
);

class AppFadeTransitions extends PageTransitionsBuilder {
  const AppFadeTransitions();
  @override
  Duration get transitionDuration => const Duration(milliseconds: 120);
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 120);
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final page = reduced
        ? child
        : FadeTransition(opacity: animation, child: child);
    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        // Retain Flutter's edge-pop detector, but pin its slide animations.
        // The real route animation above drives an interactive fade instead.
        return const CupertinoPageTransitionsBuilder().buildTransitions<T>(
          route,
          context,
          kAlwaysCompleteAnimation,
          kAlwaysDismissedAnimation,
          page,
        );
      case TargetPlatform.android:
        return _PredictiveFadeBack(route: route, child: page);
      default:
        return page;
    }
  }
}

/// Use public Route back-gesture hooks; no platform scale/slide decoration.
class _PredictiveFadeBack extends StatefulWidget {
  final PageRoute<dynamic> route;
  final Widget child;
  const _PredictiveFadeBack({required this.route, required this.child});
  @override
  State<_PredictiveFadeBack> createState() => _PredictiveFadeBackState();
}

class _PredictiveFadeBackState extends State<_PredictiveFadeBack>
    with WidgetsBindingObserver {
  bool participating = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent event) {
    if (event.isButtonEvent ||
        !widget.route.isCurrent ||
        !widget.route.popGestureEnabled) {
      return false;
    }
    participating = true;
    widget.route.handleStartBackGesture(progress: 1 - event.progress);
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent event) {
    if (participating) {
      widget.route.handleUpdateBackGestureProgress(
        progress: 1 - event.progress,
      );
    }
  }

  @override
  void handleCancelBackGesture() {
    if (participating) widget.route.handleCancelBackGesture();
    participating = false;
  }

  @override
  void handleCommitBackGesture() {
    if (participating) widget.route.handleCommitBackGesture();
    participating = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
