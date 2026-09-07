import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/ui/widgets/primary_button.dart';

/// Presentation-only data collected before the eventual complete-profile API call.
class CompleteProfileData {
  final String username;
  final String displayName;
  final String? bio;

  const CompleteProfileData({
    required this.username,
    required this.displayName,
    required this.bio,
  });
}

/// Collects profile details after username selection.
///
/// API credentials and storage references intentionally belong to the caller,
/// never to this presentation widget.
class CompleteProfileScreen extends StatefulWidget {
  final String username;
  final Future<void> Function(CompleteProfileData data)? onContinue;
  final Future<void> Function()? onPickAvatar;

  const CompleteProfileScreen({
    super.key,
    required this.username,
    this.onContinue,
    this.onPickAvatar,
  });

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;
  late final FocusNode _displayNameFocusNode;
  late final FocusNode _bioFocusNode;

  String? _displayNameError;
  String? _bioError;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController();
    _bioController = TextEditingController();
    _displayNameFocusNode = FocusNode();
    _bioFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _displayNameFocusNode.dispose();
    _bioFocusNode.dispose();
    super.dispose();
  }

  String? _validateDisplayName(String value) {
    if (value.trim().isEmpty) {
      return 'Display name is required';
    }
    if (value.length > 100) {
      return 'Display name must not exceed 100 characters';
    }
    return null;
  }

  String? _validateBio(String value) {
    if (value.length > 500) {
      return 'Bio must not exceed 500 characters';
    }
    return null;
  }

  bool get _canContinue =>
      _validateDisplayName(_displayNameController.text) == null &&
      _validateBio(_bioController.text) == null &&
      !_isSubmitting &&
      widget.onContinue != null;

  bool _validateAll() {
    final displayNameError = _validateDisplayName(_displayNameController.text);
    final bioError = _validateBio(_bioController.text);
    setState(() {
      _displayNameError = displayNameError;
      _bioError = bioError;
    });
    return displayNameError == null && bioError == null;
  }

  Future<void> _handleContinue() async {
    if (_isSubmitting || widget.onContinue == null || !_validateAll()) return;

    FocusScope.of(context).unfocus();
    final normalizedBio = _bioController.text.trim();
    final data = CompleteProfileData(
      username: widget.username,
      displayName: _displayNameController.text.trim(),
      bio: normalizedBio.isEmpty ? null : normalizedBio,
    );

    setState(() {
      _isSubmitting = true;
    });
    try {
      await widget.onContinue!(data);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _handlePickAvatar() async {
    if (_isSubmitting || widget.onPickAvatar == null) return;
    await widget.onPickAvatar!();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGradientStart,
      body: SafeArea(
        child: Column(
          children: [
            const _ProfileHeader(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
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
                            vertical: AppSpacing.xl,
                          ),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(24.0),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryShadow.withValues(
                                    alpha: 0.04,
                                  ),
                                  blurRadius: 20.0,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: EdgeInsets.all(
                              constraints.maxWidth < 380
                                  ? AppSpacing.lg
                                  : AppSpacing.xl,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  "Let's set up your profile",
                                  style: AppTextStyles.headline,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                const Text(
                                  'Add a photo and some details to help friends find you.',
                                  style: AppTextStyles.bodyMedium,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppSpacing.xl),
                                _AvatarPicker(
                                  onPressed:
                                      _isSubmitting ||
                                          widget.onPickAvatar == null
                                      ? null
                                      : _handlePickAvatar,
                                ),
                                const SizedBox(height: AppSpacing.xl),
                                _ProfileField(
                                  label: 'Display Name',
                                  hintText: 'e.g. Alex Smith',
                                  controller: _displayNameController,
                                  focusNode: _displayNameFocusNode,
                                  errorText: _displayNameError,
                                  enabled: !_isSubmitting,
                                  onChanged: (value) => setState(() {
                                    _displayNameError = _validateDisplayName(
                                      value,
                                    );
                                  }),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                _ProfileField(
                                  label: 'Bio',
                                  optional: true,
                                  hintText: 'Tell us a bit about yourself...',
                                  controller: _bioController,
                                  focusNode: _bioFocusNode,
                                  errorText: _bioError,
                                  enabled: !_isSubmitting,
                                  maxLines: 3,
                                  onChanged: (value) => setState(() {
                                    _bioError = _validateBio(value);
                                  }),
                                ),
                                const SizedBox(height: AppSpacing.xl),
                                PrimaryButton(
                                  label: 'Continue',
                                  isLoading: _isSubmitting,
                                  onPressed: _canContinue
                                      ? _handleContinue
                                      : null,
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                const Text(
                                  'Powered by WeDo',
                                  style: AppTextStyles.bodySmall,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Align(
          alignment: Alignment.centerLeft,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10.0),
            child: Image.asset(
              'assets/images/wedo_logo.png',
              width: 36.0,
              height: 36.0,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  final VoidCallback? onPressed;

  const _AvatarPicker({this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        button: true,
        label: 'Add profile photo',
        child: SizedBox(
          width: 128.0,
          height: 128.0,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: const Color(0xFFE6E8EA),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onPressed,
                  child: const Center(
                    child: Icon(
                      Icons.add_a_photo_outlined,
                      size: 36.0,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -2.0,
                bottom: -2.0,
                child: Container(
                  width: 36.0,
                  height: 36.0,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2.0),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.primaryShadow,
                        blurRadius: 8.0,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add, color: AppColors.onPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileField extends StatefulWidget {
  final String label;
  final bool optional;
  final String hintText;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? errorText;
  final bool enabled;
  final int maxLines;
  final ValueChanged<String> onChanged;

  const _ProfileField({
    required this.label,
    required this.hintText,
    required this.controller,
    required this.focusNode,
    required this.errorText,
    required this.enabled,
    required this.onChanged,
    this.optional = false,
    this.maxLines = 1,
  });

  @override
  State<_ProfileField> createState() => _ProfileFieldState();
}

class _ProfileFieldState extends State<_ProfileField> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocus);
    super.dispose();
  }

  void _handleFocus() {
    if (mounted) setState(() => _isFocused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.label, style: AppTextStyles.label),
            if (widget.optional)
              const Text('Optional', style: AppTextStyles.bodySmall),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          minLines: widget.maxLines,
          maxLines: widget.maxLines,
          textInputAction: widget.maxLines == 1
              ? TextInputAction.next
              : TextInputAction.newline,
          style: AppTextStyles.input,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: AppTextStyles.inputHint,
            filled: true,
            fillColor: _isFocused
                ? AppColors.surface
                : AppColors.inputBackground,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: widget.errorText == null
                  ? BorderSide.none
                  : const BorderSide(color: AppColors.error),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(
                color: widget.errorText == null
                    ? AppColors.primary
                    : AppColors.error,
              ),
            ),
          ),
          onChanged: widget.onChanged,
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.errorText!,
            style: const TextStyle(
              color: AppColors.error,
              fontSize: 13.0,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
