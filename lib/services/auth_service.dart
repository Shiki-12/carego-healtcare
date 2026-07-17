import '../core/api_service.dart';
import '../core/token_store.dart';
import '../models/user_session.dart';

/// Auth pasien (doc 02, endpoint `/auth/*`).
///
/// Semua panggilan lewat [ApiService] (envelope, timeout, error Indonesia).
/// Token sesi disimpan di [TokenStore] (Keychain/Keystore, doc 08 §4) begitu
/// server membalas. Identitas final ditetapkan server (role=patient).
class AuthService {
  final ApiService api;
  final TokenStore tokens;

  const AuthService(this.api, this.tokens);

  /// POST /auth/login — masuk dengan email + kata sandi.
  Future<UserSession> login({
    required String email,
    required String password,
  }) async {
    final session = await api.post<UserSession>(
      '/auth/login',
      body: {'email': email, 'password': password},
      parse: _parse,
    );
    await _persist(session);
    return session;
  }

  /// POST /auth/register — daftar langsung (tanpa OTP).
  Future<UserSession> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final session = await api.post<UserSession>(
      '/auth/register',
      body: {'name': name, 'email': email, 'password': password},
      parse: _parse,
    );
    await _persist(session);
    return session;
  }

  /// POST /auth/send-otp — kirim OTP untuk login tanpa sandi (doc 02 §4).
  Future<void> sendOtp({
    required String identifier,
    String method = 'whatsapp',
  }) {
    return api.post<void>(
      '/auth/send-otp',
      body: {'identifier': identifier, 'method': method},
      parse: (_) {},
    );
  }

  /// POST /auth/verify-otp — verifikasi OTP; auto-buat akun bila belum ada.
  Future<UserSession> verifyOtp({
    required String identifier,
    required String code,
  }) async {
    final session = await api.post<UserSession>(
      '/auth/verify-otp',
      body: {'identifier': identifier, 'code': code},
      parse: _parse,
    );
    await _persist(session);
    return session;
  }

  /// GET /auth/me — validasi token → user (dipakai saat app start).
  /// Mengembalikan null bila sesi tidak valid (bukan melempar).
  Future<UserSession?> me() async {
    final token = await tokens.readSession();
    if (token == null) return null;
    try {
      return await api.get<UserSession>('/auth/me', parse: _parse);
    } on ApiException {
      // 401 sudah dibersihkan ApiService; sesi lain gagal → anggap belum login.
      return null;
    }
  }

  /// POST /auth/logout — hapus sesi server + lokal.
  Future<void> logout() async {
    try {
      await api.post<void>('/auth/logout', parse: (_) {});
    } on ApiException {
      // Abaikan error server; yang penting sesi lokal bersih.
    }
    await tokens.clear();
  }

  UserSession _parse(dynamic data) =>
      UserSession.fromJson((data as Map).cast<String, dynamic>());

  Future<void> _persist(UserSession session) async {
    if (session.token.isNotEmpty) {
      await tokens.writeSession(session.token);
    }
  }
}
