import 'package:flutter/material.dart';

import '../constants.dart';
import '../core/api_service.dart';
import '../core/service_locator.dart';
import '../model.dart/notification_model.dart';
import 'notification_preferences_screen.dart';
import 'state_views.dart';

class NotificationsScreen extends StatefulWidget {
  final bool showScaffold;

  const NotificationsScreen({
    Key? key,
    this.showScaffold = true,
  }) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  ViewState _state = ViewState.loading;
  List<NotificationItem> _notifications = [];
  String _errorMessage = 'Gagal memuat notifikasi.';
  bool _isMarkingAllRead = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications({bool showLoading = true}) async {
    if (showLoading) setState(() => _state = ViewState.loading);
    try {
      final items = await Services.I.notifications.list(limit: 100);
      items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (!mounted) return;
      setState(() {
        _notifications = items;
        _state = items.isEmpty ? ViewState.empty : ViewState.data;
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
        _errorMessage = 'Terjadi kesalahan saat memuat notifikasi.';
        _state = ViewState.error;
      });
    }
  }

  Future<void> _markAllAsRead() async {
    if (_notifications.every((notification) => notification.isRead)) return;
    setState(() => _isMarkingAllRead = true);
    try {
      await Services.I.notifications.markAllRead();
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map((notification) => notification.copyWith(isRead: true))
            .toList();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menandai notifikasi.')),
      );
    } finally {
      if (mounted) setState(() => _isMarkingAllRead = false);
    }
  }

  Future<void> _markAsRead(NotificationItem notification) async {
    if (notification.isRead) return;
    final previous = List<NotificationItem>.from(_notifications);
    setState(() {
      _notifications = _notifications.map((item) {
        if (item.id != notification.id) return item;
        return item.copyWith(isRead: true);
      }).toList();
    });
    try {
      await Services.I.notifications.markRead(notification.id);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _notifications = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _notifications = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menandai notifikasi.')),
      );
    }
  }

  void _openPreferences() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NotificationPreferencesScreen(),
      ),
    );
  }

  String _formatTime(DateTime time) {
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
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '${time.day} ${months[time.month - 1]}, $hour:$minute';
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        16,
        widget.showScaffold ? 12 : MediaQuery.of(context).padding.top + 18,
        12,
        12,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Notifikasi',
              style: TextStyle(
                color: kHardTextColor,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          TextButton(
            onPressed: _isMarkingAllRead ||
                    _notifications.every((notification) => notification.isRead)
                ? null
                : _markAllAsRead,
            child: Text(
              _isMarkingAllRead ? 'Memproses...' : 'Tandai Semua Dibaca',
              style: const TextStyle(
                color: Color(0xff0D9488),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            onPressed: _openPreferences,
            icon: const Icon(Icons.settings, color: kHardTextColor),
            tooltip: 'Pengaturan notifikasi',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        _buildHeader(),
        Expanded(
          child: _buildBody(),
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

  Widget _buildBody() {
    switch (_state) {
      case ViewState.loading:
        return const LoadingView();
      case ViewState.error:
        return ErrorView(message: _errorMessage, onRetry: _loadNotifications);
      case ViewState.empty:
        return const EmptyView(
          text: 'Belum ada notifikasi.',
          icon: Icons.notifications_none,
        );
      case ViewState.data:
        return RefreshIndicator(
          color: const Color(0xff0D9488),
          onRefresh: _loadNotifications,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: _notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final notification = _notifications[index];
              return _NotificationCard(
                notification: notification,
                timeLabel: _formatTime(notification.timestamp),
                onTap: () => _markAsRead(notification),
              );
            },
          ),
        );
    }
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationItem notification;
  final String timeLabel;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.timeLabel,
    required this.onTap,
  });

  IconData get _icon {
    if (notification.type == 'new_message') return Icons.chat_bubble_outline;
    if (notification.type == 'promotion') return Icons.local_offer;
    if (notification.type == 'payment_received') return Icons.account_balance_wallet;
    if (notification.type == 'provider_arriving') return Icons.directions_car;
    if (notification.type == 'system') return Icons.info_outline;
    return Icons.receipt_long;
  }

  Color get _iconColor {
    if (notification.type == 'promotion') return Colors.orange[700]!;
    if (notification.type == 'provider_arriving') return kPrimaryDarkColor;
    if (notification.type == 'system') return Colors.blueGrey[500]!;
    return const Color(0xff0D9488);
  }

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              unread ? const Color(0xff0D9488).withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: unread
              ? Border.all(color: const Color(0xff0D9488).withValues(alpha: 0.18))
              : null,
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              offset: const Offset(0, 3),
              color: Colors.black.withValues(alpha: 0.06),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(_icon, color: _iconColor),
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
                          notification.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: kHardTextColor,
                            fontSize: 15,
                            fontWeight: unread ? FontWeight.w900 : FontWeight.w700,
                          ),
                        ),
                      ),
                      if (unread)
                        Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            color: Color(0xff0D9488),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    notification.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.blueGrey[600],
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    timeLabel,
                    style: TextStyle(
                      color: Colors.blueGrey[400],
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

