import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/ui/widgets/primary_button.dart';

/// Result returned by the presentation availability boundary.
enum UsernameAvailability { available, unavailable }

enum _AvailabilityState { idle, checking, available, unavailable, error }

/// First presentation step of the backend complete-profile flow.
///
/// This screen selects a username only. It deliberately has no knowledge of
/// onboarding credentials, request DTOs, or the complete-profile endpoint.
class CreateUsernameScreen extends StatefulWidget {
  final Future<UsernameAvailability> Function(String username)?
  onCheckAvailability;
  final Future<void> Function(String username)? onContinue;

  const CreateUsernameScreen({
    super.key,
    this.onCheckAvailability,
    this.onContinue,
  });

  @override
  State<CreateUsernameScreen> createState() => _CreateUsernameScreenState();
}

class _CreateUsernameScreenState extends State<CreateUsernameScreen> {
  static final RegExp _usernamePattern = RegExp(r'^[a-zA-Z0-9_]{3,30}$');
  static const Duration _availabilityDebounce = Duration(milliseconds: 400);

  late final TextEditingController _usernameController;
  late final FocusNode _usernameFocusNode;
  Timer? _debounceTimer;

  String? _validationError;
  _AvailabilityState _availabilityState = _AvailabilityState.idle;
  bool _isFocused = false;
  bool _isContinuing = false;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _usernameFocusNode = FocusNode()..addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _usernameFocusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _usernameController.dispose();
    super.dispose();
  }

  String get _canonicalUsername => _usernameController.text.toLowerCase();

  bool get _canContinue =>
      _validationError == null &&
      _usernameController.text.isNotEmpty &&
      _availabilityState == _AvailabilityState.available &&
      !_isContinuing &&
      widget.onContinue != null;

  void _handleFocusChanged() {
    if (mounted) {
      setState(() {
        _isFocused = _usernameFocusNode.hasFocus;
      });
    }
  }

  String? _validateUsername(String value) {
    if (value.isEmpty) {
      return 'Username is required';
    }
    if (value.length < 3 || value.length > 30) {
      return 'Username must be between 3 and 30 characters';
    }
    if (!_usernamePattern.hasMatch(value)) {
      return 'Username must contain only letters, numbers, and underscores';
    }
    return null;
  }

  void _handleUsernameChanged(String value) {
    _debounceTimer?.cancel();
    final requestVersion = ++_requestVersion;
    final validationError = _validateUsername(value);

    setState(() {
      _validationError = value.isEmpty ? null : validationError;
      _availabilityState = _AvailabilityState.idle;
    });

    if (validationError != null || widget.onCheckAvailability == null) {
      return;
    }

    final canonicalUsername = value.toLowerCase();
    _debounceTimer = Timer(_availabilityDebounce, () async {
      if (!mounted || requestVersion != _requestVersion) return;

      setState(() {
        _availabilityState = _AvailabilityState.checking;
      });

      try {
        final result = await widget.onCheckAvailability!(canonicalUsername);
        if (!mounted || requestVersion != _requestVersion) return;
        setState(() {
          _availabilityState = result == UsernameAvailability.available
              ? _AvailabilityState.available
              : _AvailabilityState.unavailable;
        });
      } catch (_) {
        if (!mounted || requestVersion != _requestVersion) return;
        setState(() {
          _availabilityState = _AvailabilityState.error;
        });
      }
    });
  }

  Future<void> _handleContinue() async {
    if (!_canContinue) return;

    setState(() {
      _isContinuing = true;
    });

    try {
      await widget.onContinue!(_canonicalUsername);
    } finally {
      if (mounted) {
        setState(() {
          _isContinuing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGradientStart,
      body: SafeArea(
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
                      child: Container(
                        width: double.infinity,
                        clipBehavior: Clip.hardEdge,
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
                        child: Stack(
                          children: [
                            const Positioned(
                              top: -120.0,
                              right: -120.0,
                              child: IgnorePointer(child: _AmbientGlow()),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.xl),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'WeDo',
                                    style: AppTextStyles.brand,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: AppSpacing.xxl),
                                  const Text(
                                    'Choose your vibe',
                                    style: AppTextStyles.headline,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  const Text(
                                    'Pick a unique username for your profile.',
                                    style: AppTextStyles.bodyMedium,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: AppSpacing.xl),
                                  SizedBox(
                                    height: AppSpacing.inputHeight,
                                    child: TextField(
                                      controller: _usernameController,
                                      focusNode: _usernameFocusNode,
                                      autocorrect: false,
                                      enableSuggestions: false,
                                      textInputAction: TextInputAction.done,
                                      style: const TextStyle(
                                        fontSize: 18.0,
                                        fontWeight: FontWeight.w400,
                                        color: AppColors.onSurface,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'username',
                                        hintStyle: const TextStyle(
                                          fontSize: 18.0,
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                        prefixIcon: const Center(
                                          child: Text(
                                            '@',
                                            style: TextStyle(
                                              fontSize: 18.0,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                        prefixIconConstraints:
                                            const BoxConstraints(
                                              minWidth: 48.0,
                                              minHeight: AppSpacing.inputHeight,
                                            ),
                                        filled: true,
                                        fillColor: _isFocused
                                            ? AppColors.surface
                                            : AppColors.inputBackground,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16.0,
                                              vertical: 14.0,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8.0,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8.0,
                                          ),
                                          borderSide: _validationError == null
                                              ? BorderSide.none
                                              : const BorderSide(
                                                  color: AppColors.error,
                                                ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8.0,
                                          ),
                                          borderSide: BorderSide(
                                            color: _validationError == null
                                                ? AppColors.primary
                                                : AppColors.error,
                                          ),
                                        ),
                                      ),
                                      onChanged: _handleUsernameChanged,
                                      onSubmitted: (_) => _handleContinue(),
                                    ),
                                  ),
                                  if (_validationError != null) ...[
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      _validationError!,
                                      style: const TextStyle(
                                        fontSize: 13.0,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.error,
                                      ),
                                    ),
                                  ],
                                  _AvailabilityStatus(
                                    state: _availabilityState,
                                  ),
                                  const SizedBox(height: AppSpacing.xl),
                                  PrimaryButton(
                                    label: 'Continue',
                                    isLoading: _isContinuing,
                                    onPressed: _canContinue
                                        ? _handleContinue
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 256.0,
      height: 256.0,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.05),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 56.0,
            spreadRadius: 20.0,
          ),
        ],
      ),
    );
  }
}

class _AvailabilityStatus extends StatelessWidget {
  final _AvailabilityState state;

  const _AvailabilityStatus({required this.state});

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _AvailabilityState.idle:
        return const SizedBox.shrink();
      case _AvailabilityState.checking:
        return const _StatusRow(
          icon: SizedBox(
            width: 16.0,
            height: 16.0,
            child: CircularProgressIndicator(strokeWidth: 2.0),
          ),
          message: 'Checking username...',
          color: AppColors.onSurfaceVariant,
        );
      case _AvailabilityState.available:
        return const _StatusRow(
          icon: Icon(Icons.check_circle_rounded),
          message: 'Username is available',
          color: Color(0xFF16806A),
        );
      case _AvailabilityState.unavailable:
        return const _StatusRow(
          icon: Icon(Icons.error_outline_rounded),
          message: 'Username is already taken',
          color: AppColors.error,
        );
      case _AvailabilityState.error:
        return const _StatusRow(
          icon: Icon(Icons.info_outline_rounded),
          message: "Couldn't check username availability",
          color: AppColors.onSurfaceVariant,
        );
    }
  }
}

class _StatusRow extends StatelessWidget {
  final Widget icon;
  final String message;
  final Color color;

  const _StatusRow({
    required this.icon,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          IconTheme(
            data: IconThemeData(color: color, size: 18.0),
            child: icon,
          ),
          Text(
            message,
            style: TextStyle(
              fontSize: 14.0,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
