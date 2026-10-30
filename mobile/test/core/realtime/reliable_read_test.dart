import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/core/realtime/reliable_read.dart';

void main() {
  const network = ApiException(transportFailure: ApiTransportFailure.network);
  for (final failure in [
    network,
    const ApiException(transportFailure: ApiTransportFailure.timeout),
    const ApiException(statusCode: 503),
  ]) {
    test(
      'expected ${failure.transportFailure}/${failure.statusCode} retains last valid read',
      () async {
        final read = ReliableRead<int>();
        await read.load(() async => 1);
        await read.load(() async => throw failure);
        expect(read.value.data, 1);
        expect(read.failure?.retainData, isTrue);
        await read.load(() async => 2);
        expect(read.value.data, 2);
        expect(read.failure, isNull);
        read.dispose();
      },
    );
  }
  for (final status in [401, 403, 404]) {
    test('$status clears protected cached data', () async {
      final read = ReliableRead<int>();
      await read.load(() async => 1);
      await read.load(() async => throw ApiException(statusCode: status));
      expect(read.value.hasData, isFalse);
      expect(read.failure?.retainData, isFalse);
      read.dispose();
    });
  }
  for (final fail in [false, true]) {
    test(
      'stale ${fail ? 'error' : 'data'} and disposed response cannot apply',
      () async {
        final read = ReliableRead<int>();
        final old = Completer<int>();
        final pending = read.load(() => old.future);
        await read.load(() async => 2);
        if (fail) {
          old.completeError(network);
        } else {
          old.complete(1);
        }
        await pending;
        expect(read.value.data, 2);
        expect(read.failure, isNull);
        final late = Completer<int>();
        final last = read.load(() => late.future);
        read.dispose();
        if (fail) {
          late.completeError(network);
        } else {
          late.complete(3);
        }
        await last;
        expect(read.value.data, 2);
      },
    );
  }
  test('revocation invalidates pending reads; mutation response invalidates older read', () async {
    final read = ReliableRead<int>();
    final old = Completer<int>();
    final pending = read.load(() => old.future);
    read.denyAccess();
    old.complete(1);
    await pending;
    expect(read.value.hasData, isFalse);
    final older = Completer<int>();
    final pendingOlder = read.load(() => older.future);
    read.accept(3);
    older.complete(2);
    await pendingOlder;
    expect(read.value.data, 3);
    read.dispose();
  });
  testWidgets(
    'programming failure is reported and initial loading terminates',
    (tester) async {
      final read = ReliableRead<int>();
      await read.load(() async => throw StateError('bad mapper'));
      expect(tester.takeException(), isA<StateError>());
      expect(read.value.connectionState, ConnectionState.done);
      expect(read.value.hasData, isFalse);
      read.dispose();
    },
  );
}
