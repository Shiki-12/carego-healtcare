class NotificationItem {
  final int id;
  final String type;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;

  /// Deep-link payload (doc 05 §2): {bookingId, conversationId, ...}.
  final Map<String, dynamic> data;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.isRead,
    this.data = const {},
  });

  /// Forward-compatible (doc 01 §11, doc 05 §2). `read_at != null` → sudah dibaca.
  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    return NotificationItem(
      id: _asInt(json['id']),
      type: (json['category'] ?? json['type'] ?? 'system').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['body'] ?? json['message'] ?? '').toString(),
      timestamp: _asDate(json['createdAt'] ?? json['created_at']),
      isRead: (json['readAt'] ?? json['read_at']) != null ||
          json['isRead'] == true,
      data: rawData is Map ? rawData.cast<String, dynamic>() : const {},
    );
  }

  NotificationItem copyWith({
    bool? isRead,
  }) {
    return NotificationItem(
      id: id,
      type: type,
      title: title,
      message: message,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      data: data,
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static DateTime _asDate(dynamic v) {
    if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.tryParse(v.toString())?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class NotificationPreferences {
  final bool bookingUpdates;
  final bool promotions;
  final bool systemUpdates;
  final bool chatMessages;

  const NotificationPreferences({
    required this.bookingUpdates,
    required this.promotions,
    required this.systemUpdates,
    required this.chatMessages,
  });
}
