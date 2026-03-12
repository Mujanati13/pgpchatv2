import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../services/pgp_service.dart';
import '../services/pin_service.dart';
import 'pin_setup_screen.dart';
import 'manage_pgp_screen.dart';
import 'auto_delete_screen.dart';
import 'device_management_screen.dart';
import 'contacts_screen.dart';
import 'settings_screen.dart';
import 'terms_screen.dart';
import 'login_screen.dart';

class AppNavigationDrawer extends StatefulWidget {
  const AppNavigationDrawer({super.key});

  @override
  State<AppNavigationDrawer> createState() => _AppNavigationDrawerState();
}

class _AppNavigationDrawerState extends State<AppNavigationDrawer> {
  String _username = 'Anonymous';
  String _fingerprint = '';
  bool _hasKey = false;
  int _sessionCount = 0;
  bool _pinEnabled = false;

  @override
  void initState() {
    super.initState();
    // Reload whenever the PGP key changes (generate / import / wipe)
    PgpService().addListener(_onKeyChanged);
    _pinEnabled = PinService().isEnabled;
    _loadDynamicData();
  }

  @override
  void dispose() {
    PgpService().removeListener(_onKeyChanged);
    super.dispose();
  }

  void _onKeyChanged() {
    if (mounted) _loadDynamicData();
  }

  Future<void> _loadDynamicData() async {
    final auth = context.read<AuthProvider>();
    final pgp = PgpService();
    final api = ApiService();

    final name = auth.username ?? 'Anonymous';
    String fp = '';
    bool hasKey = false;
    final pubKey = await pgp.publicKey;
    if (pubKey != null && pubKey.isNotEmpty) {
      hasKey = true;
      fp = pgp.getFingerprint(pubKey);
    }

    int sessions = 0;
    try {
      final result = await api.getSessions();
      final list = result['sessions'] as List? ?? [];
      sessions = list.length;
    } catch (_) {}

    if (mounted) {
      setState(() {
        _username = name;
        _fingerprint = fp;
        _hasKey = hasKey;
        _sessionCount = sessions;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Drawer(
      backgroundColor: AppColors.surfaceDark,
      width: MediaQuery.of(context).size.width * 0.85,
      child: SafeArea(
        child: Column(
          children: [
            // User Profile Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.slate800.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Avatar
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              blurRadius: 0,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          if (_fingerprint.isNotEmpty) {
                            Clipboard.setData(ClipboardData(text: _fingerprint));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Fingerprint copied')),
                            );
                          }
                        },
                        icon: const Icon(Icons.qr_code_scanner,
                            color: AppColors.slate400),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _username,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.slate800.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.key, size: 14, color: AppColors.slate400),
                        const SizedBox(width: 6),
                        Text(
                          _hasKey
                              ? (_fingerprint.isNotEmpty
                                  ? '0x${_fingerprint.substring(0, _fingerprint.length < 8 ? _fingerprint.length : 8)}...'
                                  : 'Key available')
                              : 'No key',
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'monospace',
                            color: AppColors.slate400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                    // Manage PGP Keys
                    _DrawerMenuItem(
                      icon: Icons.vpn_key,
                      label: 'Manage PGP Keys',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ManagePgpScreen()),
                        );
                      },
                    ),
                    // Contacts
                    _DrawerMenuItem(
                      icon: Icons.contacts_outlined,
                      label: 'Contacts',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ContactsScreen()),
                        );
                      },
                      trailing: Switch(
                        value: settings.contactsEnabled,
                        activeColor: AppColors.primary,
                        onChanged: (val) {
                          settings.setContactsEnabled(val);
                        },
                      ),
                    ),
                    // Auto-delete
                    _DrawerMenuItem(
                      icon: Icons.auto_delete_outlined,
                      label: 'Auto-delete Messages',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AutoDeleteScreen()),
                        );
                      },
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.slate800,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          settings.autoDeleteEnabled
                              ? '${settings.autoDeleteHours}h'
                              : 'Off',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.slate400,
                          ),
                        ),
                      ),
                    ),
                    // Devices
                    _DrawerMenuItem(
                      icon: Icons.devices_outlined,
                      label: 'Device Management',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const DeviceManagementScreen()),
                        );
                      },
                      trailing: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$_sessionCount',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // PIN Lock
                    _DrawerMenuItem(
                      icon: Icons.lock_outline,
                      label: 'PIN Lock',
                      onTap: () {},
                      trailing: Switch(
                        value: _pinEnabled,
                        activeColor: AppColors.primary,
                        onChanged: (val) async {
                          if (val) {
                            Navigator.pop(context);
                            final result = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(builder: (_) => const PinSetupScreen()),
                            );
                            if (result == true && mounted) {
                              setState(() => _pinEnabled = true);
                            }
                          } else {
                            await PinService().removePin();
                            if (mounted) setState(() => _pinEnabled = false);
                          }
                        },
                      ),
                    ),
                    // Divider
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Divider(
                        color: AppColors.slate800.withValues(alpha: 0.8),
                        height: 1,
                      ),
                    ),
                    // Settings
                    _DrawerMenuItem(
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SettingsScreen()),
                        );
                      },
                    ),
                    // Terms
                    _DrawerMenuItem(
                      icon: Icons.description_outlined,
                      label: 'Terms & Conditions',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const TermsScreen()),
                        );
                      },
                    ),
                    // Divider before logout
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Divider(
                        color: AppColors.slate800.withValues(alpha: 0.8),
                        height: 1,
                      ),
                    ),
                    // Logout
                    _DrawerMenuItem(
                      icon: Icons.logout,
                      label: 'Logout',
                      onTap: () async {
                        Navigator.pop(context);
                        await context.read<AuthProvider>().logout();
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (_) => const LoginScreen()),
                            (_) => false,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.slate800.withValues(alpha: 0.8)),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 16, color: AppColors.slate500),
                  SizedBox(width: 8),
                  Text(
                    'End-to-end Encrypted v2.4.1',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.slate500,
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

class _DrawerMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Widget? trailing;

  const _DrawerMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isActive
            ? AppColors.primary.withValues(alpha: 0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: isActive ? AppColors.primary : AppColors.slate500,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isActive ? AppColors.primary : AppColors.slate300,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
