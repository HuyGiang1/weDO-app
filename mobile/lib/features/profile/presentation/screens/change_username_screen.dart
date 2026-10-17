import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/network/api_exception.dart';
import '../../../auth/data/models/auth_models.dart';
import '../../data/profile_models.dart';
import '../widgets/profile_ui.dart';

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
    if (value.isEmpty) return 'Vui lòng nhập tên người dùng';
    if (value.length < 3 || value.length > 30) {
      return 'Tên người dùng phải có từ 3 đến 30 ký tự';
    }
    if (!_usernamePattern.hasMatch(value)) {
      return 'Tên người dùng chỉ gồm chữ cái, số và dấu gạch dưới';
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
              ? 'Tên người dùng đã được sử dụng.'
              : 'Không thể đổi tên người dùng. Vui lòng thử lại.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _requestError = 'Không thể đổi tên người dùng. Vui lòng thử lại.';
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đổi tên người dùng')),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            const Icon(Icons.badge_outlined, size: 44),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Chọn tên người dùng duy nhất cho bạn trên weDO.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ProfileSurface(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tên người dùng hiện tại'),
                        const SizedBox(height: AppSpacing.xs),
                        Text('@${widget.initialUser.username ?? ''}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _username,
                    enabled: !_submitting,
                    autocorrect: false,
                    enableSuggestions: false,
                    validator: _validateUsername,
                    decoration: const InputDecoration(
                      labelText: 'Tên người dùng mới',
                      prefixText: '@',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    '3–30 characters: letters, numbers, and underscores.',
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
              onPressed: _submitting ? null : _submit,
              style: profilePrimaryButtonStyle(),
              child: _submitting
                  ? const CircularProgressIndicator()
                  : const Text('Cập nhật tên người dùng'),
            ),
          ],
        ),
      ),
    ),
  );
}
