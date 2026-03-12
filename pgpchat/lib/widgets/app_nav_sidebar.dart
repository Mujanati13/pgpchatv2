import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../services/pgp_service.dart';
import '../services/pin_service.dart';
import '../screens/pin_setup_screen.dart';
import '../screens/manage_pgp_screen.dart';
import '../screens/auto_delete_screen.dart';
import '../screens/device_management_screen.dart';
import '../screens/contacts_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/terms_screen.dart';
import '../screens/login_screen.dart';

/// Permanent sidebar for desktop / web (wide screen).
/// Renders as a fixed-width column — no Drawer, no pop.
class AppNavSidebar extends StatefulWidget {
  const AppNavSidebar({super.key});

  @override
  State<AppNavSidebar> createState() => _AppNavSidebarState();
}

class _AppNavSidebarState extends State<AppNavSidebar> {
  String _username = 'Anonymous';
  String _fingerprint = '';
  bool _hasKey = false;
  int _sessionCount = 0;
  bool _pinEnabled = false;

  @override
  void initState() {
    super.initState();
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

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border(
          right: BorderSide(color: AppColors.slate800.withValues(alpha: 0.8)),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                border: Border(
                  bottom: BorderSide(
                      color: AppColors.slate800.withValues(alpha: 0.5)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      Tooltip(
                        message: 'Copy fingerprint',
                        child: IconButton(
                          onPressed: () {
                            if (_fingerprint.isNotEmpty) {
                              Clipboard.setData(
                                  ClipboardData(text: _fingerprint));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Fingerprint copied')),
                              );
                            }
                          },
                          icon: const Icon(Icons.fingerprint,
                              color: AppColors.slate400),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _username,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
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
                        const Icon(Icons.key,
                            size: 13, color: AppColors.slate400),
                        const SizedBox(width: 5),
                        Text(
                          _hasKey
                              ? (_fingerprint.isNotEmpty
                                  ? '0x${_fingerprint.substring(0, _fingerprint.length < 8 ? _fingerprint.length : 8)}...'
                                  : 'Key available')
                              : 'No key',
                          style: const TextStyle(
                            fontSize: 12,
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

            // ── Menu ─────────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(10),
                children: [
                  _SidebarItem(
                    icon: Icons.vpn_key,
                    label: 'Manage PGP Keys',
                    onTap: () => _push(const ManagePgpScreen()),
                  ),
                  _SidebarItem(
                    icon: Icons.contacts_outlined,
                    label: 'Contacts',
                    onTap: () => _push(const ContactsScreen()),
                    trailing: Switch(
                      value: settings.contactsEnabled,
                      activeColor: AppColors.primary,
                      onChanged: (val) => settings.setContactsEnabled(val),
                    ),
                  ),
                  _SidebarItem(
                    icon: Icons.auto_delete_outlined,
                    label: 'Auto-delete',
                    onTap: () => _push(const AutoDeleteScreen()),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.slate800,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        settings.autoDeleteEnabled
                            ? '${settings.autoDeleteHours}h'
                            : 'Off',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate400,
                        ),
                      ),
                    ),
                  ),
                  _SidebarItem(
                    icon: Icons.devices_outlined,
                    label: 'Device Management',
                    onTap: () => _push(const DeviceManagementScreen()),
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
                  _SidebarItem(
                    icon: Icons.lock_outline,
                    label: 'PIN Lock',
                    onTap: () {},
                    trailing: Switch(
                      value: _pinEnabled,
                      activeColor: AppColors.primary,
                      onChanged: (val) async {
                        if (val) {
                          final result = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const PinSetupScreen()),
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
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Divider(
                      color: AppColors.slate800.withValues(alpha: 0.8),
                      height: 1,
                    ),
                  ),
                  _SidebarItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () => _push(const SettingsScreen()),
                  ),
                  _SidebarItem(
                    icon: Icons.description_outlined,
                    label: 'Terms & Conditions',
                    onTap: () => _push(const TermsScreen()),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Divider(
                      color: AppColors.slate800.withValues(alpha: 0.8),
                      height: 1,
                    ),
                  ),
                  _SidebarItem(
                    icon: Icons.logout,
                    label: 'Logout',
                    destructive: true,
                    onTap: () async {
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

            // ── Footer ───────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                      color: AppColors.slate800.withValues(alpha: 0.8)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline,
                      size: 14, color: AppColors.slate500),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'End-to-end Encrypted v2.4.1',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate500,
                      ),
                      overflow: TextOverflow.ellipsis,
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

// ── Sidebar menu item ─────────────────────────────────────────────────────────

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool destructive;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : AppColors.slate400;
    final textColor = destructive ? AppColors.error : AppColors.slate300;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: AppColors.primary.withValues(alpha: 0.08),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(icon, size: 21, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textColor,
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
