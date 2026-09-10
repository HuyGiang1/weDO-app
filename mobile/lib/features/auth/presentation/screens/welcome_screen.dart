import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';

/// The auth landing screen shown before Login / Register.
///
/// Ported cleanly from Stitch visual design.
class WelcomeScreen extends StatelessWidget {
  final VoidCallback onCreateAccountPressed;
  final VoidCallback onLoginPressed;

  const WelcomeScreen({
    super.key,
    required this.onCreateAccountPressed,
    required this.onLoginPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.backgroundGradientStart,
              AppColors.backgroundGradientEnd,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AppSpacing.maxContentWidth,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.lg,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const _BrandSection(),
                            const SizedBox(height: AppSpacing.xl),
                            const _IllustrationSection(),
                            const SizedBox(height: AppSpacing.xl),
                            const _CopySection(),
                            const SizedBox(height: AppSpacing.xxl),
                            _ActionSection(
                              onCreateAccountPressed: onCreateAccountPressed,
                              onLoginPressed: onLoginPressed,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BrandSection extends StatelessWidget {
  const _BrandSection();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'WeDo',
      style: AppTextStyles.brand,
      textAlign: TextAlign.center,
    );
  }
}

class _IllustrationSection extends StatelessWidget {
  const _IllustrationSection();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: AppSpacing.maxIllustrationWidth,
        maxHeight: AppSpacing.maxIllustrationWidth,
      ),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // White decorative card with slight clockwise rotation (~3 degrees) and purple shadow
            Transform.rotate(
              angle: 3.0 * (math.pi / 180.0),
              child: Transform.scale(
                scale: 1.05,
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(32.0),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.primaryShadow,
                        blurRadius: 24.0,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Foreground image asset
            ClipRRect(
              borderRadius: BorderRadius.circular(24.0),
              child: Image.asset(
                'assets/images/wedo_logo.png',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CopySection extends StatelessWidget {
  const _CopySection();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text(
          'Squad up.',
          style: AppTextStyles.headline,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: AppSpacing.xs),
        Text(
          'Coordinate, share, and settle up with your squad effortlessly.',
          style: AppTextStyles.subtitle,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ActionSection extends StatelessWidget {
  final VoidCallback onCreateAccountPressed;
  final VoidCallback onLoginPressed;

  const _ActionSection({
    required this.onCreateAccountPressed,
    required this.onLoginPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999.0),
            boxShadow: const [
              BoxShadow(
                color: AppColors.primaryShadow,
                blurRadius: 16.0,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: SizedBox(
            height: AppSpacing.buttonHeight,
            child: ElevatedButton(
              onPressed: onCreateAccountPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              child: const Text(
                'Create Account',
                style: AppTextStyles.buttonPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: AppSpacing.buttonHeight,
          child: OutlinedButton(
            onPressed: onLoginPressed,
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.primary,
              side: const BorderSide(
                color: AppColors.outlineVariant,
                width: 1.0,
              ),
              shape: const StadiumBorder(),
            ),
            child: const Text(
              'Login',
              style: AppTextStyles.buttonSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
