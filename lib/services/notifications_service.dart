import '../core/api_service.dart';
import '../model.dart/notification_model.dart';
import '../models/booking.dart' show Paginated;

/// Notifikasi in-app pasien (doc 05). List & badge SELALU dari DB via REST,
/// bukan akumulasi push (push bisa terlewat — doc 05 §5).
class NotificationsService {
  final ApiService api;

  const NotificationsService(this.api);

  /// GET /notifications — daftar notifikasi (dari DB, sumber kebenaran).
  Future<List<NotificationItem>> list({int limit = 30, int offset = 0}) {
    return api.get<List<NotificationItem>>(
      '/notifications?limit=$limit&offset=$offset',
      parse: (data) =>
          Paginated.fromJson(data, NotificationItem.fromJson).items,
    );
  }

  /// POST /notifications/read-all — tandai semua terbaca.
  Future<void> markAllRead() {
    return api.post<void>('/notifications/read-all', parse: (_) {});
  }

  /// POST /notifications/:id/read — tandai satu terbaca.
  Future<void> markRead(int id) {
    return api.post<void>('/notifications/$id/read', parse: (_) {});
  }

  /// POST /notifications/devices — daftarkan/refresh FCM token (doc 05 §5).
  /// Dipanggil setelah login. Best-effort: kegagalan tidak memblok UI.
  Future<void> registerDevice({
    required String fcmToken,
    required String platform,
  }) {
    return api.post<void>(
      '/notifications/devices',
      body: {'fcmToken': fcmToken, 'platform': platform},
      parse: (_) {},
    );
  }

  /// DELETE /notifications/devices/:token — hapus saat logout (doc 05 §5).
  Future<void> unregisterDevice(String fcmToken) {
    return api.delete<void>('/notifications/devices/$fcmToken', parse: (_) {});
  }
}
