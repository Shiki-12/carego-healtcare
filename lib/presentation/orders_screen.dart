import 'package:flutter/material.dart';

import '../constants.dart';
import '../core/service_locator.dart';
import '../models/booking.dart';
import '../presentation/state_views.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  final bool showScaffold;

  const OrdersScreen({
    Key? key,
    this.showScaffold = true,
  }) : super(key: key);

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(
            16,
            widget.showScaffold ? 0 : MediaQuery.of(context).padding.top + 18,
            16,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pesanan Saya',
                style: TextStyle(
                  color: kHardTextColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              TabBar(
                controller: _tabController,
                labelColor: kTeal,
                unselectedLabelColor: kHardTextColor,
                indicatorColor: kTeal,
                labelStyle: const TextStyle(fontWeight: FontWeight.w900),
                tabs: const [
                  Tab(text: 'Aktif'),
                  Tab(text: 'Selesai'),
                  Tab(text: 'Dibatalkan'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _OrdersTab(statusGroup: 'active'),
              _OrdersTab(statusGroup: 'completed'),
              _OrdersTab(statusGroup: 'cancelled'),
            ],
          ),
        ),
      ],
    );

    if (!widget.showScaffold) {
      return content;
    }

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: kHardTextColor,
      ),
      body: content,
    );
  }
}

class _OrdersTab extends StatefulWidget {
  final String statusGroup;

  const _OrdersTab({required this.statusGroup});

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab>
    with AutomaticKeepAliveClientMixin {
  ViewState _state = ViewState.loading;
  List<Booking> _bookings = [];
  String _errorMessage = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    if (mounted) {
      setState(() {
        _state = ViewState.loading;
        _errorMessage = '';
      });
    }

    try {
      final result = await Services.I.bookings.list(
        statusGroup: widget.statusGroup,
        limit: 100,
      );
      result.items.sort((a, b) => b.date.compareTo(a.date));

      if (mounted) {
        setState(() {
          _bookings = result.items;
          _state = result.items.isEmpty ? ViewState.empty : ViewState.data;
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

  String get _emptyMessage {
    if (widget.statusGroup == 'active') return 'Belum ada pesanan aktif';
    if (widget.statusGroup == 'completed') return 'Belum ada pesanan selesai';
    return 'Belum ada pesanan dibatalkan';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_state == ViewState.loading) {
      return const LoadingView();
    }

    if (_state == ViewState.error) {
      return ErrorView(
        message: _errorMessage,
        onRetry: _loadBookings,
      );
    }

    if (_state == ViewState.empty) {
      return EmptyView(text: _emptyMessage, icon: Icons.receipt_long);
    }

    return RefreshIndicator(
      onRefresh: _loadBookings,
      color: kTeal,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _bookings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final booking = _bookings[index];
          return _OrderCard(
            booking: booking,
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OrderDetailScreen(bookingId: booking.id),
                ),
              );
              _loadBookings();
            },
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback onTap;

  const _OrderCard({
    required this.booking,
    required this.onTap,
  });

  String _formatDate(DateTime date) {
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

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(14),
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
            Container(
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: booking.status.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                booking.serviceEmoji,
                style: const TextStyle(fontSize: 26),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          booking.serviceLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: kHardTextColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      _StatusBadge(
                        label: booking.status.label,
                        color: booking.status.color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    booking.providerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.blueGrey[500],
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 14, color: Colors.blueGrey[400]),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          _formatDate(booking.date),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.blueGrey[500],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    booking.priceLabel,
                    style: const TextStyle(
                      color: kTeal,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: kPrimaryDarkColor),
          ],
        ),
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
