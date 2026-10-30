import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/paged_response.dart';
import 'package:mobile/features/profile/data/profile_models.dart';
import 'package:mobile/features/profile/presentation/screens/public_user_profile_screen.dart';
import 'package:mobile/features/social/data/models/social_models.dart';
import 'package:mobile/features/social/data/social_api.dart';
import 'package:mobile/features/social/data/social_repository.dart';

void main() {
  testWidgets('message action uses valid Vietnamese and retains its callback', (
    tester,
  ) async {
    var messages = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PublicUserProfileScreen(
          userId: 'id',
          loadPublicProfile: (_) async => const PublicUserProfile(
            id: 'id',
            username: 'maya',
            displayName: 'Maya',
          ),
          onMessage: () => messages++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nhắn tin'));
    expect(messages, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('renders loading then only safe public fields with fallbacks', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PublicUserProfileScreen(
          userId: 'id',
          loadPublicProfile: (_) async => const PublicUserProfile(
            id: 'id',
            username: 'maya',
            displayName: null,
            avatarStorageKey: null,
            bio: null,
          ),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('maya'), findsOneWidget);
    expect(find.text('@maya'), findsOneWidget);
    expect(find.textContaining('email', findRichText: true), findsNothing);
    expect(find.text('Add Friend'), findsNothing);
    expect(find.text('Message'), findsNothing);
    expect(find.text('Block User'), findsNothing);
  });

  testWidgets('renders bio and supports safe retry on error', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PublicUserProfileScreen(
          userId: 'id',
          loadPublicProfile: (_) async {
            calls++;
            if (calls == 1) {
              throw Exception();
            }
            return const PublicUserProfile(
              id: 'id',
              username: 'maya',
              displayName: 'Maya Lin',
              bio: 'Designer',
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Không thể tải hồ sơ này.'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Maya Lin'), findsOneWidget);
    expect(find.text('Designer'), findsOneWidget);
  });

  testWidgets('renders relationship actions and transitions on add friend', (
    tester,
  ) async {
    final socialRepo = _FakeSocialRepository(RelationshipState.none);
    await tester.pumpWidget(
      MaterialApp(
        home: PublicUserProfileScreen(
          userId: 'target-id',
          loadPublicProfile: (_) async => const PublicUserProfile(
            id: 'target-id',
            username: 'maya',
            displayName: 'Maya Lin',
          ),
          socialRepository: socialRepo,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Thêm bạn bè'), findsOneWidget);
    await tester.tap(find.text('Thêm bạn bè'));
    await tester.pumpAndSettle();
    expect(socialRepo.sentRequests, 1);
    expect(find.text('Hủy lời mời'), findsOneWidget);
  });

  testWidgets('send cancel resend accept unfriend resend uses current state', (tester) async {
    final repo = _FakeSocialRepository(RelationshipState.none);
    await tester.pumpWidget(MaterialApp(home: PublicUserProfileScreen(
      userId: 'target-id',
      loadPublicProfile: (_) async => const PublicUserProfile(id: 'target-id', username: 'maya', displayName: 'Maya Lin'),
      socialRepository: repo,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm bạn bè'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy lời mời'));
    await tester.pumpAndSettle();
    expect(find.text('Thêm bạn bè'), findsOneWidget);
    await tester.tap(find.text('Thêm bạn bè'));
    await tester.pumpAndSettle();
    expect(find.text('Hủy lời mời'), findsOneWidget);
    // Peer accepts; refresh uses canonical relationship, not request history.
    repo.state = RelationshipState.friends;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(MaterialApp(home: PublicUserProfileScreen(
      userId: 'target-id',
      loadPublicProfile: (_) async => const PublicUserProfile(id: 'target-id', username: 'maya', displayName: 'Maya Lin'),
      socialRepository: repo,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bạn bè'));
    await tester.pumpAndSettle();
    repo.failRelationshipRead = true;
    await tester.tap(find.text('Hủy kết bạn').last);
    await tester.pumpAndSettle();
    expect(find.text('Thêm bạn bè'), findsOneWidget);
    expect(find.text('Hủy lời mời'), findsNothing);
    repo.failRelationshipRead = false;
    await tester.tap(find.text('Thêm bạn bè'));
    await tester.pumpAndSettle();
    expect(find.text('Hủy lời mời'), findsOneWidget);
    expect(repo.sentRequests, 3);
  });

  testWidgets('hides social and message actions when relationship is self', (
    tester,
  ) async {
    final socialRepo = _FakeSocialRepository(RelationshipState.self);
    await tester.pumpWidget(
      MaterialApp(
        home: PublicUserProfileScreen(
          userId: 'self-id',
          loadPublicProfile: (_) async => const PublicUserProfile(
            id: 'self-id',
            username: 'me',
            displayName: 'Me',
          ),
          socialRepository: socialRepo,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Thêm bạn bè'), findsNothing);
    expect(find.text('Nhắn tin'), findsNothing);
  });
}

class _FakeSocialRepository extends SocialRepository {
  RelationshipState state;
  int sentRequests = 0;
  bool failRelationshipRead = false;

  _FakeSocialRepository(this.state) : super(api: SocialApi(Dio()));

  @override
  Future<RelationshipStatus> getRelationship(String userId) async {
    if (failRelationshipRead) throw Exception('offline');
    return RelationshipStatus(userId: userId, state: state);
  }

  @override
  Future<void> unfriend(String userId) async { state = RelationshipState.none; }

  @override
  Future<void> cancelFriendRequest(String requestId) async { state = RelationshipState.none; }

  @override
  Future<FriendRequest> sendFriendRequest(String userId) async {
    sentRequests++;
    state = RelationshipState.pendingSent;
    return FriendRequest(
      id: 'req-1',
      sender: const SocialUserSummary(
        id: 'caller',
        username: 'caller',
        displayName: 'Caller',
      ),
      receiver: SocialUserSummary(
        id: userId,
        username: 'maya',
        displayName: 'Maya Lin',
      ),
      status: FriendRequestStatus.pending,
      createdAt: DateTime.utc(2026, 10, 18),
    );
  }

  @override
  Future<PagedResponse<FriendRequest>> getSentFriendRequests({
    int page = 0,
    int size = 30,
  }) async => PagedResponse(
    items: [
      FriendRequest(
        id: 'req-1',
        sender: const SocialUserSummary(
          id: 'caller',
          username: 'caller',
          displayName: 'Caller',
        ),
        receiver: const SocialUserSummary(
          id: 'target-id',
          username: 'maya',
          displayName: 'Maya Lin',
        ),
        status: FriendRequestStatus.pending,
        createdAt: DateTime.utc(2026, 10, 18),
      ),
    ],
    page: 0,
    size: 30,
    totalElements: 1,
    totalPages: 1,
    hasNext: false,
  );
}
