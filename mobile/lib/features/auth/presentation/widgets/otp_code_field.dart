import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';

/// A 6-cell OTP input widget designed for verification codes.
///
/// Features auto-advancement, backspace navigation, 6-digit paste distribution,
/// and preservation of leading zeros.
class OtpCodeField extends StatefulWidget {
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;
  final String? errorText;
  final bool enabled;

  const OtpCodeField({
    super.key,
    this.onChanged,
    this.onCompleted,
    this.errorText,
    this.enabled = true,
  });

  @override
  State<OtpCodeField> createState() => OtpCodeFieldState();
}

class OtpCodeFieldState extends State<OtpCodeField> {
  static const int codeLength = 6;

  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(codeLength, (_) => TextEditingController());
    _focusNodes = List.generate(codeLength, (index) {
      final node = FocusNode();
      node.onKeyEvent = (focusNode, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace) {
          if (_controllers[index].text.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
            _controllers[index - 1].clear();
            _notify();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      };
      return node;
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get code => _controllers.map((c) => c.text).join();

  void clear() {
    for (final controller in _controllers) {
      controller.clear();
    }
    if (_focusNodes.isNotEmpty) {
      _focusNodes.first.requestFocus();
    }
    _notify();
  }

  void _notify() {
    final currentCode = code;
    widget.onChanged?.call(currentCode);
    if (currentCode.length == codeLength) {
      widget.onCompleted?.call(currentCode);
    }
  }

  void _onCellChanged(int index, String value) {
    if (value.length > 1) {
      // Paste detected (e.g. user pasted a full code or multiple digits)
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < codeLength; i++) {
        if (i < digits.length) {
          _controllers[i].text = digits[i];
        } else {
          _controllers[i].clear();
        }
      }
      final targetIndex = digits.length.clamp(0, codeLength - 1);
      _focusNodes[targetIndex].requestFocus();
      _notify();
      return;
    }

    if (value.isNotEmpty) {
      if (index < codeLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    }
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // Distribute 6 cells evenly within available card width.
            const double spacing = 8.0;
            final double availableWidth = constraints.maxWidth;
            final double cellWidth =
                ((availableWidth - (spacing * (codeLength - 1))) / codeLength)
                    .clamp(36.0, 48.0);

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(codeLength, (index) {
                return SizedBox(
                  width: cellWidth,
                  height: AppSpacing.inputHeight,
                  child: Focus(
                    onFocusChange: (_) => setState(() {}),
                    child: Builder(
                      builder: (cellContext) {
                        final isFocused = _focusNodes[index].hasFocus;

                        return TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          enabled: widget.enabled,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22.0,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(codeLength),
                          ],
                          autofillHints: const [AutofillHints.oneTimeCode],
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: isFocused
                                ? AppColors.surface
                                : AppColors.inputBackground,
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16.0),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16.0),
                              borderSide: hasError
                                  ? const BorderSide(
                                      color: AppColors.error,
                                      width: 1.5,
                                    )
                                  : BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16.0),
                              borderSide: BorderSide(
                                color: hasError
                                    ? AppColors.error
                                    : AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16.0),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (val) => _onCellChanged(index, val),
                        );
                      },
                    ),
                  ),
                );
              }),
            );
          },
        ),
        if (hasError) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.errorText!,
            style: const TextStyle(
              fontSize: 13.0,
              fontWeight: FontWeight.w500,
              color: AppColors.error,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
