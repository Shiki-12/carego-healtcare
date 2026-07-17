import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../constants.dart';
import '../core/api_service.dart';
import '../core/service_locator.dart';
import '../model.dart/caregiver.dart';
import '../models/booking.dart';
import 'order_detail_screen.dart';

class CaregiverBookingScreen extends StatefulWidget {
  final Caregiver caregiver;

  const CaregiverBookingScreen({
    Key? key,
    required this.caregiver,
  }) : super(key: key);

  @override
  State<CaregiverBookingScreen> createState() => _CaregiverBookingScreenState();
}

class _CaregiverBookingScreenState extends State<CaregiverBookingScreen> {
  final TextEditingController _durationController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isBooking = false;

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  int get _durationHours => int.tryParse(_durationController.text.trim()) ?? 0;

  /// Estimasi harga sisi-client (tarif × durasi) — HANYA untuk pratinjau.
  /// Harga FINAL ditetapkan backend saat POST /bookings (doc 00 §6, doc 07 §4).
  int get _estimatedPrice => widget.caregiver.hourlyRate * _durationHours;

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
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Pilih tanggal layanan',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );

    if (result != null && mounted) {
      setState(() => _selectedDate = result);
    }
  }

  Future<void> _pickTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      helpText: 'Pilih jam mulai',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );

    if (result != null && mounted) {
      setState(() => _selectedTime = result);
    }
  }

  void _submitBooking() {
    if (_selectedDate == null) {
      _showSnackBar('Pilih tanggal layanan');
      return;
    }
    if (_selectedTime == null) {
      _showSnackBar('Pilih jam mulai');
      return;
    }
    if (_durationHours <= 0) {
      _showSnackBar('Masukkan durasi dalam jam');
      return;
    }

    _performBooking();
  }

  /// Kirim booking nyata (POST /bookings, doc 07 §4). Client TIDAK mengirim
  /// harga — backend yang menghitung. Idempotency-Key cegah double-booking
  /// (doc 01 §8). Sukses → buka detail pesanan dengan ID dari response.
  Future<void> _performBooking() async {
    setState(() => _isBooking = true);

    final scheduledAt = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    final payload = <String, dynamic>{
      'serviceType': 'caregiver',
      'providerId': widget.caregiver.id,
      'scheduledAt': scheduledAt.toUtc().toIso8601String(),
      'durationHours': _durationHours,
      'patientName': widget.caregiver.name,
      'notes': 'Durasi $_durationHours jam',
    };

    try {
      final booking = await Services.I.bookings.create(
        payload: payload,
        idempotencyKey: const Uuid().v4(),
      );

      if (!mounted) return;
      setState(() => _isBooking = false);
      _showSuccessDialog(booking);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isBooking = false);
      _showErrorDialog(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isBooking = false);
      _showErrorDialog('Terjadi kesalahan. Silakan coba lagi.');
    }
  }

  void _showSuccessDialog(Booking booking) {
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
                  decoration: const BoxDecoration(
                    color: Color(0xff0D9488),
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
                  'Pemesanan Berhasil!',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: Color(0xff0D9488),
                  ),
                ),
                const SizedBox(height: 16),
                _summaryRow('Nomor Pesanan', '#${booking.id}'),
                _summaryRow('Caregiver', widget.caregiver.name),
                _summaryRow('Tanggal', _formatDate(_selectedDate!)),
                _summaryRow('Jam Mulai', _formatTime(_selectedTime!)),
                _summaryRow('Durasi', '$_durationHours jam'),
                _summaryRow('Total', booking.priceLabel),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) =>
                              OrderDetailScreen(bookingId: booking.id),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff0D9488),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Lihat Pesanan',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
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

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Gagal Memesan'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Tutup'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _performBooking();
              },
              child: const Text('Coba lagi'),
            ),
          ],
        );
      },
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.blueGrey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red[700],
      ),
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
          'Pesan Caregiver',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CaregiverHeader(
                    caregiver: widget.caregiver,
                    rateLabel:
                        '${_formatRupiah(widget.caregiver.hourlyRate)}/jam',
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Jadwal Layanan',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: kHardTextColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PickerField(
                    label: 'Tanggal',
                    value: _selectedDate == null
                        ? 'Pilih tanggal'
                        : _formatDate(_selectedDate!),
                    icon: Icons.calendar_today,
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: 10),
                  _PickerField(
                    label: 'Jam Mulai',
                    value: _selectedTime == null
                        ? 'Pilih jam mulai'
                        : _formatTime(_selectedTime!),
                    icon: Icons.schedule,
                    onTap: _pickTime,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Durasi dalam jam',
                      hintText: 'Contoh: 4',
                      hintStyle: TextStyle(color: Colors.blueGrey[400]),
                      prefixIcon:
                          Icon(Icons.timelapse, color: Colors.blueGrey[400]),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Rincian Biaya',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: kHardTextColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                          color: Colors.black.withValues(alpha: 0.06),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _priceRow(
                          'Tarif per jam',
                          _formatRupiah(widget.caregiver.hourlyRate),
                        ),
                        const Divider(height: 20),
                        _priceRow(
                          'Durasi',
                          _durationHours > 0 ? '$_durationHours jam' : '-',
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Estimasi',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: Color(0xff0D9488),
                              ),
                            ),
                            Text(
                              _formatRupiah(_estimatedPrice),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: Color(0xff0D9488),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Harga final ditetapkan setelah pesanan dikonfirmasi.',
                          style: TextStyle(
                            color: Colors.blueGrey[400],
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
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
                  onPressed: _isBooking ? null : _submitBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff0D9488),
                    disabledBackgroundColor:
                        const Color(0xff0D9488).withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                  ),
                  child: _isBooking
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
                              'Memproses...',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline,
                                color: Colors.white),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'Konfirmasi Pesanan • Est. ${_formatRupiah(_estimatedPrice)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.blueGrey[600],
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _CaregiverHeader extends StatelessWidget {
  final Caregiver caregiver;
  final String rateLabel;

  const _CaregiverHeader({
    required this.caregiver,
    required this.rateLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 3),
            color: Colors.black.withValues(alpha: 0.06),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 76,
              height: 86,
              color: kPrimarylightColor.withValues(alpha: 0.16),
              child: Image.asset(
                caregiver.photoUrl,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caregiver.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kHardTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  caregiver.specialization,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.blueGrey[500],
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  rateLabel,
                  style: const TextStyle(
                    color: Color(0xff0D9488),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.blueGrey[400]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.blueGrey[400],
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kHardTextColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: kPrimaryDarkColor),
          ],
        ),
      ),
    );
  }
}
