import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/access_token_holder.dart';

void main() {
  test(
    'AccessTokenHolder starts empty, stores, and clears an access token',
    () {
      final holder = AccessTokenHolder();

      expect(holder.currentAccessToken, isNull);

      holder.setAccessToken('access-token');
      expect(holder.currentAccessToken, 'access-token');

      holder.clearAccessToken();
      expect(holder.currentAccessToken, isNull);
    },
  );
}
