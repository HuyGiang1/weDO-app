import 'dart:async';

import 'package:flutter/material.dart';

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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),

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
                                  Text(
                                    'WeDo',
                                    style: AppTextStyles.of(context).brand,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: AppSpacing.xxl),
                                  Text(
                                    'Choose your vibe',
                                    style: AppTextStyles.of(context).headline,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    'Pick a unique username for your profile.',
                                    style: AppTextStyles.of(context).bodyMedium,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: AppSpacing.xl),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: AppSpacing.inputHeight,
                                    ),
                                    child: TextField(
                                      controller: _usernameController,
                                      focusNode: _usernameFocusNode,
                                      autocorrect: false,
                                      enableSuggestions: false,
                                      textInputAction: TextInputAction.done,
                                      cursorColor: Theme.of(context).colorScheme.primary,
                                      style: TextStyle(
                                        fontSize: 16.0,
                                        fontWeight: FontWeight.w500,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        hintText: 'username',
                                        hintStyle: TextStyle(
                                          fontSize: 16.0,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                        prefixIcon: Padding(
                                          padding: EdgeInsets.only(
                                            left: 16.0,
                                            right: 8.0,
                                          ),
                                          child: Center(
                                            widthFactor: 1.0,
                                            child: Text(
                                              '@',
                                              style: TextStyle(
                                                fontSize: 18.0,
                                                fontWeight: FontWeight.w600,
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                        ),
                                        prefixIconConstraints:
                                            const BoxConstraints(
                                              minWidth: 40.0,
                                              minHeight: 0,
                                            ),
                                        filled: true,
                                        fillColor: _isFocused
                                            ? Theme.of(context).colorScheme.surface
                                            : Theme.of(context).colorScheme.surfaceContainerLow,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16.0,
                                              vertical: 16.0,
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
                                      style: TextStyle(
                                        fontSize: 13.0,
                                        fontWeight: FontWeight.w500,
                                        color: Theme.of(context).colorScheme.error,
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
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),

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
        return _StatusRow(
          icon: SizedBox(
            width: 16.0,
            height: 16.0,
            child: CircularProgressIndicator(strokeWidth: 2.0),
          ),
          message: 'Checking username...',
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
      case _AvailabilityState.available:
        return _StatusRow(
          icon: Icon(Icons.check_circle_rounded),
          message: 'Username is available',
          color: Theme.of(context).colorScheme.onSurface,
        );
      case _AvailabilityState.unavailable:
        return _StatusRow(
          icon: Icon(Icons.error_outline_rounded),
          message: 'Username is already taken',
          color: Theme.of(context).colorScheme.error,
        );
      case _AvailabilityState.error:
        return _StatusRow(
          icon: Icon(Icons.info_outline_rounded),
          message: "Couldn't check username availability",
          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
