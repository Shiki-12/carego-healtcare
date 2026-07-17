class TransactionModel {
  final int id;
  final String title;
  final int amount;
  final bool isCredit;
  final DateTime date;

  const TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.isCredit,
    required this.date,
  });

  /// Forward-compatible (doc 01 §11). Nilai integer Rupiah (doc 01 §3);
  /// jenis debit/kredit ditetapkan backend (doc 07 §7).
  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] ?? '').toString().toLowerCase();
    final isCredit = json['isCredit'] is bool
        ? json['isCredit'] as bool
        : (type == 'credit' || type == 'topup' || type == 'top_up');
    return TransactionModel(
      id: _asInt(json['id']),
      title: (json['title'] ?? json['description'] ?? '-').toString(),
      amount: _asInt(json['amount']),
      isCredit: isCredit,
      date: _asDate(json['createdAt'] ?? json['created_at'] ?? json['date']),
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
