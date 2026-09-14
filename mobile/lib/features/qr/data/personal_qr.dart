class PersonalQr {
  final String deepLink;

  const PersonalQr({required this.deepLink});

  factory PersonalQr.fromJson(Map<String, dynamic> json) {
    final deepLink = json['deepLink'];
    if (deepLink is! String || deepLink.isEmpty) {
      throw const FormatException('Expected non-empty deepLink');
    }
    return PersonalQr(deepLink: deepLink);
  }
}
