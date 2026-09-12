import '../../auth/data/models/auth_models.dart';
import 'profile_api.dart';
import 'profile_models.dart';

class ProfileRepository {
  final ProfileApi api;

  ProfileRepository({required this.api});

  Future<CurrentUser> updateProfile(UpdateProfileRequest request) =>
      api.updateProfile(request);

  Future<CurrentUser> updateUsername(UpdateUsernameRequest request) =>
      api.updateUsername(request);
}
