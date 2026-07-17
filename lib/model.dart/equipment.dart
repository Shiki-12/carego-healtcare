class Equipment {
  final int id;
  final String name;
  final String category;
  final String description;
  final Map<String, String> specifications;
  final int dailyRate;
  final int weeklyRate;
  final int deposit;
  final int stock;
  final List<String> images;
  final bool isAvailable;

  const Equipment({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.specifications,
    required this.dailyRate,
    required this.weeklyRate,
    required this.deposit,
    required this.stock,
    required this.images,
    required this.isAvailable,
  });

  /// Forward-compatible (doc 01 §11): abaikan field tak dikenal, toleran tipe
  /// & penamaan camelCase/snake_case. Harga & stok dari backend (doc 01 §3).
  factory Equipment.fromJson(Map<String, dynamic> json) {
    final rawSpecs = json['specifications'];
    final specs = <String, String>{};
    if (rawSpecs is Map) {
      rawSpecs.forEach((k, v) => specs[k.toString()] = v.toString());
    }
    final rawImages = json['images'];
    final images = <String>[
      if (rawImages is List) ...rawImages.map((e) => e.toString()),
    ];
    return Equipment(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      category: (json['category'] ?? 'other').toString(),
      description: (json['description'] ?? '').toString(),
      specifications: specs,
      dailyRate: _asInt(json['dailyRate'] ?? json['daily_rate']),
      weeklyRate: _asInt(json['weeklyRate'] ?? json['weekly_rate']),
      deposit: _asInt(json['deposit']),
      stock: _asInt(json['stock'] ?? json['stock_count']),
      images: images,
      isAvailable: _asBool(json['isAvailable'] ?? json['is_available'] ?? true),
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static bool _asBool(dynamic v) {
    if (v is bool) return v;
    final s = v?.toString().toLowerCase();
    return s == 'true' || s == '1';
  }
}
