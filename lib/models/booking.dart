import 'package:flutter/material.dart';

/// Warna Teal design system (literal, konsisten layar pasien — doc 08 §8).
const _kTeal = Color(0xff0D9488);

/// Status kanonik pesanan (doc 07 §3, state machine doc 01 §6).
///
/// Nilai string identik dengan backend (satu kontrak — doc 00 §2.1). Enum
/// ringkas pasien (SRS-06) dipetakan: label "Dikonfirmasi" = `accepted`.
/// `unknown` menampung status baru yang belum dikenal agar parsing
/// forward-compatible (doc 01 §11) — bukan crash.
enum BookingStatus {
  pending('pending', 'Menunggu'),
  accepted('accepted', 'Dikonfirmasi'),
  onTheWay('on_the_way', 'Menuju Lokasi'),
  inProgress('in_progress', 'Sedang Berlangsung'),
  completed('completed', 'Selesai'),
  cancelled('cancelled', 'Dibatalkan'),
  rejected('rejected', 'Ditolak'),
  unknown('unknown', 'Tidak diketahui');

  final String wire;
  final String label;

  const BookingStatus(this.wire, this.label);

  static BookingStatus fromWire(String? value) {
    for (final s in BookingStatus.values) {
      if (s.wire == value) return s;
    }
    return BookingStatus.unknown;
  }

  /// Grup tab pasien (doc 07 §2): Aktif / Selesai / Dibatalkan.
  /// Aktif = pending + accepted + on_the_way + in_progress (doc 01 §7).
  bool get isActive =>
      this == BookingStatus.pending ||
      this == BookingStatus.accepted ||
      this == BookingStatus.onTheWay ||
      this == BookingStatus.inProgress;

  bool get isCompleted => this == BookingStatus.completed;

  bool get isCancelled =>
      this == BookingStatus.cancelled || this == BookingStatus.rejected;

  /// Pasien boleh membatalkan hanya saat masih bisa dibatalkan
  /// (backend tetap penegak final — doc 01 §6).
  bool get isCancellable =>
      this == BookingStatus.pending ||
      this == BookingStatus.accepted ||
      this == BookingStatus.onTheWay;

  Color get color {
    switch (this) {
      case BookingStatus.completed:
        return const Color(0xff10B981);
      case BookingStatus.cancelled:
      case BookingStatus.rejected:
        return const Color(0xffE53935);
      case BookingStatus.unknown:
        return Colors.blueGrey;
      default:
        return _kTeal;
    }
  }
}

/// Satu pesanan dari sudut pandang pasien (doc 07 §2).
///
/// Sumber kebenaran: backend. Harga (integer Rupiah, doc 01 §3) & status
/// ditetapkan server; client hanya menampilkan.
class Booking {
  final int id;
  final String serviceType; // 'ambulance' | 'caregiver' | 'rental'
  final String providerName;
  final BookingStatus status;
  final int totalPrice;
  final DateTime date;
  final String pickupAddress;
  final String? destinationAddress;
  final String notes;
  final int? conversationId;

  const Booking({
    required this.id,
    required this.serviceType,
    required this.providerName,
    required this.status,
    required this.totalPrice,
    required this.date,
    required this.pickupAddress,
    this.destinationAddress,
    required this.notes,
    this.conversationId,
  });

  /// Forward-compatible: abaikan field tak dikenal, toleran tipe (doc 01 §11).
  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: _asInt(json['id']),
      serviceType: (json['serviceType'] ?? json['service_type'] ?? '-')
          .toString(),
      providerName: (json['providerName'] ??
              json['provider_name'] ??
              json['provider'] ??
              'Penyedia')
          .toString(),
      status: BookingStatus.fromWire(json['status']?.toString()),
      totalPrice: _asInt(json['totalPrice'] ?? json['total_price']),
      date: _asDate(json['scheduledAt'] ??
          json['scheduled_at'] ??
          json['createdAt'] ??
          json['created_at']),
      pickupAddress: (json['pickupAddress'] ??
              json['pickup_address'] ??
              '-')
          .toString(),
      destinationAddress:
          (json['destAddress'] ?? json['destination_address'])?.toString(),
      notes: (json['notes'] ?? '').toString(),
      conversationId: _asNullableInt(
        json['conversationId'] ?? json['conversation_id'],
      ),
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static int? _asNullableInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static DateTime _asDate(dynamic v) {
    if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.tryParse(v.toString())?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  String get serviceLabel {
    switch (serviceType) {
      case 'ambulance':
        return 'Ambulans';
      case 'caregiver':
        return 'Caregiver';
      case 'rental':
        return 'Sewa Alkes';
      default:
        return serviceType;
    }
  }

  String get serviceEmoji {
    switch (serviceType) {
      case 'ambulance':
        return '🚑';
      case 'caregiver':
        return '👥';
      default:
        return '🏥';
    }
  }

  /// Format Rupiah dari integer (doc 01 §3): 600000 → "Rp 600.000".
  String get priceLabel {
    final s = totalPrice.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp $buf';
  }
}

/// Halaman terbungkus untuk list (doc 01 §7): `items/total/limit/offset`.
/// Toleran balasan list polos (backend v0) maupun terbungkus.
class Paginated<T> {
  final List<T> items;
  final int total;
  final int limit;
  final int offset;

  const Paginated({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory Paginated.fromJson(
    dynamic data,
    T Function(Map<String, dynamic>) itemFromJson,
  ) {
    // Toleran: backend bisa balas {items:[...]} atau list polos [...].
    if (data is List) {
      final items = data
          .whereType<Map>()
          .map((e) => itemFromJson(e.cast<String, dynamic>()))
          .toList();
      return Paginated(
          items: items, total: items.length, limit: items.length, offset: 0);
    }
    final map = (data as Map?) ?? const {};
    final rawItems = (map['items'] as List?) ?? const [];
    return Paginated(
      items: rawItems
          .whereType<Map>()
          .map((e) => itemFromJson(e.cast<String, dynamic>()))
          .toList(),
      total: (map['total'] as num?)?.toInt() ?? rawItems.length,
      limit: (map['limit'] as num?)?.toInt() ?? 20,
      offset: (map['offset'] as num?)?.toInt() ?? 0,
    );
  }
}
