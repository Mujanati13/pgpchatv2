import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../services/pgp_service.dart';

class ChatDetailScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUsername;
  final String? otherPublicKey;

  const ChatDetailScreen({
    super.key,
    required this.otherUserId,
    required this.otherUsername,
    this.otherPublicKey,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  bool _disposed = false;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _pgp = PgpService();
  String? _passphrase;
  String _fingerprint = '';
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<ChatProvider>().loadMessages(widget.otherUserId);
      _loadFingerprint();
      _startCountdown();
    });
  }

  Future<void> _loadFingerprint() async {
    if (widget.otherPublicKey != null && widget.otherPublicKey!.isNotEmpty) {
      final fp = _pgp.getFingerprint(widget.otherPublicKey!);
      if (mounted) setState(() => _fingerprint = fp);
    }
  }

  void _startCountdown() {
    final settings = context.read<SettingsProvider>();
    if (!settings.autoDeleteEnabled) return;
    _updateRemaining();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed || !mounted) return;
      _updateRemaining();
    });
  }

  void _updateRemaining() {
    final settings = context.read<SettingsProvider>();
    final messages = context.read<ChatProvider>().messages;
    if (messages.isEmpty) {
      setState(() => _remaining = Duration(hours: settings.autoDeleteHours));
      return;
    }
    // Find the newest message timestamp
    DateTime? newest;
    for (final msg in messages) {
      final ts = msg['created_at']?.toString();
      if (ts == null) continue;
      try {
        final dt = DateTime.parse(ts);
        if (newest == null || dt.isAfter(newest)) newest = dt;
      } catch (_) {}
    }
    if (newest == null) {
      setState(() => _remaining = Duration(hours: settings.autoDeleteHours));
      return;
    }
    final expiry = newest.add(Duration(hours: settings.autoDeleteHours));
    final diff = expiry.difference(DateTime.now());
    setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
  }

  @override
  void dispose() {
    _disposed = true;
    _countdownTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (widget.otherPublicKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipient has no public key')),
      );
      return;
    }

    try {
      final encrypted = await _pgp.encrypt(text, widget.otherPublicKey!);
      String? signature;
      if (_passphrase != null) {
        signature = await _pgp.sign(text, _passphrase!);
      }

      if (!mounted) return;
      final success = await context.read<ChatProvider>().sendMessage(
            recipientId: widget.otherUserId,
            encryptedBody: encrypted,
            signature: signature,
          );

      if (success) {
        _messageController.clear();
        if (mounted) {
          context.read<ChatProvider>().loadMessages(widget.otherUserId);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Encryption failed: $e')),
        );
      }
    }
  }

  // Returns null on cancel, '\x00FAIL' on wrong passphrase, decrypted text on success.
  Future<String?> _decryptMessage(String encryptedBody) async {
    if (_passphrase == null) {
      _passphrase = await _showPassphraseDialog();
      if (_passphrase == null) return null; // user cancelled
    }
    try {
      return await _pgp.decrypt(encryptedBody, _passphrase!);
    } catch (_) {
      _passphrase = null; // clear bad passphrase so next tap re-prompts
      return '\x00FAIL';
    }
  }

  Future<String?> _showPassphraseDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Enter Passphrase',
            style: TextStyle(color: AppColors.textMainDark)),
        content: TextField(
          controller: controller,
          obscureText: true,
          style: const TextStyle(color: AppColors.textMainDark),
          decoration: InputDecoration(
            hintText: 'PGP key passphrase',
            hintStyle: const TextStyle(color: AppColors.textSubDark),
            filled: true,
            fillColor: AppColors.backgroundDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.borderDark),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSubDark)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Unlock',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
    return result;
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.length >= 2
        ? name.substring(0, 2).toUpperCase()
        : name.toUpperCase();
  }

  void _showChatMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.slate700,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading:
                  const Icon(Icons.lock_outline, color: AppColors.primary),
              title: const Text('Encryption Info',
                  style: TextStyle(color: AppColors.textMainDark)),
              subtitle: const Text('End-to-end PGP encrypted',
                  style:
                      TextStyle(color: AppColors.textSubDark, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('End-to-end encrypted with PGP')),
                );
              },
            ),
            ListTile(
              leading:
                  Icon(Icons.timer_outlined, color: AppColors.yellow600),
              title: const Text('Auto-Delete',
                  style: TextStyle(color: AppColors.textMainDark)),
              subtitle: Text(
                context.read<SettingsProvider>().autoDeleteEnabled
                    ? 'Active — ${context.read<SettingsProvider>().autoDeleteHours}h'
                    : 'Disabled',
                style: const TextStyle(
                    color: AppColors.textSubDark, fontSize: 12),
              ),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('Clear Chat',
                  style: TextStyle(color: AppColors.error)),
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_disposed) return const SizedBox.shrink();
    final chat = context.watch<ChatProvider>();
    final settings = context.watch<SettingsProvider>();
    final autoDelete = settings.autoDeleteEnabled;
    final hours = settings.autoDeleteHours;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Custom App Bar ───
            Container(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
              decoration: BoxDecoration(
                color: AppColors.backgroundDark,
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.slate800.withValues(alpha: 0.6),
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, size: 24),
                    color: AppColors.slate300,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        // Name row with lock icon
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock,
                                size: 14, color: AppColors.slate400),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                widget.otherUsername,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textMainDark,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // Subtitle: fingerprint + timer or "Online"
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_fingerprint.isNotEmpty) ...[
                              Text(
                                _fingerprint.length >= 8 ? '${_fingerprint.substring(0, 4)}...${_fingerprint.substring(_fingerprint.length - 4)}' : _fingerprint,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  color: AppColors.slate500,
                                ),
                              ),
                              if (autoDelete)
                                const Text(' · ',
                                    style: TextStyle(
                                        color: AppColors.slate500,
                                        fontSize: 12)),
                            ],
                            if (autoDelete) ...[
                              Icon(Icons.timer_outlined,
                                  size: 13, color: AppColors.yellow600),
                              const SizedBox(width: 3),
                              Text(
                                '${hours}h',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.yellow600,
                                ),
                              ),
                            ] else if (_fingerprint.isEmpty) ...[
                              const Text(
                                'Online',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.slate500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _showChatMenu,
                    icon: const Icon(Icons.more_vert, size: 24),
                    color: AppColors.slate300,
                  ),
                ],
              ),
            ),

            // ─── Compact Self-Destruct Banner ───
            if (autoDelete)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.yellow600.withValues(alpha: 0.08),
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.slate800.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer, size: 15, color: AppColors.yellow600),
                    const SizedBox(width: 8),
                    Text(
                      'Self-Destruct',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.yellow600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_remaining.inHours.toString().padLeft(2, '0')}:'
                      '${(_remaining.inMinutes % 60).toString().padLeft(2, '0')}:'
                      '${(_remaining.inSeconds % 60).toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        color: AppColors.yellow600,
                      ),
                    ),
                  ],
                ),
              ),

            // ─── Messages List ───
            Expanded(
              child: chat.isLoading && chat.messages.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary))
                  : chat.messages.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: chat.messages.length + 1,
                          itemBuilder: (context, index) {
                            // "Today" divider at end (top visually)
                            if (index == chat.messages.length) {
                              return _buildDateDivider('Today');
                            }
                            final msg = chat.messages[index];
                            final isMine =
                                msg['sender_id'] != widget.otherUserId;
                            return _MessageBubble(
                              encryptedBody:
                                  msg['encrypted_body'] as String? ?? '',
                              isMine: isMine,
                              timestamp:
                                  msg['created_at'] as String? ?? '',
                              senderName: widget.otherUsername,
                              senderInitials:
                                  _getInitials(widget.otherUsername),
                              autoDeleteEnabled: autoDelete,
                              autoDeleteHours: hours,
                              messageCreatedAt:
                                  msg['created_at']?.toString(),
                              onDecrypt: _decryptMessage,
                            );
                          },
                        ),
            ),

            // ─── Encryption notice (non-autodelete mode) ───
            if (!autoDelete)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_user_outlined,
                        size: 14, color: AppColors.slate500),
                    const SizedBox(width: 6),
                    const Text(
                      'Messages are end-to-end PGP encrypted.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),

            // ─── Input Bar ───
            Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                border: Border(
                  top: BorderSide(
                    color: AppColors.slate800.withValues(alpha: 0.6),
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Attachment / plus button
                    Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        color: AppColors.slate800.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.add, size: 22),
                        color: AppColors.slate400,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Text field with mic
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.backgroundDark,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color:
                                AppColors.slate800.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                style: const TextStyle(
                                  color: AppColors.textMainDark,
                                  fontSize: 15,
                                ),
                                maxLines: 4,
                                minLines: 1,
                                decoration: InputDecoration(
                                  hintText: autoDelete
                                      ? 'Encrypted message...'
                                      : 'Message',
                                  hintStyle: const TextStyle(
                                    color: AppColors.slate500,
                                    fontSize: 15,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 10),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                  right: 8, bottom: 8),
                              child: Icon(Icons.mic_none,
                                  size: 22, color: AppColors.slate400),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Send button
                    Container(
                      width: 44,
                      height: 44,
                      margin: const EdgeInsets.only(bottom: 2),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send, size: 20),
                        color: Colors.white,
                        padding: EdgeInsets.zero,
                        onPressed: _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 48,
              color: AppColors.textSubDark.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          const Text(
            'No messages yet',
            style: TextStyle(color: AppColors.textSubDark, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text(
            'Messages are end-to-end encrypted',
            style: TextStyle(color: AppColors.textSubDark, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildDateDivider(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
              child: Divider(
                  color: AppColors.slate800.withValues(alpha: 0.5),
                  height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.slate400,
                ),
              ),
            ),
          ),
          Expanded(
              child: Divider(
                  color: AppColors.slate800.withValues(alpha: 0.5),
                  height: 1)),
        ],
      ),
    );
  }
}

// ─── Message Bubble Widget ───
class _MessageBubble extends StatefulWidget {
  final String encryptedBody;
  final bool isMine;
  final String timestamp;
  final String senderName;
  final String senderInitials;
  final bool autoDeleteEnabled;
  final int autoDeleteHours;
  final String? messageCreatedAt;
  final Future<String?> Function(String) onDecrypt;

  const _MessageBubble({
    required this.encryptedBody,
    required this.isMine,
    required this.timestamp,
    required this.senderName,
    required this.senderInitials,
    required this.autoDeleteEnabled,
    required this.autoDeleteHours,
    this.messageCreatedAt,
    required this.onDecrypt,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  String? _decryptedText;
  bool _isDecrypting = false;
  bool _decryptFailed = false;

  Future<void> _decrypt() async {
    setState(() {
      _isDecrypting = true;
      _decryptFailed = false;
    });
    final text = await widget.onDecrypt(widget.encryptedBody);
    if (!mounted) return;
    if (text == null) {
      // user cancelled the passphrase dialog
      setState(() => _isDecrypting = false);
    } else if (text == '\x00FAIL') {
      // wrong passphrase — let user retry
      setState(() {
        _isDecrypting = false;
        _decryptFailed = true;
      });
    } else {
      setState(() {
        _decryptedText = text;
        _isDecrypting = false;
      });
    }
  }

  String _formatTime(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      final h = dt.hour;
      final m = dt.minute.toString().padLeft(2, '0');
      final ampm = h >= 12 ? 'PM' : 'AM';
      final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$h12:$m $ampm';
    } catch (_) {
      return '';
    }
  }

  String _formatExpiry() {
    if (widget.messageCreatedAt == null) {
      final h = widget.autoDeleteHours;
      if (h < 24) return '${h}h';
      final d = h ~/ 24;
      final r = h % 24;
      return r == 0 ? '${d}d' : '${d}d ${r}h';
    }
    try {
      final created = DateTime.parse(widget.messageCreatedAt!);
      final expiry = created.add(Duration(hours: widget.autoDeleteHours));
      final diff = expiry.difference(DateTime.now());
      if (diff.isNegative) return 'Expired';
      if (diff.inHours >= 24) {
        final d = diff.inHours ~/ 24;
        final h = diff.inHours % 24;
        return h == 0 ? '${d}d' : '${d}d ${h}h';
      }
      if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}m';
      return '${diff.inMinutes}m';
    } catch (_) {
      return '${widget.autoDeleteHours}h';
    }
  }

  @override
  Widget build(BuildContext context) {
    final time = _formatTime(widget.timestamp);
    if (widget.isMine) {
      return _buildSentBubble(time);
    } else {
      return _buildReceivedBubble(time);
    }
  }

  // ─── SENT (right side, blue) ───
  Widget _buildSentBubble(String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Timestamp above bubble
          if (time.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, right: 4),
              child: Text(
                time,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.slate500),
              ),
            ),
          // Blue bubble
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: _buildContent(true),
          ),
          // Expiry + double-check
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 4, bottom: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.autoDeleteEnabled) ...[
                  Icon(Icons.timer_outlined,
                      size: 12, color: AppColors.yellow600),
                  const SizedBox(width: 3),
                  Text(
                    _formatExpiry(),
                    style: TextStyle(
                        fontSize: 11, color: AppColors.yellow600),
                  ),
                  const SizedBox(width: 6),
                ],
                const Icon(Icons.done_all,
                    size: 14, color: AppColors.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── RECEIVED (left side, dark card + avatar) ───
  Widget _buildReceivedBubble(String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, right: 48),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Sender avatar
          Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.slate700,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  widget.senderInitials,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate300,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sender name + time label
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 4),
                  child: Row(
                    children: [
                      Text(
                        widget.senderName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate400,
                        ),
                      ),
                      if (time.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          time,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.slate500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Dark bubble
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceHoverDark,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: _buildContent(false),
                ),
                // Expiry label
                if (widget.autoDeleteEnabled)
                  Padding(
                    padding:
                        const EdgeInsets.only(top: 4, left: 4, bottom: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_outlined,
                            size: 12, color: AppColors.yellow600),
                        const SizedBox(width: 3),
                        Text(
                          _formatExpiry(),
                          style: TextStyle(
                              fontSize: 11, color: AppColors.yellow600),
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Bubble content (decrypted text / loading / tap-to-decrypt) ───
  Widget _buildContent(bool isMine) {
    if (_decryptedText != null) {
      return Text(
        _decryptedText!,
        style: TextStyle(
          color: isMine ? Colors.white : AppColors.textMainDark,
          fontSize: 15,
          height: 1.4,
        ),
      );
    }
    if (_isDecrypting) {
      return SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: isMine ? Colors.white : AppColors.primary,
        ),
      );
    }
    // Sent messages are encrypted with the recipient's key — sender cannot decrypt
    if (isMine) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 14, color: Colors.white54),
          const SizedBox(width: 6),
          Text(
            'Encrypted',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }
    // Wrong passphrase — show retry prompt
    if (_decryptFailed) {
      return GestureDetector(
        onTap: _decrypt,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_reset, size: 14, color: Color(0xFFEF4444)),
            const SizedBox(width: 6),
            Text(
              'Wrong passphrase — tap to retry',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: _decrypt,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline,
            size: 14,
            color: AppColors.textSubDark,
          ),
          const SizedBox(width: 6),
          Text(
            'Tap to decrypt',
            style: TextStyle(
              color: AppColors.textSubDark,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
