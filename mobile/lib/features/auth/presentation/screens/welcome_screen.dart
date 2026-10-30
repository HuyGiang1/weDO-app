import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/ui/widgets/wedo_brand_mark.dart';

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
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
    return Text(
      'WeDo',
      style: AppTextStyles.of(context).brand,
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
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(32.0),
                  ),
                ),
              ),
            ),
            // Foreground image asset
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: const WeDoBrandMark(size: 72),
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
    return Column(
      children: [
        Text(
          'Squad up.',
          style: AppTextStyles.of(context).headline,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: AppSpacing.xs),
        Text(
          'Coordinate, share, and settle up with your squad effortlessly.',
          style: AppTextStyles.of(context).subtitle,
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
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
          child: SizedBox(
            height: AppSpacing.buttonHeight,
            child: ElevatedButton(
              onPressed: onCreateAccountPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                elevation: 0,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              child: Text(
                'Create Account',
                style: AppTextStyles.of(context).buttonPrimary,
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
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.primary,
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 1.0,
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
            child: Text(
              'Login',
              style: AppTextStyles.of(context).buttonSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
