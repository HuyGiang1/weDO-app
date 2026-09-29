import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:mobile/app/routes.dart';
import 'package:mobile/features/auth/application/auth_session_controller.dart';
import 'package:mobile/features/auth/presentation/auth_flow_coordinator.dart';
import 'package:mobile/features/auth/presentation/screens/create_username_screen.dart';
import 'package:mobile/features/auth/presentation/screens/verify_email_screen.dart';
import 'package:mobile/features/auth/data/models/auth_models.dart';
import 'package:mobile/features/groups/data/group_api.dart';
import 'package:mobile/features/groups/data/group_repository.dart';
import 'package:mobile/features/groups/data/models/group_models.dart';
import 'package:mobile/core/models/paged_response.dart';
import 'package:mobile/features/activity/data/activity_api.dart';
import 'package:mobile/features/activity/data/activity_repository.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/core/network/access_token_holder.dart';
import 'package:mobile/core/storage/secure_key_value_store.dart';
import 'package:mobile/core/storage/secure_storage_service.dart';
import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';
import 'package:mobile/features/groups/presentation/screens/my_groups_screen.dart';
import 'package:mobile/features/profile/data/profile_models.dart';
import 'package:mobile/features/profile/presentation/screens/public_user_profile_screen.dart';

void main() {
  group('AppRoutes Registry', () {
    test('contains exactly 40 registered production routes', () {
      expect(AppRoutes.routes.length, 40);

      final expectedRoutes = <String>{
        AppRoutes.welcome,
        AppRoutes.register,
        AppRoutes.verifyEmail,
        AppRoutes.login,
        AppRoutes.forgotPassword,
        AppRoutes.resetPassword,
        AppRoutes.createUsername,
        AppRoutes.completeProfile,
        AppRoutes.profile,
        AppRoutes.changePassword,
        AppRoutes.privacy,
        AppRoutes.personalQr,
        AppRoutes.publicUserProfile,
        AppRoutes.groups,
        AppRoutes.createGroup,
        AppRoutes.groupInfo,
        AppRoutes.groupActivityLog,
        AppRoutes.editGroup,
        AppRoutes.groupMembers,
        AppRoutes.memberManagement,
        AppRoutes.groupPermissions,
        AppRoutes.groupAdmins,
        AppRoutes.transferOwnership,
        AppRoutes.groupInvitations,
        AppRoutes.joinGroupByCode,
        AppRoutes.groupInviteLinks,
        AppRoutes.groupJoinRequests,
        AppRoutes.groupBans,
        AppRoutes.activities,
        AppRoutes.activityDetail,
        AppRoutes.polls,
        AppRoutes.tasks,
        AppRoutes.groupChat,
        AppRoutes.chatHome,
        AppRoutes.chatRequests,
        AppRoutes.groupExpenses,
        AppRoutes.groupSettlements,
        AppRoutes.groupFund,
        AppRoutes.notifications,
        AppRoutes.notificationSettings,
      };

      expect(AppRoutes.routes.keys.toSet(), expectedRoutes);
    });

    test('every registered route has explicit access metadata', () {
      for (final entry in AppRoutes.routes.entries) {
        expect(
          entry.value.access,
          entry.key == AppRoutes.profile ||
                  entry.key == AppRoutes.changePassword ||
                  entry.key == AppRoutes.privacy ||
                  entry.key == AppRoutes.personalQr ||
                  entry.key == AppRoutes.publicUserProfile ||
                  entry.key == AppRoutes.groups ||
                  entry.key == AppRoutes.createGroup ||
                  entry.key == AppRoutes.groupInfo ||
                  entry.key == AppRoutes.groupActivityLog ||
                  entry.key == AppRoutes.editGroup ||
                  entry.key == AppRoutes.groupMembers ||
                  entry.key == AppRoutes.memberManagement ||
                  entry.key == AppRoutes.groupPermissions ||
                  entry.key == AppRoutes.groupAdmins ||
                  entry.key == AppRoutes.transferOwnership ||
                  entry.key == AppRoutes.groupInvitations ||
                  entry.key == AppRoutes.joinGroupByCode ||
                  entry.key == AppRoutes.groupInviteLinks ||
                  entry.key == AppRoutes.groupJoinRequests ||
                  entry.key == AppRoutes.groupBans ||
                  entry.key == AppRoutes.activities ||
                  entry.key == AppRoutes.activityDetail ||
                  entry.key == AppRoutes.polls ||
                  entry.key == AppRoutes.tasks ||
                  entry.key == AppRoutes.groupChat ||
                  entry.key == AppRoutes.chatHome ||
                  entry.key == AppRoutes.chatRequests ||
                  entry.key == AppRoutes.groupExpenses ||
                  entry.key == AppRoutes.groupSettlements ||
                  entry.key == AppRoutes.groupFund ||
                  entry.key == AppRoutes.notifications ||
                  entry.key == AppRoutes.notificationSettings
              ? AppRouteAccess.authenticated
              : AppRouteAccess.public,
          reason: 'Route ${entry.key} must declare its intended access',
        );
      }
    });
  });

  group('Protected Profile Route', () {
    Future<CurrentUser> loadUser() async => const CurrentUser(
      id: 'user-id',
      email: 'user@wedo.social',
      status: 'ACTIVE',
      emailVerified: true,
    );

    RouteSettings settings() => RouteSettings(
      name: AppRoutes.profile,
      arguments: ProfileRouteArgs(
        loadCurrentUser: loadUser,
        updateProfile: (_) async => loadUser(),
        updateUsername: (_) async => loadUser(),
        changePassword: ({
          required currentPassword,
          required newPassword,
        }) async {},
        endSessionAfterPasswordChange: () async => true,
      ),
    );

    test('allows the profile route only for authenticated sessions', () {
      expect(
        AppRoutes.onGenerateRoute(
          settings(),
          authStatus: AuthSessionStatus.authenticated,
        ),
        isA<MaterialPageRoute<void>>(),
      );
      expect(
        AppRoutes.onGenerateRoute(
          settings(),
          authStatus: AuthSessionStatus.unauthenticated,
        ),
        isNull,
      );
      expect(
        AppRoutes.onGenerateRoute(
          settings(),
          authStatus: AuthSessionStatus.restoring,
        ),
        isNull,
      );
    });

    test('fails closed when the authenticated profile route has no loader', () {
      expect(
        AppRoutes.onGenerateRoute(
          const RouteSettings(name: AppRoutes.profile),
          authStatus: AuthSessionStatus.authenticated,
        ),
        isNull,
      );
    });
  });

  group('Protected Privacy Route', () {
    RouteSettings settings() => RouteSettings(
      name: AppRoutes.privacy,
      arguments: PrivacyRouteArgs(
        loadPrivacySettings: () async => throw UnimplementedError(),
        updatePrivacySettings: (_) async => throw UnimplementedError(),
      ),
    );

    test('allows only authenticated sessions', () {
      expect(
        AppRoutes.onGenerateRoute(
          settings(),
          authStatus: AuthSessionStatus.authenticated,
        ),
        isNotNull,
      );
      expect(
        AppRoutes.onGenerateRoute(
          settings(),
          authStatus: AuthSessionStatus.unauthenticated,
        ),
        isNull,
      );
      expect(
        AppRoutes.onGenerateRoute(
          settings(),
          authStatus: AuthSessionStatus.restoring,
        ),
        isNull,
      );
    });
  });

  group('Protected Personal QR Route', () {
    RouteSettings settings() => RouteSettings(
      name: AppRoutes.personalQr,
      arguments: PersonalQrRouteArgs(
        loadPersonalQr: () async => throw UnimplementedError(),
      ),
    );
    test('allows only authenticated sessions', () {
      expect(
        AppRoutes.onGenerateRoute(
          settings(),
          authStatus: AuthSessionStatus.authenticated,
        ),
        isNotNull,
      );
      expect(
        AppRoutes.onGenerateRoute(
          settings(),
          authStatus: AuthSessionStatus.unauthenticated,
        ),
        isNull,
      );
      expect(
        AppRoutes.onGenerateRoute(
          settings(),
          authStatus: AuthSessionStatus.restoring,
        ),
        isNull,
      );
    });
  });

  group('Protected Public User Profile Route', () {
    RouteSettings settings(String id) => RouteSettings(
      name: AppRoutes.publicUserProfile,
      arguments: PublicUserProfileRouteArgs(
        userId: id,
        loadPublicProfile: (userId) async =>
            PublicUserProfile(id: userId, username: 'maya'),
      ),
    );
    test(
      'is guarded and fails closed for missing, wrong, or blank arguments',
      () {
        expect(
          AppRoutes.onGenerateRoute(
            settings('target'),
            authStatus: AuthSessionStatus.unauthenticated,
          ),
          isNull,
        );
        expect(
          AppRoutes.onGenerateRoute(
            const RouteSettings(name: AppRoutes.publicUserProfile),
            authStatus: AuthSessionStatus.authenticated,
          ),
          isNull,
        );
        expect(
          AppRoutes.onGenerateRoute(
            const RouteSettings(
              name: AppRoutes.publicUserProfile,
              arguments: 'target',
            ),
            authStatus: AuthSessionStatus.authenticated,
          ),
          isNull,
        );
        expect(
          AppRoutes.onGenerateRoute(
            settings('  '),
            authStatus: AuthSessionStatus.authenticated,
          ),
          isNull,
        );
      },
    );
    testWidgets(
      'forwards the exact typed userId to the public profile screen',
      (tester) async {
        var received = '';
        final route =
            AppRoutes.onGenerateRoute(
                  RouteSettings(
                    name: AppRoutes.publicUserProfile,
                    arguments: PublicUserProfileRouteArgs(
                      userId: 'target-id',
                      loadPublicProfile: (id) async {
                        received = id;
                        return PublicUserProfile(id: id, username: 'maya');
                      },
                    ),
                  ),
                  authStatus: AuthSessionStatus.authenticated,
                )!
                as MaterialPageRoute<void>;
        await tester.pumpWidget(
          MaterialApp(home: Builder(builder: route.builder)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PublicUserProfileScreen), findsOneWidget);
        expect(received, 'target-id');
      },
    );
  });

  group('Public Route Generation Across Session Statuses', () {
    const statuses = [
      AuthSessionStatus.restoring,
      AuthSessionStatus.unauthenticated,
      AuthSessionStatus.authenticated,
    ];

    for (final status in statuses) {
      test('generates welcome route under $status', () {
        final route = AppRoutes.onGenerateRoute(
          const RouteSettings(name: AppRoutes.welcome),
          authStatus: status,
        );

        expect(route, isNotNull);
        expect(route, isA<MaterialPageRoute<void>>());
      });

      test('generates login route under $status', () {
        final route = AppRoutes.onGenerateRoute(
          const RouteSettings(name: AppRoutes.login),
          authStatus: status,
        );

        expect(route, isNotNull);
        expect(route, isA<MaterialPageRoute<void>>());
      });

      test('generates register route under $status', () {
        final route = AppRoutes.onGenerateRoute(
          const RouteSettings(name: AppRoutes.register),
          authStatus: status,
        );

        expect(route, isNotNull);
        expect(route, isA<MaterialPageRoute<void>>());
      });

      test('generates forgotPassword route under $status', () {
        final route = AppRoutes.onGenerateRoute(
          const RouteSettings(name: AppRoutes.forgotPassword),
          authStatus: status,
        );

        expect(route, isNotNull);
        expect(route, isA<MaterialPageRoute<void>>());
      });
    }
  });

  group('Route Argument Validation Fail-Closed Regression', () {
    const authStatus = AuthSessionStatus.unauthenticated;

    group('VerifyEmail route args', () {
      test('returns null when arguments are null', () {
        final route = AppRoutes.onGenerateRoute(
          const RouteSettings(name: AppRoutes.verifyEmail),
          authStatus: authStatus,
        );
        expect(route, isNull);
      });

      test('returns null when arguments are wrong type', () {
        final route = AppRoutes.onGenerateRoute(
          const RouteSettings(
            name: AppRoutes.verifyEmail,
            arguments: 'user@example.com',
          ),
          authStatus: authStatus,
        );
        expect(route, isNull);
      });

      test('returns null when VerifyEmailRouteArgs email is empty', () {
        final route = AppRoutes.onGenerateRoute(
          const RouteSettings(
            name: AppRoutes.verifyEmail,
            arguments: VerifyEmailRouteArgs(
              email: '',
              initialCooldownSeconds: 30,
            ),
          ),
          authStatus: authStatus,
        );
        expect(route, isNull);
      });

      test('returns null when VerifyEmailRouteArgs initialCooldownSeconds is negative', () {
        final route = AppRoutes.onGenerateRoute(
          const RouteSettings(
            name: AppRoutes.verifyEmail,
            arguments: VerifyEmailRouteArgs(
              email: 'user@example.com',
              initialCooldownSeconds: -1,
            ),
          ),
          authStatus: authStatus,
        );
        expect(route, isNull);
      });

      test('generates route when VerifyEmailRouteArgs are valid', () {
        final route = AppRoutes.onGenerateRoute(
          const RouteSettings(
            name: AppRoutes.verifyEmail,
            arguments: VerifyEmailRouteArgs(
              email: 'user@example.com',
              initialCooldownSeconds: 30,
            ),
          ),
          authStatus: authStatus,
        );
        expect(route, isNotNull);
        expect(route, isA<MaterialPageRoute<void>>());
      });

      test('generates route when VerifyEmailFlowArgs are valid', () {
        final route = AppRoutes.onGenerateRoute(
          RouteSettings(
            name: AppRoutes.verifyEmail,
            arguments: VerifyEmailFlowArgs(
              email: 'user@example.com',
              onVerify: (_) async {},
              onResend: () async => null,
            ),
          ),
          authStatus: authStatus,
        );
        expect(route, isNotNull);
        expect(route, isA<MaterialPageRoute<void>>());
      });

      testWidgets('uses only the supplied route arguments', (tester) async {
        final route = AppRoutes.onGenerateRoute(
          const RouteSettings(
            name: AppRoutes.verifyEmail,
            arguments: VerifyEmailRouteArgs(
              email: 'real.user@wedo.social',
              initialCooldownSeconds: 17,
            ),
          ),
          authStatus: authStatus,
        );

        expect(route, isA<MaterialPageRoute<void>>());
        final materialRoute = route! as MaterialPageRoute<void>;
        await tester.pumpWidget(
          MaterialApp(home: Builder(builder: materialRoute.builder)),
        );

        expect(find.byType(VerifyEmailScreen), findsOneWidget);
        expect(find.textContaining('real.user@wedo.social'), findsOneWidget);
        expect(find.text('Resend in 0:17'), findsOneWidget);
        expect(find.text('user@wedo.social'), findsNothing);
      });
    });

    group('ResetPassword route args', () {
      test('returns null when arguments are null', () {
        final route = AppRoutes.onGenerateRoute(
          const RouteSettings(name: AppRoutes.resetPassword),
          authStatus: authStatus,
        );
        expect(route, isNull);
      });

      test('returns null when arguments are wrong type', () {
        final route = AppRoutes.onGenerateRoute(
          const RouteSettings(name: AppRoutes.resetPassword, arguments: 12345),
          authStatus: authStatus,
        );
        expect(route, isNull);
      });

      test(
        'returns null when ResetPasswordRouteArgs email is empty or whitespace',
        () {
          final emptyRoute = AppRoutes.onGenerateRoute(
            const RouteSettings(
              name: AppRoutes.resetPassword,
              arguments: ResetPasswordRouteArgs(email: ''),
            ),
            authStatus: authStatus,
          );
          expect(emptyRoute, isNull);

          final whitespaceRoute = AppRoutes.onGenerateRoute(
            const RouteSettings(
              name: AppRoutes.resetPassword,
              arguments: ResetPasswordRouteArgs(email: '   '),
            ),
            authStatus: authStatus,
          );
          expect(whitespaceRoute, isNull);
        },
      );

      test('generates route when ResetPasswordRouteArgs are valid', () {
        final route = AppRoutes.onGenerateRoute(
          const RouteSettings(
            name: AppRoutes.resetPassword,
            arguments: ResetPasswordRouteArgs(email: 'user@example.com'),
          ),
          authStatus: authStatus,
        );
        expect(route, isNotNull);
        expect(route, isA<MaterialPageRoute<void>>());
      });
    });

    group('CreateUsername route args', () {
      test('returns null when arguments are null', () {
        final route = AppRoutes.onGenerateRoute(
          const RouteSettings(name: AppRoutes.createUsername),
          authStatus: authStatus,
        );
        expect(route, isNull);
      });

      test('returns null when arguments are wrong type', () {
        final route = AppRoutes.onGenerateRoute(
          const RouteSettings(
            name: AppRoutes.createUsername,
            arguments: 'my_user',
          ),
          authStatus: authStatus,
        );
        expect(route, isNull);
      });

      test('generates route when CreateUsernameFlowArgs are valid', () {
        final route = AppRoutes.onGenerateRoute(
          RouteSettings(
            name: AppRoutes.createUsername,
            arguments: CreateUsernameFlowArgs(
              onCheckAvailability: (_) async => UsernameAvailability.available,
              onContinue: (_) async {},
            ),
          ),
          authStatus: authStatus,
        );
        expect(route, isNotNull);
        expect(route, isA<MaterialPageRoute<void>>());
      });
    });

    group('CompleteProfile route args', () {
      test('returns null when arguments are null', () {
        final route = AppRoutes.onGenerateRoute(
          const RouteSettings(name: AppRoutes.completeProfile),
          authStatus: authStatus,
        );
        expect(route, isNull);
      });

      test('returns null when arguments are wrong type', () {
        final route = AppRoutes.onGenerateRoute(
          const RouteSettings(
            name: AppRoutes.completeProfile,
            arguments: {'username': 'my_user'},
          ),
          authStatus: authStatus,
        );
        expect(route, isNull);
      });

      test('generates route when CompleteProfileFlowArgs are valid', () {
        final route = AppRoutes.onGenerateRoute(
          RouteSettings(
            name: AppRoutes.completeProfile,
            arguments: CompleteProfileFlowArgs(
              username: 'user_1',
              onContinue: (_) async {},
            ),
          ),
          authStatus: authStatus,
        );
        expect(route, isNotNull);
        expect(route, isA<MaterialPageRoute<void>>());
      });
    });
  });

  group('Unknown Route Handling', () {
    const statuses = [
      AuthSessionStatus.restoring,
      AuthSessionStatus.unauthenticated,
      AuthSessionStatus.authenticated,
    ];

    for (final status in statuses) {
      test('returns null for unregistered route under $status', () {
        expect(
          AppRoutes.onGenerateRoute(
            const RouteSettings(name: '/unknown-route'),
            authStatus: status,
          ),
          isNull,
        );

        expect(
          AppRoutes.onGenerateRoute(
            const RouteSettings(name: '/home'),
            authStatus: status,
          ),
          isNull,
        );

        expect(
          AppRoutes.onGenerateRoute(
            const RouteSettings(name: '/dashboard'),
            authStatus: status,
          ),
          isNull,
        );
      });

      test('returns null for null route name under $status', () {
        expect(
          AppRoutes.onGenerateRoute(
            const RouteSettings(name: null),
            authStatus: status,
          ),
          isNull,
        );
      });
    }
  });

  group('Denied-Builder Policy (Test-Only Seam)', () {
    test('builder is never invoked when route is authenticated-required and status is unauthenticated', () {
      var builderInvocations = 0;
      final testProtectedDef = AppRouteDefinition(
        access: AppRouteAccess.authenticated,
        builder: (settings, coordinator) {
          builderInvocations++;
          return MaterialPageRoute<void>(
            builder: (_) => const SizedBox.shrink(),
            settings: settings,
          );
        },
      );

      final route = AppRoutes.evaluateAndBuildRoute(
        testProtectedDef,
        const RouteSettings(name: '/test-protected'),
        authStatus: AuthSessionStatus.unauthenticated,
      );

      expect(route, isNull);
      expect(builderInvocations, 0);
    });

    test('builder is never invoked when route is authenticated-required and status is restoring', () {
      var builderInvocations = 0;
      final testProtectedDef = AppRouteDefinition(
        access: AppRouteAccess.authenticated,
        builder: (settings, coordinator) {
          builderInvocations++;
          return MaterialPageRoute<void>(
            builder: (_) => const SizedBox.shrink(),
            settings: settings,
          );
        },
      );

      final route = AppRoutes.evaluateAndBuildRoute(
        testProtectedDef,
        const RouteSettings(name: '/test-protected'),
        authStatus: AuthSessionStatus.restoring,
      );

      expect(route, isNull);
      expect(builderInvocations, 0);
    });

    test('builder is invoked when route is authenticated-required and status is authenticated', () {
      var builderInvocations = 0;
      final testProtectedDef = AppRouteDefinition(
        access: AppRouteAccess.authenticated,
        builder: (settings, coordinator) {
          builderInvocations++;
          return MaterialPageRoute<void>(
            builder: (_) => const SizedBox.shrink(),
            settings: settings,
          );
        },
      );

      final route = AppRoutes.evaluateAndBuildRoute(
        testProtectedDef,
        const RouteSettings(name: '/test-protected'),
        authStatus: AuthSessionStatus.authenticated,
      );

      expect(route, isNotNull);
      expect(builderInvocations, 1);
    });
  });

  group('M5 typed protected group routes', () {
    final protected = <String>[
      AppRoutes.groups,
      AppRoutes.createGroup,
      AppRoutes.groupInfo,
      AppRoutes.groupActivityLog,
      AppRoutes.editGroup,
      AppRoutes.groupMembers,
      AppRoutes.memberManagement,
      AppRoutes.groupPermissions,
      AppRoutes.groupAdmins,
      AppRoutes.transferOwnership,
    ];

    test('all M5 group routes are denied before their builders for guests', () {
      final repository = _RouteGroupRepository();
      for (final name in protected) {
        final arguments = _groupRouteArgs(name, repository);
        expect(
          AppRoutes.onGenerateRoute(
            RouteSettings(name: name, arguments: arguments),
            authStatus: AuthSessionStatus.unauthenticated,
          ),
          isNull,
          reason: '$name must remain AuthRouteGuard-protected',
        );
      }
    });

    test(
      'M5 group routes fail closed for missing, wrong, or blank arguments',
      () {
        final repository = _RouteGroupRepository();
        for (final name in protected) {
          expect(
            AppRoutes.onGenerateRoute(
              RouteSettings(name: name),
              authStatus: AuthSessionStatus.authenticated,
            ),
            isNull,
          );
          expect(
            AppRoutes.onGenerateRoute(
              RouteSettings(name: name, arguments: 'wrong'),
              authStatus: AuthSessionStatus.authenticated,
            ),
            isNull,
          );
          if (name != AppRoutes.groups && name != AppRoutes.createGroup) {
            final blank = name == AppRoutes.memberManagement
                ? GroupMemberRouteArgs(
                    repository: repository,
                    groupId: '',
                    userId: 'user-id',
                  )
                : GroupInfoRouteArgs(repository: repository, groupId: '');
            expect(
              AppRoutes.onGenerateRoute(
                RouteSettings(name: name, arguments: blank),
                authStatus: AuthSessionStatus.authenticated,
              ),
              isNull,
            );
          }
        }
      },
    );

    testWidgets('typed arguments reach M5 route controllers unchanged', (
      tester,
    ) async {
      final repository = _RouteGroupRepository();
      final expectedCalls = <String, List<String>>{
        AppRoutes.groupInfo: ['group:group-id', 'members:group-id'],
        AppRoutes.groupActivityLog: ['activities:group-id'],
        AppRoutes.editGroup: ['group:group-id'],
        AppRoutes.groupMembers: ['members:group-id'],
        AppRoutes.memberManagement: [
          'group:group-id',
          'member:group-id:user-id',
        ],
        AppRoutes.groupPermissions: ['group:group-id', 'settings:group-id'],
        AppRoutes.groupAdmins: ['group:group-id', 'members:group-id'],
        AppRoutes.transferOwnership: ['group:group-id', 'members:group-id'],
      };
      for (final entry in expectedCalls.entries) {
        repository.calls.clear();
        final arguments = entry.key == AppRoutes.memberManagement
            ? GroupMemberRouteArgs(
                repository: repository,
                groupId: 'group-id',
                userId: 'user-id',
              )
            : GroupInfoRouteArgs(repository: repository, groupId: 'group-id');
        final route =
            AppRoutes.onGenerateRoute(
                  RouteSettings(name: entry.key, arguments: arguments),
                  authStatus: AuthSessionStatus.authenticated,
                )!
                as MaterialPageRoute<void>;
        await tester.pumpWidget(
          MaterialApp(home: Builder(builder: route.builder)),
        );
        await tester.pumpAndSettle();
        expect(repository.calls, entry.value, reason: entry.key);
      }
    });
  });

  group('Protected M7 Activity Routes', () {
    final activityRepo = ActivityRepository(api: ActivityApi(Dio()));

    test(
      'activities and activityDetail are denied for unauthenticated users',
      () {
        expect(
          AppRoutes.onGenerateRoute(
            RouteSettings(
              name: AppRoutes.activities,
              arguments: ActivitiesRouteArgs(
                repository: activityRepo,
                groupId: 'g1',
              ),
            ),
            authStatus: AuthSessionStatus.unauthenticated,
          ),
          isNull,
        );

        expect(
          AppRoutes.onGenerateRoute(
            RouteSettings(
              name: AppRoutes.activityDetail,
              arguments: ActivityDetailRouteArgs(
                repository: activityRepo,
                activityId: 'a1',
              ),
            ),
            authStatus: AuthSessionStatus.unauthenticated,
          ),
          isNull,
        );
      },
    );

    test('activities fails closed for missing, wrong, or blank arguments', () {
      for (final bad in [
        null,
        'wrong',
        ActivitiesRouteArgs(repository: activityRepo, groupId: ''),
        ActivitiesRouteArgs(repository: activityRepo, groupId: '   '),
      ]) {
        expect(
          AppRoutes.onGenerateRoute(
            RouteSettings(name: AppRoutes.activities, arguments: bad),
            authStatus: AuthSessionStatus.authenticated,
          ),
          isNull,
        );
      }
    });

    test(
      'activityDetail fails closed for missing, wrong, or blank arguments',
      () {
        for (final bad in [
          null,
          'wrong',
          ActivityDetailRouteArgs(repository: activityRepo, activityId: ''),
          ActivityDetailRouteArgs(repository: activityRepo, activityId: '   '),
        ]) {
          expect(
            AppRoutes.onGenerateRoute(
              RouteSettings(name: AppRoutes.activityDetail, arguments: bad),
              authStatus: AuthSessionStatus.authenticated,
            ),
            isNull,
          );
        }
      },
    );

    test('valid typed arguments generate authenticated MaterialPageRoute', () {
      final actRoute = AppRoutes.onGenerateRoute(
        RouteSettings(
          name: AppRoutes.activities,
          arguments: ActivitiesRouteArgs(
            repository: activityRepo,
            groupId: 'grp-exact-1',
          ),
        ),
        authStatus: AuthSessionStatus.authenticated,
      );
      expect(actRoute, isNotNull);
      expect(actRoute, isA<MaterialPageRoute<void>>());

      final detailRoute = AppRoutes.onGenerateRoute(
        RouteSettings(
          name: AppRoutes.activityDetail,
          arguments: ActivityDetailRouteArgs(
            repository: activityRepo,
            activityId: 'act-exact-1',
          ),
        ),
        authStatus: AuthSessionStatus.authenticated,
      );
      expect(detailRoute, isNotNull);
      expect(detailRoute, isA<MaterialPageRoute<void>>());
    });
  });

  group('Authenticated Navigation to Groups Runtime (M7 Bridge)', () {
    test('unauthenticated users cannot directly enter protected Groups', () {
      expect(
        AppRoutes.onGenerateRoute(
          const RouteSettings(name: AppRoutes.groups),
          authStatus: AuthSessionStatus.unauthenticated,
        ),
        isNull,
      );
      expect(
        AppRoutes.onGenerateRoute(
          const RouteSettings(name: AppRoutes.groups),
          authStatus: AuthSessionStatus.restoring,
        ),
        isNull,
      );
    });

    testWidgets(
      'successful login replaces auth stack and enters Groups with real GroupsRouteArgs and Back cannot return',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final groupRepo = _RouteGroupRepository();
        final store = _TestMemoryStore();
        final holder = AccessTokenHolder();
        final authRepo = AuthRepository(
          api: _TestAuthApi(),
          storage: SecureStorageService(store: store),
          accessTokenHolder: holder,
        );
        final sessionController = AuthSessionController(
          storage: SecureStorageService(store: store),
          accessTokenHolder: holder,
          repository: authRepo,
        );

        final coordinator = AuthFlowCoordinator(
          authRepo,
          sessionController: sessionController,
          onAuthenticated: (context) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.groups,
              (route) => false,
              arguments: GroupsRouteArgs(repository: groupRepo),
            );
          },
        );

        await tester.pumpWidget(
          WeDoApp(
            authFlowCoordinator: coordinator,
            authSessionController: sessionController,
            groupRepository: groupRepo,
          ),
        );
        await tester.pumpAndSettle();

        // Starts on WelcomeScreen
        final welcomeLogin = find.widgetWithText(OutlinedButton, 'Login');
        expect(welcomeLogin, findsOneWidget);
        await tester.ensureVisible(welcomeLogin);
        await tester.tap(welcomeLogin);
        await tester.pumpAndSettle();

        // Now on LoginScreen
        expect(find.text('Welcome Back'), findsOneWidget);
        await tester.enterText(
          find.byType(TextField).at(0),
          'user@wedo.social',
        );
        await tester.enterText(find.byType(TextField).at(1), 'ValidPass123!');
        await tester.pump();

        // Tap Login
        final loginButton = find.widgetWithText(ElevatedButton, 'Login');
        await tester.ensureVisible(loginButton);
        await tester.tap(loginButton);
        await tester.pumpAndSettle();

        // Successful login transitions cleanly to MyGroupsScreen
        expect(find.byType(MyGroupsScreen), findsOneWidget);
        expect(groupRepo.calls, contains('list-groups'));

        // Back cannot return to Login/Register onboarding screens
        final nav = tester.state<NavigatorState>(find.byType(Navigator));
        expect(nav.canPop(), isFalse);
      },
    );

    testWidgets(
      'app startup with persisted authenticated session lands directly on Groups',
      (tester) async {
        final groupRepo = _RouteGroupRepository();
        final store = _TestMemoryStore();
        final holder = AccessTokenHolder();
        final authRepo = AuthRepository(
          api: _TestAuthApi(),
          storage: SecureStorageService(store: store),
          accessTokenHolder: holder,
        );
        final sessionController = AuthSessionController(
          storage: SecureStorageService(store: store),
          accessTokenHolder: holder,
          repository: authRepo,
        )..markAuthenticated();

        await tester.pumpWidget(
          WeDoApp(
            authSessionController: sessionController,
            groupRepository: groupRepo,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MyGroupsScreen), findsOneWidget);
        expect(find.text('Welcome Back'), findsNothing);
      },
    );
  });
}

class _RouteGroupRepository extends GroupRepository {
  _RouteGroupRepository() : super(api: GroupApi(Dio()));
  final List<String> calls = [];
  @override
  Future<GroupDetail> getGroup(String id) async {
    calls.add('group:$id');
    return _detail();
  }

  @override
  Future<List<GroupMember>> getMembers(String id) async {
    calls.add('members:$id');
    return [_member('user-id')];
  }

  @override
  Future<GroupMember> getMember(String id, String userId) async {
    calls.add('member:$id:$userId');
    return _member(userId);
  }

  @override
  Future<GroupSettings> getSettings(String id) async {
    calls.add('settings:$id');
    return GroupSettings(
      groupId: id,
      joinPolicy: GroupJoinPolicy.autoJoin,
      memberModifyInfoAllowed: false,
      memberCreateActivityAllowed: false,
      memberPinMessageAllowed: false,
      chatHistoryPolicy: ChatHistoryPolicy.fullHistory,
      updatedAt: DateTime(2026),
    );
  }

  @override
  Future<PagedResponse<GroupActivityLog>> getActivityLogs(
    String id, {
    int page = 0,
    int size = 30,
  }) async {
    calls.add('activities:$id');
    return const PagedResponse(
      items: [],
      page: 0,
      size: 30,
      totalElements: 0,
      totalPages: 0,
      hasNext: false,
    );
  }

  @override
  Future<PagedResponse<GroupSummary>> listGroups({
    int page = 0,
    int size = 30,
    GroupStatus? status,
  }) async {
    calls.add('list-groups');
    return const PagedResponse(
      items: [],
      page: 0,
      size: 30,
      totalElements: 0,
      totalPages: 0,
      hasNext: false,
    );
  }
}

class _TestAuthApi extends AuthApi {
  _TestAuthApi() : super(Dio(), refreshDio: Dio());

  @override
  Future<LoginResult> login({
    required String email,
    required String password,
    String? deviceName,
  }) async {
    return AuthenticatedSession(
      userId: 'test-user-id',
      status: 'ACTIVE',
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      tokenType: 'Bearer',
      accessTokenExpiresAt: DateTime(2026),
      user: const UserSummary(
        id: 'test-user-id',
        email: 'user@wedo.social',
        username: 'test_user',
        displayName: 'Test User',
      ),
    );
  }
}

class _TestMemoryStore implements SecureKeyValueStore {
  final values = <String, String>{};
  @override
  Future<void> delete(String k) async => values.remove(k);
  @override
  Future<String?> read(String k) async => values[k];
  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

GroupDetail _detail() => GroupDetail(
  id: 'group-id',
  name: 'Group',
  status: GroupStatus.active,
  ownerUserId: 'owner',
  callerRole: GroupRole.owner,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

GroupMember _member(String id) => GroupMember(
  userId: id,
  username: id,
  displayName: id,
  role: GroupRole.member,
  joinedAt: DateTime(2026),
);

Object _groupRouteArgs(String name, GroupRepository repository) {
  if (name == AppRoutes.groups || name == AppRoutes.createGroup) {
    return GroupsRouteArgs(repository: repository);
  }
  if (name == AppRoutes.memberManagement) {
    return GroupMemberRouteArgs(
      repository: repository,
      groupId: 'group-id',
      userId: 'user-id',
    );
  }
  return GroupInfoRouteArgs(repository: repository, groupId: 'group-id');
}
