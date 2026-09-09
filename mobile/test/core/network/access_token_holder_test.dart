import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/access_token_holder.dart';

void main() {
  group('AccessTokenHolder', () {
    test(
      'starts empty with revision 0, stores and clears access token while incrementing revision monotonically',
      () {
        final holder = AccessTokenHolder();

        expect(holder.currentAccessToken, isNull);
        expect(holder.revision, 0);

        holder.setAccessToken('token-1');
        expect(holder.currentAccessToken, 'token-1');
        expect(holder.revision, 1);

        holder.setAccessToken('token-2');
        expect(holder.currentAccessToken, 'token-2');
        expect(holder.revision, 2);

        holder.clearAccessToken();
        expect(holder.currentAccessToken, isNull);
        expect(holder.revision, 3);

        holder.clearAccessToken();
        expect(holder.currentAccessToken, isNull);
        expect(holder.revision, 4);

        holder.setAccessToken('token-3');
        expect(holder.currentAccessToken, 'token-3');
        expect(holder.revision, 5);
      },
    );
  });
}
