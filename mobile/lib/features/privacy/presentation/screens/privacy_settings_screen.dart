import 'package:flutter/material.dart';
import '../../../../core/l10n/domain_labels.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../data/privacy_models.dart';
import '../../../profile/presentation/widgets/profile_ui.dart';

class PrivacySettingsScreen extends StatefulWidget {
  final Future<PrivacySettings> Function() loadPrivacySettings;
  final Future<PrivacySettings> Function(UpdatePrivacySettingsRequest request)
  updatePrivacySettings;

  const PrivacySettingsScreen({
    super.key,
    required this.loadPrivacySettings,
    required this.updatePrivacySettings,
  });

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  PrivacySettings? _baseline;
  PrivacySettings? _draft;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settings = await widget.loadPrivacySettings();
      if (mounted) {
        setState(() {
          _baseline = settings;
          _draft = settings;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Không thể tải cài đặt quyền riêng tư.';
        });
      }
    }
  }

  bool get _isDirty => _baseline != null && !_draftEquals(_baseline!, _draft!);

  Future<void> _save() async {
    if (_saving || !_isDirty) return;
    final request = _draft!.changesFrom(_baseline!);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final settings = await widget.updatePrivacySettings(request);
      if (mounted) {
        setState(() {
          _baseline = settings;
          _draft = settings;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Không thể lưu cài đặt quyền riêng tư. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _update(PrivacySettings Function(PrivacySettings current) change) {
    setState(() => _draft = change(_draft!));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_draft == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cài đặt quyền riêng tư')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'Không thể tải cài đặt quyền riêng tư.'),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(onPressed: _load, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }
    final draft = _draft!;
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt quyền riêng tư')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SectionTitle('Khả năng tìm kiếm'),
              ProfileSurface(
                child: Column(
                  children: [
                    _toggle(
                      'Tìm bằng tên người dùng',
                      draft.discoverByUsername,
                      (value) => _update(
                        (current) =>
                            current.copyWith(discoverByUsername: value),
                      ),
                    ),
                    _toggle(
                      'Tìm bằng mã QR',
                      draft.discoverByQr,
                      (value) => _update(
                        (current) => current.copyWith(discoverByQr: value),
                      ),
                    ),
                    _toggle(
                      'Tìm bằng email',
                      draft.discoverByEmail,
                      (value) => _update(
                        (current) => current.copyWith(discoverByEmail: value),
                      ),
                    ),
                    _toggle(
                      'Tìm bằng số điện thoại',
                      draft.discoverByPhone,
                      (value) => _update(
                        (current) => current.copyWith(discoverByPhone: value),
                      ),
                    ),
                  ],
                ),
              ),
              const _SectionTitle('Kết nối và lời mời'),
              ProfileSurface(
                child: Column(
                  children: [
                    DropdownButtonFormField<DmPolicy>(
                      initialValue: draft.dmPolicy,
                      decoration: const InputDecoration(
                        labelText: 'Ai có thể nhắn tin',
                      ),
                      items: DmPolicy.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.label),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) {
                              if (value != null) {
                                _update(
                                  (current) =>
                                      current.copyWith(dmPolicy: value),
                                );
                              }
                            },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<FriendRequestPolicy>(
                      initialValue: draft.friendRequestPolicy,
                      decoration: const InputDecoration(
                        labelText: 'Ai có thể gửi lời mời kết bạn',
                      ),
                      items: FriendRequestPolicy.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.label),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) {
                              if (value != null) {
                                _update(
                                  (current) => current.copyWith(
                                    friendRequestPolicy: value,
                                  ),
                                );
                              }
                            },
                    ),
                  ],
                ),
              ),
              const _SectionTitle('Trạng thái trực tuyến'),
              ProfileSurface(
                child: Column(
                  children: [
                    _toggle(
                      'Hiện trạng thái trực tuyến',
                      draft.showOnlineStatus,
                      (value) => _update(
                        (current) => current.copyWith(showOnlineStatus: value),
                      ),
                    ),
                    _toggle(
                      'Hiện lần truy cập gần nhất',
                      draft.showLastSeen,
                      (value) => _update(
                        (current) => current.copyWith(showLastSeen: value),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                onPressed: _saving || !_isDirty ? null : _save,
                style: profilePrimaryButtonStyle(),
                child: _saving
                    ? const CircularProgressIndicator()
                    : const Text('Lưu cài đặt quyền riêng tư'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile(
        title: Text(label),
        value: value,
        onChanged: _saving ? null : onChanged,
      );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xs),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

bool _draftEquals(PrivacySettings a, PrivacySettings b) =>
    a.discoverByUsername == b.discoverByUsername &&
    a.discoverByQr == b.discoverByQr &&
    a.discoverByEmail == b.discoverByEmail &&
    a.discoverByPhone == b.discoverByPhone &&
    a.dmPolicy == b.dmPolicy &&
    a.friendRequestPolicy == b.friendRequestPolicy &&
    a.showOnlineStatus == b.showOnlineStatus &&
    a.showLastSeen == b.showLastSeen;
