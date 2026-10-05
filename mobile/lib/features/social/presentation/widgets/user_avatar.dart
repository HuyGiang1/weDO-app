import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../media/presentation/media_storage_image.dart';

/// Reusable circular avatar widget displaying initials or storage image fallback.
class UserAvatar extends StatelessWidget {
  final String displayName;
  final String? avatarStorageKey;
  final double radius;

  const UserAvatar({
    super.key,
    required this.displayName,
    this.avatarStorageKey,
    this.radius = 24.0,
  });

  String get _baseUrl => const String.fromEnvironment(
    'WEDO_API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  String _getInitials() {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final key = avatarStorageKey?.trim();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.surfaceContainerHigh,
      child: key == null || key.isEmpty
          ? _fallback()
          : ClipOval(
              child: MediaStorageImage(
                storageKey: key,
                baseUrl: _baseUrl,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                fallback: (_) => _fallback(),
              ),
            ),
    );
  }

  Widget _fallback() => Text(
    _getInitials(),
    style: AppTextStyles.label.copyWith(
      color: AppColors.primary,
      fontWeight: FontWeight.bold,
      fontSize: radius * 0.75,
    ),
  );
}
