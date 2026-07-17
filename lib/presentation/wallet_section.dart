import 'package:flutter/material.dart';

import '../constants.dart';
import '../core/service_locator.dart';
import '../size_confige.dart';
import 'wallet_screen.dart';

class WalletSection extends StatefulWidget {
  const WalletSection({
    Key? key,
  }) : super(key: key);

  @override
  State<WalletSection> createState() => _WalletSectionState();
}

class _WalletSectionState extends State<WalletSection> {
  int? _balance;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      final balance = await Services.I.wallet.balance();
      if (!mounted) return;
      setState(() {
        _balance = balance;
        _isLoading = false;
        _hasError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
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

  String get _balanceLabel {
    if (_isLoading) return 'Memuat...';
    if (_hasError) return 'Saldo belum tersedia';
    return _formatRupiah(_balance ?? 0);
  }

  void _openWallet() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WalletScreen()),
    ).then((_) {
      if (mounted) _loadBalance();
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _openWallet,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: getRelativeWidth(0.84),
        padding: EdgeInsets.fromLTRB(
          getRelativeWidth(0.035),
          getRelativeHeight(0.012),
          getRelativeWidth(0.035),
          getRelativeHeight(0.012),
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              offset: const Offset(0, 10),
              color: const Color(0xff158A55).withValues(alpha: 0.16),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: getRelativeWidth(-0.02),
              top: getRelativeHeight(-0.018),
              child: _DotPattern(),
            ),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(getRelativeWidth(0.019)),
                  decoration: const BoxDecoration(
                    color: Color(0xff10B981),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white,
                    size: getRelativeWidth(0.046),
                  ),
                ),
                SizedBox(width: getRelativeWidth(0.025)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Carego Wallet',
                        style: TextStyle(
                          color: kHardTextColor,
                          fontWeight: FontWeight.w800,
                          fontSize: getRelativeWidth(0.034),
                        ),
                      ),
                      SizedBox(height: getRelativeHeight(0.002)),
                      Text(
                        _balanceLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xff163B2A),
                          fontWeight: FontWeight.w900,
                          fontSize: _hasError
                              ? getRelativeWidth(0.034)
                              : getRelativeWidth(0.05),
                        ),
                      ),
                      SizedBox(height: getRelativeHeight(0.002)),
                      Row(
                        children: [
                          Icon(
                            Icons.verified_user,
                            color:
                                const Color(0xff158A55).withValues(alpha: 0.7),
                            size: getRelativeWidth(0.032),
                          ),
                          SizedBox(width: getRelativeWidth(0.008)),
                          Expanded(
                            child: Text(
                              'Pembayaran Aman',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.black.withValues(alpha: 0.45),
                                fontWeight: FontWeight.w700,
                                fontSize: getRelativeWidth(0.026),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: getRelativeWidth(0.02)),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xff34D399),
                        Color(0xff059669),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 14,
                        offset: const Offset(0, 7),
                        color: const Color(0xff059669).withValues(alpha: 0.24),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: getRelativeWidth(0.028),
                      vertical: getRelativeHeight(0.011),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_circle,
                          color: Colors.white,
                          size: getRelativeWidth(0.036),
                        ),
                        SizedBox(width: getRelativeWidth(0.01)),
                        Flexible(
                          child: Text(
                            'Isi Saldo',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: getRelativeWidth(0.032),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DotPattern extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (row) => Row(
          children: List.generate(
            5,
            (column) => Container(
              width: getRelativeWidth(0.01),
              height: getRelativeWidth(0.01),
              margin: EdgeInsets.all(getRelativeWidth(0.005)),
              decoration: BoxDecoration(
                color: const Color(0xff10B981).withValues(
                  alpha: 0.12 + (row * 0.03),
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
