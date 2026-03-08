import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_center.dart';
import 'keygen_step3_screen.dart';

class KeygenStep2Screen extends StatefulWidget {
  final String name;
  final String email;

  const KeygenStep2Screen({
    super.key,
    required this.name,
    required this.email,
  });

  @override
  State<KeygenStep2Screen> createState() => _KeygenStep2ScreenState();
}

class _KeygenStep2ScreenState extends State<KeygenStep2Screen> {
  String _selectedAlgorithm = 'rsa';
  String _selectedKeySize = '4096';
  bool _obscurePassphrase = true;
  final _passphraseController = TextEditingController();

  @override
  void dispose() {
    _passphraseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: ResponsiveScaffoldBody(
        child: SafeArea(
        child: Column(
          children: [
            // Header with progress
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                color: AppColors.backgroundDark.withValues(alpha: 0.8),
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.slate800.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.slate800.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                          color: AppColors.slate300,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Key Parameters',
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
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: 0.66,
                      minHeight: 6,
                      backgroundColor: AppColors.slate800,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            // Main content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const Text(
                      'Algorithm Setup',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose the cryptographic algorithm and key size for your new PGP key pair, then secure it with a strong passphrase.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.slate400,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Algorithm Section
                    const Text(
                      'ALGORITHM',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: AppColors.slate400,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _AlgorithmOption(
                      title: 'RSA (Recommended)',
                      subtitle: 'Widely compatible, robust security.',
                      value: 'rsa',
                      selected: _selectedAlgorithm == 'rsa',
                      onTap: () =>
                          setState(() => _selectedAlgorithm = 'rsa'),
                    ),
                    const SizedBox(height: 12),
                    _AlgorithmOption(
                      title: 'ECC (Elliptic Curve)',
                      subtitle: 'Faster, smaller keys, modern security.',
                      value: 'ecc',
                      selected: _selectedAlgorithm == 'ecc',
                      onTap: () =>
                          setState(() => _selectedAlgorithm = 'ecc'),
                    ),

                    const SizedBox(height: 32),

                    // Key Length Section
                    const Text(
                      'KEY LENGTH',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: AppColors.slate400,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _KeySizeOption(
                            size: '2048',
                            label: 'Standard',
                            selected: _selectedKeySize == '2048',
                            onTap: () =>
                                setState(() => _selectedKeySize = '2048'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _KeySizeOption(
                            size: '4096',
                            label: 'High Security',
                            selected: _selectedKeySize == '4096',
                            onTap: () =>
                                setState(() => _selectedKeySize = '4096'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Passphrase Section
                    const Text(
                      'PASSPHRASE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: AppColors.slate400,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passphraseController,
                      obscureText: _obscurePassphrase,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Protect your key pair...',
                        hintStyle:
                            const TextStyle(color: AppColors.slate500),
                        filled: true,
                        fillColor:
                            AppColors.slate800.withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.slate800),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.slate800),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.primary),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                              () => _obscurePassphrase = !_obscurePassphrase),
                          icon: Icon(
                            _obscurePassphrase
                                ? Icons.visibility_off
                                : Icons.visibility,
                            size: 22,
                            color: AppColors.slate400,
                          ),
                        ),
                      ),
                    ),

                    // Strength Meter
                    const SizedBox(height: 12),
                    _StrengthMeter(
                        passphrase: _passphraseController.text),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
            // Bottom Action
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.backgroundDark.withValues(alpha: 0.0),
                    AppColors.backgroundDark,
                    AppColors.backgroundDark,
                  ],
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    final passphrase = _passphraseController.text;
                    if (passphrase.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please enter a passphrase')),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => KeygenStep3Screen(
                                name: widget.name,
                                email: widget.email,
                                passphrase: passphrase,
                                keyLength: int.parse(_selectedKeySize),
                              )),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    shadowColor: AppColors.primary.withValues(alpha: 0.2),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Generate Key Pair',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.vpn_key, size: 20),
                    ],
                  ),
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

class _AlgorithmOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _AlgorithmOption({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.slate800,
            width: selected ? 2 : 1,
          ),
          color: selected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.slate800.withValues(alpha: 0.3),
        ),
        child: Row(
          children: [
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
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.slate400,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.slate600,
                  width: selected ? 2 : 1,
                ),
                color: selected
                    ? AppColors.backgroundDark
                    : Colors.transparent,
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _KeySizeOption extends StatelessWidget {
  final String size;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _KeySizeOption({
    required this.size,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.slate800,
            width: selected ? 2 : 1,
          ),
          color: selected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.slate800.withValues(alpha: 0.3),
        ),
        child: Column(
          children: [
            Text(
              size,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.primary : AppColors.textMainDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.8)
                    : AppColors.slate400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StrengthMeter extends StatelessWidget {
  final String passphrase;

  const _StrengthMeter({required this.passphrase});

  int get _strength {
    if (passphrase.isEmpty) return 0;
    int score = 0;
    if (passphrase.length >= 4) score++;
    if (passphrase.length >= 8) score++;
    if (RegExp(r'[0-9]').hasMatch(passphrase)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(passphrase)) score++;
    return score;
  }

  String get _label {
    switch (_strength) {
      case 0:
        return '';
      case 1:
        return 'Weak';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Strong';
      default:
        return '';
    }
  }

  Color get _color {
    switch (_strength) {
      case 1:
        return Colors.red;
      case 2:
        return AppColors.yellow400;
      case 3:
        return AppColors.emerald500;
      case 4:
        return AppColors.emerald500;
      default:
        return AppColors.slate800;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: List.generate(4, (index) {
            return Expanded(
              child: Container(
                height: 6,
                margin: EdgeInsets.only(right: index < 3 ? 6 : 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: index < _strength ? _color : AppColors.slate800,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Use at least 8 characters, numbers & symbols.',
              style: TextStyle(fontSize: 12, color: AppColors.slate400),
            ),
            if (_label.isNotEmpty)
              Text(
                _label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _color,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
