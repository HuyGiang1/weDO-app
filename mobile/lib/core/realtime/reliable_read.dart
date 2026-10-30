import 'package:flutter/material.dart';

import '../network/api_exception.dart';

/// Presentation-only failure policy. Cached values are never authoritative writes.
class ReadFailure {
  final String message;
  final bool retainData;
  final bool accessDenied;
  const ReadFailure(
    this.message, {
    this.retainData = false,
    this.accessDenied = false,
  });

  static ReadFailure? fromError(Object error) {
    if (error is! ApiException) return null;
    if (error.statusCode == 401) {
      return const ReadFailure(
        'Cần đăng nhập lại để xem dữ liệu.',
        accessDenied: true,
      );
    }
    if (error.statusCode == 403 || error.statusCode == 404) {
      return const ReadFailure(
        'Bạn không có quyền truy cập hoặc dữ liệu không còn tồn tại.',
        accessDenied: true,
      );
    }
    final transient =
        error.transportFailure == ApiTransportFailure.network ||
        error.transportFailure == ApiTransportFailure.timeout ||
        (error.statusCode != null && error.statusCode! >= 500);
    return ReadFailure(
      transient
          ? 'Không thể kết nối đến máy chủ. Vui lòng thử lại.'
          : 'Không thể tải dữ liệu. Vui lòng thử lại.',
      retainData: transient,
    );
  }
}

/// Owns initial/local/realtime reads with immediate error listeners and one
/// request generation. No sockets, timers, retries or business mutations.
class ReliableRead<T> extends ValueNotifier<AsyncSnapshot<T>> {
  ReliableRead({this.classify = ReadFailure.fromError})
    : super(AsyncSnapshot<T>.nothing());

  final ReadFailure? Function(Object) classify;
  ReadFailure? failure;
  int _generation = 0;
  bool _disposed = false;
  int get generation => _generation;
  bool isCurrent(int generation) => !_disposed && generation == _generation;

  void _publish(AsyncSnapshot<T> snapshot) {
    // Failure feedback can change while retained data compares equal.
    if (value == snapshot) {
      notifyListeners();
    } else {
      value = snapshot;
    }
  }

  Future<void> load(
    Future<T> Function() fetch, {
    void Function(T)? onData,
  }) async {
    if (_disposed) return;
    final request = ++_generation;
    // Existing data stays mounted during refetch; initial retry gets a spinner.
    if (!value.hasData && failure?.accessDenied != true) {
      failure = null;
      _publish(AsyncSnapshot<T>.waiting());
    }
    try {
      final data = await fetch();
      if (_disposed || request != _generation) return;
      onData?.call(data);
      if (_disposed || request != _generation) return;
      failure = null;
      _publish(AsyncSnapshot<T>.withData(ConnectionState.done, data));
    } catch (error, stack) {
      final expected = classify(error);
      if (!_disposed && request == _generation) {
        // A transport failure cannot turn an already-known denial into offline
        // permission. Only a successful authoritative read restores access.
        if (failure?.accessDenied == true && expected?.retainData == true) {
          return;
        }
        failure = expected ?? const ReadFailure('Không thể đọc dữ liệu.');
        _publish(
          expected?.retainData == true && value.hasData
              ? AsyncSnapshot<T>.withData(
                  ConnectionState.done,
                  value.requireData,
                )
              : AsyncSnapshot<T>.withError(ConnectionState.done, error, stack),
        );
      }
      if (expected == null) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'ReliableRead',
            context: ErrorDescription(
              'while refetching authoritative resource state',
            ),
          ),
        );
      }
    }
  }

  void denyAccess() {
    if (_disposed) return;
    _generation++;
    failure = const ReadFailure(
      'Bạn không có quyền truy cập dữ liệu này.',
      accessDenied: true,
    );
    value = AsyncSnapshot<T>.withError(
      ConnectionState.done,
      const ApiException(statusCode: 403),
    );
  }

  /// Used only with a successful authoritative mutation response.
  void accept(T data) {
    if (_disposed) return;
    _generation++;
    failure = null;
    _publish(AsyncSnapshot<T>.withData(ConnectionState.done, data));
  }

  void reset() {
    if (_disposed) return;
    _generation++;
    failure = null;
    _publish(AsyncSnapshot<T>.nothing());
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

/// Six existing bounded screen bodies use this without replacing their UI.
/// Cached content is labelled and read-only until an authoritative read succeeds.
class ReliableReadBuilder<T> extends StatelessWidget {
  final ReliableRead<T> read;
  final VoidCallback onRetry;
  final Widget Function(BuildContext, AsyncSnapshot<T>) builder;
  const ReliableReadBuilder({
    super.key,
    required this.read,
    required this.onRetry,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<AsyncSnapshot<T>>(
        valueListenable: read,
        builder: (context, snapshot, _) {
          final failure = read.failure;
          if (failure != null && !snapshot.hasData) {
            return Center(
              child: TextButton(
                onPressed: onRetry,
                child: Text('${failure.message} Thử lại'),
              ),
            );
          }
          return Column(
            children: [
              if (failure != null)
                TextButton(
                  onPressed: onRetry,
                  child: Text('Dữ liệu chưa được cập nhật. ${failure.message}'),
                ),
              Expanded(
                child: AbsorbPointer(
                  absorbing: failure != null,
                  child: builder(context, snapshot),
                ),
              ),
            ],
          );
        },
      );
}
