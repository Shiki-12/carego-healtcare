import 'package:flutter/material.dart';

import '../constants.dart';
import '../core/api_service.dart';
import '../core/service_locator.dart';
import '../model.dart/transaction_model.dart';
import 'state_views.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  ViewState _state = ViewState.loading;
  int _balance = 0;
  List<TransactionModel> _transactions = [];
  String _errorMessage = 'Gagal memuat saldo.';

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet({bool showLoading = true}) async {
    if (showLoading) setState(() => _state = ViewState.loading);
    try {
      final results = await Future.wait<dynamic>([
        Services.I.wallet.balance(),
        Services.I.wallet.transactions(limit: 100),
      ]);
      final transactions = (results[1] as List<TransactionModel>)
        ..sort((a, b) => b.date.compareTo(a.date));
      if (!mounted) return;
      setState(() {
        _balance = results[0] as int;
        _transactions = transactions;
        _state = ViewState.data;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _state = ViewState.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Terjadi kesalahan saat memuat saldo.';
        _state = ViewState.error;
      });
    }
  }

  String _formatRupiah(int amount) {
    final text = amount.toString();
    final buffer = StringBuffer();
    var count = 0;
    for (var i = text.length - 1; i >= 0; i--) {
      buffer.write(text[i]);
      count++;
      if (count % 3 == 0 && i != 0) buffer.write('.');
    }
    return 'Rp ${buffer.toString().split('').reversed.join()}';
  }

  String _formatDate(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) return '-';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day} ${months[date.month - 1]} ${date.year}, $hour:$minute';
  }

  void _showTopUpPending() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Isi Saldo Belum Tersedia'),
          content: const Text(
            'Fitur isi saldo menunggu integrasi pembayaran backend. Saldo dan transaksi tetap ditetapkan oleh server.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: kHardTextColor,
        title: const Text(
          'Saldo & Pembayaran',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case ViewState.loading:
        return const LoadingView();
      case ViewState.error:
        return ErrorView(message: _errorMessage, onRetry: _loadWallet);
      case ViewState.empty:
      case ViewState.data:
        return RefreshIndicator(
          color: const Color(0xff0D9488),
          onRefresh: _loadWallet,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _BalanceCard(
                balanceLabel: _formatRupiah(_balance),
                onTopUp: _showTopUpPending,
              ),
              const SizedBox(height: 24),
              const Text(
                'Riwayat Transaksi',
                style: TextStyle(
                  color: kHardTextColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              if (_transactions.isEmpty)
                const _TransactionEmptyState()
              else
                ..._transactions.map((transaction) {
                  return _TransactionTile(
                    transaction: transaction,
                    amountLabel:
                        '${transaction.isCredit ? '+' : '-'}${_formatRupiah(transaction.amount)}',
                    dateLabel: _formatDate(transaction.date),
                  );
                }),
            ],
          ),
        );
    }
  }
}

class _BalanceCard extends StatelessWidget {
  final String balanceLabel;
  final VoidCallback onTopUp;

  const _BalanceCard({
    required this.balanceLabel,
    required this.onTopUp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff0D9488), Color(0xff14B8A6)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 6),
            color: const Color(0xff0D9488).withValues(alpha: 0.28),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Carego Wallet',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            balanceLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onTopUp,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xff0D9488),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Isi Saldo',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final String amountLabel;
  final String dateLabel;

  const _TransactionTile({
    required this.transaction,
    required this.amountLabel,
    required this.dateLabel,
  });

  @override
  Widget build(BuildContext context) {
    final color = transaction.isCredit
        ? const Color(0xff10B981)
        : Colors.red[600]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            offset: const Offset(0, 2),
            color: Colors.black.withValues(alpha: 0.05),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            transaction.isCredit ? Icons.add_circle : Icons.remove_circle,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: const TextStyle(
                    color: kHardTextColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  dateLabel,
                  style: TextStyle(
                    color: Colors.blueGrey[400],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amountLabel,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionEmptyState extends StatelessWidget {
  const _TransactionEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            offset: const Offset(0, 2),
            color: Colors.black.withValues(alpha: 0.05),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.receipt_long, color: Colors.blueGrey[300]),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Belum ada transaksi.',
              style: TextStyle(
                color: kHardTextColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
