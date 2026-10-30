import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/links/wedo_deep_link.dart';

void main() {
  group('WeDoDeepLink.parse', () {
    test('parses canonical HTTPS group invite links and preserves exact case', () {
      final link = WeDoDeepLink.parse(
        'https://wedo-3304c.web.app/inv/AbC9_xYz-123',
      );
      expect(link, isA<WeDoGroupInviteLink>());
      expect((link as WeDoGroupInviteLink).inviteCode, 'AbC9_xYz-123');
    });

    test('parses secondary firebaseapp.com group invite links', () {
      final link = WeDoDeepLink.parse(
        'https://wedo-3304c.firebaseapp.com/inv/QaX7Mix1',
      );
      expect(link, isA<WeDoGroupInviteLink>());
      expect((link as WeDoGroupInviteLink).inviteCode, 'QaX7Mix1');
    });

    test('parses custom scheme wedo://inv/<inviteCode>', () {
      final link = WeDoDeepLink.parse('wedo://inv/TeSt_CoDe9');
      expect(link, isA<WeDoGroupInviteLink>());
      expect((link as WeDoGroupInviteLink).inviteCode, 'TeSt_CoDe9');
    });

    test('parses canonical HTTPS friend links with valid UUID', () {
      const userId = '550e8400-e29b-41d4-a716-446655440000';
      final link = WeDoDeepLink.parse('https://wedo-3304c.web.app/u/$userId');
      expect(link, isA<WeDoFriendProfileLink>());
      final friendLink = link as WeDoFriendProfileLink;
      expect(friendLink.userId, userId);
      expect(
        friendLink.canonicalDeepLink,
        'https://wedo-3304c.web.app/u/$userId',
      );
    });

    test('parses custom scheme wedo://u/<uuid> and legacy wedo://user/<uuid>', () {
      const userId = '550e8400-e29b-41d4-a716-446655440000';
      final linkU = WeDoDeepLink.parse('wedo://u/$userId');
      final linkLegacy = WeDoDeepLink.parse('wedo://user/$userId');
      expect(linkU, isA<WeDoFriendProfileLink>());
      expect((linkU as WeDoFriendProfileLink).userId, userId);
      expect(linkLegacy, isA<WeDoFriendProfileLink>());
      expect((linkLegacy as WeDoFriendProfileLink).userId, userId);
    });

    test('rejects untrusted hosts, query parameters, fragments, and malformed paths', () {
      expect(
        WeDoDeepLink.parse('https://wedo.app/inv/AbC9_xYz'),
        isNull,
      );
      expect(
        WeDoDeepLink.parse('https://evil.example.com/inv/AbC9_xYz'),
        isNull,
      );
      expect(
        WeDoDeepLink.parse('http://wedo-3304c.web.app/inv/AbC9_xYz'),
        isNull,
      );
      expect(
        WeDoDeepLink.parse('https://wedo-3304c.web.app/inv/AbC9_xYz?token=secret'),
        isNull,
      );
      expect(
        WeDoDeepLink.parse('https://wedo-3304c.web.app/inv/AbC9_xYz#frag'),
        isNull,
      );
      expect(
        WeDoDeepLink.parse('https://wedo-3304c.web.app/inv/AbC9_xYz/extra'),
        isNull,
      );
      expect(
        WeDoDeepLink.parse('https://wedo-3304c.web.app/u/not-a-uuid'),
        isNull,
      );
    });
  });

  group('WeDoDeepLink.extractInviteCodeFromInput', () {
    test('extracts exact code from raw invite code or canonical invite link', () {
      expect(
        WeDoDeepLink.extractInviteCodeFromInput('  AbC9_xYz  '),
        'AbC9_xYz',
      );
      expect(
        WeDoDeepLink.extractInviteCodeFromInput(
          'https://wedo-3304c.web.app/inv/AbC9_xYz',
        ),
        'AbC9_xYz',
      );
      expect(
        WeDoDeepLink.extractInviteCodeFromInput('wedo://inv/AbC9_xYz'),
        'AbC9_xYz',
      );
    });

    test('rejects arbitrary URLs or friend URLs pasted into group invite input', () {
      expect(
        WeDoDeepLink.extractInviteCodeFromInput('https://evil.com/inv/AbC9_xYz'),
        isNull,
      );
      expect(
        WeDoDeepLink.extractInviteCodeFromInput(
          'https://wedo-3304c.web.app/u/550e8400-e29b-41d4-a716-446655440000',
        ),
        isNull,
      );
    });
  });

  group('WeDoScanDeduplicator', () {
    test('suppresses duplicate scans of the same payload within cooldown window', () {
      final deduplicator = WeDoScanDeduplicator(
        cooldown: const Duration(seconds: 2),
      );
      final t0 = DateTime.utc(2026, 10, 18, 12, 0, 0);
      expect(
        deduplicator.shouldProcess(
          'https://wedo-3304c.web.app/u/550e8400-e29b-41d4-a716-446655440000',
          now: t0,
        ),
        isTrue,
      );
      expect(
        deduplicator.shouldProcess(
          'https://wedo-3304c.web.app/u/550e8400-e29b-41d4-a716-446655440000',
          now: t0.add(const Duration(milliseconds: 800)),
        ),
        isFalse,
      );
      expect(
        deduplicator.shouldProcess(
          'https://wedo-3304c.web.app/u/550e8400-e29b-41d4-a716-446655440000',
          now: t0.add(const Duration(seconds: 3)),
        ),
        isTrue,
      );
    });
  });
}
