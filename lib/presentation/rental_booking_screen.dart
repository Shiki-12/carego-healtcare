import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../constants.dart';
import '../core/api_service.dart';
import '../core/service_locator.dart';
import '../model.dart/equipment.dart';
import '../models/booking.dart';
import 'order_detail_screen.dart';

class RentalBookingScreen extends StatefulWidget {
  final Equipment equipment;

  const RentalBookingScreen({
    Key? key,
    required this.equipment,
  }) : super(key: key);

  @override
  State<RentalBookingScreen> createState() => _RentalBookingScreenState();
}

class _RentalBookingScreenState extends State<RentalBookingScreen> {
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  DateTime? _startDate;
  String _durationUnit = 'day';
  bool _isBooking = false;

  @override
  void dispose() {
    _durationController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  int get _duration => int.tryParse(_durationController.text.trim()) ?? 0;
  int get _rate => _durationUnit == 'week'
      ? widget.equipment.weeklyRate
      : widget.equipment.dailyRate;

  /// Estimasi sisi-client (tarif × durasi + deposit) — HANYA pratinjau.
  /// Harga FINAL ditetapkan backend saat POST /bookings (doc 00 §6, doc 07 §4).
  int get _rentalPrice => _rate * _duration;
  int get _estimatedTotal => _rentalPrice + widget.equipment.deposit;

  DateTime? get _endDate {
    if (_startDate == null || _duration <= 0) return null;
    final days = _durationUnit == 'week' ? _duration * 7 : _duration;
    return _startDate!.add(Duration(days: days));
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
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Pilih tanggal mulai sewa',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );

    if (result != null && mounted) {
      setState(() => _startDate = result);
    }
  }

  void _submitBooking() {
    if (_startDate == null) {
      _showSnackBar('Pilih tanggal mulai');
      return;
    }
    if (_duration <= 0) {
      _showSnackBar('Masukkan durasi sewa');
      return;
    }
    if (_addressController.text.trim().isEmpty) {
      _showSnackBar('Masukkan alamat pengiriman');
      return;
    }

    _performBooking();
  }

  /// Kirim booking nyata (POST /bookings, doc 07 §4). Client TIDAK mengirim
  /// harga/deposit — backend yang menghitung. Idempotency-Key cegah
  /// double-booking (doc 01 §8). Sukses → buka detail dengan ID dari response.
  Future<void> _performBooking() async {
    setState(() => _isBooking = true);

    // Sewa mingguan dikirim sebagai jumlah hari (backend hitung tarif final).
    final rentalDays = _durationUnit == 'week' ? _duration * 7 : _duration;

    final payload = <String, dynamic>{
      'serviceType': 'rental',
      'providerId': widget.equipment.id,
      'rentalItemId': widget.equipment.id,
      'rentalDays': rentalDays,
      'scheduledAt': _startDate!.toUtc().toIso8601String(),
      'pickupAddress': _addressController.text.trim(),
      'patientName': widget.equipment.name,
      'notes': 'Sewa $_duration ${_durationUnit == 'week' ? 'minggu' : 'hari'}',
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
                _summaryRow('Alat', widget.equipment.name),
                _summaryRow('Mulai', _formatDate(_startDate!)),
                if (_endDate != null)
                  _summaryRow('Selesai', _formatDate(_endDate!)),
                _summaryRow(
                  'Durasi',
                  '$_duration ${_durationUnit == 'week' ? 'minggu' : 'hari'}',
                ),
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
    final unitLabel = _durationUnit == 'week' ? 'minggu' : 'hari';

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: kHardTextColor,
        title: const Text(
          'Pesan Sewa',
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
                  _EquipmentHeader(
                    equipment: widget.equipment,
                    rateLabel:
                        '${_formatRupiah(_rate)}/${_durationUnit == 'week' ? 'minggu' : 'hari'}',
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Detail Penyewaan',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: kHardTextColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PickerField(
                    label: 'Tanggal Mulai',
                    value: _startDate == null
                        ? 'Pilih tanggal mulai'
                        : _formatDate(_startDate!),
                    icon: Icons.calendar_today,
                    onTap: _pickStartDate,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _durationController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Durasi',
                            hintText: 'Contoh: 3',
                            hintStyle: TextStyle(color: Colors.blueGrey[400]),
                            prefixIcon: Icon(
                              Icons.timelapse,
                              color: Colors.blueGrey[400],
                            ),
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
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 130,
                        child: DropdownButtonFormField<String>(
                          initialValue: _durationUnit,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'day',
                              child: Text('Hari'),
                            ),
                            DropdownMenuItem(
                              value: 'week',
                              child: Text('Minggu'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _durationUnit = value);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _addressController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Alamat Pengiriman',
                      hintText: 'Masukkan alamat lengkap',
                      hintStyle: TextStyle(color: Colors.blueGrey[400]),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(bottom: 42),
                        child: Icon(
                          Icons.location_on,
                          color: Colors.blueGrey[400],
                        ),
                      ),
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
                          'Tarif per $unitLabel',
                          _formatRupiah(_rate),
                        ),
                        const Divider(height: 20),
                        _priceRow(
                          'Durasi',
                          _duration > 0 ? '$_duration $unitLabel' : '-',
                        ),
                        const Divider(height: 20),
                        _priceRow(
                          'Biaya sewa',
                          _formatRupiah(_rentalPrice),
                        ),
                        const Divider(height: 20),
                        _priceRow(
                          'Deposit',
                          _formatRupiah(widget.equipment.deposit),
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
                              _formatRupiah(_estimatedTotal),
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
                                'Konfirmasi Pesanan - Est. ${_formatRupiah(_estimatedTotal)}',
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

class _EquipmentHeader extends StatelessWidget {
  final Equipment equipment;
  final String rateLabel;

  const _EquipmentHeader({
    required this.equipment,
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
                equipment.images.first,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  equipment.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kHardTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
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
