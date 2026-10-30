import 'dart:async';

import 'package:flutter/widgets.dart';

import 'realtime_sync.dart';
import '../../features/auth/application/auth_session_controller.dart';

class RealtimeHost extends InheritedWidget {
  final RealtimeSync sync;
  const RealtimeHost({super.key, required this.sync, required super.child});
  static RealtimeSync? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RealtimeHost>()?.sync;
  @override
  bool updateShouldNotify(RealtimeHost oldWidget) => sync != oldWidget.sync;
}

class RealtimeSession extends StatefulWidget {
  final RealtimeSync sync;
  final AuthSessionController session;
  final Widget child;
  const RealtimeSession({
    super.key,
    required this.sync,
    required this.session,
    required this.child,
  });
  @override
  State<RealtimeSession> createState() => _RealtimeSessionState();
}

class _RealtimeSessionState extends State<RealtimeSession>
    with WidgetsBindingObserver {
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.session.addListener(_sessionChanged);
    _sessionChanged();
  }

  Future<void> _sessionChanged() async {
    final generation = ++_generation;
    widget.sync.reset();
    await widget.sync.client.disconnect();
    if (!mounted ||
        generation != _generation ||
        !widget.session.isAuthenticated) {
      return;
    }
    widget.sync.resync();
    await widget.sync.client.connect();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.session.isAuthenticated) {
      widget.sync.resync();
      unawaited(widget.sync.client.connect());
    }
  }

  @override
  void dispose() {
    _generation++;
    widget.session.removeListener(_sessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.sync.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RealtimeHost(sync: widget.sync, child: widget.child);
}

/// A binding invalidates one feature resource, not the application/root tree.
/// Trailing coalescing prevents bursts/own mutation echoes from refetch storms.
mixin RealtimeBinding<T extends StatefulWidget> on State<T> {
  String? get realtimeScope;
  String get realtimePrefix;
  Set<String> get realtimeAdditionalPrefixes => const {};
  String? get realtimeAggregateId => null;
  Set<String> get realtimeAdditionalScopes => const {};
  FutureOr<void> reloadRealtime();
  // Clear protected cached data immediately, even if the following REST read
  // cannot reach the server. Default preserves behavior of unaudited modules.
  void onRealtimeAccessLost() {}
  // Opt-in for an expected transient read failure, never a denied/programming
  // error or a mutation. PONG is existing transport reachability, not permission.
  bool get realtimeReadNeedsRecovery => false;
  bool _reachabilityRetrySpent = false;
  void Function()? _unwatch;
  RealtimeSync? _sync;
  String? _boundScope;
  Timer? _pending;
  bool _busy = false, _again = false, _closed = false;
  String? _resourceScope;
  final Set<String> _changeTypes = {};
  Set<String> takeRealtimeEventTypes() {
    final types = Set<String>.of(_changeTypes);
    _changeTypes.clear();
    return types;
  }

  void refreshRealtimeBindings() {
    if (mounted && !_closed) {
      _reachabilityRetrySpent = false;
      _bind();
    }
  }

  void bindRealtimeResource(String scope) {
    if (!mounted || _resourceScope == scope) return;
    _resourceScope = scope;
    _bind();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sync = RealtimeHost.maybeOf(context);
    if (_sync != sync) {
      _unwatch?.call();
      _unwatch = null;
      _boundScope = null;
      _sync = sync;
    }
    _bind();
  }

  void _bind() {
    final scope = _resourceScope ?? realtimeScope;
    final scopes = {?scope, ...realtimeAdditionalScopes};
    final key = (scopes.toList()..sort()).join('|');
    if (_closed || key == _boundScope) return;
    _unwatch?.call();
    _boundScope = key;
    final removers = [
      for (final item in scopes)
        for (final prefix in {realtimePrefix, ...realtimeAdditionalPrefixes})
          if (_sync != null)
            _sync!.watch(
              item,
              prefix,
              _invalidate,
              aggregateId: realtimeAggregateId,
              onAccessLost: onRealtimeAccessLost,
              onReachable: _onReachable,
              onChange: (event) {
                onRealtimeInvalidated();
                _changeTypes.add(event?.eventType ?? '*');
              },
            ),
    ];
    _unwatch = () {
      for (final remove in removers) {
        remove();
      }
    };
  }

  /// Feature may clear permission-sensitive caches before the coalesced REST read.
  void onRealtimeInvalidated() {}

  void _invalidate() {
    if (_closed) return;
    _reachabilityRetrySpent = false;
    _scheduleReload();
  }

  void _onReachable() {
    if (_closed || !mounted || _busy) return;
    if (!realtimeReadNeedsRecovery) {
      _reachabilityRetrySpent = false;
      return;
    }
    if (_reachabilityRetrySpent) return;
    _reachabilityRetrySpent = true;
    _scheduleReload();
  }

  void _scheduleReload() {
    _pending?.cancel();
    _pending = Timer(const Duration(milliseconds: 80), _reload);
  }

  Future<void> _reload() async {
    if (_closed || !mounted) return;
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    try {
      await reloadRealtime();
    } catch (_) {
      /* Feature retains its normal error state. */
    } finally {
      _busy = false;
      if (!realtimeReadNeedsRecovery) _reachabilityRetrySpent = false;
      if (_again && !_closed) {
        _again = false;
        _invalidate();
      }
    }
  }

  @override
  void dispose() {
    _closed = true;
    _pending?.cancel();
    _unwatch?.call();
    super.dispose();
  }
}
