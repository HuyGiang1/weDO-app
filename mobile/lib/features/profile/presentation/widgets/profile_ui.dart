import 'package:flutter/material.dart';

import 'dart:typed_data';

import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_text_styles.dart';
import '../../../media/presentation/media_storage_image.dart';

class ProfileSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const ProfileSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),

    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: child,
    ),
  );
}

class ProfileAvatar extends StatelessWidget {
  final String label;
  final double radius;
  final String? avatarStorageKey;
  final Uint8List? imageBytes;
  const ProfileAvatar({
    super.key,
    required this.label,
    this.radius = 44,
    this.avatarStorageKey,
    this.imageBytes,
  });
  @override
  Widget build(BuildContext context) {
    final value = label.trim();
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      child: imageBytes != null
          ? ClipOval(
              child: Image.memory(
                imageBytes!,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
              ),
            )
          : avatarStorageKey == null || avatarStorageKey!.isEmpty
          ? _fallback(context, value)
          : ClipOval(
              child: MediaStorageImage(
                storageKey: avatarStorageKey!,
                baseUrl: const String.fromEnvironment(
                  'WEDO_API_BASE_URL',
                  defaultValue: 'http://localhost:8080',
                ),
                width: radius * 2,
                height: radius * 2,
                fallback: (_) => _fallback(context, value),
              ),
            ),
    );
  }

  Widget _fallback(BuildContext context, String value) => Text(
    value.isEmpty ? '?' : value.substring(0, 1).toUpperCase(),
    style: AppTextStyles.of(context).headline,
  );
}

class ProfileActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const ProfileActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => ProfileSurface(
    padding: EdgeInsets.zero,
    child: ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label, style: AppTextStyles.of(context).label),
      trailing: Icon(
        Icons.chevron_right,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    ),
  );
}

ButtonStyle profilePrimaryButtonStyle(BuildContext context) => ElevatedButton.styleFrom(
  minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
  backgroundColor: Theme.of(context).colorScheme.primary,
  foregroundColor: Theme.of(context).colorScheme.onPrimary,
);
