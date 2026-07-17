import '../core/api_service.dart';
import '../model.dart/caregiver.dart';
import '../model.dart/equipment.dart';
import '../models/booking.dart' show Paginated;

/// Katalog layanan pasien (doc 07 §8): daftar caregiver & alat rental.
///
/// Read-only dari sudut pandang pasien; sumber kebenaran backend. Harga & stok
/// dari server (doc 01 §3).
class CatalogService {
  final ApiService api;

  const CatalogService(this.api);

  /// GET /caregivers — daftar caregiver tersedia.
  Future<List<Caregiver>> caregivers({int limit = 50, int offset = 0}) {
    return api.get<List<Caregiver>>(
      '/caregivers?limit=$limit&offset=$offset',
      parse: (data) => Paginated.fromJson(data, Caregiver.fromJson).items,
    );
  }

  /// GET /caregivers/:id — detail caregiver.
  Future<Caregiver> caregiverDetail(int id) {
    return api.get<Caregiver>(
      '/caregivers/$id',
      parse: (data) => Caregiver.fromJson((data as Map).cast<String, dynamic>()),
    );
  }

  /// GET /rental/items — katalog alat medis.
  Future<List<Equipment>> equipment({int limit = 50, int offset = 0}) {
    return api.get<List<Equipment>>(
      '/rental/items?limit=$limit&offset=$offset',
      parse: (data) => Paginated.fromJson(data, Equipment.fromJson).items,
    );
  }

  /// GET /rental/items/:id — detail alat.
  Future<Equipment> equipmentDetail(int id) {
    return api.get<Equipment>(
      '/rental/items/$id',
      parse: (data) => Equipment.fromJson((data as Map).cast<String, dynamic>()),
    );
  }
}
