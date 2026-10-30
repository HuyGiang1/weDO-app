import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../app/routes.dart';
import '../../../auth/data/models/auth_models.dart';
import '../../../groups/presentation/widgets/group_widgets.dart';
import '../../data/profile_models.dart';
import 'change_username_screen.dart';
import 'edit_profile_screen.dart';
import '../widgets/profile_ui.dart';

/// Read-only self-profile screen backed by the authenticated `/api/v1/me` API.
class ProfileScreen extends StatefulWidget {
  final Future<CurrentUser> Function() loadCurrentUser;
  final Future<CurrentUser> Function(UpdateProfileRequest request)
  updateProfile;
  final Future<String> Function({
    required List<int> bytes,
    required String fileName,
    required String contentType,
  })?
  uploadAvatar;
  final Future<CurrentUser> Function(UpdateUsernameRequest request)
  updateUsername;
  final Future<void> Function({
    required String currentPassword,
    required String newPassword,
  })
  changePassword;
  final Future<bool> Function() endSessionAfterPasswordChange;
  final Future<void> Function()? logout;
  final VoidCallback? onHome, onGroups, onChat, onCalendar;
  final VoidCallback? onScanQr;

  const ProfileScreen({
    super.key,
    required this.loadCurrentUser,
    required this.updateProfile,
    this.uploadAvatar,
    required this.updateUsername,
    required this.changePassword,
    required this.endSessionAfterPasswordChange,
    this.logout,
    this.onHome,
    this.onGroups,
    this.onChat,
    this.onCalendar,
    this.onScanQr,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<CurrentUser>? _profileFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final profileFuture = widget.loadCurrentUser();
    setState(() {
      _profileFuture = profileFuture;
    });
  }

  bool _logoutPending = false;

  Future<void> _logout() async {
    if (_logoutPending) return;
    _logoutPending = true;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Đăng xuất'),
          content: const Text('Bạn có chắc muốn đăng xuất không?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Đăng xuất'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await widget.logout!();
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
      }
    } finally {
      _logoutPending = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ'),
        actions: [
          if (widget.logout != null)
            Tooltip(
              message: 'Đăng xuất',
              child: TextButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Đăng xuất'),
              ),
            ),
          if (widget.onScanQr != null)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded),
              tooltip: 'Quét QR',
              onPressed: widget.onScanQr,
            ),
        ],
      ),
      bottomNavigationBar: widget.onHome == null
          ? null
          : GroupsBottomNavigation(
              currentIndex: 4,
              onTap: (index) {
                if (index == 0) widget.onHome?.call();
                if (index == 1) widget.onGroups?.call();
                if (index == 2) widget.onChat?.call();
                if (index == 3) widget.onCalendar?.call();
              },
            ),
      body: FutureBuilder<CurrentUser>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ProfileError(onRetry: _reload);
          }
          final user = snapshot.data;
          if (user == null) return _ProfileError(onRetry: _reload);
          return _ProfileContent(
            user: user,
            onEdit: () async {
              final updated = await Navigator.of(context).push<CurrentUser>(
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(
                    initialUser: user,
                    updateProfile: widget.updateProfile,
                    uploadAvatar: widget.uploadAvatar,
                  ),
                ),
              );
              if (updated != null && mounted) {
                setState(() {
                  _profileFuture = Future.value(updated);
                });
              }
            },
            onChangeUsername: () async {
              final updated = await Navigator.of(context).push<CurrentUser>(
                MaterialPageRoute(
                  builder: (_) => ChangeUsernameScreen(
                    initialUser: user,
                    updateUsername: widget.updateUsername,
                  ),
                ),
              );
              if (updated != null && mounted) {
                setState(() {
                  _profileFuture = Future.value(updated);
                });
              }
            },
            onChangePassword: () => Navigator.of(context).pushNamed(
              AppRoutes.changePassword,
              arguments: ChangePasswordRouteArgs(
                changePassword: widget.changePassword,
                endSessionAfterPasswordChange:
                    widget.endSessionAfterPasswordChange,
              ),
            ),
            onScanQr: widget.onScanQr,
            onLogout: widget.logout == null ? null : _logout,
          );
        },
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  final CurrentUser user;
  final VoidCallback onEdit;
  final VoidCallback onChangeUsername;
  final VoidCallback onChangePassword;
  final VoidCallback? onScanQr;
  final VoidCallback? onLogout;

  const _ProfileContent({
    required this.user,
    required this.onEdit,
    required this.onChangeUsername,
    required this.onChangePassword,
    this.onScanQr,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = user.displayName?.trim();
    final title = displayName == null || displayName.isEmpty
        ? (user.username ?? user.email)
        : displayName;
    final initial = title.isEmpty ? '?' : title.substring(0, 1).toUpperCase();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.maxContentWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ProfileAvatar(
                    label: initial,
                    radius: 36,
                    avatarStorageKey: user.avatarStorageKey,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                if (user.username != null &&
                    user.username!.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '@${user.username}',
                    style: AppTextStyles.of(context).bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                if (_hasText(user.bio))
                  ProfileSurface(
                    child: Text(
                      user.bio!,
                      style: AppTextStyles.of(context).bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                ElevatedButton(
                  onPressed: onEdit,
                  style: profilePrimaryButtonStyle(context),
                  child: const Text('Chỉnh sửa hồ sơ'),
                ),
                const SizedBox(height: AppSpacing.sm),
                ProfileActionRow(
                  icon: Icons.badge_outlined,
                  label: 'Đổi tên người dùng',
                  onTap: onChangeUsername,
                ),
                const SizedBox(height: AppSpacing.xs),
                ProfileActionRow(
                  icon: Icons.lock_outline,
                  label: 'Cài đặt quyền riêng tư',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.privacy),
                ),
                const SizedBox(height: AppSpacing.xs),
                ProfileActionRow(
                  icon: Icons.password_outlined,
                  label: 'Đổi mật khẩu',
                  onTap: onChangePassword,
                ),
                const SizedBox(height: AppSpacing.xs),
                ProfileActionRow(
                  icon: Icons.qr_code_rounded,
                  label: 'Mã QR của tôi',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.personalQr),
                ),
                if (onScanQr != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  ProfileActionRow(
                    icon: Icons.qr_code_scanner_rounded,
                    label: 'Quét QR',
                    onTap: onScanQr!,
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                ProfileActionRow(
                  icon: Icons.people_outline_rounded,
                  label: 'Bạn bè',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.friends),
                ),
                const SizedBox(height: AppSpacing.xs),
                ProfileActionRow(
                  icon: Icons.person_add_alt_1_outlined,
                  label: 'Lời mời kết bạn',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.friendRequests),
                ),
                const SizedBox(height: AppSpacing.xs),
                ProfileActionRow(
                  icon: Icons.block_outlined,
                  label: 'Người dùng đã chặn',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.blockedUsers),
                ),
                if (onLogout != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  ProfileActionRow(
                    icon: Icons.logout_rounded,
                    label: 'Đăng xuất',
                    onTap: onLogout!,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                ProfileSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ProfileField(label: 'Email', value: user.email),
                      _ProfileField(
                        label: 'Xác minh email',
                        value: user.emailVerified
                            ? 'Đã xác minh'
                            : 'Chưa xác minh',
                      ),
                      if (_hasText(user.phone))
                        _ProfileField(
                          label: 'Số điện thoại',
                          value: user.phone!,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static bool _hasText(String? value) =>
      value != null && value.trim().isNotEmpty;
}

class _ProfileField extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.of(context).label),
        const SizedBox(height: AppSpacing.xs),
        Text(value, style: AppTextStyles.of(context).bodyMedium),
      ],
    ),
  );
}

class _ProfileError extends StatelessWidget {
  final VoidCallback onRetry;

  const _ProfileError({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Không thể tải hồ sơ của bạn.',
            style: AppTextStyles.of(context).bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    ),
  );
}
