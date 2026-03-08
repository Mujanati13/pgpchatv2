import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_center.dart';
import '../services/pgp_service.dart';
import 'chat_list_screen.dart';

class KeygenSuccessScreen extends StatelessWidget {
  final String? fingerprint;

  const KeygenSuccessScreen({super.key, this.fingerprint});

  static const Color _successGreen = AppColors.successPrimary;
  static const Color _successBgDark = AppColors.successBackgroundDark;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _successBgDark,
      body: ResponsiveScaffoldBody(
        child: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 22),
                    color: _successGreen,
                  ),
                  const Expanded(
                    child: Text(
                      'Key Generation',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        color: AppColors.textMainDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 48),
                    // Success Graphic
                    Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        color: _successGreen.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        size: 72,
                        color: _successGreen,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Header Text
                    const Text(
                      'Success!',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: AppColors.textMainDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your keys are now stored in the local encrypted database.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.slate400,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Fingerprint Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Left accent bar
                          Positioned(
                            left: -20,
                            top: -20,
                            bottom: -20,
                            child: Container(
                              width: 4,
                              color: _successGreen,
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'PGP FINGERPRINT',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 2,
                                      color: _successGreen,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      final fp = fingerprint ?? '';
                                      if (fp.isNotEmpty) {
                                        Clipboard.setData(ClipboardData(text: fp));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Fingerprint copied to clipboard')),
                                        );
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.content_copy,
                                      size: 18,
                                      color: AppColors.slate400,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                fingerprint ?? 'Fingerprint unavailable',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'monospace',
                                  color: AppColors.slate200,
                                  letterSpacing: 1.5,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Action Buttons
                    _ActionButton(
                      icon: Icons.vpn_key,
                      label: 'Backup Private Key',
                      onTap: () async {
                        try {
                          final file = await PgpService().exportPrivateKey();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Saved to ${file.path}')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      },
                      bgColor: Colors.white.withValues(alpha: 0.1),
                      textColor: AppColors.textMainDark,
                    ),
                    const SizedBox(height: 12),
                    _ActionButton(
                      icon: Icons.share,
                      label: 'Share Public Key',
                      onTap: () async {
                        try {
                          final file = await PgpService().exportPublicKey();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Saved to ${file.path}')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      },
                      bgColor: Colors.white.withValues(alpha: 0.1),
                      textColor: AppColors.textMainDark,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (_) => const ChatListScreen()),
                            (_) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _successGreen,
                          foregroundColor: const Color(0xFF0F172A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 8,
                          shadowColor: _successGreen.withValues(alpha: 0.39),
                        ),
                        child: const Text(
                          'Finish',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color bgColor;
  final Color textColor;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: textColor),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
