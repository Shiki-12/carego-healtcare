import '../core/api_service.dart';
import '../model.dart/transaction_model.dart';
import '../models/booking.dart' show Paginated;

/// Saldo & transaksi pasien (doc 07 §7). Saldo/mutasi ditetapkan backend dalam
/// transaksi; client hanya menampilkan (doc 00 §6).
class WalletService {
  final ApiService api;

  const WalletService(this.api);

  /// GET /user/balance — saldo dompet (integer Rupiah, doc 01 §3).
  Future<int> balance() {
    return api.get<int>(
      '/user/balance',
      parse: (data) {
        if (data is Map) {
          final b = data['balance'];
          if (b is num) return b.toInt();
          return int.tryParse(b?.toString() ?? '') ?? 0;
        }
        if (data is num) return data.toInt();
        return 0;
      },
    );
  }

  /// GET /user/transactions — riwayat mutasi saldo.
  Future<List<TransactionModel>> transactions({int limit = 30, int offset = 0}) {
    return api.get<List<TransactionModel>>(
      '/user/transactions?limit=$limit&offset=$offset',
      parse: (data) =>
          Paginated.fromJson(data, TransactionModel.fromJson).items,
    );
  }
}
