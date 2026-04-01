import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../theme/app_theme.dart';
import '../widgets/responsive_center.dart';
import '../services/pgp_service.dart';

class PgpVerifyScreen extends StatefulWidget {
  const PgpVerifyScreen({super.key});

  @override
  State<PgpVerifyScreen> createState() => _PgpVerifyScreenState();
}

class _PgpVerifyScreenState extends State<PgpVerifyScreen> {
  final _signatureCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _pubKeyCtrl = TextEditingController();
  final _pgp = PgpService();
  bool _loading = false;
  String? _error;
  bool? _verified; // null = not checked, true = valid, false = invalid

  @override
  void dispose() {
    _signatureCtrl.dispose();
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

  Future<void> _verify() async {
    if (_signatureCtrl.text.trim().isEmpty ||
        _messageCtrl.text.trim().isEmpty ||
        _pubKeyCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _verified = null;
    });
    try {
      final valid = await _pgp.verify(
        _signatureCtrl.text,
        _messageCtrl.text,
        _pubKeyCtrl.text,
      );
      setState(() {
        _verified = valid;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not verify signature. Check the message, signature, and public key, then try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Verify Signature'),
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
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.verified_user,
                      color: AppColors.primary, size: 32),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Verify PGP Signature',
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
                  'Check if a signed message is authentic',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSubDark),
                ),
              ),
              const SizedBox(height: 24),

              // Signed message / signature
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('SIGNED MESSAGE / SIGNATURE',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSubDark,
                          letterSpacing: 1.2)),
                  GestureDetector(
                    onTap: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null) {
                        _signatureCtrl.text = data!.text!;
                      }
                    },
                    child: const Row(
                      children: [
                        Icon(Icons.paste, size: 16, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text('Paste',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.primary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _signatureCtrl,
                maxLines: 6,
                style: const TextStyle(
                    color: AppColors.textMainDark,
                    fontSize: 12,
                    fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText:
                      '-----BEGIN PGP SIGNED MESSAGE-----\n...\n-----END PGP SIGNATURE-----',
                  hintStyle: const TextStyle(
                      color: AppColors.textSubDark, fontFamily: 'monospace'),
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

              // Original message
              const Text('ORIGINAL MESSAGE',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSubDark,
                      letterSpacing: 1.2)),
              const SizedBox(height: 8),
              TextField(
                controller: _messageCtrl,
                maxLines: 4,
                style: const TextStyle(
                    color: AppColors.textMainDark, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'The original plaintext message that was signed',
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

              // Signer public key
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('SIGNER PUBLIC KEY',
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
                  hintText: 'Paste the signer\'s PGP public key...',
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

              // Verify button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _verify,
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.verified_user, size: 20),
                  label: Text(
                      _loading ? 'Verifying...' : 'Verify Signature',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

              // Result
              if (_verified != null) ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _verified!
                        ? AppColors.emerald500.withValues(alpha: 0.1)
                        : AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _verified!
                          ? AppColors.emerald500.withValues(alpha: 0.3)
                          : AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _verified!
                            ? Icons.check_circle
                            : Icons.cancel,
                        color: _verified!
                            ? AppColors.emerald500
                            : AppColors.error,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _verified!
                            ? 'Signature Valid'
                            : 'Signature Invalid',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _verified!
                              ? AppColors.emerald500
                              : AppColors.error,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _verified!
                            ? 'The message was signed by the owner of the provided public key and has not been tampered with.'
                            : 'The signature does not match. The message may have been altered or was not signed by this key.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: _verified!
                              ? AppColors.emerald500.withValues(alpha: 0.8)
                              : AppColors.error.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
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
