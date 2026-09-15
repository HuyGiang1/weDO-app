import 'package:flutter/material.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_text_styles.dart';

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
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(
          color: AppColors.primaryShadow,
          blurRadius: 18,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: child,
    ),
  );
}

class ProfileAvatar extends StatelessWidget {
  final String label;
  final double radius;
  const ProfileAvatar({super.key, required this.label, this.radius = 44});
  @override
  Widget build(BuildContext context) {
    final value = label.trim();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.backgroundGradientEnd,
      child: Text(
        value.isEmpty ? '?' : value.substring(0, 1).toUpperCase(),
        style: AppTextStyles.headline,
      ),
    );
  }
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
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label, style: AppTextStyles.label),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.onSurfaceVariant,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onTap: onTap,
    ),
  );
}

ButtonStyle profilePrimaryButtonStyle() => ElevatedButton.styleFrom(
  minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
  shape: const StadiumBorder(),
  backgroundColor: AppColors.primary,
  foregroundColor: AppColors.onPrimary,
);
