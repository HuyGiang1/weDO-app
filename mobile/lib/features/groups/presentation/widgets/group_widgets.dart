import '../../../../app/navigation/app_bottom_navigation.dart';
import '../../../../app/routes.dart';
import 'package:flutter/material.dart';
import '../../../../core/l10n/domain_labels.dart';

import '../../../../core/ui/widgets/app_management.dart';
import '../../data/models/group_models.dart';

import 'dart:typed_data';

import '../../../media/presentation/media_storage_image.dart';

class GroupAvatar extends StatelessWidget {
  final String name;
  final double radius;
  final String? avatarStorageKey;
  final String? avatarUrl;
  final Uint8List? imageBytes;
  final String? baseUrl;

  static String? defaultBaseUrl;

  const GroupAvatar({
    super.key,
    required this.name,
    this.radius = 28,
    this.avatarStorageKey,
    this.avatarUrl,
    this.imageBytes,
    this.baseUrl,
  });

  String? get resolvedUrl {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) return avatarUrl;
    if (avatarStorageKey == null || avatarStorageKey!.trim().isEmpty) {
      return null;
    }
    final key = avatarStorageKey!.trim();
    if (key.startsWith('http://') || key.startsWith('https://')) return key;
    final base =
        baseUrl ??
        defaultBaseUrl ??
        const String.fromEnvironment(
          'WEDO_API_BASE_URL',
          defaultValue: 'http://localhost:8080',
        );
    final cleanBase = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    final cleanKey = key.startsWith('/') ? key.substring(1) : key;
    if (cleanKey.startsWith('api/v1/media/')) {
      return '$cleanBase/$cleanKey';
    }
    return '$cleanBase/api/v1/media/$cleanKey';
  }

  Widget _buildFallback(BuildContext context) => Text(
    name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
    style: TextStyle(
      fontSize: radius * .75,
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.primary,
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (imageBytes != null && imageBytes!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        child: ClipOval(
          child: Image.memory(
            imageBytes!,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFallback(context),
          ),
        ),
      );
    }

    final key = avatarStorageKey?.trim();
    final url = avatarUrl;
    if ((key != null && key.isNotEmpty) || (url != null && url.isNotEmpty)) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        child: ClipOval(
          child: MediaStorageImage(
            storageKey: url ?? key!,
            baseUrl:
                baseUrl ??
                defaultBaseUrl ??
                const String.fromEnvironment(
                  'WEDO_API_BASE_URL',
                  defaultValue: 'http://localhost:8080',
                ),
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            fallback: (_) => _buildFallback(context),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      child: _buildFallback(context),
    );
  }
}

class GroupRoleBadge extends StatelessWidget {
  final GroupRole role;
  const GroupRoleBadge({super.key, required this.role});
  @override
  Widget build(BuildContext context) {
    return AppStatusLabel(role.label);
  }
}

String groupUpdatedLabel(DateTime value, {DateTime? now}) {
  final days = (now ?? DateTime.now()).toUtc().difference(value.toUtc()).inDays;
  if (days <= 0) return 'Cập nhật gần đây';
  if (days == 1) return 'Cập nhật hôm qua';
  return 'Cập nhật $days ngày trước';
}

class GroupsBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;
  const GroupsBottomNavigation({super.key, this.currentIndex = 1, this.onTap});
  // Compatibility adapter for existing screen callback indices. Group pages
  // remain accessible through Home; they are no longer a sixth/global tab.
  @override
  Widget build(BuildContext context) => AppBottomNavigation(
    selectedIndex: currentIndex < 0 ? 0 : currentIndex < 2 ? 1 : currentIndex,
    onFallback: (index) {
      if (index == 0) {
        Navigator.of(context).pushNamed(AppRoutes.community);
      } else {
        onTap?.call(index == 1 ? 0 : index);
      }
    },
  );
}
