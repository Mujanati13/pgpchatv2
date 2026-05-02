import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_center.dart';
import '../services/pgp_service.dart';
import '../services/api_service.dart';
import '../services/download_service.dart';
import '../providers/auth_provider.dart';
import 'keygen_step1_screen.dart';
import 'pgp_encrypt_screen.dart';
import 'pgp_decrypt_screen.dart';
import 'pgp_sign_screen.dart';
import 'pgp_verify_screen.dart';
import 'backup_recovery_screen.dart';

class ManagePgpScreen extends StatefulWidget {
  const ManagePgpScreen({super.key});

  @override
  State<ManagePgpScreen> createState() => _ManagePgpScreenState();
}

enum _KeySyncStatus { unknown, noKeys, localOnly, synced, syncing, error }

class _ManagePgpScreenState extends State<ManagePgpScreen> {
  final PgpService _pgp = PgpService();
  final ApiService _api = ApiService();

  _KeySyncStatus _syncStatus = _KeySyncStatus.unknown;
  bool _isBusy = false; // import or sync in progress
  String? _errorDetail;

  @override
  void initState() {
    super.initState();
    _pgp.addListener(_onPgpChanged);
    _refreshKeyStatus();
  }

  @override
  void dispose() {
    _pgp.removeListener(_onPgpChanged);
    super.dispose();
  }

  void _onPgpChanged() => _refreshKeyStatus();

  Future<void> _refreshKeyStatus() async {
    final hasPub = await _pgp.hasPublicKey;
    final hasPair = await _pgp.hasKeyPair;
    if (!mounted) return;

    if (!hasPub && !hasPair) {
      setState(() => _syncStatus = _KeySyncStatus.noKeys);
      return;
    }

    // Check if server has our key
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId != null) {
        final serverKey = await _api.getUserPublicKey(userId);
        final localKey = await _pgp.publicKey;
        if (serverKey != null &&
            localKey != null &&
            serverKey.replaceAll(RegExp(r'\s+'), '') ==
                localKey.replaceAll(RegExp(r'\s+'), '')) {
          if (mounted) setState(() => _syncStatus = _KeySyncStatus.synced);
          return;
        }
      }
    } catch (_) {
      // Network error — can't verify, assume local only
    }

    if (mounted) setState(() => _syncStatus = _KeySyncStatus.localOnly);
  }

  Future<String?> _readKeyFileSafely(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      if (bytes.isEmpty) return null;

      final sample = bytes.length > 2048 ? bytes.sublist(0, 2048) : bytes;
      final hasNullByte = sample.any((b) => b == 0);
      if (hasNullByte) return null;

      return utf8.decode(bytes, allowMalformed: false);
    } catch (_) {
      return null;
    }
  }

  /// Sync public key to server with up to [maxRetries] retries.
  Future<bool> _autoSyncPublicKey(String publicKey, {int maxRetries = 2}) async {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        await _api.updatePublicKey(publicKey);
        return true;
      } catch (_) {
        if (attempt < maxRetries) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }
    return false;
  }

  Future<void> _importKey(BuildContext context) async {
    setState(() {
      _isBusy = true;
      _errorDetail = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _isBusy = false);
        return;
      }

      final filePath = result.files.single.path;
      if (filePath == null) {
        setState(() => _isBusy = false);
        return;
      }

      final content = await _readKeyFileSafely(filePath);
      if (content == null) {
        setState(() => _isBusy = false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please choose a valid text-based PGP key file.'),
            ),
          );
        }
        return;
      }

      if (content.contains('BEGIN PGP PRIVATE KEY')) {
        // Also require the public key so we can upload it to the server
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Private key selected. Now pick your PUBLIC key file.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        final pubResult = await FilePicker.platform.pickFiles(
          type: FileType.any,
          allowMultiple: false,
        );
        String publicKey = '';
        if (pubResult != null && pubResult.files.single.path != null) {
          final pubContent = await _readKeyFileSafely(pubResult.files.single.path!);
          if (pubContent != null && pubContent.contains('BEGIN PGP PUBLIC KEY')) {
            publicKey = pubContent;
          }
        }
        await _pgp.importKeys(publicKey: publicKey, privateKey: content);

        // Auto-sync public key to server with retry
        var syncedToServer = false;
        if (publicKey.isNotEmpty) {
          if (mounted) setState(() => _syncStatus = _KeySyncStatus.syncing);
          syncedToServer = await _autoSyncPublicKey(publicKey);
        }

        await _refreshKeyStatus();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                publicKey.isEmpty
                    ? 'Private key imported. Import your public key too to enable syncing.'
                    : (syncedToServer
                        ? 'Key pair imported and synced to server ✓'
                        : 'Key pair imported locally. Auto-sync failed — tap "Sync public key to server".'),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else if (content.contains('BEGIN PGP PUBLIC KEY')) {
        await _pgp.importKeys(publicKey: content, privateKey: '');

        // Auto-sync public key to server with retry
        if (mounted) setState(() => _syncStatus = _KeySyncStatus.syncing);
        final syncedToServer = await _autoSyncPublicKey(content);

        await _refreshKeyStatus();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                syncedToServer
                    ? 'Public key imported and synced to server ✓'
                    : 'Public key imported locally. Auto-sync failed — tap "Sync public key to server".',
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid PGP key file — no PGP key block found')),
          );
        }
      }
    } on FormatException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } on ApiException catch (e) {
      setState(() => _errorDetail = e.message);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: ${e.message}')),
        );
      }
    } catch (e) {
      final msg = e.toString();
      setState(() => _errorDetail = msg);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg.contains('account context')
                  ? 'Please log in again before importing keys.'
                  : 'Could not import key. Please try again with a valid key file.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _syncPublicKeyToServer(BuildContext context) async {
    setState(() {
      _isBusy = true;
      _syncStatus = _KeySyncStatus.syncing;
    });

    final pubKey = await _pgp.publicKey;
    if (pubKey == null || pubKey.isEmpty) {
      setState(() {
        _isBusy = false;
        _syncStatus = _KeySyncStatus.noKeys;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No public key found on this device')),
        );
      }
      return;
    }

    final synced = await _autoSyncPublicKey(pubKey);
    await _refreshKeyStatus();
    setState(() => _isBusy = false);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            synced
                ? 'Public key synced to server successfully ✓'
                : 'Could not sync public key. Please check your connection and try again.',
          ),
        ),
      );
    }
  }

  Future<void> _downloadPublicKey(BuildContext context) async {
    final publicKey = await _pgp.publicKey;
    if (publicKey == null || publicKey.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No public key available')),
        );
      }
      return;
    }

    try {
      final fileName = 'PGP-${DateTime.now().millisecondsSinceEpoch}.txt';
      final savedPath = await DownloadService.downloadTextFile(
        fileName: fileName,
        content: publicKey,
      );

      if (savedPath == null) {
        return;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Platform.isAndroid
                  ? 'Public key downloaded successfully'
                  : 'Public key downloaded to $savedPath',
            ),
            action: Platform.isAndroid
                ? SnackBarAction(
                    label: 'Open',
                    onPressed: () async {
                      await DownloadService.openDownloads();
                    },
                  )
                : null,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not download public key. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _resetPgp(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset PGP Protocol',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
        content: const Text(
          'This will permanently delete all your PGP keys, messages, and contacts. This action cannot be undone.',
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
            child: const Text('Reset Everything',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().resetPgp();
      await _refreshKeyStatus();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PGP reset complete')),
        );
      }
    }
  }

  Widget _buildKeyStatusCard() {
    IconData icon;
    Color color;
    String title;
    String subtitle;

    switch (_syncStatus) {
      case _KeySyncStatus.unknown:
        icon = Icons.hourglass_top;
        color = AppColors.slate400;
        title = 'Checking key status…';
        subtitle = 'Verifying local and server keys';
      case _KeySyncStatus.noKeys:
        icon = Icons.key_off;
        color = AppColors.amber500;
        title = 'No PGP keys';
        subtitle = 'Generate or import a key pair to start';
      case _KeySyncStatus.localOnly:
        icon = Icons.warning_amber_rounded;
        color = AppColors.amber500;
        title = 'Keys stored locally only';
        subtitle = 'Public key not synced to server — others cannot encrypt to you';
      case _KeySyncStatus.synced:
        icon = Icons.check_circle;
        color = AppColors.emerald500;
        title = 'Keys loaded & synced';
        subtitle = 'Public key is up to date on the server';
      case _KeySyncStatus.syncing:
        icon = Icons.cloud_sync;
        color = AppColors.primary;
        title = 'Syncing to server…';
        subtitle = 'Uploading your public key';
      case _KeySyncStatus.error:
        icon = Icons.error_outline;
        color = Colors.red;
        title = 'Sync error';
        subtitle = _errorDetail ?? 'Could not sync key to server';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          _syncStatus == _KeySyncStatus.syncing
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: color,
                  ),
                )
              : Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.slate400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          ResponsiveScaffoldBody(
            child: SafeArea(
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundDark.withValues(alpha: 0.8),
                    border: Border(
                      bottom: BorderSide(color: AppColors.slate800),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios, size: 22),
                        color: AppColors.primary,
                      ),
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: 40),
                          child: Text(
                            'Manage PGP',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
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
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 32),
                    children: [
                      // Key Status Card
                      _buildKeyStatusCard(),
                  // Backup & Recovery Section
                  const _SectionTitle(title: 'Backup & Recovery'),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 0),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCardDark,
                      border: Border.symmetric(
                        horizontal: BorderSide(color: AppColors.slate800),
                      ),
                    ),
                    child: Column(
                      children: [
                        _SettingsItem(
                          icon: Icons.backup,
                          iconColor: AppColors.emerald500,
                          iconBgColor:
                              AppColors.emerald500.withValues(alpha: 0.1),
                          title: 'Backup & Recovery',
                          subtitle: 'Create and manage your recovery seed phrase',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const BackupRecoveryScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Key Management Section
                  const _SectionTitle(title: 'Key Management'),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 0),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCardDark,
                      border: Border.symmetric(
                        horizontal: BorderSide(color: AppColors.slate800),
                      ),
                    ),
                    child: Column(
                      children: [
                        _SettingsItem(
                          icon: Icons.download,
                          iconColor: AppColors.primary,
                          iconBgColor: AppColors.primary.withValues(alpha: 0.1),
                          title: 'Import PGP Key',
                          subtitle: 'Import existing private or public keys',
                          onTap: () => _importKey(context),
                        ),
                        _divider(),
                        _SettingsItem(
                          icon: Icons.cloud_upload,
                          iconColor: AppColors.primary,
                          iconBgColor: AppColors.primary.withValues(alpha: 0.1),
                          title: 'Sync public key to server',
                          subtitle: 'Re-upload your public key — fixes "incorrect key" decryption errors',
                          onTap: () => _syncPublicKeyToServer(context),
                        ),
                        _divider(),
                        _SettingsItem(
                          icon: Icons.key,
                          iconColor: AppColors.primary,
                          iconBgColor: AppColors.primary.withValues(alpha: 0.1),
                          title: 'Generate New Key',
                          subtitle: 'Create a new 4096-bit RSA key pair',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const KeygenStep1Screen()),
                            );
                          },
                        ),
                        _divider(),
                        _SettingsItem(
                          icon: Icons.description,
                          iconColor: AppColors.primary,
                          iconBgColor: AppColors.primary.withValues(alpha: 0.1),
                          title: 'Download Public Key',
                          subtitle: 'Save public key as PGP.txt',
                          onTap: () => _downloadPublicKey(context),
                        ),
                      ],
                    ),
                  ),

                  // Manual Tools Section
                  const _SectionTitle(title: 'PGP Tools'),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCardDark,
                      border: Border.symmetric(
                        horizontal: BorderSide(color: AppColors.slate800),
                      ),
                    ),
                    child: Column(
                      children: [
                        _SettingsItem(
                          icon: Icons.lock,
                          iconColor: AppColors.emerald500,
                          iconBgColor:
                              AppColors.emerald500.withValues(alpha: 0.1),
                          title: 'Encrypt Message',
                          subtitle: 'Encrypt text with a public key',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const PgpEncryptScreen()),
                            );
                          },
                        ),
                        _divider(),
                        _SettingsItem(
                          icon: Icons.lock_open,
                          iconColor: AppColors.amber500,
                          iconBgColor:
                              AppColors.amber500.withValues(alpha: 0.1),
                          title: 'Decrypt Message',
                          subtitle: 'Decrypt PGP encrypted text',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const PgpDecryptScreen()),
                            );
                          },
                        ),
                        _divider(),
                        _SettingsItem(
                          icon: Icons.draw,
                          iconColor: AppColors.purple500,
                          iconBgColor:
                              AppColors.purple500.withValues(alpha: 0.1),
                          title: 'Sign Message',
                          subtitle: 'Digitally sign a message',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const PgpSignScreen()),
                            );
                          },
                        ),
                        _divider(),
                        _SettingsItem(
                          icon: Icons.verified_user,
                          iconColor: AppColors.primary,
                          iconBgColor:
                              AppColors.primary.withValues(alpha: 0.1),
                          title: 'Verify Signature',
                          subtitle: 'Check if a signed message is authentic',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const PgpVerifyScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Danger Zone
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Material(
                      color: AppColors.surfaceCardDark,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => _resetPgp(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Column(
                            children: [
                              Text(
                                'Reset PGP Protocol',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Wipe all keys and local encrypted data',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0x99EF4444),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
          // Loading overlay
          if (_isBusy)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
                child: const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static Widget _divider() {
    return Container(
      margin: const EdgeInsets.only(left: 64),
      height: 1,
      color: AppColors.slate800,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMainDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.slate400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.slate400,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
