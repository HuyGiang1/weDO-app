import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../auth/data/auth_failure.dart';
import '../../../../app/theme/app_spacing.dart';
import '../widgets/profile_ui.dart';

class ChangePasswordScreen extends StatefulWidget {
  final Future<void> Function({
    required String currentPassword,
    required String newPassword,
  })
  changePassword;
  final Future<bool> Function() endSessionAfterPasswordChange;
  final VoidCallback onSuccess;

  const ChangePasswordScreen({
    super.key,
    required this.changePassword,
    required this.endSessionAfterPasswordChange,
    required this.onSuccess,
  });

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _submitting = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  String? _submissionError;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateCurrentPassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập mật khẩu hiện tại';
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập mật khẩu mới';
    }
    if (value.length < 8 || value.length > 72) {
      return 'Mật khẩu phải có từ 8 đến 72 ký tự';
    }
    if (utf8.encode(value).length > 72) {
      return 'Mật khẩu không được vượt quá 72 byte';
    }
    return null;
  }

  String? _validateConfirmation(String? value) {
    if (value != _newPasswordController.text) {
      return 'Mật khẩu không khớp';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _submissionError = null;
    });

    try {
      await widget.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      final invalidated = await widget.endSessionAfterPasswordChange();
      if (!mounted) return;
      if (invalidated) {
        widget.onSuccess();
        return;
      }
      setState(() {
        _submitting = false;
        _submissionError = 'Đã đổi mật khẩu. Vui lòng đăng nhập lại.';
      });
    } on AuthException catch (exception) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submissionError = switch (exception.failure.type) {
          AuthFailureType.invalidCredentials => 'Mật khẩu hiện tại không đúng',
          _ when exception.failure.fieldErrors.isNotEmpty =>
            exception.failure.fieldErrors.values.first,
          _ => 'Không thể đổi mật khẩu. Vui lòng thử lại.',
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submissionError = 'Không thể đổi mật khẩu. Vui lòng thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đổi mật khẩu')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              const Text(
                'Sử dụng mật khẩu dài và khó đoán để bảo vệ tài khoản.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              ProfileSurface(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _currentPasswordController,
                      obscureText: !_showCurrentPassword,
                      enabled: !_submitting,
                      validator: _validateCurrentPassword,
                      decoration: _passwordDecoration(
                        label: 'Mật khẩu hiện tại',
                        visible: _showCurrentPassword,
                        onToggle: () => setState(
                          () => _showCurrentPassword = !_showCurrentPassword,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ProfileSurface(
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Yêu cầu mật khẩu:'),
                    SizedBox(height: 8),
                    Text('• Từ 8 đến 72 ký tự'),
                    Text('• Không quá 72 byte UTF-8'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                obscureText: !_showNewPassword,
                enabled: !_submitting,
                validator: _validateNewPassword,
                decoration: _passwordDecoration(
                  label: 'Mật khẩu mới',
                  visible: _showNewPassword,
                  onToggle: () =>
                      setState(() => _showNewPassword = !_showNewPassword),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: !_showConfirmPassword,
                enabled: !_submitting,
                validator: _validateConfirmation,
                decoration: _passwordDecoration(
                  label: 'Xác nhận mật khẩu mới',
                  visible: _showConfirmPassword,
                  onToggle: () => setState(
                    () => _showConfirmPassword = !_showConfirmPassword,
                  ),
                ),
              ),
              if (_submissionError != null) ...[
                const SizedBox(height: 16),
                Text(
                  _submissionError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: profilePrimaryButtonStyle(context),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(),
                      )
                    : const Text('Đổi mật khẩu'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _passwordDecoration({
    required String label,
    required bool visible,
    required VoidCallback onToggle,
  }) => InputDecoration(
    labelText: label,
    suffixIcon: IconButton(
      tooltip: visible ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
      onPressed: _submitting ? null : onToggle,
      icon: Icon(visible ? Icons.visibility_off : Icons.visibility),
    ),
  );
}
