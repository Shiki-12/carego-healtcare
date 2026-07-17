import 'dart:async';

import 'package:flutter/material.dart';

import '../constants.dart';
import '../core/api_service.dart';
import '../model.dart/chat_model.dart';
import '../services/chat_service.dart';
import '../core/service_locator.dart';
import 'state_views.dart';
import 'chat_room_screen.dart';

class ChatScreen extends StatefulWidget {
  final bool showScaffold;

  const ChatScreen({
    Key? key,
    this.showScaffold = true,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatService _chat;
  StreamSubscription<ChatEvent>? _eventSub;
  ViewState _state = ViewState.loading;
  List<Conversation> _conversations = [];
  String _errorMessage = 'Gagal memuat percakapan.';
  bool _isReconnecting = false;

  @override
  void initState() {
    super.initState();
    _chat = Services.I.newChatService();
    _eventSub = _chat.events.listen(_onChatEvent);
    _loadConversations();
    _chat.connect();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _chat.dispose();
    super.dispose();
  }

  void _onChatEvent(ChatEvent event) {
    if (!mounted) return;
    if (event.kind == ChatEventKind.connected) {
      setState(() => _isReconnecting = false);
      _loadConversations(showLoading: false);
      return;
    }
    if (event.kind == ChatEventKind.reconnecting) {
      setState(() => _isReconnecting = true);
      return;
    }
    if (event.kind == ChatEventKind.message ||
        event.kind == ChatEventKind.read) {
      _loadConversations(showLoading: false);
    }
  }

  Future<void> _loadConversations({bool showLoading = true}) async {
    if (showLoading) setState(() => _state = ViewState.loading);
    try {
      final items = await _chat.conversations(limit: 100);
      if (!mounted) return;
      setState(() {
        _conversations = items;
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
        _errorMessage = 'Terjadi kesalahan saat memuat percakapan.';
        _state = ViewState.error;
      });
    }
  }

  String _formatTime(DateTime time) {
    if (time.millisecondsSinceEpoch == 0) return '';
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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
            widget.showScaffold ? 12 : MediaQuery.of(context).padding.top + 18,
            16,
            14,
          ),
          child: const Text(
            'Pesan',
            style: TextStyle(
              color: kHardTextColor,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (_isReconnecting)
          Container(
            width: double.infinity,
            color: const Color(0xff0D9488).withValues(alpha: 0.12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Text(
              'Menyambungkan ulang...',
              style: TextStyle(
                color: Color(0xff0D9488),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
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
        return ErrorView(
          message: _errorMessage,
          onRetry: _loadConversations,
        );
      case ViewState.empty:
        return const EmptyView(
          text: 'Belum ada percakapan.',
          icon: Icons.chat_bubble_outline,
        );
      case ViewState.data:
        return RefreshIndicator(
          color: const Color(0xff0D9488),
          onRefresh: _loadConversations,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: _conversations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final conversation = _conversations[index];
              return _ConversationCard(
                conversation: conversation,
                timeLabel: _formatTime(conversation.lastMessageTime),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatRoomScreen(
                        conversation: conversation,
                      ),
                    ),
                  );
                  if (mounted) _loadConversations(showLoading: false);
                },
              );
            },
          ),
        );
    }
  }
}

class _ConversationCard extends StatelessWidget {
  final Conversation conversation;
  final String timeLabel;
  final VoidCallback onTap;

  const _ConversationCard({
    required this.conversation,
    required this.timeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
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
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 58,
                height: 58,
                color: kPrimarylightColor.withValues(alpha: 0.16),
                child: _ParticipantPhoto(url: conversation.participantPhotoUrl),
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
                          conversation.participantName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: kHardTextColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
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
                  const SizedBox(height: 3),
                  Text(
                    conversation.participantRole,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xff0D9488),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.blueGrey[500],
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (conversation.unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xff0D9488),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            conversation.unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
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

class _ParticipantPhoto extends StatelessWidget {
  final String url;

  const _ParticipantPhoto({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('http')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.person,
          color: Color(0xff0D9488),
          size: 28,
        ),
      );
    }
    if (url.isNotEmpty) {
      return Image.asset(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.person,
          color: Color(0xff0D9488),
          size: 28,
        ),
      );
    }
    return const Icon(
      Icons.person,
      color: Color(0xff0D9488),
      size: 28,
    );
  }
}
