import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/pgp_service.dart';
import '../services/api_service.dart';
import 'keygen_success_screen.dart';

class KeygenStep3Screen extends StatefulWidget {
  final String name;
  final String email;
  final String passphrase;
  final int keyLength;

  const KeygenStep3Screen({
    super.key,
    required this.name,
    required this.email,
    required this.passphrase,
    required this.keyLength,
  });

  @override
  State<KeygenStep3Screen> createState() => _KeygenStep3ScreenState();
}

class _KeygenStep3ScreenState extends State<KeygenStep3Screen>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinController;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _simulateProgress();
  }

  void _simulateProgress() async {
    // Start progress animation  
    for (int i = 0; i <= 50; i += 5) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      setState(() => _progress = i / 100);
    }

    // Actually generate the key pair
    try {
      final pgp = PgpService();
      final keyPair = await pgp.generateKeyPair(
        name: widget.name,
        email: widget.email,
        passphrase: widget.passphrase,
        keyLength: widget.keyLength,
      );

      // Upload public key to server
      await ApiService().updatePublicKey(keyPair.publicKey);

      if (!mounted) return;
      setState(() => _progress = 1.0);
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      final fingerprint = pgp.getFingerprint(keyPair.publicKey);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => KeygenSuccessScreen(fingerprint: fingerprint)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Key generation failed: $e')),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  const Spacer(),
                  const Text(
                    'Key Generation',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.015,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            // Progress dots
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildDot(false),
                  const SizedBox(width: 12),
                  _buildDot(false),
                  const SizedBox(width: 12),
                  _buildDot(true),
                ],
              ),
            ),
            // Main content
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Lock animation
                  Container(
                    width: 192,
                    height: 192,
                    decoration: BoxDecoration(
                      color: AppColors.slate800,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundDark,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: RotationTransition(
                          turns: _spinController,
                          child: const Icon(
                            Icons.lock,
                            size: 56,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'Generating your secure\nkey pair locally...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.015,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Do not close the app. Your private key stays on this device.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.slate400,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Progress Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 64),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _progress,
                            minHeight: 10,
                            backgroundColor: AppColors.slate800,
                            valueColor: const AlwaysStoppedAnimation(
                                AppColors.primary),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(_progress * 100).toInt()}% Complete',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.slate400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(bool active) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active
            ? AppColors.primary
            : AppColors.primary.withValues(alpha: 0.3),
      ),
    );
  }
}
