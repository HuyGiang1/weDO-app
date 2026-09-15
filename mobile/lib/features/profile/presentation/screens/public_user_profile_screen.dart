import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../data/profile_models.dart';
import '../widgets/profile_ui.dart';

class PublicUserProfileScreen extends StatefulWidget {
  final String userId;
  final Future<PublicUserProfile> Function(String userId) loadPublicProfile;
  const PublicUserProfileScreen({
    super.key,
    required this.userId,
    required this.loadPublicProfile,
  });

  @override
  State<PublicUserProfileScreen> createState() =>
      _PublicUserProfileScreenState();
}

class _PublicUserProfileScreenState extends State<PublicUserProfileScreen> {
  late Future<PublicUserProfile> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.loadPublicProfile(widget.userId);
  }

  void _retry() {
    final next = widget.loadPublicProfile(widget.userId);
    setState(() {
      _future = next;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Profile')),
    body: FutureBuilder<PublicUserProfile>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Unable to load this profile.'),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(onPressed: _retry, child: const Text('Retry')),
              ],
            ),
          );
        }
        final profile = snapshot.data!;
        final displayName = profile.displayName?.trim();
        final title = displayName == null || displayName.isEmpty
            ? profile.username
            : displayName;
        final bio = profile.bio?.trim();
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSpacing.maxContentWidth,
                ),
                child: Column(
                  children: [
                    ProfileAvatar(label: title),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      title,
                      style: AppTextStyles.headline,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '@${profile.username}',
                      style: AppTextStyles.bodyMedium,
                    ),
                    if (bio != null && bio.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      ProfileSurface(
                        child: Text(
                          bio,
                          style: AppTextStyles.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
