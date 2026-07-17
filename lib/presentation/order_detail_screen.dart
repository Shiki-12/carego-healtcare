import 'package:flutter/material.dart';

import '../constants.dart';
import '../core/service_locator.dart';
import '../model.dart/chat_model.dart';
import '../models/booking.dart';
import '../presentation/state_views.dart';
import 'chat_room_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final int bookingId;

  const OrderDetailScreen({
    Key? key,
    required this.bookingId,
  }) : super(key: key);

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  ViewState _state = ViewState.loading;
  Booking? _booking;
  String _errorMessage = '';
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _loadBooking();
  }

  Future<void> _loadBooking() async {
    setState(() {
      _state = ViewState.loading;
      _errorMessage = '';
    });

    try {
      final booking = await Services.I.bookings.detail(widget.bookingId);
      if (mounted) {
        setState(() {
          _booking = booking;
          _state = ViewState.data;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = ViewState.error;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  bool get _canCancel {
    return _booking?.status.isCancellable ?? false;
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
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day} ${months[date.month - 1]} ${date.year}, $hour:$minute';
  }

  String get _providerRole {
    if (_booking == null) return '';
    if (_booking!.serviceType == 'ambulance') return 'Penyedia Ambulans';
    if (_booking!.serviceType == 'caregiver') return 'Caregiver';
    return 'Penyedia Sewa Alkes';
  }

  String get _providerPhoto {
    if (_booking == null) return 'assets/images/doctor_1.png';
    if (_booking!.serviceType == 'ambulance') {
      return 'assets/images/doctor_2.png';
    }
    if (_booking!.serviceType == 'caregiver') {
      return 'assets/images/doctor_1.png';
    }
    return 'assets/images/doctor_3.png';
  }

  void _openProviderChat() {
    if (_booking == null) return;
    final conversationId = _booking!.conversationId;
    if (conversationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chat tersedia setelah percakapan dibuat oleh server.',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          conversation: Conversation(
            id: conversationId,
            participantName: _booking!.providerName,
            participantRole: _providerRole,
            participantPhotoUrl: _providerPhoto,
            lastMessage: 'Halo, saya ingin menanyakan pesanan ini.',
            lastMessageTime: DateTime.now(),
            unreadCount: 0,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmCancellation() async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Batalkan Pesanan?'),
          content: const Text(
            'Pesanan aktif akan dibatalkan. Tindakan ini tidak dapat diurungkan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Tidak'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Ya, Batalkan',
                style: TextStyle(
                  color: Colors.red[700],
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldCancel != true) return;
    await _performCancellation();
  }

  Future<void> _performCancellation() async {
    setState(() => _isCancelling = true);

    try {
      await Services.I.bookings.cancel(
        widget.bookingId,
        reason: 'Dibatalkan oleh pasien',
      );

      if (!mounted) return;
      setState(() => _isCancelling = false);
      _showCancellationSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCancelling = false);

      final message = e.toString().replaceFirst('Exception: ', '');
      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Gagal Membatalkan'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  void _showCancellationSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[600],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Pesanan berhasil dibatalkan',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: kHardTextColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kTeal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Kembali ke Pesanan',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
          'Detail Pesanan',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_state == ViewState.loading) {
      return const LoadingView();
    }

    if (_state == ViewState.error) {
      return ErrorView(
        message: _errorMessage,
        onRetry: _loadBooking,
      );
    }

    if (_booking == null) {
      return const EmptyView(
        text: 'Detail pesanan tidak ditemukan',
        icon: Icons.receipt_long,
      );
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, _canCancel ? 110 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                        color: Colors.black.withValues(alpha: 0.07),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _booking!.status.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          _booking!.serviceEmoji,
                          style: const TextStyle(fontSize: 30),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _booking!.serviceLabel,
                              style: const TextStyle(
                                color: kHardTextColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _booking!.providerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.blueGrey[500],
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _StatusBadge(
                              label: _booking!.status.label,
                              color: _booking!.status.color,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Status Pesanan',
                  child: _StatusTimeline(status: _booking!.status),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Detail Layanan',
                  child: Column(
                    children: [
                      _InfoRow('Nomor Pesanan', '#${_booking!.id}'),
                      _InfoRow('Tanggal', _formatDate(_booking!.date)),
                      _InfoRow('Penyedia', _booking!.providerName),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: _openProviderChat,
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Hubungi Penyedia'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kTeal,
                            side: const BorderSide(color: kTeal),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: _booking!.serviceType == 'ambulance'
                      ? 'Lokasi'
                      : 'Alamat Layanan',
                  child: Column(
                    children: [
                      _InfoRow('Alamat', _booking!.pickupAddress),
                      if (_booking!.destinationAddress != null)
                        _InfoRow(
                          'Tujuan',
                          _booking!.destinationAddress!,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Rincian Biaya',
                  child: Column(
                    children: [
                      _InfoRow('Subtotal', _formatRupiah(_booking!.totalPrice)),
                      const Divider(height: 20),
                      _InfoRow('Total', _formatRupiah(_booking!.totalPrice)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Catatan',
                  child: Text(
                    _booking!.notes.isEmpty ? '-' : _booking!.notes,
                    style: TextStyle(
                      color: Colors.blueGrey[600],
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_canCancel)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                  color: Colors.black.withValues(alpha: 0.08),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isCancelling ? null : _confirmCancellation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    disabledBackgroundColor:
                        Colors.red[300]!.withValues(alpha: 0.7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                  ),
                  child: _isCancelling
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Membatalkan...',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'Batalkan Pesanan',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  final BookingStatus status;

  const _StatusTimeline({
    required this.status,
  });

  int get _activeStep {
    if (status == BookingStatus.pending) return 0;
    if (status == BookingStatus.accepted) return 1;
    if (status == BookingStatus.onTheWay) return 2;
    if (status == BookingStatus.inProgress) return 3;
    if (status == BookingStatus.completed) return 4;
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    if (status.isCancelled) {
      return Row(
        children: [
          Icon(Icons.cancel, color: Colors.red[600]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pesanan ${status == BookingStatus.rejected ? "ditolak" : "dibatalkan"}',
              style: const TextStyle(
                color: kHardTextColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      );
    }

    const steps = [
      'Menunggu Konfirmasi',
      'Dikonfirmasi',
      'Menuju Lokasi',
      'Sedang Berlangsung',
      'Selesai',
    ];

    return Column(
      children: List.generate(steps.length, (index) {
        final isDone = index <= _activeStep;
        final isLast = index == steps.length - 1;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isDone ? kTeal : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDone ? kTeal : Colors.blueGrey[200]!,
                      width: 2,
                    ),
                  ),
                  child: isDone
                      ? const Icon(Icons.check, color: Colors.white, size: 15)
                      : null,
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 34,
                    color: isDone ? kTeal : Colors.blueGrey[200],
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  steps[index],
                  style: TextStyle(
                    color: isDone ? kHardTextColor : Colors.blueGrey[400],
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: kHardTextColor,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.blueGrey[500],
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
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

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
