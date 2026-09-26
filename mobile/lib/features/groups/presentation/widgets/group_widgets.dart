import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../data/models/group_models.dart';

import 'dart:typed_data';

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
    if (avatarStorageKey == null || avatarStorageKey!.trim().isEmpty) return null;
    final key = avatarStorageKey!.trim();
    if (key.startsWith('http://') || key.startsWith('https://')) return key;
    final base = baseUrl ?? defaultBaseUrl ?? const String.fromEnvironment('WEDO_API_BASE_URL', defaultValue: 'http://localhost:8080');
    final cleanBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final cleanKey = key.startsWith('/') ? key.substring(1) : key;
    if (cleanKey.startsWith('api/v1/media/')) {
      return '$cleanBase/$cleanKey';
    }
    return '$cleanBase/api/v1/media/$cleanKey';
  }

  Widget _buildFallback() => Text(
    name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
    style: TextStyle(
      fontSize: radius * .75,
      fontWeight: FontWeight.w700,
      color: AppColors.primary,
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (imageBytes != null && imageBytes!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFEDE9FE),
        child: ClipOval(
          child: Image.memory(
            imageBytes!,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFallback(),
          ),
        ),
      );
    }

    final url = resolvedUrl;
    if (url != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFEDE9FE),
        child: ClipOval(
          child: Image.network(
            url,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFallback(),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFEDE9FE),
      child: _buildFallback(),
    );
  }
}

class GroupRoleBadge extends StatelessWidget {
  final GroupRole role;
  const GroupRoleBadge({super.key, required this.role});
  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      GroupRole.owner => AppColors.primary,
      GroupRole.admin => const Color(0xFF006B5F),
      GroupRole.member => const Color(0xFF64748B),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          role.name.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

String groupUpdatedLabel(DateTime value, {DateTime? now}) {
  final days = (now ?? DateTime.now()).toUtc().difference(value.toUtc()).inDays;
  if (days <= 0) return 'Cập nhật gần đây';
  if (days == 1) return 'Cập nhật hôm qua';
  return 'Cập nhật $days ngày trước';
}

class GroupsBottomNavigation extends StatelessWidget {
  const GroupsBottomNavigation({super.key});
  @override
  Widget build(BuildContext context) => BottomNavigationBar(
    currentIndex: 1,
    type: BottomNavigationBarType.fixed,
    items: [
      BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
      BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Groups'),
      BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'Chat'),
      BottomNavigationBarItem(
        icon: Icon(Icons.calendar_today),
        label: 'Calendar',
      ),
      BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
    ],
  );
}
