import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/api_service.dart';
import '../core/env.dart';

/// Konsumsi lokasi driver ambulans oleh pasien (doc 03 §5).
/// Kelas **Kritikal-nyawa**: reconnect + tandai "sinyal hilang"/"usang",
/// JANGAN diam seolah masih live (doc 03 §5).
///
/// Pola: ticket → WS `/realtime/track/:bookingId` → reconnect 3 dtk. Hanya
/// booking milik pasien yang aktif (`accepted/on_the_way/in_progress`) yang
/// menyiarkan lokasi (otorisasi server, doc 03 §2).
class TrackingService {
  final ApiService api;
  final int bookingId;

  TrackingService(this.api, this.bookingId);

  WebSocketChannel? _ch;
  StreamSubscription? _sub;
  bool _disposed = false;

  final _events = StreamController<TrackEvent>.broadcast();
  Stream<TrackEvent> get events => _events.stream;

  Future<void> connect() async {
    if (_disposed) return;
    try {
      final ticket = await api.post<String>(
        '/realtime/ticket',
        parse: (data) => (data is Map ? data['ticket'] : data).toString(),
      );
      _ch = WebSocketChannel.connect(
        Uri.parse('${Env.wsBase}/realtime/track/$bookingId?ticket=$ticket'),
      );
      _events.add(const TrackEvent.connected());
      _sub = _ch!.stream.listen(
        _onData,
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onData(dynamic raw) {
    try {
      final json = jsonDecode(raw.toString()) as Map<String, dynamic>;
      final lat = _asDouble(json['lat']);
      final lng = _asDouble(json['lng']);
      _events.add(TrackEvent.location(
        lat: lat,
        lng: lng,
        heading: _asDouble(json['heading']),
        etaMinutes: json['etaMinutes'] == null
            ? null
            : _asDouble(json['etaMinutes']),
      ));
    } catch (_) {
      // Frame tak dikenal → abaikan (forward-compatible).
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _events.add(const TrackEvent.signalLost());
    _sub?.cancel();
    _sub = null;
    _ch = null;
    Future.delayed(const Duration(seconds: 3), () {
      if (!_disposed) connect();
    });
  }

  static double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _ch?.sink.close();
    _events.close();
  }
}

/// Event tracking untuk UI peta (doc 03 §5).
class TrackEvent {
  final TrackEventKind kind;
  final double? lat;
  final double? lng;
  final double? heading;
  final double? etaMinutes;

  const TrackEvent._(
    this.kind, {
    this.lat,
    this.lng,
    this.heading,
    this.etaMinutes,
  });

  const TrackEvent.connected() : this._(TrackEventKind.connected);
  const TrackEvent.signalLost() : this._(TrackEventKind.signalLost);
  const TrackEvent.location({
    required double lat,
    required double lng,
    double? heading,
    double? etaMinutes,
  }) : this._(
          TrackEventKind.location,
          lat: lat,
          lng: lng,
          heading: heading,
          etaMinutes: etaMinutes,
        );
}

enum TrackEventKind { connected, signalLost, location }
