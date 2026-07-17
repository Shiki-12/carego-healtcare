/// Sesi pasien hasil auth (doc 02 §3): token + identitas user.
///
/// Parsing forward-compatible (doc 01 §11): toleran envelope produksi
/// (`{token, user:{...}}`) maupun bentuk v0 (`{token, user:{...}}` flat).
class UserSession {
  final String token;
  final int userId;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final String? photoUrl;

  const UserSession({
    required this.token,
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.photoUrl,
  });

  factory UserSession.fromJson(Map<String, dynamic> json) {
    // user bisa nested di 'user' atau berada di root.
    final user = (json['user'] is Map)
        ? (json['user'] as Map).cast<String, dynamic>()
        : json;
    return UserSession(
      token: (json['token'] ?? json['session_token'] ?? '').toString(),
      userId: _asInt(user['id']),
      name: (user['name'] ?? '').toString(),
      email: (user['email'] ?? '').toString(),
      role: (user['role'] ?? 'patient').toString(),
      phone: user['phone']?.toString(),
      photoUrl: (user['photoUrl'] ?? user['photo_url'])?.toString(),
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}
