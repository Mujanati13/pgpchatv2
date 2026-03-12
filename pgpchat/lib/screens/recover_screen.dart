import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/pgp_service.dart';
import '../widgets/responsive_center.dart';

class RecoverScreen extends StatefulWidget {
  const RecoverScreen({super.key});

  @override
  State<RecoverScreen> createState() => _RecoverScreenState();
}

class _RecoverScreenState extends State<RecoverScreen> {
  final _api = ApiService();
  final _pgp = PgpService();

  final _usernameController = TextEditingController();
  final _passphraseController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  int _step = 0; // 0=username, 1=passphrase, 2=new password, 3=done
  bool _loading = false;
  bool _obscurePassphrase = true;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;
  String? _encryptedChallenge;
  String? _decryptedToken;

  @override
  void dispose() {
    _usernameController.dispose();
    _passphraseController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // Step 1: Request recovery challenge
  Future<void> _requestChallenge() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      setState(() => _error = 'Please enter your username');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      final result = await _api.requestRecovery(username);
      _encryptedChallenge = result['encryptedChallenge'] as String;
      setState(() { _step = 1; _loading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to request recovery'; _loading = false; });
    }
  }

  // Step 2: Decrypt challenge with PGP private key
  Future<void> _decryptChallenge() async {
    final passphrase = _passphraseController.text;
    if (passphrase.isEmpty) {
      setState(() => _error = 'Please enter your PGP passphrase');
      return;
    }

    final hasKey = await _pgp.hasKeyPair;
    if (!hasKey) {
      setState(() => _error = 'No PGP private key found on this device');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      _decryptedToken = (await _pgp.decrypt(_encryptedChallenge!, passphrase)).trim();
      setState(() { _step = 2; _loading = false; });
    } catch (e) {
      setState(() {
        _error = 'Decryption error: ${e.toString()}';
        _loading = false;
      });
    }
  }

  // Step 3: Submit new password
  Future<void> _resetPassword() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      await _api.confirmRecovery(
        _usernameController.text.trim(),
        _decryptedToken!,
        password,
      );
      setState(() { _step = 3; _loading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to reset password'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recover Password'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ResponsiveScaffoldBody(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      _step == 3 ? Icons.check_circle_outline : Icons.vpn_key_outlined,
                      size: 40,
                      color: _step == 3 ? AppColors.success : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    _step == 0
                        ? 'PGP Recovery'
                        : _step == 1
                            ? 'Decrypt Challenge'
                            : _step == 2
                                ? 'New Password'
                                : 'Password Reset',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMainDark,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    _step == 0
                        ? 'Enter your username to receive an encrypted challenge'
                        : _step == 1
                            ? 'Enter your PGP passphrase to decrypt the challenge token'
                            : _step == 2
                                ? 'Choose a new password for your account'
                                : 'Your password has been reset successfully',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSubDark,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Step indicator
                  if (_step < 3)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (i) => Container(
                        width: i == _step ? 24 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: i <= _step
                              ? AppColors.primary
                              : AppColors.borderDark,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      )),
                    ),
                  const SizedBox(height: 32),

                  // Error message
                  if (_error != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.error, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                  color: AppColors.error, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Step content
                  if (_step == 0) _buildUsernameStep(),
                  if (_step == 1) _buildPassphraseStep(),
                  if (_step == 2) _buildPasswordStep(),
                  if (_step == 3) _buildSuccessStep(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUsernameStep() {
    return Column(
      children: [
        TextField(
          controller: _usernameController,
          style: const TextStyle(color: AppColors.textMainDark),
          decoration: _inputDecoration('Username', Icons.person_outline),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _requestChallenge(),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.textSubDark, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You must have your PGP private key on this device to recover your account.',
                  style: TextStyle(color: AppColors.textSubDark, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildButton(
          'Request Recovery Challenge',
          _loading ? null : _requestChallenge,
        ),
      ],
    );
  }

  Widget _buildPassphraseStep() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.lock_outline, color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'An encrypted challenge has been generated. Decrypt it with your PGP key to prove your identity.',
                  style: TextStyle(color: AppColors.textSubDark, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passphraseController,
          obscureText: _obscurePassphrase,
          style: const TextStyle(color: AppColors.textMainDark),
          decoration: _inputDecoration('PGP Passphrase', Icons.vpn_key_outlined)
              .copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassphrase ? Icons.visibility_off : Icons.visibility,
                color: AppColors.textSubDark,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassphrase = !_obscurePassphrase),
            ),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _decryptChallenge(),
        ),
        const SizedBox(height: 24),
        _buildButton(
          'Decrypt & Verify',
          _loading ? null : _decryptChallenge,
        ),
      ],
    );
  }

  Widget _buildPasswordStep() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: AppColors.success, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Identity verified! Choose a new password.',
                  style: TextStyle(color: AppColors.textSubDark, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(color: AppColors.textMainDark),
          decoration:
              _inputDecoration('New Password', Icons.lock_outline).copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: AppColors.textSubDark,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmController,
          obscureText: _obscureConfirm,
          style: const TextStyle(color: AppColors.textMainDark),
          decoration:
              _inputDecoration('Confirm Password', Icons.lock_outline).copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                color: AppColors.textSubDark,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _resetPassword(),
        ),
        const SizedBox(height: 24),
        _buildButton(
          'Reset Password',
          _loading ? null : _resetPassword,
        ),
      ],
    );
  }

  Widget _buildSuccessStep() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
          ),
          child: const Column(
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 48),
              SizedBox(height: 12),
              Text(
                'All existing sessions have been terminated for security.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSubDark, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildButton('Back to Login', () => Navigator.pop(context)),
      ],
    );
  }

  Widget _buildButton(String label, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textSubDark, fontSize: 14),
      prefixIcon: Icon(icon, color: AppColors.textSubDark, size: 20),
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
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
