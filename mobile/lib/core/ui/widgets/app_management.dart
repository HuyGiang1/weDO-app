import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

enum AppTone { neutral, accent, success, warning, danger }

Color toneColor(BuildContext context, AppTone tone) => switch (tone) {
  AppTone.accent => Theme.of(context).colorScheme.primary,
  AppTone.success => AppSemanticColors.of(context).success,
  AppTone.warning => AppSemanticColors.of(context).warning,
  AppTone.danger => Theme.of(context).colorScheme.error,
  AppTone.neutral => Theme.of(context).colorScheme.onSurfaceVariant,
};

class AppStatusLabel extends StatelessWidget {
  final String label;
  final AppTone tone;
  final IconData? icon;
  const AppStatusLabel(
    this.label, {
    super.key,
    this.tone = AppTone.neutral,
    this.icon,
  });
  @override
  Widget build(BuildContext context) {
    final color = toneColor(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const AppSectionHeader(this.title, {super.key, this.subtitle});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    ),
  );
}

class AppSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const AppSurface({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  );
}

class AppManagementRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle, status;
  final VoidCallback? onTap;
  final Widget? leading;
  final AppTone tone;
  const AppManagementRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.status,
    this.onTap,
    this.leading,
    this.tone = AppTone.neutral,
  });
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = toneColor(context, tone);
    return ListTile(
      enabled: onTap != null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      minTileHeight: 64,
      leading:
          leading ??
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tone == AppTone.neutral
                  ? colors.surfaceContainerLow
                  : color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: onTap == null
                  ? colors.onSurface.withValues(alpha: .38)
                  : color,
            ),
          ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: tone == AppTone.danger && onTap != null ? color : null,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status != null) ...[
            Text(status!, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(width: 4),
          ],
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }
}

class AppNotice extends StatelessWidget {
  final String message;
  final AppTone tone;
  const AppNotice(this.message, {super.key, this.tone = AppTone.neutral});
  @override
  Widget build(BuildContext context) {
    final color = toneColor(context, tone);
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            tone == AppTone.warning
                ? Icons.info_outline
                : tone == AppTone.danger
                ? Icons.error_outline
                : Icons.info_outline,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
