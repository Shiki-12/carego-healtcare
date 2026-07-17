import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../constants.dart';
import '../core/api_service.dart';
import '../core/service_locator.dart';
import '../model.dart/chat_model.dart';
import '../services/chat_service.dart';
import 'state_views.dart';

class ChatRoomScreen extends StatefulWidget {
  final Conversation conversation;

  const ChatRoomScreen({
    Key? key,
    required this.conversation,
  }) : super(key: key);

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final ChatService _chat;
  StreamSubscription<ChatEvent>? _eventSub;
  ViewState _state = ViewState.loading;
  List<Message> _messages = [];
  String _errorMessage = 'Gagal memuat pesan.';
  int? _currentUserId;
  bool _isReconnecting = false;

  @override
  void initState() {
    super.initState();
    _chat = Services.I.newChatService();
    _eventSub = _chat.events.listen(_onChatEvent);
    _bootstrap();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _chat.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final session = await Services.I.auth.me();
    if (mounted) _currentUserId = session?.userId;
    await _loadMessages();
    await _chat.connect();
  }

  void _onChatEvent(ChatEvent event) {
    if (!mounted) return;
    if (event.kind == ChatEventKind.connected) {
      setState(() => _isReconnecting = false);
      _loadMessages(showLoading: false);
      return;
    }
    if (event.kind == ChatEventKind.reconnecting) {
      setState(() => _isReconnecting = true);
      return;
    }
    if (event.conversationId == widget.conversation.id) {
      _loadMessages(showLoading: false);
    }
  }

  Future<void> _loadMessages({bool showLoading = true}) async {
    if (showLoading) setState(() => _state = ViewState.loading);
    try {
      final items = await _chat.messages(
        widget.conversation.id,
        currentUserId: _currentUserId,
        limit: 100,
      );
      if (!mounted) return;
      setState(() {
        _messages = items..sort((a, b) => a.timestamp.compareTo(b.timestamp));
        _state = ViewState.data;
      });
      _markReadBestEffort();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _state = ViewState.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Terjadi kesalahan saat memuat pesan.';
        _state = ViewState.error;
      });
    }
  }

  Future<void> _markReadBestEffort() async {
    try {
      await _chat.markRead(widget.conversation.id);
    } catch (_) {
      // Read receipt tidak boleh menghalangi pengguna membaca chat.
    }
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final now = DateTime.now();
    final clientMsgId = const Uuid().v4();
    final optimistic = Message(
      id: -now.microsecondsSinceEpoch,
      text: text,
      isSentByMe: true,
      timestamp: now,
      isRead: false,
      clientMsgId: clientMsgId,
      status: MessageStatus.sending,
    );

    setState(() {
      _state = ViewState.data;
      _messages.add(optimistic);
      _messageController.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    await _sendOptimistic(optimistic);
  }

  Future<void> _sendOptimistic(Message pending) async {
    try {
      final saved = await _chat.send(
        widget.conversation.id,
        body: pending.text,
        clientMsgId: pending.clientMsgId!,
        currentUserId: _currentUserId,
      );
      if (!mounted) return;
      _replaceMessage(
        pending.clientMsgId!,
        saved.copyWith(isSentByMe: true),
      );
    } on ApiException catch (_) {
      if (!mounted) return;
      _replaceMessage(
        pending.clientMsgId!,
        pending.copyWith(status: MessageStatus.failed),
      );
    } catch (_) {
      if (!mounted) return;
      _replaceMessage(
        pending.clientMsgId!,
        pending.copyWith(status: MessageStatus.failed),
      );
    }
  }

  void _replaceMessage(String clientMsgId, Message replacement) {
    setState(() {
      final index = _messages.indexWhere((m) => m.clientMsgId == clientMsgId);
      if (index == -1) {
        _messages.add(replacement);
      } else {
        _messages[index] = replacement;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _retryMessage(Message failed) async {
    if (failed.clientMsgId == null) return;
    _replaceMessage(
      failed.clientMsgId!,
      failed.copyWith(status: MessageStatus.sending),
    );
    await _sendOptimistic(failed.copyWith(status: MessageStatus.sending));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: kHardTextColor,
        titleSpacing: 0,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 38,
                height: 38,
                color: kPrimarylightColor.withValues(alpha: 0.16),
                child: _ParticipantPhoto(
                  url: widget.conversation.participantPhotoUrl,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.conversation.participantName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kHardTextColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    widget.conversation.participantRole,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.blueGrey[400],
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
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
            child: _buildMessages(),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
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
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Tulis pesan...',
                        hintStyle: TextStyle(color: Colors.blueGrey[400]),
                        filled: true,
                        fillColor: kBackgroundColor,
                        border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xff0D9488),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                      tooltip: 'Kirim pesan',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    switch (_state) {
      case ViewState.loading:
        return const LoadingView();
      case ViewState.error:
        return ErrorView(message: _errorMessage, onRetry: _loadMessages);
      case ViewState.empty:
      case ViewState.data:
        if (_messages.isEmpty) {
          return const EmptyView(
            text: 'Belum ada pesan.',
            icon: Icons.chat_bubble_outline,
          );
        }
        return RefreshIndicator(
          color: const Color(0xff0D9488),
          onRefresh: _loadMessages,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              return _MessageBubble(
                message: message,
                timeLabel: _formatTime(message.timestamp),
                onRetry: message.status == MessageStatus.failed
                    ? () => _retryMessage(message)
                    : null,
              );
            },
          ),
        );
    }
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
          size: 22,
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
          size: 22,
        ),
      );
    }
    return const Icon(
      Icons.person,
      color: Color(0xff0D9488),
      size: 22,
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final String timeLabel;
  final VoidCallback? onRetry;

  const _MessageBubble({
    required this.message,
    required this.timeLabel,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isMine = message.isSentByMe;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xff0D9488) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 8,
              offset: const Offset(0, 2),
              color: Colors.black.withValues(alpha: 0.05),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isMine ? Colors.white : kHardTextColor,
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeLabel,
                  style: TextStyle(
                    color: isMine
                        ? Colors.white.withValues(alpha: 0.76)
                        : Colors.blueGrey[400],
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 5),
                  Icon(
                    Icons.done_all,
                    color: message.isRead || message.status == MessageStatus.read
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.58),
                    size: 15,
                  ),
                ],
              ],
            ),
            if (message.status == MessageStatus.sending) ...[
              const SizedBox(height: 4),
              Text(
                'Mengirim...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.76),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (message.status == MessageStatus.failed) ...[
              const SizedBox(height: 4),
              InkWell(
                onTap: onRetry,
                child: Text(
                  'Gagal - ketuk untuk kirim ulang',
                  style: TextStyle(
                    color: Colors.red[100],
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
