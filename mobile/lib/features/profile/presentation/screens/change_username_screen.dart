import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/network/api_exception.dart';
import '../../../auth/data/models/auth_models.dart';
import '../../data/profile_models.dart';

class ChangeUsernameScreen extends StatefulWidget {
  final CurrentUser initialUser;
  final Future<CurrentUser> Function(UpdateUsernameRequest request)
  updateUsername;

  const ChangeUsernameScreen({
    super.key,
    required this.initialUser,
    required this.updateUsername,
  });

  @override
  State<ChangeUsernameScreen> createState() => _ChangeUsernameScreenState();
}

class _ChangeUsernameScreenState extends State<ChangeUsernameScreen> {
  static final RegExp _usernamePattern = RegExp(r'^[a-zA-Z0-9_]{3,30}$');

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _username;
  bool _submitting = false;
  String? _requestError;

  @override
  void initState() {
    super.initState();
    _username = TextEditingController(text: widget.initialUser.username ?? '');
  }

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  String get _canonicalUsername => _username.text.trim().toLowerCase();

  String? _validateUsername(String? _) {
    final value = _canonicalUsername;
    if (value.isEmpty) return 'Username is required';
    if (value.length < 3 || value.length > 30) {
      return 'Username must be between 3 and 30 characters';
    }
    if (!_usernamePattern.hasMatch(value)) {
      return 'Username must contain only letters, numbers, and underscores';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _requestError = null;
    });
    try {
      final updated = await widget.updateUsername(
        UpdateUsernameRequest(username: _canonicalUsername),
      );
      if (mounted) Navigator.of(context).pop(updated);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _requestError = error.code == 'USERNAME_ALREADY_EXISTS'
              ? 'Username is already taken.'
              : 'Unable to update your username. Please try again.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _requestError = 'Unable to update your username. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Change Username')),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            TextFormField(
              controller: _username,
              enabled: !_submitting,
              autocorrect: false,
              enableSuggestions: false,
              validator: _validateUsername,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            if (_requestError != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _requestError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const CircularProgressIndicator()
                  : const Text('Save username'),
            ),
          ],
        ),
      ),
    ),
  );
}
