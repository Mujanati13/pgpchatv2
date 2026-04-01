import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../theme/app_theme.dart';
import '../widgets/responsive_center.dart';
import '../services/pgp_service.dart';

class PgpEncryptScreen extends StatefulWidget {
  const PgpEncryptScreen({super.key});

  @override
  State<PgpEncryptScreen> createState() => _PgpEncryptScreenState();
}

class _PgpEncryptScreenState extends State<PgpEncryptScreen> {
  final _messageCtrl = TextEditingController();
  final _pubKeyCtrl = TextEditingController();
  final _pgp = PgpService();
  String? _result;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _messageCtrl.dispose();
    _pubKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _importPublicKey() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    final content = await File(path).readAsString();
    if (content.contains('BEGIN PGP PUBLIC KEY')) {
      _pubKeyCtrl.text = content;
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not a valid PGP public key file')),
        );
      }
    }
  }

  Future<void> _encrypt() async {
    if (_messageCtrl.text.trim().isEmpty || _pubKeyCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please fill in both fields');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final encrypted =
          await _pgp.encrypt(_messageCtrl.text, _pubKeyCtrl.text);
      setState(() {
        _result = encrypted;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not encrypt the message. Make sure the public key is valid and try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Encrypt Message'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ResponsiveScaffoldBody(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Icon header
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.emerald500.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.lock,
                      color: AppColors.emerald500, size: 32),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Encrypt with PGP',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMainDark,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Center(
                child: Text(
                  'Encrypt a message using a recipient\'s public key',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSubDark),
                ),
              ),
              const SizedBox(height: 24),

              // Recipient public key
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('RECIPIENT PUBLIC KEY',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSubDark,
                          letterSpacing: 1.2)),
                  GestureDetector(
                    onTap: _importPublicKey,
                    child: const Row(
                      children: [
                        Icon(Icons.file_upload_outlined,
                            size: 16, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text('Import file',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.primary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _pubKeyCtrl,
                maxLines: 4,
                style: const TextStyle(
                    color: AppColors.textMainDark,
                    fontSize: 13,
                    fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: 'Paste recipient\'s PGP public key here...',
                  hintStyle: const TextStyle(color: AppColors.textSubDark),
                  filled: true,
                  fillColor: AppColors.surfaceDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderDark),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderDark),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Message to encrypt
              const Text('MESSAGE',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSubDark,
                      letterSpacing: 1.2)),
              const SizedBox(height: 8),
              TextField(
                controller: _messageCtrl,
                maxLines: 5,
                style: const TextStyle(
                    color: AppColors.textMainDark, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Type or paste your message...',
                  hintStyle: const TextStyle(color: AppColors.textSubDark),
                  filled: true,
                  fillColor: AppColors.surfaceDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderDark),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderDark),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Error
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppColors.error, fontSize: 13)),
                      ),
                    ],
                  ),
                ),

              // Encrypt button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _encrypt,
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.lock, size: 20),
                  label: Text(_loading ? 'Encrypting...' : 'Encrypt',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald500,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

              // Result
              if (_result != null) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ENCRYPTED OUTPUT',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.emerald500,
                            letterSpacing: 1.2)),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _result!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Encrypted text copied')),
                        );
                      },
                      child: const Row(
                        children: [
                          Icon(Icons.copy, size: 16, color: AppColors.primary),
                          SizedBox(width: 4),
                          Text('Copy',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.emerald500.withValues(alpha: 0.3)),
                  ),
                  child: SelectableText(
                    _result!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: AppColors.textMainDark,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
