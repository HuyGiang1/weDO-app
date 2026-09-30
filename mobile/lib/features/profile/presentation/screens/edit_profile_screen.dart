import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../auth/data/models/auth_models.dart';
import '../../data/profile_models.dart';
import '../widgets/profile_ui.dart';

class EditProfileScreen extends StatefulWidget {
  final CurrentUser initialUser;
  final Future<CurrentUser> Function(UpdateProfileRequest request)
  updateProfile;
  final Future<String> Function({
    required List<int> bytes,
    required String fileName,
    required String contentType,
  })?
  uploadAvatar;

  const EditProfileScreen({
    super.key,
    required this.initialUser,
    required this.updateProfile,
    this.uploadAvatar,
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
  bool _uploadingAvatar = false;
  String? _newAvatarStorageKey;
  Uint8List? _avatarPreview;
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
    if (_submitting ||
        _uploadingAvatar ||
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
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
          avatarStorageKey: _newAvatarStorageKey,
        ),
      );
      if (mounted) {
        Navigator.of(context).pop(updated);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _newAvatarStorageKey = null;
          _avatarPreview = null;
          _requestError = 'Unable to update your profile. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _pickAvatar() async {
    if (_uploadingAvatar || widget.uploadAvatar == null) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (!mounted || picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      if (mounted) {
        setState(() => _requestError = 'Choose an image smaller than 5 MiB.');
      }
      return;
    }
    final extension = picked.name.split('.').last.toLowerCase();
    final contentType =
        picked.mimeType ??
        switch (extension) {
          'png' => 'image/png',
          'webp' => 'image/webp',
          'jpg' || 'jpeg' => 'image/jpeg',
          _ => '',
        };
    if (!const {
      'image/jpeg',
      'image/png',
      'image/webp',
    }.contains(contentType)) {
      if (mounted) {
        setState(() => _requestError = 'Choose a JPEG, PNG, or WebP image.');
      }
      return;
    }
    setState(() {
      _uploadingAvatar = true;
      _requestError = null;
    });
    try {
      final key = await widget.uploadAvatar!(
        bytes: bytes,
        fileName: picked.name,
        contentType: contentType,
      );
      if (mounted) {
        setState(() {
          _newAvatarStorageKey = key;
          _avatarPreview = bytes;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _requestError =
              'Unable to upload your photo. Your current photo is unchanged.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
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
            Center(
              child: Stack(
                children: [
                  ProfileAvatar(
                    label:
                        widget.initialUser.displayName ??
                        widget.initialUser.username ??
                        widget.initialUser.email,
                    avatarStorageKey:
                        _newAvatarStorageKey ??
                        widget.initialUser.avatarStorageKey,
                    imageBytes: _avatarPreview,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: IconButton.filled(
                      tooltip: 'Change profile photo',
                      onPressed: _uploadingAvatar || widget.uploadAvatar == null
                          ? null
                          : _pickAvatar,
                      icon: _uploadingAvatar
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.edit, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ProfileSurface(
              child: Column(
                children: [
                  TextFormField(
                    controller: _displayName,
                    enabled: !_submitting,
                    validator: _displayNameValidator,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                    ),
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
                ],
              ),
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
              onPressed: _submitting || _uploadingAvatar ? null : _submit,
              style: profilePrimaryButtonStyle(),
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
