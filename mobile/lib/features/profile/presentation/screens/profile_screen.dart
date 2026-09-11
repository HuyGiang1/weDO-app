import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../auth/data/models/auth_models.dart';

/// Read-only self-profile screen backed by the authenticated `/api/v1/me` API.
class ProfileScreen extends StatefulWidget {
  final Future<CurrentUser> Function() loadCurrentUser;

  const ProfileScreen({super.key, required this.loadCurrentUser});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
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
          return _ProfileContent(user: user);
        },
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  final CurrentUser user;

  const _ProfileContent({required this.user});

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
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.backgroundGradientEnd,
                    child: Text(initial, style: AppTextStyles.headline),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  title,
                  style: AppTextStyles.headline,
                  textAlign: TextAlign.center,
                ),
                if (user.username != null &&
                    user.username!.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '@${user.username}',
                    style: AppTextStyles.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                _ProfileField(label: 'Email', value: user.email),
                _ProfileField(
                  label: 'Email verification',
                  value: user.emailVerified ? 'Verified' : 'Not verified',
                ),
                if (_hasText(user.phone))
                  _ProfileField(label: 'Phone', value: user.phone!),
                if (_hasText(user.bio))
                  _ProfileField(label: 'Bio', value: user.bio!),
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
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.xs),
        Text(value, style: AppTextStyles.bodyMedium),
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
          const Text(
            'Unable to load your profile.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}
