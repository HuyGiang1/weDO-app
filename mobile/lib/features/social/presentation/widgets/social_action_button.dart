import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../data/models/social_models.dart';

/// Reusable widget rendering relationship-sensitive action buttons.
class SocialActionButton extends StatelessWidget {
  final RelationshipState state;
  final bool isLoading;
  final VoidCallback? onAddFriend;
  final VoidCallback? onCancelRequest;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onUnfriend;
  final VoidCallback? onUnblock;

  const SocialActionButton({
    super.key,
    required this.state,
    this.isLoading = false,
    this.onAddFriend,
    this.onCancelRequest,
    this.onAccept,
    this.onDecline,
    this.onUnfriend,
    this.onUnblock,
  });

  @override
  Widget build(BuildContext context) {
    if (state == RelationshipState.self) {
      return const SizedBox.shrink();
    }

    if (isLoading) {
      return const SizedBox(
        width: 28.0,
        height: 28.0,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.0,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );
    }

    switch (state) {
      case RelationshipState.none:
        return FilledButton.icon(
          onPressed: onAddFriend,
          icon: const Icon(Icons.person_add_rounded, size: 18.0),
          label: const Text('Thêm bạn bè'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: const StadiumBorder(),
          ),
        );

      case RelationshipState.pendingSent:
        return OutlinedButton.icon(
          onPressed: onCancelRequest,
          icon: const Icon(Icons.close_rounded, size: 18.0),
          label: const Text('Hủy lời mời'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.onSurfaceVariant,
            side: const BorderSide(color: AppColors.outlineVariant),
            shape: const StadiumBorder(),
          ),
        );

      case RelationshipState.pendingReceived:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: onAccept,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              ),
              child: const Text('Chấp nhận'),
            ),
            const SizedBox(width: AppSpacing.xs),
            OutlinedButton(
              onPressed: onDecline,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.onSurfaceVariant,
                side: const BorderSide(color: AppColors.outlineVariant),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              ),
              child: const Text('Từ chối'),
            ),
          ],
        );

      case RelationshipState.friends:
        return OutlinedButton.icon(
          onPressed: onUnfriend,
          icon: const Icon(Icons.check_rounded, size: 18.0),
          label: const Text('Bạn bè'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            shape: const StadiumBorder(),
          ),
        );

      case RelationshipState.blocked:
        return OutlinedButton(
          onPressed: onUnblock,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error),
            shape: const StadiumBorder(),
          ),
          child: const Text('Bỏ chặn'),
        );

      case RelationshipState.blockedBy:
        return const SizedBox.shrink();

      case RelationshipState.self:
        return const SizedBox.shrink();
    }
  }
}
