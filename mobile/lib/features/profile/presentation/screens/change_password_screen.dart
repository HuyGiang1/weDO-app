import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../auth/data/auth_failure.dart';

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
      return 'Current password is required';
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'New password is required';
    }
    if (value.length < 8 || value.length > 72) {
      return 'Password must be between 8 and 72 characters';
    }
    if (utf8.encode(value).length > 72) {
      return 'Password must not exceed 72 bytes';
    }
    return null;
  }

  String? _validateConfirmation(String? value) {
    if (value != _newPasswordController.text) {
      return 'Passwords do not match';
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
        _submissionError = 'Password changed. Please sign in again.';
      });
    } on AuthException catch (exception) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submissionError = switch (exception.failure.type) {
          AuthFailureType.invalidCredentials => 'Current password is incorrect',
          _ when exception.failure.fieldErrors.isNotEmpty =>
            exception.failure.fieldErrors.values.first,
          _ => 'Unable to change password. Please try again.',
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submissionError = 'Unable to change password. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextFormField(
                controller: _currentPasswordController,
                obscureText: !_showCurrentPassword,
                enabled: !_submitting,
                validator: _validateCurrentPassword,
                decoration: _passwordDecoration(
                  label: 'Current password',
                  visible: _showCurrentPassword,
                  onToggle: () => setState(
                    () => _showCurrentPassword = !_showCurrentPassword,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                obscureText: !_showNewPassword,
                enabled: !_submitting,
                validator: _validateNewPassword,
                decoration: _passwordDecoration(
                  label: 'New password',
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
                  label: 'Confirm new password',
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
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(),
                      )
                    : const Text('Change password'),
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
      tooltip: visible ? 'Hide password' : 'Show password',
      onPressed: _submitting ? null : onToggle,
      icon: Icon(visible ? Icons.visibility_off : Icons.visibility),
    ),
  );
}
