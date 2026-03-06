import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import 'navigation_drawer_screen.dart';
import 'chat_detail_screen.dart';
import 'new_chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  String _searchQuery = '';
  bool _showSearch = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().startConversationPolling();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void deactivate() {
    context.read<ChatProvider>().stopConversationPolling();
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      drawer: const AppNavigationDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              child: Row(
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      icon: const Icon(Icons.menu, size: 24),
                      color: AppColors.slate300,
                      splashRadius: 24,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Secure Chats',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.015,
                        color: AppColors.textMainDark,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showSearch = !_showSearch;
                        if (!_showSearch) {
                          _searchQuery = '';
                          _searchController.clear();
                        }
                      });
                    },
                    icon: Icon(_showSearch ? Icons.close : Icons.search, size: 24),
                    color: AppColors.slate300,
                    splashRadius: 24,
                  ),
                ],
              ),
            ),
            // Chat List
            if (_showSearch)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search chats...',
                    hintStyle: const TextStyle(color: AppColors.slate500),
                    filled: true,
                    fillColor: AppColors.surfaceDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    prefixIcon: const Icon(Icons.search, color: AppColors.slate500),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                ),
              ),
            Expanded(
              child: chat.isLoading && chat.conversations.isEmpty
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary))
                  : chat.conversations.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline,
                                  size: 64,
                                  color: AppColors.textSubDark
                                      .withValues(alpha: 0.5)),
                              const SizedBox(height: 16),
                              const Text(
                                'No conversations yet',
                                style: TextStyle(
                                  color: AppColors.textSubDark,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Start a new encrypted chat',
                                style: TextStyle(
                                  color: AppColors.textSubDark,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: () =>
                              chat.loadConversations(),
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 80),
                            itemCount: chat.conversations.length,
                            itemBuilder: (context, index) {
                              final conv = chat.conversations[index];
                              final username =
                                  conv['other_username']?.toString() ?? 'Unknown';
                              if (_searchQuery.isNotEmpty &&
                                  !username.toLowerCase().contains(_searchQuery)) {
                                return const SizedBox.shrink();
                              }
                              final rawUnread = conv['unread_count'];
                              final unread = rawUnread is int
                                  ? rawUnread
                                  : (rawUnread is num
                                      ? rawUnread.toInt()
                                      : int.tryParse(
                                              rawUnread?.toString() ?? '') ??
                                          0);
                              final autoDelete = context.read<SettingsProvider>().autoDeleteEnabled;
                              const lastMsgText = 'Encrypted message';
                              return _ChatItem(
                                name: username,
                                message: lastMsgText,
                                time: _formatConvTime(
                                    conv['last_message_at']?.toString()),
                                avatarColor: _avatarColor(index),
                                avatarLetter: username.isNotEmpty
                                    ? username[0].toUpperCase()
                                    : '?',
                                showLock: true,
                                hasTimer: autoDelete,
                                timerActive: autoDelete,
                                unreadCount: unread,
                                isHighlighted: unread > 0,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatDetailScreen(
                                        otherUserId:
                                            conv['other_user_id'].toString(),
                                        otherUsername: username,
                                        otherPublicKey:
                                            conv['other_public_key']
                                                as String?,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NewChatScreen()),
          );
        },
        backgroundColor: AppColors.primary,
        elevation: 6,
        child: const Icon(Icons.edit_square, color: Colors.white, size: 28),
      ),
    );
  }

  String _formatConvTime(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      if (diff.inDays == 1) return 'Yesterday';
      return '${dt.month}/${dt.day}';
    } catch (_) {
      return '';
    }
  }

  Color _avatarColor(int index) {
    const colors = [
      Color(0xFF6366F1),
      Color(0xFF8B5CF6),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFF3B82F6),
    ];
    return colors[index % colors.length];
  }
}

class _ChatItem extends StatelessWidget {
  final String name;
  final String message;
  final String time;
  final Color avatarColor;
  final String avatarLetter;
  final bool hasTimer;
  final bool timerActive;
  final int unreadCount;
  final bool isHighlighted;
  final bool showLock;
  final bool showDoubleCheck;
  final VoidCallback? onTap;

  const _ChatItem({
    required this.name,
    required this.message,
    required this.time,
    required this.avatarColor,
    required this.avatarLetter,
    this.hasTimer = false,
    this.timerActive = false,
    this.unreadCount = 0,
    this.isHighlighted = false,
    this.showLock = false,
    this.showDoubleCheck = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isHighlighted
          ? AppColors.primary.withValues(alpha: 0.1)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 28,
                backgroundColor: avatarColor,
                child: Text(
                  avatarLetter,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isHighlighted
                                  ? AppColors.primary
                                  : AppColors.textMainDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (hasTimer)
                          Icon(
                            Icons.timer_outlined,
                            size: 14,
                            color: timerActive
                                ? AppColors.primary
                                : AppColors.slate400,
                          ),
                        if (hasTimer) const SizedBox(width: 4),
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isHighlighted
                                ? AppColors.primary
                                : AppColors.slate400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (showLock) ...[
                          const Icon(Icons.lock_outline,
                              size: 16, color: AppColors.slate400),
                          const SizedBox(width: 4),
                        ],
                        if (showDoubleCheck) ...[
                          const Icon(Icons.done_all,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            message,
                            style: TextStyle(
                              fontSize: 14,
                              color: isHighlighted
                                  ? AppColors.slate300
                                  : AppColors.slate400,
                              fontWeight: isHighlighted
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (unreadCount > 0)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
