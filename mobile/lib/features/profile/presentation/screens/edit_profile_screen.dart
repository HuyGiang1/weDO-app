import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../auth/data/models/auth_models.dart';
import '../../data/profile_models.dart';

class EditProfileScreen extends StatefulWidget {
  final CurrentUser initialUser;
  final Future<CurrentUser> Function(UpdateProfileRequest request)
  updateProfile;

  const EditProfileScreen({
    super.key,
    required this.initialUser,
    required this.updateProfile,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayName;
  late final TextEditingController _bio;
  late final TextEditingController _phone;
  bool _submitting = false;
  String? _requestError;

  @override
  void initState() {
    super.initState();
    _displayName = TextEditingController(
      text: widget.initialUser.displayName ?? '',
    );
    _bio = TextEditingController(text: widget.initialUser.bio ?? '');
    _phone = TextEditingController(text: widget.initialUser.phone ?? '');
  }

  @override
  void dispose() {
    _displayName.dispose();
    _bio.dispose();
    _phone.dispose();
    super.dispose();
  }

  String? _displayNameValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Display name is required';
    }
    if (value.length > 100) {
      return 'Display name must not exceed 100 characters';
    }
    return null;
  }

  String? _lengthValidator(String? value, int max, String label) {
    if ((value?.length ?? 0) > max) {
      return '$label must not exceed $max characters';
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
      final updated = await widget.updateProfile(
        UpdateProfileRequest(
          displayName: _displayName.text,
          bio: _bio.text,
          phone: _phone.text,
        ),
      );
      if (mounted) {
        Navigator.of(context).pop(updated);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _requestError =
              'Unable to update your profile. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit Profile')),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            TextFormField(
              controller: _displayName,
              enabled: !_submitting,
              validator: _displayNameValidator,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _bio,
              enabled: !_submitting,
              validator: (value) => _lengthValidator(value, 500, 'Bio'),
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Bio'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _phone,
              enabled: !_submitting,
              validator: (value) => _lengthValidator(value, 20, 'Phone'),
              decoration: const InputDecoration(labelText: 'Phone'),
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
                  : const Text('Save changes'),
            ),
          ],
        ),
      ),
    ),
  );
}
