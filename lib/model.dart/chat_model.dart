class Conversation {
  final int id;
  final String participantName;
  final String participantRole;
  final String participantPhotoUrl;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;

  const Conversation({
    required this.id,
    required this.participantName,
    required this.participantRole,
    required this.participantPhotoUrl,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
  });

  /// Forward-compatible (doc 01 §11, doc 04 §3). Nama lawan bicara diresolusi
  /// server sesuai peran pembaca; client hanya menampilkan.
  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: _asInt(json['id']),
      participantName: (json['participantName'] ??
              json['participant_name'] ??
              json['name'] ??
              'Percakapan')
          .toString(),
      participantRole:
          (json['participantRole'] ?? json['participant_role'] ?? '')
              .toString(),
      participantPhotoUrl: (json['participantPhotoUrl'] ??
              json['participant_photo_url'] ??
              json['photoUrl'] ??
              json['photo_url'] ??
              json['imageUrl'] ??
              json['image_url'] ??
              '')
          .toString(),
      lastMessage:
          (json['lastMessage'] ?? json['last_message'] ?? '').toString(),
      lastMessageTime: _asDate(
          json['lastMessageAt'] ?? json['last_message_at'] ?? json['createdAt']),
      unreadCount: _asInt(json['unreadCount'] ?? json['unread_count']),
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

/// Status kirim pesan (doc 04 §2): optimistic 'sending'/'failed' di client,
/// 'sent'/'delivered'/'read' dari server.
enum MessageStatus { sending, sent, delivered, read, failed }

class Message {
  final int id;
  final String text;
  final bool isSentByMe;
  final DateTime timestamp;
  final bool isRead;

  /// Idempotency dari client (doc 04 §5) — cocokkan pesan optimistik dengan
  /// versi server saat balasan tiba.
  final String? clientMsgId;
  final MessageStatus status;

  const Message({
    required this.id,
    required this.text,
    required this.isSentByMe,
    required this.timestamp,
    required this.isRead,
    this.clientMsgId,
    this.status = MessageStatus.sent,
  });

  /// [currentUserId] menentukan `isSentByMe` dari `sender_id` (doc 04 §2).
  factory Message.fromJson(Map<String, dynamic> json, {int? currentUserId}) {
    final senderId = _asInt(json['senderId'] ?? json['sender_id']);
    final statusWire = (json['status'] ?? 'sent').toString();
    final explicitMine = json['isSentByMe'] ??
        json['is_sent_by_me'] ??
        json['isMine'] ??
        json['is_mine'];
    return Message(
      id: _asInt(json['id']),
      text: (json['body'] ?? json['text'] ?? '').toString(),
      isSentByMe: explicitMine != null
          ? _asBool(explicitMine)
          : currentUserId != null && senderId == currentUserId,
      timestamp: _asDate(json['createdAt'] ?? json['created_at']),
      isRead: statusWire == 'read',
      clientMsgId: (json['clientMsgId'] ?? json['client_msg_id'])?.toString(),
      status: _statusFromWire(statusWire),
    );
  }

  Message copyWith({
    int? id,
    bool? isRead,
    bool? isSentByMe,
    MessageStatus? status,
  }) {
    return Message(
      id: id ?? this.id,
      text: text,
      isSentByMe: isSentByMe ?? this.isSentByMe,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      clientMsgId: clientMsgId,
      status: status ?? this.status,
    );
  }

  static MessageStatus _statusFromWire(String s) {
    switch (s) {
      case 'delivered':
        return MessageStatus.delivered;
      case 'read':
        return MessageStatus.read;
      case 'sending':
        return MessageStatus.sending;
      case 'failed':
        return MessageStatus.failed;
      default:
        return MessageStatus.sent;
    }
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static bool _asBool(dynamic v) {
    if (v is bool) return v;
    final s = v?.toString().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }

  static DateTime _asDate(dynamic v) {
    if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.tryParse(v.toString())?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }
}
