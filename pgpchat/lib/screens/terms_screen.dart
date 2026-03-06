import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('1. Acceptance of Terms'),
            _sectionBody(
              'By accessing and using PGP Chat ("the Application"), you accept and '
              'agree to be bound by the terms and provisions of this agreement. '
              'If you do not agree to abide by the above, please do not use this service.',
            ),
            const SizedBox(height: 20),
            _sectionTitle('2. Privacy & Encryption'),
            _sectionBody(
              'PGP Chat uses end-to-end encryption. All PGP key generation, encryption, '
              'and decryption operations occur exclusively on your device. Your private keys '
              'are never transmitted to or stored on our servers. We employ a zero-knowledge '
              'architecture — we cannot read your messages or access your private keys.',
            ),
            const SizedBox(height: 20),
            _sectionTitle('3. Data Retention'),
            _sectionBody(
              'Messages are stored on our servers in encrypted form only. Auto-delete is '
              'enabled by default (24 hours). You can adjust the retention period or '
              'disable auto-delete in your settings. IP logs are automatically wiped '
              'every 60 minutes as part of our zero-knowledge policy.',
            ),
            const SizedBox(height: 20),
            _sectionTitle('4. User Responsibilities'),
            _sectionBody(
              'You are responsible for maintaining the security of your PGP keys and '
              'account credentials. You agree not to use the Application for any unlawful '
              'purpose or in violation of any applicable laws. You are solely responsible '
              'for backing up your PGP private keys.',
            ),
            const SizedBox(height: 20),
            _sectionTitle('5. PGP Key Management'),
            _sectionBody(
              'You may generate, import, export, and reset your PGP keys at any time. '
              'Performing a PGP Reset will permanently delete all your messages, contacts, '
              'and key associations from the server. This action cannot be undone.',
            ),
            const SizedBox(height: 20),
            _sectionTitle('6. Contact Management'),
            _sectionBody(
              'The contacts feature is disabled by default. When enabled, you can add, '
              'remove, and block contacts. Blocked contacts cannot send you messages. '
              'You may also block users by their PGP key fingerprint.',
            ),
            const SizedBox(height: 20),
            _sectionTitle('7. Device Sessions'),
            _sectionBody(
              'You can manage your active sessions and terminate access from specific '
              'devices. We track device type and last activity time for session management '
              'purposes. You may terminate all sessions at any time.',
            ),
            const SizedBox(height: 20),
            _sectionTitle('8. Limitation of Liability'),
            _sectionBody(
              'The Application is provided "as is" without warranty of any kind. We are '
              'not responsible for any loss of data, including messages or PGP keys, '
              'that may result from the use or inability to use the Application.',
            ),
            const SizedBox(height: 20),
            _sectionTitle('9. Changes to Terms'),
            _sectionBody(
              'We reserve the right to modify these terms at any time. Continued use '
              'of the Application after changes constitutes acceptance of the new terms.',
            ),
            const SizedBox(height: 32),
            Center(
              child: Text(
                'Last updated: ${DateTime.now().year}',
                style: const TextStyle(
                  color: AppColors.textSubDark,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textMainDark,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _sectionBody(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textSubDark,
        fontSize: 14,
        height: 1.6,
      ),
    );
  }
}
