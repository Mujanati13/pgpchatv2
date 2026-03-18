import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../theme/app_theme.dart';
import '../widgets/responsive_center.dart';
import '../services/pgp_service.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import 'keygen_step1_screen.dart';
import 'pgp_encrypt_screen.dart';
import 'pgp_decrypt_screen.dart';
import 'pgp_sign_screen.dart';
import 'pgp_verify_screen.dart';

class ManagePgpScreen extends StatelessWidget {
  const ManagePgpScreen({super.key});

  Future<void> _importKey(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.single.path;
    if (filePath == null) return;

    final content = await File(filePath).readAsString();
    final pgp = PgpService();

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
        final pubContent = await File(pubResult.files.single.path!).readAsString();
        if (pubContent.contains('BEGIN PGP PUBLIC KEY')) {
          publicKey = pubContent;
        }
      }
      await pgp.importKeys(publicKey: publicKey, privateKey: content);
      if (publicKey.isNotEmpty) {
        await ApiService().updatePublicKey(publicKey);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(publicKey.isNotEmpty
                ? 'Key pair imported and synced to server'
                : 'Private key imported (public key not provided — tap "Sync public key to server" to fix)'),
          ),
        );
      }
    } else if (content.contains('BEGIN PGP PUBLIC KEY')) {
      await pgp.importKeys(publicKey: content, privateKey: '');
      // Also upload to server
      await ApiService().updatePublicKey(content);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Public key imported and uploaded')),
        );
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid PGP key file')),
        );
      }
    }
  }

  Future<void> _syncPublicKeyToServer(BuildContext context) async {
    final pgp = PgpService();
    final pubKey = await pgp.publicKey;
    if (pubKey == null || pubKey.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No public key found on this device')),
        );
      }
      return;
    }
    try {
      await ApiService().updatePublicKey(pubKey);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Public key synced to server successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    }
  }

  Future<void> _downloadPublicKey(BuildContext context) async {
    final pgp = PgpService();
    final hasKey = await pgp.hasKeyPair;
    if (!hasKey) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No key pair generated yet')),
        );
      }
      return;
    }
    final file = await pgp.exportPublicKey();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Public key saved to ${file.path}')),
      );
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PGP reset complete')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: ResponsiveScaffoldBody(
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
