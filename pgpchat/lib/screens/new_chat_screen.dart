import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'chat_detail_screen.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _api = ApiService();
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    setState(() => _query = value.trim());
    if (value.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _isLoading = true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value.trim()));
  }

  Future<void> _search(String q) async {
    try {
      final result = await _api.searchUsers(q);
      if (mounted) {
        setState(() {
          _results = List<Map<String, dynamic>>.from(result['users'] as List? ?? []);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.slate300),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'New Chat',
          style: TextStyle(
            color: AppColors.textMainDark,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _controller,
              autofocus: true,
              style: const TextStyle(color: AppColors.textMainDark),
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: 'Search by username…',
                hintStyle: const TextStyle(color: AppColors.slate500),
                prefixIcon: const Icon(Icons.search, color: AppColors.slate500),
                suffixIcon: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, color: AppColors.slate500),
                            onPressed: () {
                              _controller.clear();
                              _onChanged('');
                            },
                          )
                        : null,
                filled: true,
                fillColor: AppColors.surfaceDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          const Divider(height: 1, color: AppColors.borderDark),

          // Results / empty states
          Expanded(
            child: _query.length < 2
                ? _buildHint()
                : _results.isEmpty && !_isLoading
                    ? _buildNoResults()
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final user = _results[index];
                          final username = user['username'] as String? ?? '';
                          final userId = user['id']?.toString() ?? '';
                          final publicKey = user['public_key'] as String?;
                          return ListTile(
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatDetailScreen(
                                    otherUserId: userId,
                                    otherUsername: username,
                                    otherPublicKey: publicKey,
                                  ),
                                ),
                              );
                            },
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.15),
                              child: Text(
                                _getInitials(username),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            title: Text(
                              username,
                              style: const TextStyle(
                                color: AppColors.textMainDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              publicKey != null && publicKey.isNotEmpty
                                  ? 'Has PGP key'
                                  : 'No PGP key',
                              style: TextStyle(
                                color: publicKey != null && publicKey.isNotEmpty
                                    ? AppColors.success
                                    : AppColors.textSubDark,
                                fontSize: 12,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: AppColors.slate600,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHint() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_outlined,
              size: 56, color: AppColors.slate600),
          const SizedBox(height: 16),
          const Text(
            'Search for a user',
            style: TextStyle(
                color: AppColors.textMainDark,
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Type at least 2 characters\nto find someone by username.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSubDark, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_outlined, size: 56, color: AppColors.slate600),
          const SizedBox(height: 16),
          Text(
            'No users found for "$_query"',
            style: const TextStyle(
                color: AppColors.textSubDark, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
