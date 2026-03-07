import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  State<DeviceManagementScreen> createState() =>
      _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      final result = await _api.getSessions();
      setState(() {
        _sessions = List<Map<String, dynamic>>.from(
            result['sessions'] as List? ?? []);
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() => _isLoading = false);
      if (e.statusCode == 401) {
        _handleSessionExpired();
      } else {
        _showError('Failed to load sessions: ${e.message}');
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _terminateSession(String sessionId) async {
    try {
      await _api.terminateSession(sessionId);
      _loadSessions();
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        _handleSessionExpired();
      } else {
        _showError('Failed to terminate session: ${e.message}');
      }
    }
  }

  Future<void> _terminateAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Terminate All Sessions',
            style: TextStyle(color: AppColors.textMainDark)),
        content: const Text(
          'This will log you out of all devices except this one.',
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
            child: const Text('Terminate All',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _api.terminateAllSessions();
        _loadSessions();
      } on ApiException catch (e) {
        if (e.statusCode == 401) {
          _handleSessionExpired();
        } else {
          _showError('Failed to terminate sessions: ${e.message}');
        }
      }
    }
  }

  void _handleSessionExpired() {
    if (!mounted) return;
    context.read<AuthProvider>().logout();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentSession =
        _sessions.where((s) => s['isCurrent'] == true).toList();
    final otherSessions =
        _sessions.where((s) => s['isCurrent'] != true).toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Container(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                border: Border(
                  bottom: BorderSide(color: AppColors.borderDark),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 22),
                    color: AppColors.primary,
                  ),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: 40),
                      child: Text(
                        'Device Management',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.015,
                          color: AppColors.textMainDark,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary))
                  : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current Device Section
                    if (currentSession.isNotEmpty) ...[
                      const Text(
                        'CURRENT DEVICE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: AppColors.textSubDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _CurrentDeviceCard(
                        deviceName:
                            currentSession.first['device_name'] as String? ??
                                'This Device',
                        onLogout: () {
                          final id = currentSession.first['id']?.toString();
                          if (id != null) _terminateSession(id);
                        },
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Active Sessions Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ACTIVE SESSIONS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                            color: AppColors.textSubDark,
                          ),
                        ),
                        TextButton(
                          onPressed: _terminateAll,
                          child: const Text(
                            'Terminate All',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...otherSessions.map((session) {
                      final deviceName =
                          session['device_name'] as String? ?? 'Unknown Device';
                      final lastActive = session['last_active'] as String? ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _SessionItem(
                          icon: _deviceIcon(deviceName),
                          name: deviceName,
                          lastActive: 'Last active: ${_formatAge(lastActive)}',
                          location: 'Session #${session['id']}',
                          onTerminate: () {
                            final id = session['id']?.toString();
                            if (id != null) _terminateSession(id);
                          },
                        ),
                      );
                    }),
                    if (otherSessions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No other active sessions',
                            style: TextStyle(
                              color: AppColors.textSubDark,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),

                    // Security Info
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.security, size: 20, color: AppColors.primary),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'For your security, old sessions are automatically terminated after 30 days of inactivity. All connections use PGP encryption.',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSubDark,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _deviceIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('iphone') || lower.contains('android') ||
        lower.contains('phone') || lower.contains('mobile')) {
      return Icons.smartphone;
    }
    if (lower.contains('ipad') || lower.contains('tablet')) {
      return Icons.tablet_android;
    }
    if (lower.contains('mac') || lower.contains('laptop')) {
      return Icons.laptop_mac;
    }
    return Icons.desktop_windows;
  }

  String _formatAge(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      return '${diff.inDays} days ago';
    } catch (_) {
      return 'Unknown';
    }
  }
}

class _CurrentDeviceCard extends StatelessWidget {
  final String deviceName;
  final VoidCallback onLogout;

  const _CurrentDeviceCard({
    required this.deviceName,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Stack(
        children: [
          // Left accent bar
          Positioned(
            left: -16,
            top: -16,
            bottom: -16,
            child: Container(width: 4, color: AppColors.primary),
          ),
          Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.smartphone,
                      size: 24,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'This Device',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMainDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Online now',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSubDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 14, color: AppColors.textSubDark),
                            SizedBox(width: 4),
                            Text(
                              'IP Obfuscated',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSubDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Logout this device'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(
                      color: Colors.red.withValues(alpha: 0.2),
                    ),
                    backgroundColor: Colors.red.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionItem extends StatelessWidget {
  final IconData icon;
  final String name;
  final String lastActive;
  final String location;
  final VoidCallback? onTerminate;

  const _SessionItem({
    required this.icon,
    required this.name,
    required this.lastActive,
    required this.location,
    this.onTerminate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.borderDark,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: AppColors.textSubDark),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMainDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  lastActive,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSubDark,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        size: 14, color: AppColors.textSubDark),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSubDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onTerminate,
            icon: const Icon(Icons.logout, size: 20),
            color: AppColors.textSubDark,
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}
