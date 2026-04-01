import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../theme/app_theme.dart';
import '../services/seed_backup_service.dart';
import '../services/api_service.dart';
import '../widgets/responsive_center.dart';

class BackupRecoveryScreen extends StatefulWidget {
  const BackupRecoveryScreen({super.key});

  @override
  State<BackupRecoveryScreen> createState() => _BackupRecoveryScreenState();
}

class _BackupRecoveryScreenState extends State<BackupRecoveryScreen> {
  final _seedBackup = SeedBackupService();
  final _api = ApiService();
  String? _seedPhrase;
  bool _showSeed = false;
  bool _loading = true;
  bool _syncing = false;
  String? _error;
  int _step = 0; // 0: view, 1: confirm, 2: done
  String? _syncStatus;

  @override
  void initState() {
    super.initState();
    _loadSeedPhrase();
  }

  Future<void> _loadSeedPhrase() async {
    try {
      final seed = await _seedBackup.getSeedPhrase();
      setState(() {
        _seedPhrase = seed;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading seed phrase';
        _loading = false;
      });
    }
  }

  Future<void> _generateNewSeed() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Generate New Seed Phrase?',
          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'This will replace your current backup seed phrase. Make sure you have it written down safely before proceeding.',
          style: TextStyle(color: AppColors.textSubDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSubDark)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Generate New', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final newSeed = _seedBackup.generateSeedPhrase();
      await _seedBackup.saveSeedPhrase(newSeed);
      setState(() {
        _seedPhrase = newSeed;
        _step = 0;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New seed phrase generated')),
        );
      }
    }
  }

  Future<void> _copySeedToClipboard() async {
    if (_seedPhrase == null) return;

    await Clipboard.setData(ClipboardData(text: _seedPhrase!));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seed phrase copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _confirmSeedPhrase() {
    setState(() => _step = 1);
  }

  Future<void> _syncCheckpointToServer() async {
    if (_seedPhrase == null) return;

    setState(() => _syncing = true);
    try {
      // Calculate checkpoint (SHA256 hash of seed phrase)
      final checkpoint = sha256.convert(utf8.encode(_seedPhrase!)).toString();

      // Send checkpoint to server
      await _api.backupSeedCheckpoint(checkpoint);

      if (mounted) {
        setState(() {
          _syncStatus = 'Checkpoint synced to server successfully!';
          _syncing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seed backup synced to server'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _syncStatus = 'Could not sync backup to server. Check your connection and try again.';
          _syncing = false;
        });
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
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
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
                      child: Text(
                        'Backup & Recovery',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                          color: AppColors.textMainDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              // Content
              if (_loading)
                Expanded(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  ),
                )
              else if (_error != null)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: const TextStyle(color: AppColors.textSubDark),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),

                        // Title
                        if (_step == 0) ...[
                          const Text(
                            'Recovery Seed Phrase',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMainDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Your 12-word seed phrase can be used to recover your account if you forget your password. Store it safely!',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSubDark,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Warning box
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber, color: Colors.orange, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'Keep it secure',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.orange,
                                          fontSize: 13,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Anyone with your seed phrase can recover your account. Never share it.',
                                        style: TextStyle(
                                          color: AppColors.textSubDark,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Seed display
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceDark,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.slate800),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Your Seed Phrase',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSubDark,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        _showSeed
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                        size: 18,
                                        color: AppColors.slate400,
                                      ),
                                      onPressed: () =>
                                          setState(() => _showSeed = !_showSeed),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.backgroundDark,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _showSeed
                                        ? (_seedPhrase ?? '')
                                        : _seedPhrase
                                                ?.split(' ')
                                                .map((word) => '••••')
                                                .join(' ') ??
                                            '',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontFamily: 'monospace',
                                      color: AppColors.textMainDark,
                                      height: 1.8,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 40,
                                  child: ElevatedButton.icon(
                                    onPressed: _copySeedToClipboard,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    icon: const Icon(Icons.content_copy, size: 18),
                                    label: const Text('Copy to Clipboard'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Action buttons
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _confirmSeedPhrase,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'I Have Saved This Seed Phrase',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: _generateNewSeed,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.orange),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.refresh, color: Colors.orange),
                              label: const Text(
                                'Generate New Seed',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ] else if (_step == 1) ...[
                          // Confirmation step
                          const Text(
                            'Verify Your Seed Phrase',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMainDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Select the correct words in order to confirm you have saved your seed phrase.',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSubDark,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Verification widget would go here (simplified)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceDark,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.slate800),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Verification UI would display 3 random words from your seed phrase to select.',
                                  style: TextStyle(
                                    color: AppColors.textSubDark,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() => _step = 2);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Back Up Complete',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ] else if (_step == 2) ...[
                          // Success step
                          const SizedBox(height: 32),
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle,
                              size: 48,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Backup Complete!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMainDark,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Your seed phrase has been securely stored on this device. You can now recover your account using this phrase if needed.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSubDark,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (_syncStatus != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _syncStatus!.contains('failed')
                                    ? Colors.red.withValues(alpha: 0.1)
                                    : AppColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _syncStatus!.contains('failed')
                                      ? Colors.red.withValues(alpha: 0.3)
                                      : AppColors.success.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _syncStatus!.contains('failed')
                                        ? Icons.error_outline
                                        : Icons.check_circle_outline,
                                    color: _syncStatus!.contains('failed')
                                        ? Colors.red
                                        : AppColors.success,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _syncStatus!,
                                      style: TextStyle(
                                        color: _syncStatus!.contains('failed')
                                            ? Colors.red
                                            : AppColors.success,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (_syncStatus == null) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _syncing ? null : _syncCheckpointToServer,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: _syncing
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : const Icon(Icons.cloud_upload, size: 18),
                                label: Text(_syncing
                                    ? 'Syncing...'
                                    : 'Sync Backup to Server'),
                              ),
                            ),
                          ],
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Done',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
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
