import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/api_service.dart';
import '../core/env.dart';
import '../model.dart/chat_model.dart';
import '../models/booking.dart' show Paginated;

/// Layanan chat pasien (doc 04). **DB = sumber kebenaran** (REST); WebSocket
/// hanya transport cepat (doc 04 §1). Kirim pesan lewat REST dengan
/// `clientMsgId` untuk idempotency (doc 04 §5); WS untuk notify + typing + read.
///
/// Pola koneksi seragam (doc 08 §6): ticket → connect WS → reconnect 3 dtk →
/// tarik pesan terlewat via REST.
class ChatService {
  final ApiService api;

  ChatService(this.api);

  WebSocketChannel? _ch;
  StreamSubscription? _sub;
  bool _disposed = false;

  /// Event masuk dari WS (pesan baru / read receipt) untuk konsumsi UI.
  final _events = StreamController<ChatEvent>.broadcast();
  Stream<ChatEvent> get events => _events.stream;

  // ---- REST (sumber kebenaran) ----

  /// GET /chat/conversations — daftar percakapan user.
  Future<List<Conversation>> conversations({int limit = 30, int offset = 0}) {
    return api.get<List<Conversation>>(
      '/chat/conversations?limit=$limit&offset=$offset',
      parse: (data) => Paginated.fromJson(data, Conversation.fromJson).items,
    );
  }

  /// GET /chat/conversations/:id/messages — riwayat pesan (paginasi ke belakang).
  Future<List<Message>> messages(
    int conversationId, {
    int? currentUserId,
    int limit = 30,
    int? before,
  }) {
    final q = StringBuffer('?limit=$limit');
    if (before != null) q.write('&before=$before');
    return api.get<List<Message>>(
      '/chat/conversations/$conversationId/messages$q',
      parse: (data) => Paginated.fromJson(
        data,
        (m) => Message.fromJson(m, currentUserId: currentUserId),
      ).items,
    );
  }

  /// POST /chat/conversations/:id/messages — kirim pesan (idempoten via
  /// [clientMsgId], doc 04 §5). Mengembalikan pesan versi server.
  Future<Message> send(
    int conversationId, {
    required String body,
    required String clientMsgId,
    int? currentUserId,
  }) {
    return api.post<Message>(
      '/chat/conversations/$conversationId/messages',
      body: {'type': 'text', 'body': body, 'clientMsgId': clientMsgId},
      parse: (data) => Message.fromJson(
        (data as Map).cast<String, dynamic>(),
        currentUserId: currentUserId,
      ),
    );
  }

  /// POST /chat/conversations/:id/read — tandai terbaca s/d pesan terakhir.
  Future<void> markRead(int conversationId) {
    return api.post<void>(
      '/chat/conversations/$conversationId/read',
      parse: (_) {},
    );
  }

  // ---- WebSocket (transport cepat) ----

  /// Buka koneksi WS via ticket sekali-pakai (doc 03 §4.3, doc 04 §4). Token
  /// utama TIDAK pernah di query string.
  Future<void> connect() async {
    if (_disposed) return;
    try {
      final ticket = await api.post<String>(
        '/realtime/ticket',
        parse: (data) => (data is Map ? data['ticket'] : data).toString(),
      );
      _ch = WebSocketChannel.connect(
        Uri.parse('${Env.wsBase}/chat/ws?ticket=$ticket'),
      );
      _events.add(const ChatEvent.connected());
      _sub = _ch!.stream.listen(
        _onData,
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
      );
    } catch (_) {
      // Gagal ambil ticket / connect → jadwalkan reconnect, jangan diam.
      _scheduleReconnect();
    }
  }

  void _onData(dynamic raw) {
    try {
      final json = jsonDecode(raw.toString()) as Map<String, dynamic>;
      final kind = (json['kind'] ?? json['type'] ?? '').toString();
      if (kind == 'message') {
        _events.add(ChatEvent.message(
          conversationId: _asInt(json['conversationId']),
        ));
      } else if (kind == 'read') {
        _events.add(ChatEvent.read(
          conversationId: _asInt(json['conversationId']),
        ));
      }
    } catch (_) {
      // Frame tak dikenal → abaikan (forward-compatible, doc 01 §11).
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _events.add(const ChatEvent.reconnecting());
    _sub?.cancel();
    _sub = null;
    _ch = null;
    Future.delayed(const Duration(seconds: 3), () {
      if (!_disposed) connect();
    });
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _ch?.sink.close();
    _events.close();
  }
}

/// Event realtime chat untuk UI (doc 04 §4).
class ChatEvent {
  final ChatEventKind kind;
  final int? conversationId;

  const ChatEvent._(this.kind, {this.conversationId});

  const ChatEvent.connected() : this._(ChatEventKind.connected);
  const ChatEvent.reconnecting() : this._(ChatEventKind.reconnecting);
  const ChatEvent.message({required int conversationId})
      : this._(ChatEventKind.message, conversationId: conversationId);
  const ChatEvent.read({required int conversationId})
      : this._(ChatEventKind.read, conversationId: conversationId);
}

enum ChatEventKind { connected, reconnecting, message, read }
