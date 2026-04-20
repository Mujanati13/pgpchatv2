import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/pgp_service.dart';
import '../services/seed_backup_service.dart';
import '../widgets/responsive_center.dart';

class RecoverScreen extends StatefulWidget {
  const RecoverScreen({super.key});

  @override
  State<RecoverScreen> createState() => _RecoverScreenState();
}

class _RecoverScreenState extends State<RecoverScreen> {
  final _api = ApiService();
  final _pgp = PgpService();
  final _seedBackup = SeedBackupService();

  final _usernameController = TextEditingController();
  final _passphraseController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _seedPhraseController = TextEditingController();

  // Recovery method: 'pgp' or 'seed'
  String _recoveryMethod = '';

  // Steps depend on recovery method
  // PGP: 0=method selection, 1=username, 2=passphrase, 3=new password, 4=done
  // Seed: 0=method selection, 1=username, 2=seed phrase, 3=new password, 4=done
  int _step = 0;
  bool _loading = false;
  bool _obscurePassphrase = true;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;
  String? _encryptedChallenge;
  String? _decryptedToken;

  String _friendlyRecoverError(Object error) {
    final raw = error.toString().replaceFirst(RegExp(r'^Exception:\\s*'), '');
    final lower = raw.toLowerCase();

    if (lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('connection') ||
        lower.contains('timeout')) {
      return 'Could not connect to the server. Please check your internet and try again.';
    }

    if (lower.contains('seed phrase')) {
      return raw;
    }

    return 'Something went wrong. Please try again.';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passphraseController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _seedPhraseController.dispose();
    super.dispose();
  }

  // Step 0: Select recovery method
  void _selectRecoveryMethod(String method) {
    setState(() {
      _recoveryMethod = method;
      _error = null;
      _step = 1;
    });
  }

  // Step 1: Request recovery challenge (PGP only)
  Future<void> _requestChallenge() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      setState(() => _error = 'Please enter your username');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      final result = await _api.post('/auth/recover-request', body: {
        'username': username,
        'recoveryMethod': 'pgp',
      });
      _encryptedChallenge = result['encryptedChallenge'] as String;
      setState(() { _step = 2; _loading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      setState(() { _error = _friendlyRecoverError(e); _loading = false; });
    }
  }

  // Alternative Step 1: Request recovery via seed phrase
  Future<void> _requestSeedRecovery() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      setState(() => _error = 'Please enter your username');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      // API call to initiate seed-based recovery
      await _api.post('/auth/recover-request', body: {
        'username': username,
        'recoveryMethod': 'seed',
      });
      // Move directly to seed verification step
      setState(() { _step = 2; _loading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      setState(() { _error = _friendlyRecoverError(e); _loading = false; });
    }
  }

  // Step 2a: Decrypt challenge with PGP private key
  Future<void> _decryptChallenge() async {
    final username = _usernameController.text.trim();
    final passphrase = _passphraseController.text;
    if (passphrase.isEmpty) {
      setState(() => _error = 'Please enter your PGP passphrase');
      return;
    }

    final hasKey = await _pgp.hasKeyPairForAccount(username: username);
    if (!hasKey) {
      setState(() => _error = 'No PGP private key found on this device');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      final decrypted = (await _pgp.decryptForAccount(
        _encryptedChallenge!,
        passphrase,
        username: username,
      )).trim();
      if (decrypted.isEmpty) {
        throw Exception('Decryption returned empty token');
      }
      _decryptedToken = decrypted;
      setState(() { _step = 3; _error = null; _loading = false; });
    } catch (e) {
      setState(() {
        _error = 'Could not decrypt the recovery challenge. Check your passphrase and private key, then try again.';
        _decryptedToken = null;
        _loading = false;
      });
    }
  }

  // Step 2b: Verify seed phrase
  Future<void> _verifySeedPhrase() async {
    final seedPhrase = _seedPhraseController.text.trim();
    if (seedPhrase.isEmpty) {
      setState(() => _error = 'Please enter your seed phrase');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      // Validate seed phrase format
      if (!_seedBackup.validateSeedPhrase(seedPhrase)) {
        throw Exception('Invalid seed phrase format (must be 12 words)');
      }

      // Verify against stored checkpoint
      final isValid = await _seedBackup.verifySeedPhrase(seedPhrase);
      if (!isValid) {
        throw Exception('Seed phrase does not match. Please check and try again.');
      }

      // Derive recovery token from seed phrase
      final token = _seedBackup.deriveRecoveryToken(seedPhrase);
      if (token.isEmpty) {
        throw Exception('Failed to derive recovery token');
      }
      _decryptedToken = token;
      setState(() { _step = 3; _error = null; _loading = false; });
    } catch (e) {
      setState(() {
        _error = _friendlyRecoverError(e);
        _decryptedToken = null;
        _loading = false;
      });
    }
  }

  // Step 3: Submit new password
  Future<void> _resetPassword() async {
    if (_decryptedToken == null || _decryptedToken!.isEmpty) {
      setState(() => _error = 'Invalid state: Recovery token is missing. Please go back and verify your identity again.');
      return;
    }

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
        method: _recoveryMethod,
      );
      setState(() { _step = 4; _loading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      setState(() { _error = _friendlyRecoverError(e); _loading = false; });
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
                      _step == 4 ? Icons.check_circle_outline : Icons.vpn_key_outlined,
                      size: 40,
                      color: _step == 4 ? AppColors.success : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    _step == 0
                        ? 'Account Recovery'
                        : _step == 1
                            ? 'Enter Username'
                            : (_recoveryMethod == 'pgp'
                                ? (_step == 2 ? 'Decrypt Challenge' : _step == 3 ? 'New Password' : 'Password Reset')
                                : (_step == 2 ? 'Enter Seed Phrase' : _step == 3 ? 'New Password' : 'Password Reset')),
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
                        ? 'Choose how you want to recover your account'
                        : _step == 1
                            ? 'Enter your username to proceed with recovery'
                            : (_recoveryMethod == 'pgp'
                                ? (_step == 2
                                    ? 'Enter your PGP passphrase to decrypt the challenge token'
                                    : _step == 3
                                        ? 'Choose a new password for your account'
                                        : 'Your password has been reset successfully')
                                : (_step == 2
                                    ? 'Enter your 12-word seed phrase to verify your identity'
                                    : _step == 3
                                        ? 'Choose a new password for your account'
                                        : 'Your password has been reset successfully')),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSubDark,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Step indicator
                  if (_step < 4)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (i) => Container(
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
                  if (_step == 0) _buildMethodSelection(),
                  if (_step == 1) _buildUsernameStep(),
                  if (_step == 2 && _recoveryMethod == 'pgp') _buildPassphraseStep(),
                  if (_step == 2 && _recoveryMethod == 'seed') _buildSeedPhraseStep(),
                  if (_step == 3) _buildPasswordStep(),
                  if (_step == 4) _buildSuccessStep(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMethodSelection() {
    return Column(
      children: [
        // PGP Method
        _RecoveryMethodCard(
          icon: Icons.vpn_key,
          title: 'PGP Private Key',
          description: 'Decrypt challenge with your PGP passphrase',
          onTap: () => _selectRecoveryMethod('pgp'),
        ),
        const SizedBox(height: 16),

        // Seed Phrase Method
        _RecoveryMethodCard(
          icon: Icons.text_fields,
          title: 'Seed Phrase',
          description: 'Use your 12-word recovery seed phrase',
          onTap: () => _selectRecoveryMethod('seed'),
        ),
      ],
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
          onSubmitted: (_) => _recoveryMethod == 'pgp' ? _requestChallenge() : _requestSeedRecovery(),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.textSubDark, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _recoveryMethod == 'pgp'
                      ? 'You must have your PGP private key on this device to recover your account.'
                      : 'You must have your recovery seed phrase saved to proceed.',
                  style: const TextStyle(color: AppColors.textSubDark, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildButton(
          _recoveryMethod == 'pgp' ? 'Request Recovery Challenge' : 'Verify Username',
          _loading ? null : (_recoveryMethod == 'pgp' ? _requestChallenge : _requestSeedRecovery),
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

  Widget _buildSeedPhraseStep() {
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
              Icon(Icons.text_fields, color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Enter your 12-word seed phrase to verify your identity and reset your password.',
                  style: TextStyle(color: AppColors.textSubDark, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _seedPhraseController,
          style: const TextStyle(color: AppColors.textMainDark),
          decoration: _inputDecoration('Seed Phrase', Icons.text_fields)
              .copyWith(
                hintText: 'Enter 12 words separated by spaces',
              ),
          maxLines: 4,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _verifySeedPhrase(),
        ),
        const SizedBox(height: 24),
        _buildButton(
          'Verify Seed Phrase',
          _loading ? null : _verifySeedPhrase,
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

class _RecoveryMethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _RecoveryMethodCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 28),
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
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMainDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSubDark,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.slate400, size: 24),
          ],
        ),
      ),
    );
  }
}
