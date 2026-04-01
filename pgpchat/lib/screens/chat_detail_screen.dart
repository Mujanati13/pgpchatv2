import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../services/pgp_service.dart';
import '../services/screenshot_service.dart';
import '../services/push_notification_service.dart';
import '../widgets/responsive_center.dart';
import 'auto_delete_screen.dart';

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
  bool _isUploadingImage = false;
  bool _isClearingChat = false;
  bool _isBlocked = false;
  bool _isTogglingBlock = false;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _pgp = PgpService();
  final _api = ApiService();
  final _screenshotService = ScreenshotService();
  String? _passphrase;
  String _fingerprint = '';
  String? _otherPublicKey;
  bool _isCheckingKey = true; // true until _fetchLatestPublicKey completes
  Timer? _countdownTimer;
  StreamSubscription<String>? _incomingMessageSub;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _otherPublicKey = widget.otherPublicKey; // fix: use widget value
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<ChatProvider>().startMessagePolling(widget.otherUserId);
      context.read<ChatProvider>().markRead(widget.otherUserId);
      PushNotificationService().clearNotificationBadge();
      await _loadBlockStatus();
      await _fetchLatestPublicKey();
      _loadFingerprint();
      _startCountdown();
    });

    _incomingMessageSub =
        PushNotificationService().incomingMessageStream.listen((senderId) async {
      if (!mounted || _disposed) return;
      if (senderId != widget.otherUserId) return;

      await context.read<ChatProvider>().loadMessages(widget.otherUserId);
      context.read<ChatProvider>().markRead(widget.otherUserId);

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });

    // Listen for screenshot attempts (iOS callback; Android uses FLAG_SECURE)
    _screenshotService.startListening(onDetected: _onScreenshotDetected);
  }

  Future<void> _fetchLatestPublicKey() async {
    try {
      final key = await _api.getUserPublicKey(widget.otherUserId);
      if (mounted) {
        setState(() {
          if (key != null && key.isNotEmpty) _otherPublicKey = key;
          _isCheckingKey = false;
        });
      }
    } catch (_) {
      // fall back to the key passed from the conversation list
      if (mounted) setState(() => _isCheckingKey = false);
    }
  }

  Future<void> _loadFingerprint() async {
    if (_otherPublicKey != null && _otherPublicKey!.isNotEmpty) {
      final fp = _pgp.getFingerprint(_otherPublicKey!);
      if (mounted) setState(() => _fingerprint = fp);
    }
  }

  Future<void> _loadBlockStatus() async {
    try {
      final result = await _api.getContacts();
      final contacts = List<Map<String, dynamic>>.from(
        result['contacts'] as List? ?? [],
      );
      final matched = contacts.where((c) {
        return c['contact_user_id']?.toString() == widget.otherUserId;
      }).toList();
      if (!mounted) return;
      if (matched.isEmpty) {
        setState(() => _isBlocked = false);
        return;
      }
      final raw = matched.first['is_blocked'];
      setState(() => _isBlocked = raw == 1 || raw == true);
    } catch (_) {}
  }

  Future<void> _toggleBlockUser() async {
    final willBlock = !_isBlocked;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          willBlock ? 'Block user?' : 'Unblock user?',
          style: const TextStyle(color: AppColors.textMainDark),
        ),
        content: Text(
          willBlock
              ? 'You will stop receiving messages from ${widget.otherUsername} and you will not be able to send messages until unblocked.'
              : 'You can send and receive messages with ${widget.otherUsername} again.',
          style: const TextStyle(color: AppColors.textSubDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSubDark),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              willBlock ? 'Block' : 'Unblock',
              style: TextStyle(
                color: willBlock ? AppColors.error : AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isTogglingBlock = true);
    try {
      await _api.toggleBlockByUser(widget.otherUserId, willBlock);
      if (!mounted) return;
      setState(() => _isBlocked = willBlock);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            willBlock
                ? '${widget.otherUsername} blocked'
                : '${widget.otherUsername} unblocked',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update block status')),
      );
    } finally {
      if (mounted) setState(() => _isTogglingBlock = false);
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
    _incomingMessageSub?.cancel();
    _screenshotService.stopListening();
    context.read<ChatProvider>().stopMessagePolling();
    _countdownTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScreenshotDetected() {
    if (_disposed) return;
    // Send screenshot alert to the other user in this chat
    ApiService().sendScreenshotAlert(widget.otherUserId);
    // Reload messages so the alert appears in the chat
    if (mounted) {
      context.read<ChatProvider>().loadMessages(widget.otherUserId);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);

    await _refreshRecipientPublicKeyBeforeSend();
    if (!mounted || _disposed) return;

    if (_isCheckingKey) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Checking recipient PGP key...')),
      );
      return;
    }

    if (_otherPublicKey == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Recipient has no public key')),
      );
      return;
    }

    try {
      final encrypted = await _pgp.encrypt(text, _otherPublicKey!);
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
          await context.read<ChatProvider>().loadMessages(widget.otherUserId);
          // Scroll to bottom (index 0 = newest with reverse:true)
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        }
      }
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Message could not be encrypted. Check the recipient key and try again.',
          ),
        ),
      );
    }
  }

  Future<void> _pickAndSendImage() async {
    // Capture messenger before any async gap to avoid deactivated-widget error
    final messenger = ScaffoldMessenger.of(context);

    await _refreshRecipientPublicKeyBeforeSend();
    if (!mounted || _disposed) return;

    if (_otherPublicKey == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Recipient has no public key')),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
      allowCompression:
          false, // avoid temp-file write that causes Permission denied
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    const maxSize = 5 * 1024 * 1024; // 5 MB
    if (bytes.lengthInBytes > maxSize) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Image must be smaller than 5 MB')),
      );
      return;
    }

    final ext = (file.extension ?? 'jpg').toLowerCase();
    final filename = file.name;

    setState(() => _isUploadingImage = true);
    // Scroll to bottom so the skeleton is visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });

    try {
      // 1. Upload image file to server
      final serverFilename = await ApiService().uploadImage(bytes, filename);

      // 2. Encrypt only the small reference string
      final payload = '[IMAGE:$serverFilename]';
      final encrypted = await _pgp.encrypt(payload, _otherPublicKey!);
      if (!mounted) return;

      // 3. Send encrypted reference as message
      final success = await context.read<ChatProvider>().sendMessage(
        recipientId: widget.otherUserId,
        encryptedBody: encrypted,
      );
      if (success && mounted) {
        await context.read<ChatProvider>().loadMessages(widget.otherUserId);
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      }
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Image could not be sent. Check your connection and try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _refreshRecipientPublicKeyBeforeSend() async {
    try {
      final latest = await _api.getUserPublicKey(widget.otherUserId);
      if (latest == null || latest.isEmpty || latest == _otherPublicKey) return;

      if (!mounted || _disposed) return;
      setState(() {
        _otherPublicKey = latest;
        _fingerprint = _pgp.getFingerprint(latest);
      });
    } catch (_) {
      // Best-effort refresh. Existing key (if any) remains in use.
    }
  }

  // Returns null on cancel, '\x00FAIL:reason' on error, decrypted text on success.
  Future<String?> _decryptMessage(String encryptedBody) async {
    final privateKey = await _pgp.privateKey;
    if (privateKey == null || privateKey.trim().isEmpty) {
      return '\x00FAIL:Cannot decrypt on this device because your private key is missing. Open Manage PGP and import your private key backup.';
    }

    if (_passphrase == null) {
      _passphrase = await _showPassphraseDialog();
      if (_passphrase == null) return null; // user cancelled
    }
    try {
      final result = await _pgp.decrypt(encryptedBody.trim(), _passphrase!);
      return result.trim();
    } catch (e) {
      final err = e.toString().toLowerCase();
      debugPrint('[Decrypt] Error: $e');
      if (err.contains('passphrase') ||
          err.contains('password') ||
          err.contains('checksum') ||
          err.contains('s2k')) {
        _passphrase = null;
        return '\x00FAIL';
      }
      if (err.contains('incorrect key') || err.contains('no valid openpgp')) {
        return '\x00FAIL:Encrypted with a different key';
      }
      return '\x00FAIL:Unable to decrypt this message with the current key and passphrase';
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
        title: const Text(
          'Enter Passphrase',
          style: TextStyle(color: AppColors.textMainDark),
        ),
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
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSubDark),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text(
              'Unlock',
              style: TextStyle(color: AppColors.primary),
            ),
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
    final settings = context.read<SettingsProvider>();
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
            // ── Encryption Info ──
            ListTile(
              leading: const Icon(Icons.lock_outline, color: AppColors.primary),
              title: const Text(
                'Encryption Info',
                style: TextStyle(color: AppColors.textMainDark),
              ),
              subtitle: const Text(
                'End-to-end PGP encrypted',
                style: TextStyle(color: AppColors.textSubDark, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showEncryptionInfoDialog();
              },
            ),
            // ── Auto-Delete ──
            ListTile(
              leading: Icon(Icons.timer_outlined, color: AppColors.yellow600),
              title: const Text(
                'Auto-Delete',
                style: TextStyle(color: AppColors.textMainDark),
              ),
              subtitle: Text(
                settings.autoDeleteEnabled
                    ? 'Active — ${settings.autoDeleteHours}h'
                    : 'Disabled',
                style: const TextStyle(
                  color: AppColors.textSubDark,
                  fontSize: 12,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AutoDeleteScreen()),
                );
              },
            ),
            // ── Clear Chat ──
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text(
                'Clear Chat',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _confirmClearChat();
              },
            ),
            // ── Block / Unblock ──
            ListTile(
              leading: Icon(
                _isBlocked ? Icons.check_circle_outline : Icons.block,
                color: _isBlocked ? AppColors.success : AppColors.warning,
              ),
              title: Text(
                _isBlocked ? 'Unblock User' : 'Block User',
                style: TextStyle(
                  color: _isBlocked ? AppColors.success : AppColors.warning,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _toggleBlockUser();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showEncryptionInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.lock, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text(
              'Encryption Info',
              style: TextStyle(color: AppColors.textMainDark, fontSize: 17),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Messages in this chat are end-to-end encrypted using PGP (Pretty Good Privacy).',
              style: TextStyle(
                color: AppColors.textSubDark,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (_fingerprint.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Recipient Fingerprint:',
                style: TextStyle(color: AppColors.slate400, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                _fingerprint,
                style: const TextStyle(
                  color: AppColors.textMainDark,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Clear Chat',
          style: TextStyle(color: AppColors.textMainDark),
        ),
        content: Text(
          'Delete all messages with ${widget.otherUsername}? This cannot be undone.',
          style: const TextStyle(color: AppColors.textSubDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSubDark),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Clear',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isClearingChat = true);
      try {
        await ApiService().clearChat(widget.otherUserId);
        if (mounted) {
          context.read<ChatProvider>().clearMessages();
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Failed to clear chat')));
        }
      } finally {
        if (mounted) setState(() => _isClearingChat = false);
      }
    }
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
      body: ResponsiveScaffoldBody(
        child: Stack(
          children: [
            SafeArea(
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
                                  const Icon(
                                    Icons.lock,
                                    size: 14,
                                    color: AppColors.slate400,
                                  ),
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
                                      _fingerprint.length >= 8
                                          ? '${_fingerprint.substring(0, 4)}...${_fingerprint.substring(_fingerprint.length - 4)}'
                                          : _fingerprint,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                        color: AppColors.slate500,
                                      ),
                                    ),
                                    if (autoDelete)
                                      const Text(
                                        ' · ',
                                        style: TextStyle(
                                          color: AppColors.slate500,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                  if (autoDelete) ...[
                                    Icon(
                                      Icons.timer_outlined,
                                      size: 13,
                                      color: AppColors.yellow600,
                                    ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
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
                          Icon(
                            Icons.timer,
                            size: 15,
                            color: AppColors.yellow600,
                          ),
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
                              color: AppColors.primary,
                            ),
                          )
                        : chat.messages.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            controller: _scrollController,
                            reverse: true,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount:
                                chat.messages.length +
                                1 +
                                (_isUploadingImage ? 1 : 0),
                            itemBuilder: (context, index) {
                              // Skeleton bubble at index 0 when uploading
                              if (_isUploadingImage && index == 0) {
                                return const _ImageUploadSkeleton();
                              }
                              final msgIndex = _isUploadingImage
                                  ? index - 1
                                  : index;
                              // "Today" divider at end (top visually)
                              if (msgIndex == chat.messages.length) {
                                return _buildDateDivider('Today');
                              }
                              final msg = chat.messages[msgIndex];
                              final isMine =
                                  msg['sender_id'] != widget.otherUserId;

                              // Screenshot alert — render as system message
                              if (msg['signature'] == '__SCREENSHOT_ALERT__') {
                                return _ScreenshotAlertBubble(
                                  text: msg['encrypted_body'] as String? ?? '',
                                  timestamp: msg['created_at'] as String? ?? '',
                                );
                              }

                              return _MessageBubble(
                                encryptedBody:
                                    msg['encrypted_body'] as String? ?? '',
                                isMine: isMine,
                                timestamp: msg['created_at'] as String? ?? '',
                                senderName: widget.otherUsername,
                                senderInitials: _getInitials(
                                  widget.otherUsername,
                                ),
                                autoDeleteEnabled: autoDelete,
                                autoDeleteHours: hours,
                                messageCreatedAt: msg['created_at']?.toString(),
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
                          Icon(
                            Icons.verified_user_outlined,
                            size: 14,
                            color: AppColors.slate500,
                          ),
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

                  // ─── No PGP key warning ───
                  if (!_isCheckingKey &&
                      (_otherPublicKey == null || _otherPublicKey!.isEmpty))
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFF59E0B),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'This user has no PGP key — messages cannot be sent until they set one up.',
                              style: TextStyle(
                                color: Color(0xFFF59E0B),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (_isBlocked)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.block, color: AppColors.error, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'You blocked this user. Unblock to send messages.',
                              style: TextStyle(
                                color: AppColors.error,
                                fontSize: 12,
                                height: 1.4,
                              ),
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
                              onPressed: _isBlocked ? null : _pickAndSendImage,
                              icon: const Icon(Icons.add, size: 22),
                              color: _isBlocked
                                  ? AppColors.slate600
                                  : AppColors.slate400,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Text field (no mic)
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.backgroundDark,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: AppColors.slate800.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              child: TextField(
                                controller: _messageController,
                                enabled: !_isBlocked,
                                style: const TextStyle(
                                  color: AppColors.textMainDark,
                                  fontSize: 15,
                                ),
                                maxLines: 4,
                                minLines: 1,
                                decoration: InputDecoration(
                                  hintText: _isBlocked
                                      ? 'User is blocked'
                                      : autoDelete
                                      ? 'Encrypted message...'
                                      : 'Message',
                                  hintStyle: const TextStyle(
                                    color: AppColors.slate500,
                                    fontSize: 15,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                ),
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
                              onPressed: _isBlocked ? null : _sendMessage,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ─── Clear-chat loading overlay ───
            if (_isClearingChat)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: 16),
                        Text(
                          'Clearing chat…',
                          style: TextStyle(
                            color: AppColors.textMainDark,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_isTogglingBlock)
              Container(
                color: Colors.black38,
                child: const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
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
          Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: AppColors.textSubDark.withValues(alpha: 0.5),
          ),
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
              height: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
              height: 1,
            ),
          ),
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
  String _failReason = '';

  String _friendlyFailReason(String raw) {
    final text = raw.trim();
    final lower = text.toLowerCase();

    if (lower.contains('no private key') || lower.contains('private key is missing')) {
      return 'Cannot decrypt here: private key missing. Import your private key in Manage PGP, then tap to retry.';
    }

    if (lower.contains('different key') || lower.contains('incorrect key')) {
      return 'Cannot decrypt: message was encrypted for a different key pair. Sync/import keys on both accounts and ask sender to resend.';
    }

    if (lower.contains('wrong passphrase') || lower.contains('passphrase')) {
      return 'Wrong passphrase. Enter your PGP passphrase again and tap to retry.';
    }

    return 'Decryption failed. Check your passphrase and key, then tap to retry.';
  }

  Future<void> _decrypt() async {
    setState(() {
      _isDecrypting = true;
      _decryptFailed = false;
      _failReason = '';
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
        _failReason = 'Wrong passphrase';
      });
    } else if (text.startsWith('\x00FAIL:')) {
      // decryption error (not passphrase related)
      setState(() {
        _isDecrypting = false;
        _decryptFailed = true;
        _failReason = text.substring(6); // strip '\x00FAIL:' prefix
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
                style: const TextStyle(fontSize: 11, color: AppColors.slate500),
              ),
            ),
          // Blue bubble
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  Icon(
                    Icons.timer_outlined,
                    size: 12,
                    color: AppColors.yellow600,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    _formatExpiry(),
                    style: TextStyle(fontSize: 11, color: AppColors.yellow600),
                  ),
                  const SizedBox(width: 6),
                ],
                const Icon(Icons.done_all, size: 14, color: AppColors.primary),
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
                    horizontal: 14,
                    vertical: 10,
                  ),
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
                    padding: const EdgeInsets.only(top: 4, left: 4, bottom: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 12,
                          color: AppColors.yellow600,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _formatExpiry(),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.yellow600,
                          ),
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

  // ─── Bubble content (decrypted text / image / loading / tap-to-decrypt) ───
  Widget _buildContent(bool isMine) {
    if (_decryptedText != null) {
      // Detect image payload: [IMAGE:filename]
      if (_decryptedText!.startsWith('[IMAGE:')) {
        final closeBracket = _decryptedText!.indexOf(']');
        if (closeBracket > 0) {
          final filename = _decryptedText!.substring(7, closeBracket);
          return _NetworkImage(filename: filename);
        }
      }
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
    // Decryption failed — show error and retry prompt
    if (_decryptFailed) {
      final failMessage = _friendlyFailReason(_failReason);
      return GestureDetector(
        onTap: _decrypt,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_reset,
                  size: 14,
                  color: Color(0xFFEF4444),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    failMessage,
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
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
          Icon(Icons.lock_outline, size: 14, color: AppColors.textSubDark),
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

// ─── Authenticated network image widget ───
class _NetworkImage extends StatefulWidget {
  final String filename;
  const _NetworkImage({required this.filename});

  @override
  State<_NetworkImage> createState() => _NetworkImageState();
}

class _NetworkImageState extends State<_NetworkImage> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _fetchImage();
  }

  Future<void> _fetchImage() async {
    try {
      final api = ApiService();
      final url = await api.getImageUrl(widget.filename);
      final headers = await api.getAuthHeaders();
      final response = await http.get(Uri.parse(url), headers: headers);
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _bytes = response.bodyBytes;
          _loading = false;
        });
      } else {
        setState(() {
          _error = true;
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        width: 220,
        height: 150,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      );
    }
    if (_error || _bytes == null) {
      return const SizedBox(
        width: 220,
        height: 60,
        child: Center(
          child: Text(
            'Image unavailable',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.memory(
        _bytes!,
        fit: BoxFit.cover,
        width: 220,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) =>
            const Text('Image error', style: TextStyle(color: Colors.white54)),
      ),
    );
  }
}

// ─── Skeleton bubble shown while image is uploading ───
class _ImageUploadSkeleton extends StatefulWidget {
  const _ImageUploadSkeleton();

  @override
  State<_ImageUploadSkeleton> createState() => _ImageUploadSkeletonState();
}

class _ImageUploadSkeletonState extends State<_ImageUploadSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _shimmer = Tween<double>(
      begin: 0.3,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Shimmer image placeholder
          AnimatedBuilder(
            animation: _shimmer,
            builder: (_, __) => Container(
              width: 220,
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.primary.withValues(alpha: _shimmer.value),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_outlined,
                    size: 32,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 80,
                    height: 3,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white70,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Uploading…',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Screenshot alert system message (centered) ───
class _ScreenshotAlertBubble extends StatelessWidget {
  final String text;
  final String timestamp;

  const _ScreenshotAlertBubble({required this.text, required this.timestamp});

  String _formatTime(String ts) {
    try {
      final dt = DateTime.parse(ts).toLocal();
      final h = dt.hour;
      final m = dt.minute.toString().padLeft(2, '0');
      final ampm = h >= 12 ? 'PM' : 'AM';
      final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$h12:$m $ampm';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0x33EF4444), // translucent red
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x55EF4444), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: Color(0xFFEF4444),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (_formatTime(timestamp).isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  _formatTime(timestamp),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0x99EF4444),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
