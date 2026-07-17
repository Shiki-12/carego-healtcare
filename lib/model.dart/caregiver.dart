class Caregiver {
  final int id;
  final String name;
  final String specialization;
  final int experienceYears;
  final int hourlyRate;
  final double rating;
  final int reviews;
  final String photoUrl;
  final bool isAvailable;
  final String bio;

  Caregiver({
    required this.id,
    required this.name,
    required this.specialization,
    required this.experienceYears,
    required this.hourlyRate,
    required this.rating,
    required this.reviews,
    required this.photoUrl,
    required this.isAvailable,
    required this.bio,
  });

  /// Forward-compatible (doc 01 §11): abaikan field tak dikenal, toleran tipe
  /// & penamaan camelCase/snake_case. Sumber kebenaran: backend.
  factory Caregiver.fromJson(Map<String, dynamic> json) {
    return Caregiver(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      specialization:
          (json['specialization'] ?? json['specialty'] ?? '-').toString(),
      experienceYears:
          _asInt(json['experienceYears'] ?? json['experience_years']),
      hourlyRate: _asInt(json['hourlyRate'] ?? json['hourly_rate']),
      rating: _asDouble(json['rating']),
      reviews: _asInt(json['reviews'] ?? json['review_count']),
      photoUrl: (json['photoUrl'] ?? json['photo_url'] ?? '').toString(),
      isAvailable: _asBool(json['isAvailable'] ?? json['is_available'] ?? true),
      bio: (json['bio'] ?? '').toString(),
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  static bool _asBool(dynamic v) {
    if (v is bool) return v;
    final s = v?.toString().toLowerCase();
    return s == 'true' || s == '1';
  }
}
