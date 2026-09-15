import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';

/// Clean dialog prompt for confirming social actions like Unfriend and Unblock.
abstract final class SocialConfirmationDialog {
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Xác nhận',
    String cancelLabel = 'Hủy',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
        ),
        backgroundColor: AppColors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        contentPadding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 16.0),
        actionsPadding: const EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 24.0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 64.0,
              height: 64.0,
              decoration: BoxDecoration(
                color: isDestructive
                    ? AppColors.errorContainer
                    : AppColors.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  isDestructive ? Icons.block_rounded : Icons.info_outline_rounded,
                  size: 32.0,
                  color: isDestructive ? AppColors.error : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            Text(
              title,
              style: AppTextStyles.headline.copyWith(
                fontSize: 22.0,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8.0),
            Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
                fontSize: 15.0,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  backgroundColor:
                      isDestructive ? AppColors.error : AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                ),
                child: Text(
                  confirmLabel,
                  style: AppTextStyles.buttonPrimary.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8.0),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.onSurface,
                  backgroundColor: AppColors.surfaceContainerLowest,
                  side: const BorderSide(color: AppColors.outlineVariant),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                ),
                child: Text(
                  cancelLabel,
                  style: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
