import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_center.dart';
import '../services/pgp_service.dart';

class PgpDecryptScreen extends StatefulWidget {
  const PgpDecryptScreen({super.key});

  @override
  State<PgpDecryptScreen> createState() => _PgpDecryptScreenState();
}

class _PgpDecryptScreenState extends State<PgpDecryptScreen> {
  final _messageCtrl = TextEditingController();
  final _passphraseCtrl = TextEditingController();
  final _pgp = PgpService();
  String? _result;
  bool _loading = false;
  String? _error;
  bool _obscurePassphrase = true;

  @override
  void dispose() {
    _messageCtrl.dispose();
    _passphraseCtrl.dispose();
    super.dispose();
  }

  Future<void> _decrypt() async {
    if (_messageCtrl.text.trim().isEmpty ||
        _passphraseCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please fill in both fields');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final decrypted =
          await _pgp.decrypt(_messageCtrl.text, _passphraseCtrl.text);
      setState(() {
        _result = decrypted.trim();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Decryption failed: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Decrypt Message'),
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
                    color: AppColors.amber500.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.lock_open,
                      color: AppColors.amber500, size: 32),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Decrypt with PGP',
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
                  'Decrypt an encrypted PGP message with your private key',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSubDark),
                ),
              ),
              const SizedBox(height: 24),

              // Encrypted message input
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ENCRYPTED MESSAGE',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSubDark,
                          letterSpacing: 1.2)),
                  GestureDetector(
                    onTap: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null) {
                        _messageCtrl.text = data!.text!;
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
                controller: _messageCtrl,
                maxLines: 6,
                style: const TextStyle(
                    color: AppColors.textMainDark,
                    fontSize: 12,
                    fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText:
                      '-----BEGIN PGP MESSAGE-----\n...\n-----END PGP MESSAGE-----',
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

              // Passphrase
              const Text('PASSPHRASE',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSubDark,
                      letterSpacing: 1.2)),
              const SizedBox(height: 8),
              TextField(
                controller: _passphraseCtrl,
                obscureText: _obscurePassphrase,
                style: const TextStyle(
                    color: AppColors.textMainDark, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter your PGP passphrase',
                  hintStyle: const TextStyle(color: AppColors.textSubDark),
                  filled: true,
                  fillColor: AppColors.surfaceDark,
                  prefixIcon: const Icon(Icons.key,
                      color: AppColors.textSubDark, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassphrase
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: AppColors.textSubDark,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassphrase = !_obscurePassphrase),
                  ),
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

              // Decrypt button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _decrypt,
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.lock_open, size: 20),
                  label: Text(_loading ? 'Decrypting...' : 'Decrypt',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.amber500,
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
                    const Text('DECRYPTED OUTPUT',
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
                              content: Text('Decrypted text copied')),
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
                      fontSize: 14,
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
