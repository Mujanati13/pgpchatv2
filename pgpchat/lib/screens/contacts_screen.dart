import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    try {
      final result = await _api.getContacts();
      setState(() {
        _contacts = List<Map<String, dynamic>>.from(
            result['contacts'] as List? ?? []);
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddContactDialog() async {
    final userId = await showDialog<String>(
      context: context,
      builder: (ctx) => const _AddContactDialog(),
    );

    if (userId != null) {
      try {
        await _api.addContact(userId);
        _loadContacts();
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)),
          );
        }
      }
    }
  }

  Future<void> _removeContact(String contactId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Contact',
            style: TextStyle(color: AppColors.textMainDark)),
        content: const Text(
          'Are you sure you want to remove this contact?',
          style: TextStyle(color: AppColors.textSubDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSubDark)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _api.removeContact(contactId);
      _loadContacts();
    }
  }

  Future<void> _toggleBlock(String contactId, bool currentlyBlocked) async {
    await _api.toggleBlock(contactId, !currentlyBlocked);
    _loadContacts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: _showAddContactDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _contacts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.contacts_outlined,
                          size: 64, color: AppColors.textSubDark.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      const Text(
                        'No contacts yet',
                        style: TextStyle(
                          color: AppColors.textSubDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add contacts to start messaging',
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
                  onRefresh: _loadContacts,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _contacts.length,
                    separatorBuilder: (_, __) => const Divider(
                      color: AppColors.borderDark,
                      height: 1,
                      indent: 72,
                    ),
                    itemBuilder: (context, index) {
                      final contact = _contacts[index];
                      final isBlocked = contact['is_blocked'] == 1 ||
                          contact['is_blocked'] == true;
                      final username =
                          contact['contact_username'] as String? ?? 'Unknown';

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: isBlocked
                              ? AppColors.error.withValues(alpha: 0.2)
                              : AppColors.primary.withValues(alpha: 0.15),
                          child: Text(
                            username.isNotEmpty
                                ? username[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: isBlocked
                                  ? AppColors.error
                                  : AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        title: Text(
                          username,
                          style: TextStyle(
                            color: isBlocked
                                ? AppColors.textSubDark
                                : AppColors.textMainDark,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            decoration: isBlocked
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        subtitle: isBlocked
                            ? const Text('Blocked',
                                style: TextStyle(
                                    color: AppColors.error, fontSize: 12))
                            : null,
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert,
                              color: AppColors.textSubDark, size: 20),
                          color: AppColors.surfaceDark,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          onSelected: (value) {
                            if (value == 'block') {
                              _toggleBlock(
                                  contact['id'].toString(), isBlocked);
                            } else if (value == 'remove') {
                              _removeContact(contact['id'].toString());
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'block',
                              child: Row(
                                children: [
                                  Icon(
                                    isBlocked
                                        ? Icons.check_circle_outline
                                        : Icons.block,
                                    size: 18,
                                    color: isBlocked
                                        ? AppColors.success
                                        : AppColors.warning,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isBlocked ? 'Unblock' : 'Block',
                                    style: const TextStyle(
                                        color: AppColors.textMainDark),
                                  ),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'remove',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline,
                                      size: 18, color: AppColors.error),
                                  SizedBox(width: 8),
                                  Text('Remove',
                                      style:
                                          TextStyle(color: AppColors.error)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// Separate StatefulWidget so the controller is disposed with the widget,
// not prematurely after showDialog returns during the close animation.
class _AddContactDialog extends StatefulWidget {
  const _AddContactDialog();

  @override
  State<_AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<_AddContactDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Add Contact',
          style: TextStyle(color: AppColors.textMainDark)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: const TextStyle(color: AppColors.textMainDark),
        decoration: InputDecoration(
          hintText: 'Enter username',
          hintStyle: const TextStyle(color: AppColors.textSubDark),
          filled: true,
          fillColor: AppColors.backgroundDark,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.borderDark),
          ),
        ),
        onSubmitted: (text) {
          final t = text.trim();
          if (t.isNotEmpty) Navigator.pop(context, t);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.textSubDark)),
        ),
        TextButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isNotEmpty) Navigator.pop(context, text);
          },
          child: const Text('Add', style: TextStyle(color: AppColors.primary)),
        ),
      ],
    );
  }
}
