import 'package:flutter/widgets.dart';

import 'api_service.dart';
import 'env.dart';
import 'token_store.dart';
import '../services/auth_service.dart';
import '../services/bookings_service.dart';
import '../services/catalog_service.dart';
import '../services/chat_service.dart';
import '../services/notifications_service.dart';
import '../services/wallet_service.dart';

/// Composition root sederhana (doc 08 §9) — satu instance [ApiService]
/// dipakai seragam semua layar/service, tanpa dependency injection berat
/// (pola setState prototipe dipertahankan, ADR-005).
class Services {
  Services._();
  static final Services I = Services._();

  /// Navigator global agar 401 dari mana pun mengarahkan ke login tanpa akses
  /// [BuildContext] di lapisan service (doc 08 §2).
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Diisi root app: cara kembali ke layar login setelah sesi habis.
  void Function()? onSessionExpired;

  final TokenStore tokens = const TokenStore();

  late final ApiService api = ApiService(
    baseUrl: Env.apiBase,
    tokens: tokens,
    onUnauthenticated: _handleUnauthenticated,
  );

  late final AuthService auth = AuthService(api, tokens);
  late final BookingsService bookings = BookingsService(api);
  late final CatalogService catalog = CatalogService(api);
  late final NotificationsService notifications = NotificationsService(api);
  late final WalletService wallet = WalletService(api);

  /// Chat memegang koneksi WS; buat baru bila dibutuhkan layar chat.
  ChatService newChatService() => ChatService(api);

  /// Callback saat 401 (token invalid/kedaluwarsa): sesi sudah dibersihkan
  /// [ApiService]; arahkan ke login (doc 02 §3).
  Future<void> _handleUnauthenticated() async {
    onSessionExpired?.call();
  }
}
