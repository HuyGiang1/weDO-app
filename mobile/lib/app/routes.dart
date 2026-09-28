// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';

import 'auth_route_guard.dart';
import '../features/auth/application/auth_session_controller.dart';
import '../features/auth/presentation/auth_flow_coordinator.dart';
import '../features/auth/presentation/screens/complete_profile_screen.dart';
import '../features/auth/presentation/screens/create_username_screen.dart';
import '../features/auth/presentation/screens/forgot_password_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/auth/presentation/screens/reset_password_screen.dart';
import '../features/auth/presentation/screens/verify_email_screen.dart';
import '../features/auth/presentation/screens/welcome_screen.dart';
import '../features/auth/data/models/auth_models.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/profile/presentation/screens/change_password_screen.dart';
import '../features/profile/data/profile_models.dart';
import '../features/profile/presentation/screens/public_user_profile_screen.dart';
import '../features/privacy/data/privacy_models.dart';
import '../features/privacy/presentation/screens/privacy_settings_screen.dart';
import '../features/qr/data/personal_qr.dart';
import '../features/qr/presentation/screens/personal_qr_screen.dart';
import '../features/groups/data/group_repository.dart';
import '../features/groups/application/groups_controller.dart';
import '../features/groups/application/create_group_controller.dart';
import '../features/groups/application/group_detail_controller.dart';
import '../features/groups/application/group_activity_log_controller.dart';
import '../features/groups/presentation/screens/my_groups_screen.dart';
import '../features/groups/presentation/screens/create_group_screen.dart';
import '../features/groups/presentation/screens/group_info_screen.dart';
import '../features/groups/presentation/screens/group_activity_log_screen.dart';
import '../features/groups/application/group_management_controllers.dart';
import '../features/groups/presentation/screens/group_management_screens.dart';
import '../features/groups/application/group_admission_controllers.dart';
import '../features/groups/presentation/screens/group_admission_screens.dart';
import '../features/activity/data/activity_api.dart';
import '../features/activity/data/activity_repository.dart';
import '../features/activity/application/activity_controllers.dart';
import '../features/activity/presentation/screens/activity_runtime_screens.dart';
import '../features/groups/data/group_api.dart';
import '../features/poll/data/poll_api.dart';
import '../features/poll/data/poll_repository.dart';
import '../features/poll/presentation/screens/poll_screens.dart';
import '../features/task/data/task_api.dart';
import '../features/task/data/task_repository.dart';
import '../features/task/presentation/screens/task_screens.dart';
import '../features/discussion/data/discussion_api.dart';
import '../features/discussion/data/discussion_repository.dart';
import '../features/discussion/presentation/widgets/activity_discussion_section.dart';
import '../features/chat/data/chat_api.dart';
import '../features/chat/data/chat_models.dart';
import '../features/chat/data/chat_repository.dart';
import '../features/chat/presentation/chat_screen.dart';
import '../features/chat/presentation/chat_home_screen.dart';
import '../features/chat/presentation/chat_requests_screen.dart';
import '../features/expense/data/expense_api.dart';
import '../features/expense/data/expense_repository.dart';
import '../features/expense/presentation/expense_screens.dart';

export 'auth_route_guard.dart';

/// Data required to render the verification screen from a real auth flow.
class VerifyEmailRouteArgs {
  final String email;
  final int initialCooldownSeconds;

  const VerifyEmailRouteArgs({
    required this.email,
    required this.initialCooldownSeconds,
  });
}

class ResetPasswordRouteArgs {
  final String email;

  const ResetPasswordRouteArgs({required this.email});
}

class ProfileRouteArgs {
  final Future<CurrentUser> Function() loadCurrentUser;
  final Future<CurrentUser> Function(UpdateProfileRequest request)
  updateProfile;
  final Future<CurrentUser> Function(UpdateUsernameRequest request)
  updateUsername;
  final Future<void> Function({
    required String currentPassword,
    required String newPassword,
  })
  changePassword;
  final Future<bool> Function() endSessionAfterPasswordChange;

  const ProfileRouteArgs({
    required this.loadCurrentUser,
    required this.updateProfile,
    required this.updateUsername,
    required this.changePassword,
    required this.endSessionAfterPasswordChange,
  });
}

class ChangePasswordRouteArgs {
  final Future<void> Function({
    required String currentPassword,
    required String newPassword,
  })
  changePassword;
  final Future<bool> Function() endSessionAfterPasswordChange;
  const ChangePasswordRouteArgs({
    required this.changePassword,
    required this.endSessionAfterPasswordChange,
  });
}

class PrivacyRouteArgs {
  final Future<PrivacySettings> Function() loadPrivacySettings;
  final Future<PrivacySettings> Function(UpdatePrivacySettingsRequest request)
  updatePrivacySettings;

  const PrivacyRouteArgs({
    required this.loadPrivacySettings,
    required this.updatePrivacySettings,
  });
}

class PersonalQrRouteArgs {
  final Future<PersonalQr> Function() loadPersonalQr;
  const PersonalQrRouteArgs({required this.loadPersonalQr});
}

class PublicUserProfileRouteArgs {
  final String userId;
  final Future<PublicUserProfile> Function(String userId) loadPublicProfile;
  final ChatRepository? chatRepository;
  const PublicUserProfileRouteArgs({
    required this.userId,
    required this.loadPublicProfile,
    this.chatRepository,
  });
}

class GroupsRouteArgs {
  final GroupRepository repository;
  const GroupsRouteArgs({required this.repository});
}

class GroupInfoRouteArgs {
  final GroupRepository repository;
  final ChatRepository? chatRepository;
  final String groupId;
  const GroupInfoRouteArgs({
    required this.repository,
    required this.groupId,
    this.chatRepository,
  });
}

class GroupMemberRouteArgs {
  final GroupRepository repository;
  final String groupId, userId;
  const GroupMemberRouteArgs({
    required this.repository,
    required this.groupId,
    required this.userId,
  });
}

class ActivitiesRouteArgs {
  final ActivityRepository repository;
  final String groupId;
  const ActivitiesRouteArgs({required this.repository, required this.groupId});
}

class ChatRouteArgs {
  final ChatRepository repository;
  final String? groupId;
  final ChatConversation? conversation;
  final GroupRepository? groupRepository;
  const ChatRouteArgs({
    required this.repository,
    this.groupId,
    this.conversation,
    this.groupRepository,
  });
}

class ChatRequestsRouteArgs {
  final ChatRepository repository;
  const ChatRequestsRouteArgs(this.repository);
}

class ChatHomeRouteArgs {
  final ChatRepository chatRepository;
  final GroupRepository groupRepository;
  const ChatHomeRouteArgs(this.chatRepository, this.groupRepository);
}

class ActivityDetailRouteArgs {
  final ActivityRepository repository;
  final String activityId;
  const ActivityDetailRouteArgs({
    required this.repository,
    required this.activityId,
  });
}

class ExpenseRouteArgs {
  final ExpenseRepository repository;
  final GroupRepository groupRepository;
  final String groupId;
  const ExpenseRouteArgs({required this.repository, required this.groupRepository, required this.groupId});
}

/// A unified route definition binding access policy to route construction.
final class AppRouteDefinition {
  final AppRouteAccess access;
  final Route<dynamic>? Function(
    RouteSettings settings,
    AuthFlowCoordinator? coordinator,
  )
  builder;

  const AppRouteDefinition({required this.access, required this.builder});
}

/// Application route definitions, registry, and Navigator 1.0 generator.
abstract final class AppRoutes {
  static const String welcome = '/';
  static const String register = '/register';
  static const String verifyEmail = '/verify-email';
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String createUsername = '/create-username';
  static const String completeProfile = '/complete-profile';
  static const String profile = '/profile';
  static const String changePassword = '/profile/change-password';
  static const String privacy = '/profile/privacy';
  static const String personalQr = '/profile/qr';
  static const String publicUserProfile = '/users/profile';
  static const String groups = '/groups';
  static const String createGroup = '/groups/create';
  static const String groupInfo = '/groups/info';
  static const String groupActivityLog = '/groups/activity-log';
  static const String editGroup = '/groups/edit';
  static const String groupMembers = '/groups/members';
  static const String memberManagement = '/groups/member-management';
  static const String groupPermissions = '/groups/permissions';
  static const String groupAdmins = '/groups/admins';
  static const String transferOwnership = '/groups/transfer-ownership';
  static const String groupInvitations = '/groups/invitations';
  static const String joinGroupByCode = '/groups/join-by-code';
  static const String groupInviteLinks = '/groups/invite-links';
  static const String groupJoinRequests = '/groups/join-requests';
  static const String groupBans = '/groups/bans';
  static const String activities = '/groups/activities';
  static const String groupExpenses = '/groups/expenses';
  static const String activityDetail = '/activities/detail';
  static const String polls = '/activities/polls';
  static const String tasks = '/activities/tasks';
  static const String groupChat = '/groups/chat';
  static const String chatHome = '/chat';
  static const String chatRequests = '/chat/requests';

  static final Map<String, AppRouteDefinition> _routes = {
    welcome: AppRouteDefinition(
      access: AppRouteAccess.public,
      builder: (settings, coordinator) => MaterialPageRoute<void>(
        builder: (context) => WelcomeScreen(
          onCreateAccountPressed: () {
            Navigator.of(context).pushNamed(register);
          },
          onLoginPressed: () {
            Navigator.of(context).pushNamed(login);
          },
        ),
        settings: settings,
      ),
    ),
    register: AppRouteDefinition(
      access: AppRouteAccess.public,
      builder: (settings, coordinator) => MaterialPageRoute<void>(
        builder: (context) => RegisterScreen(
          onSubmit: coordinator == null
              ? null
              : (email, password) =>
                    coordinator.register(context, email, password),
          onLoginPressed: () {
            Navigator.of(context).pushNamed(login);
          },
        ),
        settings: settings,
      ),
    ),
    login: AppRouteDefinition(
      access: AppRouteAccess.public,
      builder: (settings, coordinator) => MaterialPageRoute<void>(
        builder: (context) => LoginScreen(
          onLogin: coordinator == null
              ? null
              : ({required email, required password}) =>
                    coordinator.login(context, email, password),
          onCreateAccount: () => Navigator.of(context).pushNamed(register),
          onForgotPassword: () =>
              Navigator.of(context).pushNamed(forgotPassword),
        ),
        settings: settings,
      ),
    ),
    createUsername: AppRouteDefinition(
      access: AppRouteAccess.public,
      builder: (settings, coordinator) {
        final args = settings.arguments;
        if (args is! CreateUsernameFlowArgs) return null;
        return MaterialPageRoute<void>(
          builder: (_) => CreateUsernameScreen(
            onCheckAvailability: args.onCheckAvailability,
            onContinue: args.onContinue,
          ),
          settings: settings,
        );
      },
    ),
    completeProfile: AppRouteDefinition(
      access: AppRouteAccess.public,
      builder: (settings, coordinator) {
        final args = settings.arguments;
        if (args is! CompleteProfileFlowArgs) return null;
        return MaterialPageRoute<void>(
          builder: (_) => CompleteProfileScreen(
            username: args.username,
            onContinue: args.onContinue,
          ),
          settings: settings,
        );
      },
    ),
    forgotPassword: AppRouteDefinition(
      access: AppRouteAccess.public,
      builder: (settings, coordinator) => MaterialPageRoute<void>(
        builder: (context) => ForgotPasswordScreen(
          onSubmit: coordinator == null
              ? null
              : ({required email}) =>
                    coordinator.forgotPassword(context, email),
          onBack: () => Navigator.of(context).maybePop(),
          onReturnToLogin: () => Navigator.of(context).maybePop(),
          onRequestSuccess: (email) => Navigator.of(context).pushNamed(
            resetPassword,
            arguments: ResetPasswordRouteArgs(email: email),
          ),
        ),
        settings: settings,
      ),
    ),
    resetPassword: AppRouteDefinition(
      access: AppRouteAccess.public,
      builder: (settings, coordinator) {
        final arguments = settings.arguments;
        if (arguments is! ResetPasswordRouteArgs ||
            arguments.email.trim().isEmpty) {
          return null;
        }
        return MaterialPageRoute<void>(
          builder: (context) => ResetPasswordScreen(
            email: arguments.email,
            onSubmit: coordinator == null
                ? null
                : ({required email, required code, required newPassword}) =>
                      coordinator.resetPassword(
                        context,
                        email: email,
                        code: code,
                        newPassword: newPassword,
                      ),
            onBackToLogin: () => Navigator.of(context).popUntil(
              (route) => route.settings.name == login || route.isFirst,
            ),
            onResetSuccess: () {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(context).popUntil(
                (route) => route.settings.name == login || route.isFirst,
              );
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Password updated. You can now log in.'),
                ),
              );
            },
          ),
          settings: settings,
        );
      },
    ),
    verifyEmail: AppRouteDefinition(
      access: AppRouteAccess.public,
      builder: (settings, coordinator) {
        final arguments = settings.arguments;
        if (arguments is VerifyEmailFlowArgs) {
          return MaterialPageRoute<void>(
            builder: (context) => VerifyEmailScreen(
              email: arguments.email,
              initialCooldownSeconds: 0,
              onBack: () => Navigator.of(context).maybePop(),
              onChangeEmail: () => Navigator.of(context).maybePop(),
              onVerify: arguments.onVerify,
              onResend: arguments.onResend,
            ),
            settings: settings,
          );
        }
        if (arguments is! VerifyEmailRouteArgs ||
            arguments.email.isEmpty ||
            arguments.initialCooldownSeconds < 0) {
          return null;
        }
        return MaterialPageRoute<void>(
          builder: (context) => VerifyEmailScreen(
            email: arguments.email,
            initialCooldownSeconds: arguments.initialCooldownSeconds,
            onBack: () => Navigator.of(context).maybePop(),
            onChangeEmail: () => Navigator.of(context).maybePop(),
          ),
          settings: settings,
        );
      },
    ),
    profile: AppRouteDefinition(
      access: AppRouteAccess.authenticated,
      builder: (settings, coordinator) {
        final loader = settings.arguments;
        if (loader is! ProfileRouteArgs) return null;
        return MaterialPageRoute<void>(
          builder: (_) => ProfileScreen(
            loadCurrentUser: loader.loadCurrentUser,
            updateProfile: loader.updateProfile,
            updateUsername: loader.updateUsername,
            changePassword: loader.changePassword,
            endSessionAfterPasswordChange: loader.endSessionAfterPasswordChange,
          ),
          settings: settings,
        );
      },
    ),
    changePassword: AppRouteDefinition(
      access: AppRouteAccess.authenticated,
      builder: (settings, coordinator) {
        final args = settings.arguments;
        if (args is! ChangePasswordRouteArgs) return null;
        return MaterialPageRoute<void>(
          builder: (context) => ChangePasswordScreen(
            changePassword: args.changePassword,
            endSessionAfterPasswordChange: args.endSessionAfterPasswordChange,
            onSuccess: () {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(context)
                  .pushNamedAndRemoveUntil(login, (route) => false);
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Password changed. Please sign in again.'),
                ),
              );
            },
          ),
          settings: settings,
        );
      },
    ),
    privacy: AppRouteDefinition(
      access: AppRouteAccess.authenticated,
      builder: (settings, coordinator) {
        final args = settings.arguments;
        if (args is! PrivacyRouteArgs) return null;
        return MaterialPageRoute<void>(
          builder: (_) => PrivacySettingsScreen(
            loadPrivacySettings: args.loadPrivacySettings,
            updatePrivacySettings: args.updatePrivacySettings,
          ),
          settings: settings,
        );
      },
    ),
    personalQr: AppRouteDefinition(
      access: AppRouteAccess.authenticated,
      builder: (settings, coordinator) {
        final args = settings.arguments;
        if (args is! PersonalQrRouteArgs) return null;
        return MaterialPageRoute<void>(
          builder: (_) => PersonalQrScreen(loadPersonalQr: args.loadPersonalQr),
          settings: settings,
        );
      },
    ),
    publicUserProfile: AppRouteDefinition(
      access: AppRouteAccess.authenticated,
      builder: (settings, coordinator) {
        final args = settings.arguments;
        if (args is! PublicUserProfileRouteArgs || args.userId.trim().isEmpty)
          return null;
        return MaterialPageRoute<void>(
          builder: (context) => PublicUserProfileScreen(
            userId: args.userId,
            loadPublicProfile: args.loadPublicProfile,
            onMessage: args.chatRepository == null
                ? null
                : () async {
                    try {
                      final direct = await args.chatRepository!.openDirect(
                        args.userId,
                      );
                      if (!context.mounted) return;
                      Navigator.of(context).pushNamed(
                        groupChat,
                        arguments: ChatRouteArgs(
                          repository: args.chatRepository!,
                          conversation: direct.conversation,
                        ),
                      );
                    } catch (_) {
                      if (context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Không thể bắt đầu cuộc trò chuyện.'),
                          ),
                        );
                    }
                  },
          ),
          settings: settings,
        );
      },
    ),
    groups: AppRouteDefinition(
      access: AppRouteAccess.authenticated,
      builder: (settings, coordinator) {
        final args = settings.arguments;
        if (args is! GroupsRouteArgs) return null;
        return MaterialPageRoute<void>(
          builder: (context) {
            final groupsController = GroupsController(args.repository);
            return MyGroupsScreen(
              controller: groupsController,
              onCreate: () =>
                  Navigator.of(context).pushNamed(createGroup, arguments: args),
              onOpenGroup: (id) => Navigator.of(context)
                  .pushNamed(
                    groupInfo,
                    arguments: GroupInfoRouteArgs(
                      repository: args.repository,
                      groupId: id,
                    ),
                  )
                  .whenComplete(groupsController.refresh),
              onJoinByCode: () =>
                  Navigator.of(context)
                      .pushNamed(joinGroupByCode, arguments: args)
                      .whenComplete(groupsController.refresh),
              onInvitations: () =>
                  Navigator.of(context)
                      .pushNamed(groupInvitations, arguments: args)
                      .whenComplete(groupsController.refresh),
              onChatRequests: () => Navigator.of(context).pushNamed(
                chatRequests,
                arguments: ChatRequestsRouteArgs(
                  ChatRepository(ChatApi(args.repository.api.dio)),
                ),
              ),
              onChat: () => Navigator.of(context).pushNamed(
                chatHome,
                arguments: ChatHomeRouteArgs(
                  ChatRepository(ChatApi(args.repository.api.dio)),
                  args.repository,
                ),
              ),
            );
          },
          settings: settings,
        );
      },
    ),
    createGroup: AppRouteDefinition(
      access: AppRouteAccess.authenticated,
      builder: (settings, coordinator) {
        final args = settings.arguments;
        if (args is! GroupsRouteArgs) return null;
        return MaterialPageRoute<void>(
          builder: (context) => CreateGroupScreen(
            controller: CreateGroupController(args.repository),
            onCreated: (detail) => Navigator.of(context).pushReplacementNamed(
              groupInfo,
              arguments: GroupInfoRouteArgs(
                repository: args.repository,
                groupId: detail.id,
              ),
            ),
          ),
          settings: settings,
        );
      },
    ),
    groupInfo: AppRouteDefinition(
      access: AppRouteAccess.authenticated,
      builder: (settings, coordinator) {
        final args = settings.arguments;
        if (args is! GroupInfoRouteArgs || args.groupId.trim().isEmpty) {
          return null;
        }
        return MaterialPageRoute<void>(
          builder: (context) {
            final detail = GroupDetailController(args.repository);
            return GroupInfoScreen(
              groupId: args.groupId,
              controller: detail,
              onEdit: () =>
                  Navigator.of(context)
                      .pushNamed(editGroup, arguments: args)
                      .whenComplete(() => detail.load(args.groupId)),
              onMembers: () =>
                  Navigator.of(context)
                      .pushNamed(groupMembers, arguments: args)
                      .whenComplete(() => detail.load(args.groupId)),
              onSettings: () =>
                  Navigator.of(context)
                      .pushNamed(groupPermissions, arguments: args)
                      .whenComplete(() => detail.load(args.groupId)),
              onActivityLog: () =>
                  Navigator.of(context)
                      .pushNamed(groupActivityLog, arguments: args),
              onActivities: () => Navigator.of(context).pushNamed(
                activities,
                arguments: ActivitiesRouteArgs(
                  repository: ActivityRepository(
                    api: ActivityApi(args.repository.api.dio),
                  ),
                  groupId: args.groupId,
                ),
              ),
              onExpenses: () => Navigator.of(context).pushNamed(
                groupExpenses,
                arguments: ExpenseRouteArgs(
                  repository: ExpenseRepository(ExpenseApi(args.repository.api.dio)),
                  groupRepository: args.repository,
                  groupId: args.groupId,
                ),
              ),
              onChatHome: () => Navigator.of(context).pushNamed(
                chatHome,
                arguments: ChatHomeRouteArgs(
                  args.chatRepository ??
                      ChatRepository(ChatApi(args.repository.api.dio)),
                  args.repository,
                ),
              ),
              onChat: () => Navigator.of(context).pushNamed(
                groupChat,
                arguments: ChatRouteArgs(
                  repository:
                      args.chatRepository ??
                      ChatRepository(ChatApi(args.repository.api.dio)),
                  groupId: args.groupId,
                  groupRepository: args.repository,
                ),
              ),
              onInviteLinks: () =>
                  Navigator.of(context)
                      .pushNamed(groupInviteLinks, arguments: args),
              onJoinRequests: () =>
                  Navigator.of(context)
                      .pushNamed(groupJoinRequests, arguments: args),
              onBans: () =>
                  Navigator.of(context).pushNamed(groupBans, arguments: args),
              onArchive: () async {
                final ok = await GroupLifecycleController(args.repository)
                    .archive(args.groupId);
                if (ok && context.mounted) {
                  detail.load(args.groupId);
                }
              },
              onRestore: () async {
                final ok = await GroupLifecycleController(args.repository)
                    .restore(args.groupId);
                if (ok && context.mounted) {
                  detail.load(args.groupId);
                }
              },
              onDelete: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Group'),
                    content: const Text(
                      'Are you sure you want to permanently delete this group?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  final ok = await GroupLifecycleController(args.repository)
                      .delete(args.groupId);
                  if (ok && context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                }
              },
              onLeave: () => Navigator.of(context).pop(true),
            );
          },
          settings: settings,
        );
      },
    ),
    groupActivityLog: AppRouteDefinition(
      access: AppRouteAccess.authenticated,
      builder: (settings, coordinator) {
        final args = settings.arguments;
        if (args is! GroupInfoRouteArgs || args.groupId.trim().isEmpty) {
          return null;
        }
        return MaterialPageRoute<void>(
          builder: (_) => GroupActivityLogScreen(
            groupId: args.groupId,
            controller: GroupActivityLogController(args.repository),
          ),
          settings: settings,
        );
      },
    ),
    groupExpenses: AppRouteDefinition(
      access: AppRouteAccess.authenticated,
      builder: (settings, coordinator) {
        final args = settings.arguments;
        if (args is! ExpenseRouteArgs || args.groupId.trim().isEmpty) return null;
        return MaterialPageRoute<void>(
          builder: (_) => ExpenseListScreen(groupId: args.groupId, repository: args.repository, groupRepository: args.groupRepository),
          settings: settings,
        );
      },
    ),
    groupChat: AppRouteDefinition(
      access: AppRouteAccess.authenticated,
      builder: (settings, coordinator) {
        final args = settings.arguments;
        if (args is! ChatRouteArgs ||
            (args.conversation == null &&
                (args.groupId == null || args.groupId!.trim().isEmpty)))
          return null;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) {
            final groupId = args.conversation?.groupId ?? args.groupId;
            return ChatScreen(
              groupId: args.groupId,
              initialConversation: args.conversation,
              repository: args.repository,
              onOpenGroupInfo: groupId == null || args.groupRepository == null
                  ? null
                  : () => Navigator.of(context).pushNamed(
                      groupInfo,
                      arguments: GroupInfoRouteArgs(
                        repository: args.groupRepository!,
                        groupId: groupId,
                        chatRepository: args.repository,
                      ),
                    ),
            );
          },
        );
      },
    ),
    chatHome: AppRouteDefinition(
      access: AppRouteAccess.authenticated,
      builder: (settings, coordinator) {
        final args = settings.arguments;
        if (args is! ChatHomeRouteArgs) return null;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => ChatHomeScreen(
            repository: args.chatRepository,
            onGroups: () => Navigator.of(context).pushReplacementNamed(
              groups,
              arguments: GroupsRouteArgs(repository: args.groupRepository),
            ),
            onOpenConversation: (conversation) =>
                Navigator.of(context).pushNamed(
                  groupChat,
                  arguments: ChatRouteArgs(
                    repository: args.chatRepository,
                    conversation: conversation,
                    groupRepository: args.groupRepository,
                  ),
                ),
          ),
        );
      },
    ),
    chatRequests: AppRouteDefinition(
      access: AppRouteAccess.authenticated,
      builder: (settings, coordinator) {
        final args = settings.arguments;
        if (args is! ChatRequestsRouteArgs) return null;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => ChatRequestsScreen(
            repository: args.repository,
            onOpenDirect: (userId) async {
              final direct = await args.repository.openDirect(userId);
              if (!context.mounted) return;
              Navigator.of(context).pushNamed(
                groupChat,
                arguments: ChatRouteArgs(
                  repository: args.repository,
                  conversation: direct.conversation,
                ),
              );
            },
          ),
        );
      },
    ),
    activities: AppRouteDefinition(
      access: AppRouteAccess.authenticated,
      builder: (settings, coordinator) {
        final args = settings.arguments;
        if (args is! ActivitiesRouteArgs || args.groupId.trim().isEmpty)
          return null;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => ActivityListRuntimeScreen(
            groupId: args.groupId,
            controller: ActivityListController(args.repository),
            onOpen: (activityId) => Navigator.of(context).pushNamed(
              activityDetail,
              arguments: ActivityDetailRouteArgs(
                repository: args.repository,
                activityId: activityId,
              ),
            ),
          ),
        );
      },
    ),
    activityDetail: AppRouteDefinition(
      access: AppRouteAccess.authenticated,
      builder: (settings, coordinator) {
        final args = settings.arguments;
        if (args is! ActivityDetailRouteArgs || args.activityId.trim().isEmpty)
          return null;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => ActivityDetailRuntimeScreen(
            activityId: args.activityId,
            controller: ActivityDetailController(args.repository),
            onOpenPolls: () => Navigator.of(context).pushNamed(
              polls,
              arguments: ActivityDetailRouteArgs(
                repository: args.repository,
                activityId: args.activityId,
              ),
            ),
            onOpenTasks: () => Navigator.of(context).pushNamed(
              tasks,
              arguments: ActivityDetailRouteArgs(
                repository: args.repository,
                activityId: args.activityId,
              ),
            ),
            discussion: ActivityDiscussionSection(
              activityId: args.activityId,
              repository: DiscussionRepository(
                DiscussionApi(args.repository.api.dio),
              ),
            ),
          ),
        );
      },
    ),
    polls: AppRouteDefinition(
      access: AppRouteAccess.authenticated,
      builder: (settings, coordinator) {
        final args = settings.arguments;
        if (args is! ActivityDetailRouteArgs || args.activityId.trim().isEmpty)
          return null;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => PollListScreen(
            activityId: args.activityId,
            repository: PollRepository(PollApi(args.repository.api.dio)),
          ),
        );
      },
    ),
    tasks: AppRouteDefinition(
      access: AppRouteAccess.authenticated,
      builder: (settings, coordinator) {
        final args = settings.arguments;
        if (args is! ActivityDetailRouteArgs || args.activityId.trim().isEmpty)
          return null;
        final groupApi = GroupApi(args.repository.api.dio);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => TaskListScreen(
            activityId: args.activityId,
            repository: TaskRepository(TaskApi(args.repository.api.dio)),
            loadMembers: () async {
              final detail = await args.repository.detail(args.activityId);
              return groupApi.getMembers(detail.groupId);
            },
          ),
        );
      },
    ),
    editGroup: AppRouteDefinition(
      access: AppRouteAccess.authenticated,
      builder: (settings, coordinator) {
        final a = settings.arguments;
        if (a is! GroupInfoRouteArgs || a.groupId.trim().isEmpty) return null;
        return MaterialPageRoute<void>(
          builder: (_) => EditGroupScreen(
            groupId: a.groupId,
            controller: EditGroupController(a.repository),
          ),
          settings: settings,
        );
      },
    ),
    groupMembers: AppRouteDefinition(
      access: AppRouteAccess.authenticated,
      builder: (settings, coordinator) {
        final a = settings.arguments;
        if (a is! GroupInfoRouteArgs || a.groupId.trim().isEmpty) return null;
        return MaterialPageRoute<void>(
          builder: (context) {
            final members = GroupMembersController(a.repository);
            return GroupMembersScreen(
              groupId: a.groupId,
              controller: members,
              onMember: (userId) => Navigator.of(context)
                  .pushNamed(
                    memberManagement,
                    arguments: GroupMemberRouteArgs(
                      repository: a.repository,
                      groupId: a.groupId,
                      userId: userId,
                    ),
                  )
                  .whenComplete(() => members.load(a.groupId)),
            );
          },
          settings: settings,
        );
      },
    ),
    memberManagement: AppRouteDefinition(
      access: AppRouteAccess.authenticated,
      builder: (settings, coordinator) {
        final a = settings.arguments;
        if (a is! GroupMemberRouteArgs ||
            a.groupId.trim().isEmpty ||
            a.userId.trim().isEmpty)
          return null;
        return MaterialPageRoute<void>(
          builder: (context) => MemberManagementScreen(
            groupId: a.groupId,
            userId: a.userId,
            controller: MemberManagementController(a.repository),
            onKicked: () => Navigator.of(context).pop(true),
          ),
          settings: settings,
        );
      },
    ),
    groupPermissions: AppRouteDefinition(
      access: AppRouteAccess.authenticated,
      builder: (settings, coordinator) {
        final a = settings.arguments;
        if (a is! GroupInfoRouteArgs || a.groupId.trim().isEmpty) return null;
        return MaterialPageRoute<void>(
          builder: (context) {
            final permissions = GroupPermissionsController(a.repository);
            return GroupPermissionsScreen(
              groupId: a.groupId,
              controller: permissions,
              onAdmins: () =>
                  Navigator.of(context)
                      .pushNamed(groupAdmins, arguments: a)
                      .whenComplete(() => permissions.load(a.groupId)),
              onTransfer: () =>
                  Navigator.of(context)
                      .pushNamed(transferOwnership, arguments: a)
                      .whenComplete(() => permissions.load(a.groupId)),
            );
          },
          settings: settings,
        );
      },
    ),
    groupAdmins: AppRouteDefinition(
      access: AppRouteAccess.authenticated,
      builder: (settings, coordinator) {
        final a = settings.arguments;
        if (a is! GroupInfoRouteArgs || a.groupId.trim().isEmpty) return null;
        return MaterialPageRoute<void>(
          builder: (_) => GroupAdminManagementScreen(
            groupId: a.groupId,
            controller: GroupAdminController(a.repository),
          ),
          settings: settings,
        );
      },
    ),
    transferOwnership: AppRouteDefinition(
      access: AppRouteAccess.authenticated,
      builder: (settings, coordinator) {
        final a = settings.arguments;
        if (a is! GroupInfoRouteArgs || a.groupId.trim().isEmpty) return null;
        return MaterialPageRoute<void>(
          builder: (context) => TransferOwnershipScreen(
            groupId: a.groupId,
            controller: TransferOwnershipController(a.repository),
            onTransferred: (detail) => Navigator.of(context).pop(detail),
          ),
          settings: settings,
        );
      },
    ),
    groupInvitations: AppRouteDefinition(
      access: AppRouteAccess.authenticated,
      builder: (settings, coordinator) {
        final a = settings.arguments;
        if (a is! GroupsRouteArgs) return null;
        return MaterialPageRoute<void>(
          builder: (context) => MyGroupInvitationsScreen(
            controller: GroupInvitationsController(a.repository),
          ),
          settings: settings,
        );
      },
    ),
    joinGroupByCode: AppRouteDefinition(
      access: AppRouteAccess.authenticated,
      builder: (settings, coordinator) {
        final a = settings.arguments;
        if (a is! GroupsRouteArgs) return null;
        return MaterialPageRoute<void>(
          builder: (context) => JoinByInviteCodeScreen(
            controller: JoinByCodeController(a.repository),
          ),
          settings: settings,
        );
      },
    ),
    groupInviteLinks: AppRouteDefinition(
      access: AppRouteAccess.authenticated,
      builder: (settings, coordinator) {
        final a = settings.arguments;
        if (a is! GroupInfoRouteArgs || a.groupId.trim().isEmpty) return null;
        return MaterialPageRoute<void>(
          builder: (_) => GroupInviteLinksScreen(
            groupId: a.groupId,
            controller: InviteLinksController(a.repository),
          ),
          settings: settings,
        );
      },
    ),
    groupJoinRequests: AppRouteDefinition(
      access: AppRouteAccess.authenticated,
      builder: (settings, coordinator) {
        final a = settings.arguments;
        if (a is! GroupInfoRouteArgs || a.groupId.trim().isEmpty) return null;
        return MaterialPageRoute<void>(
          builder: (_) => GroupJoinRequestsScreen(
            groupId: a.groupId,
            controller: JoinRequestsController(a.repository),
          ),
          settings: settings,
        );
      },
    ),
    groupBans: AppRouteDefinition(
      access: AppRouteAccess.authenticated,
      builder: (settings, coordinator) {
        final a = settings.arguments;
        if (a is! GroupInfoRouteArgs || a.groupId.trim().isEmpty) return null;
        return MaterialPageRoute<void>(
          builder: (_) => GroupBansScreen(
            groupId: a.groupId,
            controller: GroupBansController(a.repository),
          ),
          settings: settings,
        );
      },
    ),
  };

  /// Read-only view of all registered production route definitions.
  static Map<String, AppRouteDefinition> get routes =>
      Map.unmodifiable(_routes);

  /// Evaluates guard policy and invokes the builder if and only if access is allowed.
  @visibleForTesting
  static Route<dynamic>? evaluateAndBuildRoute(
    AppRouteDefinition definition,
    RouteSettings settings, {
    required AuthSessionStatus authStatus,
    AuthFlowCoordinator? coordinator,
  }) {
    final decision = AuthRouteGuard.evaluate(
      access: definition.access,
      authStatus: authStatus,
    );
    if (decision != RouteGuardDecision.allow) {
      return null;
    }
    return definition.builder(settings, coordinator);
  }

  /// Evaluates route existence and authorization before building any target screen.
  static Route<dynamic>? onGenerateRoute(
    RouteSettings settings, {
    required AuthSessionStatus authStatus,
    AuthFlowCoordinator? coordinator,
  }) {
    final name = settings.name;
    if (name == null) {
      return null;
    }

    final definition = _routes[name];
    if (definition == null) {
      return null;
    }

    return evaluateAndBuildRoute(
      definition,
      settings,
      authStatus: authStatus,
      coordinator: coordinator,
    );
  }
}
