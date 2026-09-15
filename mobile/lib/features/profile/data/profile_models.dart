class UpdateProfileRequest {
  final String? displayName;
  final String? bio;
  final String? phone;
  final String? avatarStorageKey;

  const UpdateProfileRequest({
    this.displayName,
    this.bio,
    this.phone,
    this.avatarStorageKey,
  });

  Map<String, dynamic> toJson() => {
    if (displayName != null) 'displayName': displayName,
    if (bio != null) 'bio': bio,
    if (phone != null) 'phone': phone,
    if (avatarStorageKey != null) 'avatarStorageKey': avatarStorageKey,
  };
}

class UpdateUsernameRequest {
  final String username;

  const UpdateUsernameRequest({required this.username});

  Map<String, dynamic> toJson() => {'username': username};
}

/// Deliberately narrow client boundary for another user's M3 public profile.
class PublicUserProfile {
  final String id;
  final String username;
  final String? displayName;
  final String? avatarStorageKey;
  final String? bio;

  const PublicUserProfile({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarStorageKey,
    this.bio,
  });

  factory PublicUserProfile.fromJson(Map<String, dynamic> json) {
    String requiredString(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty) {
        throw FormatException('Expected non-empty $key');
      }
      return value;
    }

    String? nullableString(String key) {
      final value = json[key];
      if (value == null) {
        return null;
      }
      if (value is! String) {
        throw FormatException('Expected nullable string $key');
      }
      return value;
    }

    return PublicUserProfile(
      id: requiredString('id'),
      username: requiredString('username'),
      displayName: nullableString('displayName'),
      avatarStorageKey: nullableString('avatarStorageKey'),
      bio: nullableString('bio'),
    );
  }
}
