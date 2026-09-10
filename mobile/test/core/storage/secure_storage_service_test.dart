import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/storage/secure_key_value_store.dart';
import 'package:mobile/core/storage/secure_storage_service.dart';

void main() {
  group('SecureStorageService', () {
    late InMemorySecureStore store;
    late SecureStorageService service;

    setUp(() {
      store = InMemorySecureStore();
      service = SecureStorageService(store: store);
    });

    test(
      'writes and reads only access and refresh session credentials',
      () async {
        await service.writeSession(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
        );

        expect(await service.readAccessToken(), 'access-token');
        expect(await service.readRefreshToken(), 'refresh-token');
        expect(store.values.keys, {
          SecureStorageService.accessTokenKey,
          SecureStorageService.refreshTokenKey,
        });
        expect(store.operations.join(' '), isNot(contains('profile')));
      },
    );

    test('clears both session credentials', () async {
      await service.writeSession(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      );

      await service.clearSession();

      expect(await service.readAccessToken(), isNull);
      expect(await service.readRefreshToken(), isNull);
    });

    test('clears both keys if a session write partially fails', () async {
      store.failWriteFor = SecureStorageService.refreshTokenKey;

      await expectLater(
        service.writeSession(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
        ),
        throwsStateError,
      );

      expect(store.values, isEmpty);
    });
  });
}

class InMemorySecureStore implements SecureKeyValueStore {
  final Map<String, String> values = {};
  final List<String> operations = [];
  String? failWriteFor;

  @override
  Future<void> delete(String key) async {
    operations.add('delete:$key');
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async {
    operations.add('read:$key');
    return values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    operations.add('write:$key');
    if (key == failWriteFor) throw StateError('simulated write failure');
    values[key] = value;
  }
}
