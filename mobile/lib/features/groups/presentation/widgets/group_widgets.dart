import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../data/models/group_models.dart';

class GroupAvatar extends StatelessWidget {
  final String name;
  final double radius;
  const GroupAvatar({super.key, required this.name, this.radius = 28});

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: const Color(0xFFEDE9FE),
    child: Text(
      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
      style: TextStyle(
        fontSize: radius * .75,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      ),
    ),
  );
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
