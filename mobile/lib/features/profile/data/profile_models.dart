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
