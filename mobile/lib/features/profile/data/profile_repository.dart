import 'dart:typed_data';

import '../../auth/data/models/auth_models.dart';
import '../../media/data/media_upload_service.dart';
import 'profile_api.dart';
import 'profile_models.dart';

class ProfileRepository {
  final ProfileApi api;
  final MediaUploadService? mediaUploadService;

  ProfileRepository({required this.api, this.mediaUploadService});

  Future<String> uploadAvatar({
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) {
    final uploader = mediaUploadService;
    if (uploader == null) throw StateError('Media upload is not configured');
    return uploader.uploadImage(
      category: 'AVATAR',
      fileName: fileName,
      contentType: contentType,
      bytes: Uint8List.fromList(bytes),
    );
  }

  Future<CurrentUser> updateProfile(UpdateProfileRequest request) async {
    await api.updateProfile(request);
    return api.getCurrentUser();
  }

  Future<CurrentUser> updateUsername(UpdateUsernameRequest request) =>
      api.updateUsername(request);

  Future<PublicUserProfile> getPublicProfile(String userId) =>
      api.getPublicProfile(userId);
}
