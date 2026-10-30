import '../../profile/data/profile_models.dart';
import 'personal_qr.dart';
import 'personal_qr_api.dart';

class PersonalQrRepository {
  final PersonalQrApi api;

  PersonalQrRepository({required this.api});

  Future<PersonalQr> getPersonalQr() => api.getPersonalQr();

  Future<PublicUserProfile> resolveQr(String deepLink) =>
      api.resolveQr(deepLink);
}
