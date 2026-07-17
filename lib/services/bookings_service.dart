import '../core/api_service.dart';
import '../models/booking.dart';

/// Pesanan pasien (doc 07 §2-4, endpoint doc 01 §4).
///
/// Semua panggilan lewat [ApiService]. Status & harga ditetapkan backend —
/// service ini tidak menghitung apa pun sendiri (doc 00 §6, doc 07 §4).
class BookingsService {
  final ApiService api;

  const BookingsService(this.api);

  /// GET /bookings — daftar pesanan milik pasien (difilter server berdasarkan
  /// token, doc 07 §2). Grup tab via [statusGroup]: 'active' | 'completed' |
  /// 'cancelled'. Terbungkus paginasi (doc 01 §7).
  Future<Paginated<Booking>> list({
    String? statusGroup,
    int limit = 20,
    int offset = 0,
  }) {
    final query = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      if (statusGroup != null) 'status': statusGroup,
    };
    final qs = query.entries.map((e) => '${e.key}=${e.value}').join('&');
    return api.get<Paginated<Booking>>(
      '/bookings?$qs',
      parse: (data) => Paginated.fromJson(data, Booking.fromJson),
    );
  }

  /// GET /bookings/:id — detail satu pesanan (otorisasi objek server-side).
  Future<Booking> detail(int id) {
    return api.get<Booking>(
      '/bookings/$id',
      parse: (data) => Booking.fromJson((data as Map).cast<String, dynamic>()),
    );
  }

  /// POST /bookings — buat pesanan baru (doc 07 §4). Harga FINAL dihitung
  /// backend; client hanya mengirim parameter layanan + [idempotencyKey]
  /// (doc 01 §8) agar retry/double-tap tak menggandakan.
  Future<Booking> create({
    required Map<String, dynamic> payload,
    required String idempotencyKey,
  }) {
    return api.post<Booking>(
      '/bookings',
      body: payload,
      headers: {'Idempotency-Key': idempotencyKey},
      parse: (data) => Booking.fromJson((data as Map).cast<String, dynamic>()),
    );
  }

  /// POST /bookings/:id/cancel — batalkan pesanan (backend menegakkan transisi
  /// legal, doc 01 §6).
  Future<Booking> cancel(int id, {String? reason}) {
    return api.post<Booking>(
      '/bookings/$id/cancel',
      body: {if (reason != null) 'reason': reason},
      parse: (data) => Booking.fromJson((data as Map).cast<String, dynamic>()),
    );
  }
}
