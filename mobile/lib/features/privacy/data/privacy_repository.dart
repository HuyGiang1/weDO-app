import 'privacy_api.dart';
import 'privacy_models.dart';

class PrivacyRepository {
  final PrivacyApi api;
  PrivacyRepository({required this.api});

  Future<PrivacySettings> getPrivacySettings() => api.getPrivacySettings();
  Future<PrivacySettings> updatePrivacySettings(
    UpdatePrivacySettingsRequest request,
  ) => api.updatePrivacySettings(request);
}
